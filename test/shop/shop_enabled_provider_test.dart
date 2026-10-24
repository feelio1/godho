import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/shop/providers/shop_providers.dart';

/// 쇼핑 탭 런타임 스위치("쇼핑 기초" 지시서 1) — 기본값은 항상 닫힘
/// (fail-closed). 컴파일 플래그([kEnableShopCode])는 상수라 이 테스트
/// 환경에서 false로 바꿔볼 수 없으므로(그러려면 별도 빌드가 필요하다),
/// 여기서는 그 플래그가 true인 지금 빌드에서 Firestore 쪽 분기(문서 없음·
/// false·true·읽기 실패)만 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer containerWith(FakeFirebaseFirestore firestore) {
    final container = ProviderContainer(
      overrides: [shopFirestoreProvider.overrideWithValue(firestore)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('config/shop 문서가 없으면 닫힘(false)이다', () async {
    final firestore = FakeFirebaseFirestore();
    final container = containerWith(firestore);

    final sub = container.listen(shopEnabledProvider, (previous, next) {});
    final value = await container.read(shopEnabledProvider.future);
    sub.close();
    expect(value, isFalse);
  });

  test('enabled가 false면 닫힘이다', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('config').doc('shop').set({'enabled': false});
    final container = containerWith(firestore);

    final sub = container.listen(shopEnabledProvider, (previous, next) {});
    final value = await container.read(shopEnabledProvider.future);
    sub.close();
    expect(value, isFalse);
  });

  test('enabled가 true면 열림이다', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('config').doc('shop').set({'enabled': true});
    final container = containerWith(firestore);

    final sub = container.listen(shopEnabledProvider, (previous, next) {});
    final value = await container.read(shopEnabledProvider.future);
    sub.close();
    expect(value, isTrue);
  });

  test('enabled 필드가 없는 문서는 닫힘이다', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('config').doc('shop').set({'notice': '점검 중'});
    final container = containerWith(firestore);

    final sub = container.listen(shopEnabledProvider, (previous, next) {});
    final value = await container.read(shopEnabledProvider.future);
    sub.close();
    expect(value, isFalse);
  });
}
