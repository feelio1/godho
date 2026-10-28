import 'book_input.dart';

/// 레이아웃 결과 — 모든 좌표·크기는 mm, 원점은 완성 크기 기준 왼쪽 위다.
/// 렌더러(PDF)는 이 값을 그대로 옮겨 그리기만 하고 배치를 다시 계산하지
/// 않는다 — 그래야 미리보기와 나중의 인쇄용 파일이 같은 결과가 된다.
class MmRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const MmRect(this.x, this.y, this.width, this.height);

  double get right => x + width;
  double get bottom => y + height;
  double get centerX => x + width / 2;
  double get centerY => y + height / 2;

  MmRect inset(double d) => MmRect(x + d, y + d, width - d * 2, height - d * 2);

  @override
  bool operator ==(Object other) =>
      other is MmRect && other.x == x && other.y == y && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'MmRect($x, $y, $width, $height)';
}

/// 원본 사진에서 잘라 쓸 영역 — 0~1 비율(가로·세로 각각 원본 기준).
class CropRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const CropRect(this.left, this.top, this.width, this.height);

  static const full = CropRect(0, 0, 1, 1);

  @override
  String toString() => 'CropRect($left, $top, $width, $height)';
}

/// 사진 한 칸 — [crop]은 칸 비율에 맞춰 가운데 기준으로 잘라낸 영역.
class PhotoSlot {
  final MmRect rect;
  final BookPhoto photo;
  final CropRect crop;

  /// 인쇄 해상도 — 사진 크기를 모르면 null(경고를 판단하지 않는다).
  final double? dpi;
  final bool lowResolution;

  const PhotoSlot({
    required this.rect,
    required this.photo,
    required this.crop,
    required this.dpi,
    required this.lowResolution,
  });
}

/// 원고지 — [cells]는 rows×cols, 빈 칸은 ''.
class ManuscriptGrid {
  final MmRect rect;
  final double cellMm;
  final int columns;
  final int rows;
  final List<List<String>> cells;

  const ManuscriptGrid({
    required this.rect,
    required this.cellMm,
    required this.columns,
    required this.rows,
    required this.cells,
  });

  MmRect cellRect(int row, int column) => MmRect(rect.x + column * cellMm, rect.y + row * cellMm, cellMm, cellMm);
}

/// 머리 칸 날씨 아이콘 한 개의 자리.
class WeatherIconSlot {
  final BookWeather weather;
  final double centerX;
  final double centerY;

  /// 아이콘 크기(지름 기준 mm).
  final double sizeMm;

  const WeatherIconSlot({required this.weather, required this.centerX, required this.centerY, required this.sizeMm});
}

/// 기록된 날씨에 그리는 동그라미.
class WeatherMark {
  final double centerX;
  final double centerY;
  final double radiusMm;

  const WeatherMark({required this.centerX, required this.centerY, required this.radiusMm});
}

/// 원고지 아래 "강아지 한마디" 말풍선 자리 — 다음 단계(AI)에서 켠다. 이번
/// 단계에서는 레이아웃이 이 자리를 만들지 않는다([DiaryPage.dogSpeech]는
/// 늘 null).
class DogSpeechSlot {
  final MmRect rect;
  final String text;

  const DogSpeechSlot({required this.rect, required this.text});
}

/// AI 말풍선이 켜질 때 함께 넣을 고지 문구.
const String kDogSpeechAiNotice = 'AI가 사진과 기록을 바탕으로 상상해 쓴 글이에요. 실제 아이의 생각과 다를 수 있어요.';

/// 이번 단계에서는 말풍선을 만들지 않는다.
const bool kDogSpeechEnabled = false;

sealed class BookPage {
  /// 1부터 세는 실제 쪽 번호(표지 = 1).
  final int pageNumber;

  const BookPage(this.pageNumber);

  /// 이 쪽에 해상도가 낮은 사진이 있는가.
  bool get hasLowResolutionPhoto => false;

  /// 하단 가운데 쪽 번호 표시("— 3 —") — null이면 표시하지 않는다.
  String? get pageLabel => null;
}

class CoverPage extends BookPage {
  final String title;
  final String periodLabel;
  final MmRect frameRect;
  final PhotoSlot? photo;
  final MmRect titleRect;
  final MmRect periodRect;

  const CoverPage({
    required int pageNumber,
    required this.title,
    required this.periodLabel,
    required this.frameRect,
    required this.photo,
    required this.titleRect,
    required this.periodRect,
  }) : super(pageNumber);

  @override
  bool get hasLowResolutionPhoto => photo?.lowResolution ?? false;
}

class DiaryPage extends BookPage {
  final String diaryId;
  final String dateLabel;
  final MmRect headerRect;

