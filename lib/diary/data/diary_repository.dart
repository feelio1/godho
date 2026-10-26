import 'dart:io';

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
abstract class DiaryRepository {
  Future<DiaryPage> fetchDiaries(String uid, {int limit = 20, Object? cursor});

  /// 캘린더용 — 그 달에 속한 일기 전체(반려동물 필터 없음, 호출부가 건다).
  Future<List<Diary>> fetchDiariesForMonth(String uid, DateTime month);

  Future<Diary?> fetchDiary(String uid, String diaryId);

  /// 사진을 먼저 올리고, 전부 성공해야 문서를 만든다 — 하나라도 실패하면
  /// 예외가 그대로 올라가고 문서는 생성되지 않는다("방향 개편" 지시서 C:
  /// "업로드 실패 시 일기 저장 안 함"). 새로 생성된 문서 id를 돌려준다.
  Future<String> createDiary(String uid, Diary diary, List<File> photoFiles);

  /// [diary.photos]는 수정 시점 기준 "유지하려는 기존 사진 전체"여야
  /// 한다 — [removedPhotoPaths]에 있는 것만 더 제외하고, [newPhotoFiles]를
  /// 추가로 올려 합친다. 새 사진 업로드가 실패하면 예외가 올라가고 기존
  /// 문서는 그대로 남는다(부분 저장 없음).
  Future<void> updateDiary(
    String uid,
    Diary diary, {
    List<File> newPhotoFiles = const [],
    List<String> removedPhotoPaths = const [],
  });

  /// Storage에 올라간 사진을 전부 지운 뒤 문서를 지운다(순서: 사진 → 문서).
  Future<void> deleteDiary(String uid, String diaryId);
}
