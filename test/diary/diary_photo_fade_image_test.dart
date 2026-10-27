import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/diary/screens/diary_detail_screen.dart';

/// 상세 PageView·전체화면이 쓰는 "썸네일 먼저, 원본은 fade로" 위젯
/// ("일기 수정" 지시서 2-1) — 실제 네트워크 로딩 타이밍에 의존하지 않고,
/// `CachedNetworkImage`에 넘겨준 `placeholder` 빌더를 직접 호출해 그
/// 빌더가 thumbUrl을 가리키는 `CachedNetworkImage`를 돌려주는지만
/// 확인한다(위젯 구조 검증 — 실제 로딩 상태는 실기기 검증 대상).
void main() {
  testWidgets('thumbUrl이 있으면 placeholder가 그 주소를 가리키는 이미지를 돌려준다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DiaryPhotoFadeImage(
          mainUrl: 'https://example.com/main.jpg',
          thumbUrl: 'https://example.com/thumb.jpg',
        ),
      ),
    );

    final mainWidget = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first);
    expect(mainWidget.imageUrl, 'https://example.com/main.jpg');
    expect(mainWidget.placeholder, isNotNull);

    final placeholderWidget = mainWidget.placeholder!(tester.element(find.byType(DiaryPhotoFadeImage)), 'https://example.com/main.jpg');
    expect(placeholderWidget, isA<CachedNetworkImage>());
    expect((placeholderWidget as CachedNetworkImage).imageUrl, 'https://example.com/thumb.jpg');
  });

  testWidgets('thumbUrl이 없으면 placeholder를 쓰지 않는다(기존처럼 원본만)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DiaryPhotoFadeImage(
          mainUrl: 'https://example.com/main.jpg',
          thumbUrl: null,
        ),
      ),
    );

    final mainWidget = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first);
    expect(mainWidget.imageUrl, 'https://example.com/main.jpg');
    expect(mainWidget.placeholder, isNull);
  });

  testWidgets('memCacheWidth를 그대로 CachedNetworkImage에 전달한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DiaryPhotoFadeImage(
          mainUrl: 'https://example.com/main.jpg',
          thumbUrl: null,
          memCacheWidth: 480,
        ),
      ),
    );

    final mainWidget = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first);
    expect(mainWidget.memCacheWidth, 480);
  });
}
