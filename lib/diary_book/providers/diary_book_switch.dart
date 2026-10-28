import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/feature_flags.dart';

/// `config/book` 문서를 읽을 [FirebaseFirestore] — 테스트가
/// `fake_cloud_firestore`로 바꿔 끼울 수 있게 provider로 뺐다.
final diaryBookFirestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// 그림일기 런타임 스위치 — 쇼핑(`shopEnabledProvider`)과 같은 fail-closed
/// 패턴. 컴파일 플래그 [kEnableDiaryBookCode]가 false면 조회하지 않고 늘
/// false. 문서·필드가 없거나, `enabled`가 정확히 true가 아니거나, 읽기가
/// 실패하면(오프라인·권한 오류 등, 한 번 열린 뒤의 오류 포함) false다.
final diaryBookEnabledProvider = StreamProvider<bool>((ref) {
  if (!kEnableDiaryBookCode) return Stream.value(false);
  return watchDiaryBookEnabled(ref.watch(diaryBookFirestoreProvider));
});

/// 진입점 표시 여부 — 로딩 중에도 닫힘으로 본다.
final diaryBookVisibleProvider = Provider<bool>((ref) => ref.watch(diaryBookEnabledProvider).value == true);

Stream<bool> watchDiaryBookEnabled(FirebaseFirestore firestore) {
  try {
    return diaryBookEnabledFrom(firestore.collection('config').doc('book').snapshots().map((doc) => doc.data()));
  } catch (_) {
    return Stream.value(false);
  }
}

/// 문서 데이터 스트림 → 열림 여부. `enabled`가 정확히 true일 때만 열리고,
/// 스트림 오류는 닫힘(false)으로 바꿔 흘린다 — 열린 뒤에 오류가 나도
/// 이전 "열림" 값이 남지 않는다.
Stream<bool> diaryBookEnabledFrom(Stream<Map<String, dynamic>?> data) => data
    .map((d) => d?['enabled'] == true)
    .transform(StreamTransformer<bool, bool>.fromHandlers(
      handleError: (error, stackTrace, sink) => sink.add(false),
    ));
