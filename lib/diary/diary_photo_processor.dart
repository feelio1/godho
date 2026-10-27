import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import '../utils/appointment_calendar.dart' show dateOnly;

/// 일기 사진 업로드 전 처리 결과 — 책 인쇄용 원본과 작게 보이는 곳에 쓸
/// 썸네일 2벌("일기 활성화" 지시서 A). 두 벌 모두 EXIF를 전부 지운 상태로
/// 인코딩한다(위치 등 메타데이터를 업로드 파일에 남기지 않음) — 인코딩
/// 전에 원본의 방향(orientation) 태그는 픽셀에 반영해 두어 세로·회전된
/// 사진이 그대로 보이게 한다.
class ProcessedDiaryPhoto {
  final Uint8List mainBytes;
  final Uint8List thumbBytes;
  final int width;
  final int height;

  const ProcessedDiaryPhoto({
    required this.mainBytes,
    required this.thumbBytes,
    required this.width,
    required this.height,
  });
}

/// 원본(인쇄용) 긴 변 — 기존 품질(JPEG 85) 그대로 유지한다.
const int kDiaryPhotoMainLongSide = 2048;
const int kDiaryPhotoMainQuality = 85;

/// 목록·캘린더·홈 카드 등 작게 보이는 곳에 쓰는 썸네일.
const int kDiaryPhotoThumbLongSide = 480;
const int kDiaryPhotoThumbQuality = 75;

/// [bytes]를 디코딩해 원본(최대 [kDiaryPhotoMainLongSide])·썸네일(최대
/// [kDiaryPhotoThumbLongSide]) 2벌의 JPEG를 만든다. 디코딩할 수 없는
/// 파일(깨진 파일 등)이면 null.
ProcessedDiaryPhoto? processDiaryPhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final main = _fitLongSideStripped(decoded, kDiaryPhotoMainLongSide);
  final thumb = _fitLongSideStripped(decoded, kDiaryPhotoThumbLongSide);

  return ProcessedDiaryPhoto(
    mainBytes: img.encodeJpg(main, quality: kDiaryPhotoMainQuality),
    thumbBytes: img.encodeJpg(thumb, quality: kDiaryPhotoThumbQuality),
    width: main.width,
    height: main.height,
  );
}

/// 한 장씩 부를 때마다 부른다(1-based [index], [total]은 전체 장수) —
/// 저장 화면이 "사진 준비 중 (n/m)"을 보여주는 데 쓴다.
typedef DiaryPhotoProgressListener = void Function(int index, int total);

/// [files]를 한 장씩 순차로(동시에 여러 장을 메모리에 올리지 않도록)
/// 처리한다 — 무거운 디코딩·리사이즈·인코딩([processDiaryPhoto])은
/// [compute]로 메인 isolate 밖에서 돌려 화면이 멈추지 않게 한다("일기
/// 보완" 지시서 1). 디코딩에 실패한 자리는 결과 목록에 null로 남는다
/// (예외를 던지지 않음) — 호출부(저장소)가 그 사진만 빼고 계속 올릴 수
/// 있게 한다.
Future<List<ProcessedDiaryPhoto?>> processDiaryPhotosSequentially(
  List<File> files, {
  DiaryPhotoProgressListener? onProgress,
}) async {
  final results = <ProcessedDiaryPhoto?>[];
  for (var i = 0; i < files.length; i++) {
    onProgress?.call(i + 1, files.length);
    final bytes = await files[i].readAsBytes();
    results.add(await compute(processDiaryPhoto, bytes));
  }
  return results;
}

/// 긴 변을 [maxLongSide] 이하로 맞추고(원본이 더 작으면 그대로 둔다) EXIF를
/// 전부 비운다 — [img.copyResize]가 원본의 방향(orientation) 태그를 보고
/// 먼저 픽셀을 바로 돌려주므로, 크기가 그대로여도 리사이즈 호출을 거쳐야
/// 회전이 반영된다.
img.Image _fitLongSideStripped(img.Image src, int maxLongSide) {
  final longSide = src.width >= src.height ? src.width : src.height;
  final target = longSide > maxLongSide ? maxLongSide : longSide;
  final resized = src.width >= src.height
      ? img.copyResize(src, width: target)
      : img.copyResize(src, height: target);
  resized.exif = img.ExifData();
  return resized;
}

final _exifDateTimePattern = RegExp(r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})');

/// 사진의 EXIF 촬영일(DateTimeOriginal)을 읽는다 — 위치(GPS) 등 다른 EXIF는
/// 읽지 않는다("일기 활성화" 지시서 C). JPEG가 아니거나 태그가 없으면
/// null.
DateTime? readDiaryPhotoCaptureDate(Uint8List bytes) {
  final exif = img.decodeJpgExif(bytes) ?? img.decodeImage(bytes)?.exif;
  if (exif == null) return null;
  final raw = exif.exifIfd['DateTimeOriginal']?.toString();
  if (raw == null || raw.isEmpty) return null;
  return _parseExifDateTime(raw);
}

DateTime? _parseExifDateTime(String raw) {
  final match = _exifDateTimePattern.firstMatch(raw.trim());
  if (match == null) return null;
  try {
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  } catch (_) {
    return null;
  }
}

/// 여러 장의 EXIF 촬영일 중 일기 날짜로 제안할 값을 고른다 — 가장 이른
/// 날(시각은 버림)을 쓰고, 미래 날짜는 후보에서 제외한다("가장 이른 날짜를
/// 일기 날짜로 제안", "미래 날짜거나 정보가 없으면 오늘 유지"). 쓸 수
/// 있는 후보가 없으면 null — 호출부는 현재 날짜를 그대로 둔다.
DateTime? suggestDiaryDateFromCaptureDates(List<DateTime?> captureDates, {DateTime? today}) {
  final todayOnly = dateOnly(today ?? DateTime.now());
  final candidates = captureDates.whereType<DateTime>().map(dateOnly).where((d) => !d.isAfter(todayOnly)).toList()
    ..sort();
  return candidates.isEmpty ? null : candidates.first;
}
