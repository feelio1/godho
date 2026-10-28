import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcliniccheck/diary_book/providers/diary_book_switch.dart';

/// 그림일기 런타임 스위치 — 쇼핑과 같은 fail-closed. 컴파일 플래그는
/// 상수라 여기서는 true인 지금 빌드에서 Firestore 쪽 분기만 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<bool> read(FakeFirebaseFirestore firestore) async {
    final container = ProviderContainer(overrides: [diaryBookFirestoreProvider.overrideWithValue(firestore)]);
    addTearDown(container.dispose);
    final sub = container.listen(diaryBookEnabledProvider, (previous, next) {});
    final value = await container.read(diaryBookEnabledProvider.future);
    sub.close();
    return value;
  }

  test('config/book 문서가 없으면 닫힘', () async {
    expect(await read(FakeFirebaseFirestore()), isFalse);
  });

  test('enabled false·필드 없음·true가 아닌 값이면 닫힘', () async {
    for (final data in [
      {'enabled': false},
      {'notice': '준비 중'},
      {'enabled': 'true'},
    ]) {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('config').doc('book').set(data);
      expect(await read(firestore), isFalse, reason: '$data');
    }
  });

  test('enabled가 true면 열림', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('config').doc('book').set({'enabled': true});
    expect(await read(firestore), isTrue);
  });

  test('열린 뒤 읽기 오류가 나면 닫힘으로 떨어진다', () async {
    final controller = StreamController<Map<String, dynamic>?>();
    final values = diaryBookEnabledFrom(controller.stream).toList();
    controller
      ..add({'enabled': true})
      ..addError(Exception('offline'))
      ..add(null);
    unawaited(controller.close());
    expect(await values, [true, false, false]);
  });
}
