import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../data/diary_repository.dart';
import '../data/firestore_diary_repository.dart';
import '../models/diary.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) => FirestoreDiaryRepository());

/// 일기 목록 첫 페이지(최신순, 20개) — 로그인 전용 기능이라 게스트는 항상
/// 빈 페이지다("방향 개편" 지시서 C). 더 보기(페이지네이션)는 화면이
/// 직접 [DiaryRepository.fetchDiaries]를 커서와 함께 다시 불러 처리한다.
/// 쓰기(작성/수정/삭제) 뒤에는 호출부가 `ref.invalidate(diariesPageProvider)`
/// 로 새로 고친다(`accountSignupPetsProvider`와 같은 관례 — Firestore
/// 쓰기가 이 provider를 자동으로 다시 부르지 않는다).
final diariesPageProvider = FutureProvider.autoDispose<DiaryPage>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Future.value(DiaryPage.empty);
  return ref.watch(diaryRepositoryProvider).fetchDiaries(uid);
});

/// "우리 아이" 탭 일기 세그먼트 — 선택된 반려동물([petId])이 포함된
/// 일기만 최신순으로. 반려동물 필터는 이 provider가(= 클라이언트 쪽에서)
/// 건다 — [DiaryRepository] 설계 문서 참고.
final diariesForPetProvider = FutureProvider.autoDispose.family<List<Diary>, String>((ref, petId) async {
  final page = await ref.watch(diariesPageProvider.future);
  return page.diaries.where((d) => d.petIds.contains(petId)).toList();
});

final diaryProvider = FutureProvider.autoDispose.family<Diary?, String>((ref, diaryId) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Future.value(null);
  return ref.watch(diaryRepositoryProvider).fetchDiary(uid, diaryId);
});

/// 캘린더용 — [month]는 항상 `DateTime(year, month, 1)`로 정규화해서
/// 넘겨야 같은 달이 같은 캐시 키로 묶인다. 반려동물 필터는 호출부가
/// 받은 목록을 걸러서 적용한다(월 단위라 양이 적어 비용이 작다).
final diariesForMonthProvider = FutureProvider.autoDispose.family<List<Diary>, DateTime>((ref, month) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Future.value(const <Diary>[]);
  return ref.watch(diaryRepositoryProvider).fetchDiariesForMonth(uid, month);
});
