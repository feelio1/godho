/// 레이아웃 엔진 입력 — 일기 모델(`Diary`, Firestore 의존)을 직접 보지
/// 않도록 엔진이 필요한 값만 옮겨 담는다. 변환은 앱 쪽
/// `diary_book_source.dart`가 맡는다.
library;

/// 그림일기 머리 칸의 날씨 아이콘 5개 — 순서가 곧 왼쪽→오른쪽 배치다.
enum BookWeather { sunny, partlyCloudy, cloudy, rainy, snowy }

/// 사진 한 장의 메타데이터. 실제 바이트는 렌더러가 [id]로 찾아 읽는다.
class BookPhoto {
  /// 렌더러가 파일을 찾는 열쇠(다운로드 URL 또는 업로드 대기 중인 로컬
  /// 파일 경로).
  final String id;

  /// 원본 픽셀 크기 — 모르면 0(그 사진은 해상도 경고를 판단하지 않는다).
  final int widthPx;
  final int heightPx;

  const BookPhoto({required this.id, required this.widthPx, required this.heightPx});

  bool get hasKnownSize => widthPx > 0 && heightPx > 0;
}

/// 일기 한 편.
class BookDiaryEntry {
  final String id;
  final DateTime date;
  final BookWeather? weather;

  /// 활동 태그 라벨("산책" 등) — 일기에 적힌 순서 그대로.
  final List<String> activities;
  final String text;

  /// 보여줄 순서대로 정렬된 사진.
  final List<BookPhoto> photos;

  const BookDiaryEntry({
    required this.id,
    required this.date,
    this.weather,
    this.activities = const [],
    this.text = '',
    this.photos = const [],
  });
}

class BookInput {
  final String petName;

  /// 표지 제목 — 비우면 "○○의 그림일기".
  final String title;

  /// 기간(날짜만 의미 있음, 양 끝 포함).
  final DateTime periodStart;
  final DateTime periodEnd;

  final List<BookDiaryEntry> entries;

  /// 표지 사진 — null이면 기간 안 첫 사진.
  final String? coverPhotoId;

  const BookInput({
    required this.petName,
    required this.title,
    required this.periodStart,
    required this.periodEnd,
    required this.entries,
    this.coverPhotoId,
  });
}

String defaultBookTitle(String petName) => '$petName의 그림일기';
