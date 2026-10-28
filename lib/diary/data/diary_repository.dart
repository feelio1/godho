import '../models/diary.dart';

/// 일기 목록 한 페이지("방향 개편" 지시서 C — 페이지네이션 20개). [cursor]는
/// 호출부가 내용을 들여다보지 않고 그대로 다음 호출에 돌려주는 불투명
/// 값이다(`ShopRepository.ProductPage`와 같은 관례).
class DiaryPage {
  final List<Diary> diaries;
  final Object? cursor;
  final bool hasMore;

  const DiaryPage({required this.diaries, this.cursor, this.hasMore = false});

  static const empty = DiaryPage(diaries: []);
}

/// 반려동물 일기 데이터 접근 인터페이스 — 화면은 이 인터페이스만 보고,
/// 실제 구현은 [FirestoreDiaryRepository]다. 반려동물별 필터("이 아이만
/// 보기")는 이 계층이 아니라 호출부가 받은 목록을 걸러서 처리한다
/// (petIds 배열 필터 + 날짜 정렬을 함께 쓰는 Firestore 복합 색인을 피하기
/// 위해서 — 일기 수가 많지 않은 개인 데이터라 클라이언트 필터링 비용이
/// 작다).
///
/// 사진 업로드(네트워크)는 이 계층의 일이 아니다("일기 재수정" 지시서
/// 2) — [createDiary]/[updateDiary]는 문서만 바로 만들거나 갱신하고
/// 돌아온다(기다리지 않음). 새로 추가한 사진의 실제 업로드는 호출부가
/// `DiaryPhotoUploadQueueService`에 별도로 넘겨 백그라운드로 처리한다 —
/// 그래서 이 메서드들은 압축된 사진 바이트를 전혀 받지 않고, 몇 장이
/// 아직 올라가는 중인지([pendingPhotoCount])만 받는다.
abstract class DiaryRepository {
  Future<DiaryPage> fetchDiaries(String uid, {int limit = 20, Object? cursor});

  /// 캘린더용 — 그 달에 속한 일기 전체(반려동물 필터 없음, 호출부가 건다).
  Future<List<Diary>> fetchDiariesForMonth(String uid, DateTime month);

  Future<Diary?> fetchDiary(String uid, String diaryId);

  /// [diary.photos]는 보통 빈 목록이다(사진이 있어도 아직 올라가지
  /// 않았으므로) — [pendingPhotoCount]만큼 "올리는 중"으로 표시된다.
  /// 새로 생성된 문서 id를 돌려준다. 네트워크를 기다리지 않아 거의
  /// 즉시 끝난다("일기 재수정" 지시서 2-1).
  Future<String> createDiary(String uid, Diary diary, {int pendingPhotoCount = 0});

  /// [diary.photos]는 수정 시점 기준 "유지하려는 기존 사진 전체(순서
  /// 반영)"여야 한다 — 새로 추가한 사진은 여기 포함하지 않고
  /// [newPendingPhotoCount]만 늘린다(실제 업로드는 호출부가 큐에 별도로
  /// 넘긴다). [removedPhotos]는 (원본·썸네일을 함께 지우기 위해) 경로
  /// 문자열이 아니라 사진 전체를 받고, 즉시(네트워크를 기다려) 지운다 —
  /// 대기열과 달리 삭제는 뒤로 미루지 않는다.
  Future<void> updateDiary(
    String uid,
    Diary diary, {
    List<DiaryPhoto> removedPhotos = const [],
    int newPendingPhotoCount = 0,
  });

  /// Storage에 올라간 사진을 전부 지운 뒤 문서를 지운다(순서: 사진 → 문서).
  /// 아직 업로드 대기열에 남아 있는 사진(로컬 파일·대기열 항목)은
  /// 포함하지 않는다 — 호출부가 `DiaryPhotoUploadQueueService`로 따로
  /// 정리한다("일기 재수정" 지시서 2-6).
  Future<void> deleteDiary(String uid, String diaryId);
}
