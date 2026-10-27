import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:petcliniccheck/diary/diary_photo_processor.dart';

Uint8List _jpegOf(int width, int height, {String? dateTimeOriginal}) {
  final image = img.Image(width: width, height: height);
  if (dateTimeOriginal != null) {
    image.exif.exifIfd['DateTimeOriginal'] = dateTimeOriginal;
  }
  return img.encodeJpg(image, quality: 90);
}

void main() {
  group('processDiaryPhoto — 원본·썸네일 2벌("일기 활성화" 지시서 A)', () {
    test('큰 사진은 각각 긴 변 한도로 줄어든다', () {
      final jpeg = _jpegOf(4000, 2000);
      final processed = processDiaryPhoto(jpeg);

      expect(processed, isNotNull);
      final main = img.decodeImage(processed!.mainBytes)!;
      final thumb = img.decodeImage(processed.thumbBytes)!;

      expect(main.width, kDiaryPhotoMainLongSide);
      expect(main.height, (kDiaryPhotoMainLongSide * 2000 / 4000).round());
      expect(thumb.width, kDiaryPhotoThumbLongSide);
      expect(processed.width, main.width);
      expect(processed.height, main.height);
    });

    test('원본보다 작은 한도로는 키우지 않는다(업스케일 금지)', () {
      final jpeg = _jpegOf(100, 50);
      final processed = processDiaryPhoto(jpeg);

      expect(processed, isNotNull);
      final main = img.decodeImage(processed!.mainBytes)!;
      final thumb = img.decodeImage(processed.thumbBytes)!;
      expect(main.width, 100);
      expect(main.height, 50);
      expect(thumb.width, 100);
      expect(thumb.height, 50);
    });

    test('EXIF는 원본·썸네일 둘 다에서 전부 지워진다(위치 등 저장 안 함)', () {
      final jpeg = _jpegOf(800, 600, dateTimeOriginal: '2024:05:01 10:00:00');
      final processed = processDiaryPhoto(jpeg);

      final main = img.decodeImage(processed!.mainBytes)!;
      final thumb = img.decodeImage(processed.thumbBytes)!;
      expect(main.exif.isEmpty, isTrue);
      expect(thumb.exif.isEmpty, isTrue);
      expect(main.exif.exifIfd['DateTimeOriginal'], isNull);
      expect(thumb.exif.exifIfd['DateTimeOriginal'], isNull);
    });

    test('디코딩할 수 없는 바이트면 null을 돌려준다', () {
      expect(processDiaryPhoto(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  group('readDiaryPhotoCaptureDate — EXIF 촬영일만 읽는다(위치 등은 읽지 않음)', () {
    test('DateTimeOriginal 태그가 있으면 그 날짜를 읽는다', () {
      final jpeg = _jpegOf(100, 100, dateTimeOriginal: '2024:05:01 10:30:15');
      final date = readDiaryPhotoCaptureDate(jpeg);
      expect(date, DateTime(2024, 5, 1, 10, 30, 15));
    });

    test('태그가 없으면 null이다', () {
      final jpeg = _jpegOf(100, 100);
      expect(readDiaryPhotoCaptureDate(jpeg), isNull);
    });

    test('JPEG가 아니면 null이다', () {
      expect(readDiaryPhotoCaptureDate(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  group('suggestDiaryDateFromCaptureDates — 가장 이른 날짜를 제안("일기 활성화" 지시서 C)', () {
    final today = DateTime(2026, 5, 10);

    test('여러 장이면 가장 이른 날짜를 고른다', () {
      final suggested = suggestDiaryDateFromCaptureDates(
        [DateTime(2026, 5, 3, 9), DateTime(2026, 5, 1, 20), DateTime(2026, 5, 2)],
        today: today,
      );
      expect(suggested, DateTime(2026, 5, 1));
    });

    test('미래 날짜는 후보에서 뺀다', () {
      final suggested = suggestDiaryDateFromCaptureDates(
        [DateTime(2026, 5, 20), DateTime(2026, 5, 2)],
        today: today,
      );
      expect(suggested, DateTime(2026, 5, 2));
    });

    test('전부 미래거나 정보가 없으면 null(오늘 유지)', () {
      expect(
        suggestDiaryDateFromCaptureDates([DateTime(2026, 5, 20), null], today: today),
        isNull,
      );
      expect(suggestDiaryDateFromCaptureDates([null, null], today: today), isNull);
      expect(suggestDiaryDateFromCaptureDates(const [], today: today), isNull);
    });

    test('오늘 날짜 사진은 그대로 후보가 된다', () {
      final suggested = suggestDiaryDateFromCaptureDates([today], today: today);
      expect(suggested, today);
    });
  });
}