  /// 머리 칸 안 날짜/날씨 경계 x(mm).
  final double headerDividerX;
  final MmRect dateLabelRect;
  final MmRect dateTextRect;
  final MmRect weatherLabelRect;
  final List<WeatherIconSlot> weatherIcons;
  final WeatherMark? weatherMark;

  final MmRect activityLabelRect;
  final MmRect activityTextRect;

  /// "산책 · 간식 · 놀이" — 태그가 없으면 ''(줄만 그린다).
  final String activityText;
  final double activityLineY;

  /// 사진이 없으면 null(그 자리를 원고지가 쓴다).
  final MmRect? pictureBox;
  final List<PhotoSlot> photos;
  final ManuscriptGrid grid;
  final DogSpeechSlot? dogSpeech;

  const DiaryPage({
    required int pageNumber,
    required this.diaryId,
    required this.dateLabel,
    required this.headerRect,
    required this.headerDividerX,
    required this.dateLabelRect,
    required this.dateTextRect,
    required this.weatherLabelRect,
    required this.weatherIcons,
    required this.weatherMark,
    required this.activityLabelRect,
    required this.activityTextRect,
    required this.activityText,
    required this.activityLineY,
    required this.pictureBox,
    required this.photos,
    required this.grid,
    this.dogSpeech,
  }) : super(pageNumber);

  @override
  bool get hasLowResolutionPhoto => photos.any((p) => p.lowResolution);

  @override
  String get pageLabel => '— $pageNumber —';
}

/// 원고지가 넘친 일기의 다음 쪽 — 머리 칸은 날짜와 "(이어서)"만.
class ContinuationPage extends BookPage {
  final String diaryId;
  final String dateLabel;
  final MmRect headerRect;
  final ManuscriptGrid grid;

  const ContinuationPage({
    required int pageNumber,
    required this.diaryId,
    required this.dateLabel,
    required this.headerRect,
    required this.grid,
  }) : super(pageNumber);

  @override
  String get pageLabel => '— $pageNumber —';
}

/// 쪽 수를 맞추려고 넣는 빈 메모 쪽.
class MemoPage extends BookPage {
  final MmRect labelRect;
  final List<double> lineYs;
  final double lineStartX;
  final double lineEndX;

  const MemoPage({
    required int pageNumber,
    required this.labelRect,
    required this.lineYs,
    required this.lineStartX,
    required this.lineEndX,
  }) : super(pageNumber);

  @override
  String get pageLabel => '— $pageNumber —';
}

class ActivityCount {
  final String label;
  final int count;

  const ActivityCount(this.label, this.count);

  @override
  bool operator ==(Object other) => other is ActivityCount && other.label == label && other.count == count;

  @override
  int get hashCode => Object.hash(label, count);

  @override
  String toString() => 'ActivityCount($label, $count)';
}

/// 마지막 쪽 "함께한 날들" — 집계만 보여준다(평가 문구 없음).
class SummaryPage extends BookPage {
  final String periodLabel;
  final int diaryCount;

  /// 많이 기록된 순서로 최대 3개 — 기록된 활동이 없으면 빈 목록.
  final List<ActivityCount> topActivities;
  final MmRect titleRect;
  final MmRect bodyRect;

  /// 하단 작은 글씨("펫클로 만든 그림일기").
  final MmRect footerRect;

  const SummaryPage({
    required int pageNumber,
    required this.periodLabel,
    required this.diaryCount,
    required this.topActivities,
    required this.titleRect,
    required this.bodyRect,
    required this.footerRect,
  }) : super(pageNumber);
}

const String kBookFooterText = '펫클로 만든 그림일기';

class BookLayout {
  final List<BookPage> pages;

  const BookLayout(this.pages);

  int get pageCount => pages.length;

  /// 해상도 경고가 달린 쪽 번호들.
  List<int> get lowResolutionPageNumbers =>
      [for (final p in pages) if (p.hasLowResolutionPhoto) p.pageNumber];
}

sealed class BookLayoutResult {
  const BookLayoutResult();
}

class BookLayoutOk extends BookLayoutResult {
  final BookLayout layout;

  const BookLayoutOk(this.layout);
}

/// 기간 안에 일기가 한 편도 없다.
class BookLayoutEmpty extends BookLayoutResult {
  const BookLayoutEmpty();
}

/// 최대 쪽수를 넘는다 — 자동으로 줄이지 않고 그대로 알린다.
class BookLayoutTooManyPages extends BookLayoutResult {
  final int pageCount;
  final int maxPages;

  const BookLayoutTooManyPages({required this.pageCount, required this.maxPages});
}
