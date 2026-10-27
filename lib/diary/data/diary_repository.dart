import 'dart:io';

import '../models/diary.dart';

/// 사진을 한 장씩 순차로 처리할 때마다 부른다(1-based [index], [total]은
/// 전체 장수) — 저장 화면이 "사진 준비 중 (n/m)"을 보여주는 데 쓴다
/// ("일기 보완" 지시서 1).
typedef DiaryPhotoProgressCallback = void Function(int index, int total);

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

  /// 사진을 먼저 올리고, 전부 성공해야 문서를 만든다 — (디코딩 실패가
  /// 아닌) 업로드 자체가 하나라도 실패하면 예외가 그대로 올라가고 문서는
  /// 생성되지 않는다("방향 개편" 지시서 C: "업로드 실패 시 일기 저장
  /// 안 함"). 디코딩에 실패한 사진(깨진 파일 등)은 그 사진만 조용히
  /// 빼고 계속 올리며, [onPhotoDecodeFailed]로 몇 장이 빠졌는지만
  /// 알려준다("일기 보완" 지시서 1). 새로 생성된 문서 id를 돌려준다.
  Future<String> createDiary(
    String uid,
    Diary diary,
    List<File> photoFiles, {
    DiaryPhotoProgressCallback? onPhotoProgress,
    void Function()? onPhotoDecodeFailed,
  });

  /// [diary.photos]는 수정 시점 기준 "유지하려는 기존 사진 전체"여야
  /// 한다 — [removedPhotos]에 있는 것만 더 제외하고, [newPhotoFiles]를
  /// 추가로 올려 합친다. [removedPhotos]는 (원본·썸네일을 함께 지우기
  /// 위해) 경로 문자열이 아니라 사진 전체를 받는다. 새 사진 업로드가
  /// (디코딩 실패가 아닌) 실패하면 예외가 올라가고 기존 문서는 그대로
  /// 남는다(부분 저장 없음) — 디코딩 실패는 [createDiary]와 같이 그
  /// 사진만 빼고 계속한다.
  Future<void> updateDiary(
    String uid,
    Diary diary, {
    List<File> newPhotoFiles = const [],
    List<DiaryPhoto> removedPhotos = const [],
    DiaryPhotoProgressCallback? onPhotoProgress,
    void Function()? onPhotoDecodeFailed,
  });

  /// Storage에 올라간 사진을 전부 지운 뒤 문서를 지운다(순서: 사진 → 문서).
  Future<void> deleteDiary(String uid, String diaryId);
}
