import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../data/diary_repository.dart';
import '../data/firestore_diary_repository.dart';
import '../diary_calendar.dart' show onThisDayCandidates;
import '../diary_photo_upload_queue.dart';
import '../models/diary.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) => FirestoreDiaryRepository());

/// 이 일기의 이 기기 업로드 대기열 항목(아직 안 올라간 사진, 순서 포함) —
/// 목록·상세가 "올리는 중" 자리표시로 즉시 보여주는 데 쓴다("일기
/// 재수정" 지시서 2-3). 큐 상태가 바뀌면(`DiaryPhotoUploadQueueService.
/// instance.changeTick`) 호출부가 invalidate해 다시 불러온다.
final diaryPendingPhotosProvider =
    FutureProvider.autoDispose.family<List<DiaryPhotoQueueItem>, String>((ref, diaryId) {
  return const DiaryPhotoUploadQueueStore().loadForDiary(diaryId);
});

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

/// 활동 태그를 자주 쓴 순서로 보여주기 위한 최근 50편("일기 활성화"
/// 지시서 E) — 목록 페이지네이션([diariesPageProvider], 20개)과는
/// 별도의 가벼운 집계 전용 호출이다.
final recentDiariesForTagOrderProvider = FutureProvider.autoDispose<List<Diary>>((ref) async {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const [];
  final page = await ref.watch(diaryRepositoryProvider).fetchDiaries(uid, limit: 50);
  return page.diaries;
});

/// 홈 "그날의 기록" 카드용 — 1년 전 오늘 일기가 있으면 그것, 없으면 한
/// 달 전 오늘, 둘 다 없으면 null("일기 활성화" 지시서 I). 반려동물과
/// 무관하게(계정 전체) 먼저 걸리는 한 편만 쓴다.
final onThisDayDiaryProvider = FutureProvider.autoDispose<Diary?>((ref) async {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return null;
  final repo = ref.watch(diaryRepositoryProvider);

  for (final day in onThisDayCandidates(DateTime.now())) {
    final monthDiaries = await repo.fetchDiariesForMonth(uid, DateTime(day.year, day.month, 1));
    for (final diary in monthDiaries) {
      if (diary.date.year == day.year && diary.date.month == day.month && diary.date.day == day.day) {
        return diary;
      }
    }
  }
  return null;
});
