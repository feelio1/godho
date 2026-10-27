import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

import '../utils/appointment_calendar.dart' show dateOnly;

/// 일기 사진 업로드 전 처리 결과 — 책 인쇄용 원본과 작게 보이는 곳에 쓸
/// 썸네일 2벌("일기 활성화" 지시서 A). 두 벌 모두 EXIF를 전부 지운 상태로
/// 인코딩한다(위치 등 메타데이터를 업로드 파일에 남기지 않음) — 네이티브
/// 압축기가 방향(orientation)도 픽셀에 반영해 두어 회전된 사진이 그대로
/// 보이게 한다("일기 수정" 지시서 1).
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

void _logTiming(String label, Stopwatch stopwatch) {
  // release 빌드에서는 아무것도 찍지 않는다("일기 수정" 지시서 1-6).
  if (kDebugMode) {
    debugPrint('[DiaryPhotoTiming] $label ${stopwatch.elapsedMilliseconds}ms');
  }
}

/// [filePath]의 원본 파일을 네이티브 압축기(`flutter_image_compress`)로
/// 직접 처리한다 — 순수 Dart 전체 디코딩(기존 `image` 패키지 경로)이
/// 고해상도 사진(수천만 화소급)에서 사진당 수 초~10초 이상 걸리던 문제를
/// 없앤다("일기 수정" 지시서 1). 썸네일은 원본을 다시 파일에서 읽지 않고
/// 이미 압축된 원본 바이트에서 만든다(한 번만 큰 파일을 건드린다).
/// 네이티브 쪽이 null을 돌려주거나 예외를 던지면(처리할 수 없는 파일)
/// null을 돌려준다 — 호출부가 그 사진만 빼고 계속 진행할 수 있게 한다.
Future<ProcessedDiaryPhoto?> processDiaryPhotoNative(String filePath) async {
  final totalStopwatch = Stopwatch()..start();
  try {
    final mainStopwatch = Stopwatch()..start();
    final mainBytes = await FlutterImageCompress.compressWithFile(
      filePath,
      minWidth: kDiaryPhotoMainLongSide,
      minHeight: kDiaryPhotoMainLongSide,
      quality: kDiaryPhotoMainQuality,
      keepExif: false,
    );
    _logTiming('원본 압축($filePath)', mainStopwatch);
    if (mainBytes == null) return null;

    final thumbStopwatch = Stopwatch()..start();
    final thumbBytes = await FlutterImageCompress.compressWithList(
      mainBytes,
      minWidth: kDiaryPhotoThumbLongSide,
      minHeight: kDiaryPhotoThumbLongSide,
      quality: kDiaryPhotoThumbQuality,
      keepExif: false,
    );
    _logTiming('썸네일 압축($filePath)', thumbStopwatch);

    final size = _peekJpegSize(mainBytes);
    if (size == null) return null;

    return ProcessedDiaryPhoto(
      mainBytes: mainBytes,
      thumbBytes: thumbBytes,
      width: size.width,
      height: size.height,
    );
  } catch (e) {
    if (kDebugMode) debugPrint('[DiaryPhotoTiming] 처리 실패($filePath): $e');
    return null;
  } finally {
    _logTiming('전체 처리($filePath)', totalStopwatch);
  }
}

/// 압축된(이미 2048px 이하로 작은) 결과물의 가로·세로만 가볍게 읽는다 —
/// JPEG 마커만 훑고 실제 픽셀은 디코딩하지 않는[img.JpegDecoder.startDecode]
/// 를 쓴다(이미 작으니 전체 디코딩도 빠르겠지만, 굳이 더 할 필요가 없다).
({int width, int height})? _peekJpegSize(Uint8List jpegBytes) {
  try {
    final info = img.JpegDecoder().startDecode(jpegBytes);
    if (info == null) return null;
    return (width: info.width, height: info.height);
  } catch (_) {
    return null;
  }
}

/// EXIF 헤더를 찾는 데 충분한, 파일 앞부분만 읽는 크기 — 전체 파일을
/// 읽지 않는다("일기 수정" 지시서 1-2).
const int kDiaryPhotoExifHeaderBytes = 256 * 1024;

final _exifDateTimePattern = RegExp(r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})');

/// [file]의 EXIF 촬영일(DateTimeOriginal)을 파일 앞부분(최대
/// [kDiaryPhotoExifHeaderBytes])만 읽어 알아낸다 — 위치(GPS) 등 다른
/// EXIF는 읽지 않는다. 헤더에서 못 찾으면(잘린 파일, EXIF 없음, JPEG가
/// 아님 등) 전체를 다시 읽어 디코딩하지 않고 그냥 null로 돌아간다(날짜
/// 정보 없음으로 처리 — "일기 수정" 지시서 1-2).
Future<DateTime?> readDiaryPhotoCaptureDate(File file) async {
  RandomAccessFile? raf;
  try {
    raf = await file.open();
    final header = await raf.read(kDiaryPhotoExifHeaderBytes);
    final exif = img.decodeJpgExif(header);
    if (exif == null) return null;
    final raw = exif.exifIfd['DateTimeOriginal']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return _parseExifDateTime(raw);
  } catch (_) {
    return null;
  } finally {
    await raf?.close();
  }
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
