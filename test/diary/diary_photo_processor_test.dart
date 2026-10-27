import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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

/// 네이티브 압축기([FlutterImageCompress])를 실기기 없이 테스트하기 위한
/// 가짜 구현("일기 수정" 지시서 1) — `compressWithFile`/`compressWithList`
/// 호출을 그대로 가로채 미리 정해둔 동작을 흉내 낸다.
class _FakeImageCompressPlatform extends FlutterImageCompressPlatform {
  _FakeImageCompressPlatform({this.onCompressWithFile, this.onCompressWithList});

  final Future<Uint8List?> Function(String path)? onCompressWithFile;
  final Future<Uint8List> Function(Uint8List data)? onCompressWithList;

  @override
  FlutterImageCompressValidator get validator =>
      FlutterImageCompressValidator(const MethodChannel('fake_flutter_image_compress'));

  @override
  Future<void> showNativeLog(bool value) async {}

  @override
  void ignoreCheckSupportPlatform(bool bool) {}

  @override
  Future<Uint8List?> compressWithFile(
    String path, {
    int minWidth = 1920,
    int minHeight = 1080,
    int inSampleSize = 1,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int numberOfRetries = 5,
  }) {
    return onCompressWithFile!(path);
  }

  @override
  Future<Uint8List> compressWithList(
    Uint8List image, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    int inSampleSize = 1,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
  }) {
    return onCompressWithList!(image);
  }

  @override
  Future<XFile?> compressAndGetFile(
    String path,
    String targetPath, {
    int minWidth = 1920,
    int minHeight = 1080,
    int inSampleSize = 1,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int numberOfRetries = 5,
  }) =>
      throw UnimplementedError();

  @override
  Future<Uint8List?> compressAssetImage(
    String assetName, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
  }) =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final originalPlatform = FlutterImageCompressPlatform.instance;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('diary_photo_native_test_');
  });

  tearDown(() async {
    FlutterImageCompressPlatform.instance = originalPlatform;
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<File> writeFile(String name, List<int> bytes) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  group('processDiaryPhotoNative — 네이티브 압축 경로("일기 수정" 지시서 1)', () {
    test('정상 압축되면 원본·썸네일 바이트와 크기를 돌려준다', () async {
      final mainJpeg = _jpegOf(1600, 900);
      final thumbJpeg = _jpegOf(480, 270);
      FlutterImageCompressPlatform.instance = _FakeImageCompressPlatform(
        onCompressWithFile: (path) async => mainJpeg,
        onCompressWithList: (data) async => thumbJpeg,
      );

      final file = await writeFile('a.jpg', [0xff, 0xd8, 0xff, 0xd9]);
      final processed = await processDiaryPhotoNative(file.path);

      expect(processed, isNotNull);
      expect(processed!.mainBytes, mainJpeg);
      expect(processed.thumbBytes, thumbJpeg);
      expect(processed.width, 1600);
      expect(processed.height, 900);
    });

    test('네이티브가 null을 돌려주면(처리 불가 파일) null이다', () async {
      FlutterImageCompressPlatform.instance = _FakeImageCompressPlatform(
        onCompressWithFile: (path) async => null,
        onCompressWithList: (data) async => Uint8List(0),
      );

      final file = await writeFile('b.jpg', [0, 1, 2]);
      expect(await processDiaryPhotoNative(file.path), isNull);
    });

    test('네이티브가 예외를 던지면 null이다(그 사진만 제외)', () async {
      FlutterImageCompressPlatform.instance = _FakeImageCompressPlatform(
        onCompressWithFile: (path) async => throw Exception('boom'),
      );

      final file = await writeFile('c.jpg', [0, 1, 2]);
      expect(await processDiaryPhotoNative(file.path), isNull);
    });

    test('썸네일 압축이 실패해도(예외) null이다', () async {
      FlutterImageCompressPlatform.instance = _FakeImageCompressPlatform(
        onCompressWithFile: (path) async => _jpegOf(800, 600),
        onCompressWithList: (data) async => throw Exception('thumb failed'),
      );

      final file = await writeFile('d.jpg', [0, 1, 2]);
      expect(await processDiaryPhotoNative(file.path), isNull);
    });
  });

  group('readDiaryPhotoCaptureDate — 파일 앞부분만 읽어 EXIF 촬영일("일기 수정" 지시서 1-2)', () {
    test('DateTimeOriginal 태그가 있으면 그 날짜를 읽는다', () async {
      final jpeg = _jpegOf(100, 100, dateTimeOriginal: '2024:05:01 10:30:15');
      final file = await writeFile('e.jpg', jpeg);

      final date = await readDiaryPhotoCaptureDate(file);
      expect(date, DateTime(2024, 5, 1, 10, 30, 15));
    });

    test('EXIF 태그가 없으면 null이다(날짜 정보 없음)', () async {
      final jpeg = _jpegOf(100, 100);
      final file = await writeFile('f.jpg', jpeg);

      expect(await readDiaryPhotoCaptureDate(file), isNull);
    });

    test('잘렸거나 JPEG가 아닌 파일이면 전체를 다시 읽지 않고 null이다', () async {
      final file = await writeFile('g.jpg', [1, 2, 3, 4, 5]);
      expect(await readDiaryPhotoCaptureDate(file), isNull);
    });

    test('존재하지 않는 파일이면 예외 없이 null이다', () async {
      final missing = File('${tempDir.path}/missing.jpg');
      expect(await readDiaryPhotoCaptureDate(missing), isNull);
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
