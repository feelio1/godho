import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 압축된 바이트를 이미지 디스크 캐시에 [url] 키로 넣는다 — 실제 구현은
/// `flutter_cache_manager`를 그대로 쓰고, 테스트에서는 가짜로 바꿔 끼울
/// 수 있게 함수 타입으로 둔다.
typedef DiaryPhotoCacheWriter = Future<void> Function({required String url, required Uint8List bytes});

/// `cached_network_image`가 쓰는 기본 캐시 매니저에 바로 써 넣는다 —
/// 그래야 같은 URL로 `CachedNetworkImage`를 띄울 때 네트워크를 타지
/// 않는다.
Future<void> cacheDiaryPhotoBytesDefault({required String url, required Uint8List bytes}) async {
  await DefaultCacheManager().putFile(url, bytes, fileExtension: 'jpg');
}

/// 방금 업로드한 사진들(다운로드 URL + 그 사진의 바이트)을 전부 캐시에
/// 넣는다 — 방금 쓴 일기는 다운로드 없이 목록·상세에서 바로 보이게
/// 한다("일기 수정" 지시서 2-4). 캐시 주입은 어디까지나 편의 기능이라
/// 하나가 실패해도 나머지는 계속 넣고, 예외를 밖으로 던지지 않는다.
Future<void> cacheUploadedDiaryPhotos(
  List<({String url, Uint8List bytes})> entries,
  DiaryPhotoCacheWriter writer,
) async {
  for (final entry in entries) {
    try {
      await writer(url: entry.url, bytes: entry.bytes);
    } catch (_) {
      // 캐시에 못 넣어도 다음에 네트워크로 받아오면 되므로 무시한다.
    }
  }
}
