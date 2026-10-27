import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/diary/diary_photo_cache.dart';

/// 업로드 직후 캐시 주입 호출("일기 수정" 지시서 2-4) — 실제
/// `flutter_cache_manager` 없이, [DiaryPhotoCacheWriter]를 가짜로
/// 바꿔 끼워 호출 여부·인자·실패 허용을 검증한다.
void main() {
  test('각 항목마다 url·bytes를 그대로 넘겨 writer를 부른다', () async {
    final calls = <({String url, Uint8List bytes})>[];
    Future<void> fakeWriter({required String url, required Uint8List bytes}) async {
      calls.add((url: url, bytes: bytes));
    }

    final mainBytes = Uint8List.fromList([1, 2, 3]);
    final thumbBytes = Uint8List.fromList([4, 5]);
    await cacheUploadedDiaryPhotos(
      [(url: 'https://example.com/a.jpg', bytes: mainBytes), (url: 'https://example.com/a_t.jpg', bytes: thumbBytes)],
      fakeWriter,
    );

    expect(calls, hasLength(2));
    expect(calls[0].url, 'https://example.com/a.jpg');
    expect(calls[0].bytes, mainBytes);
    expect(calls[1].url, 'https://example.com/a_t.jpg');
    expect(calls[1].bytes, thumbBytes);
  });

  test('하나가 실패해도(예외) 나머지는 계속 넣고 예외를 밖으로 던지지 않는다', () async {
    final calls = <String>[];
    Future<void> flakyWriter({required String url, required Uint8List bytes}) async {
      calls.add(url);
      if (url == 'fail') throw Exception('캐시 쓰기 실패');
    }

    await cacheUploadedDiaryPhotos(
      [
        (url: 'ok1', bytes: Uint8List(0)),
        (url: 'fail', bytes: Uint8List(0)),
        (url: 'ok2', bytes: Uint8List(0)),
      ],
      flakyWriter,
    );

    expect(calls, ['ok1', 'fail', 'ok2']);
  });

  test('빈 목록이면 writer를 부르지 않는다', () async {
    var called = false;
    Future<void> writer({required String url, required Uint8List bytes}) async {
      called = true;
    }

    await cacheUploadedDiaryPhotos(const [], writer);
    expect(called, isFalse);
  });
}
