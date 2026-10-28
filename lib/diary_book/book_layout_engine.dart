import 'book_input.dart';
import 'book_layout.dart';
import 'book_spec.dart';
import 'book_text.dart';
import 'manuscript.dart';
import 'photo_slots.dart';

/// 그림일기 배치 상수(mm) — 모두 안전 여백 안쪽 기준.
class BookLayoutMetrics {
  static const headerHeight = 13.0;

  /// 머리 칸에서 날짜 쪽이 차지하는 비율.
  static const headerDateFraction = 0.56;
  static const headerLabelWidth = 11.0;
  static const activityGap = 3.0;
  static const activityRowHeight = 7.0;
  static const activityToPictureGap = 3.0;
  static const pictureBoxHeight = 64.0;
  static const pictureBoxPadding = 1.5;
  static const pictureToGridGap = 4.0;

  /// 원고지 아래 쪽 번호 자리.
  static const footerHeight = 8.0;
  static const continuationHeaderHeight = 8.0;
  static const continuationHeaderGap = 4.0;
}

/// [input]을 [spec] 판형의 쪽 목록으로 배치한다. 일기는 날짜순(같은 날이면
/// 들어온 순서)으로 놓고, 한 편은 기본 1쪽 — 원고지가 넘치면 이어지는 쪽에
/// 원고지만 더한다.
BookLayoutResult layoutBook(BookInput input, {BookSpec spec = BookSpec.a5}) {
  if (input.entries.isEmpty) return const BookLayoutEmpty();

  final entries = input.entries.indexed.toList()
    ..sort((a, b) {
      final diff = a.$2.date.compareTo(b.$2.date);
      return diff != 0 ? diff : a.$1 - b.$1;
    });
  final sorted = [for (final e in entries) e.$2];
  final periodLabel = bookPeriodLabel(input.periodStart, input.periodEnd);

  final pages = <BookPage>[];
  pages.add(_coverPage(spec, input, sorted, periodLabel));

  for (final entry in sorted) {
    _addDiaryPages(spec, entry, pages);
  }

  // 표지 + 일기 쪽 + 마지막 "함께한 날들" 쪽. 짝수·최소 쪽수가 되도록 그
  // 앞에 메모 쪽을 넣는다.
  var total = pages.length + 1;
  if (total < spec.minPages) total = spec.minPages;
  if (total.isOdd) total++;
  if (total > spec.maxPages) {
    return BookLayoutTooManyPages(pageCount: total, maxPages: spec.maxPages);
  }
  while (pages.length < total - 1) {
    pages.add(_memoPage(spec, pages.length + 1));
  }
  pages.add(_summaryPage(spec, sorted, periodLabel, pages.length + 1));
  return BookLayoutOk(BookLayout(pages));
}

BookPhoto? _findCoverPhoto(BookInput input, List<BookDiaryEntry> sorted) {
  final all = [for (final e in sorted) ...e.photos];
  if (input.coverPhotoId != null) {
    for (final p in all) {
      if (p.id == input.coverPhotoId) return p;
    }
  }
  return all.isEmpty ? null : all.first;
}

CoverPage _coverPage(BookSpec spec, BookInput input, List<BookDiaryEntry> sorted, String periodLabel) {
  final left = spec.safeMm;
  final top = spec.safeMm;
  final w = spec.contentWidthMm;
  final h = spec.contentHeightMm;
  final frameSize = w * 0.72;
  final frame = MmRect(left + (w - frameSize) / 2, top + h * 0.12, frameSize, frameSize);
  final photo = _findCoverPhoto(input, sorted);
  final titleRect = MmRect(left, frame.bottom + 12, w, 16);
  final periodRect = MmRect(left, titleRect.bottom + 3, w, 7);
  final title = input.title.trim().isEmpty ? defaultBookTitle(input.petName) : input.title.trim();
  return CoverPage(
    pageNumber: 1,
    title: title,
    periodLabel: periodLabel,
    frameRect: frame,
    photo: photo == null ? null : buildPhotoSlot(photo, frame.inset(3), minDpi: spec.minPhotoDpi),
    titleRect: titleRect,
    periodRect: periodRect,
  );
}

/// 원고지 한 칸 크기와 [top]~[bottom] 사이에 들어가는 줄 수.
({double cell, int rows}) _gridFit(BookSpec spec, double top, double bottom) {
  final cell = spec.contentWidthMm / kManuscriptColumns;
  final rows = ((bottom - top) / cell + 1e-9).floor();
  return (cell: cell, rows: rows < 1 ? 1 : rows);
}

void _addDiaryPages(BookSpec spec, BookDiaryEntry entry, List<BookPage> pages) {
  final left = spec.safeMm;
  final top = spec.safeMm;
  final w = spec.contentWidthMm;
  final gridBottom = top + spec.contentHeightMm - BookLayoutMetrics.footerHeight;
  final dateLabel = bookDateLabel(entry.date);

  // 머리 칸.
  final header = MmRect(left, top, w, BookLayoutMetrics.headerHeight);
  final dividerX = left + w * BookLayoutMetrics.headerDateFraction;
  final dateLabelRect = MmRect(left + 2.5, top, BookLayoutMetrics.headerLabelWidth - 2, header.height);
  final dateTextRect = MmRect(dateLabelRect.right + 1, top, dividerX - dateLabelRect.right - 2, header.height);
  final weatherLabelRect = MmRect(dividerX + 2.5, top, BookLayoutMetrics.headerLabelWidth - 2, header.height);
  final iconsLeft = weatherLabelRect.right + 1;
  final iconsWidth = header.right - 2 - iconsLeft;
  final iconCell = iconsWidth / BookWeather.values.length;
  final iconSize = (iconCell - 1.2).clamp(3.0, 6.0);
  final weatherIcons = [
    for (final (i, weather) in BookWeather.values.indexed)
      WeatherIconSlot(
        weather: weather,
        centerX: iconsLeft + iconCell * (i + 0.5),
        centerY: header.centerY,
        sizeMm: iconSize,
      ),
  ];
  WeatherMark? mark;
  if (entry.weather != null) {
    final slot = weatherIcons[entry.weather!.index];
    mark = WeatherMark(centerX: slot.centerX, centerY: slot.centerY, radiusMm: iconSize / 2 + 0.9);
  }

  // 오늘 한 일.
  final activityTop = header.bottom + BookLayoutMetrics.activityGap;
  final activityLabelRect = MmRect(left + 1, activityTop, 16, BookLayoutMetrics.activityRowHeight);
  final activityTextRect = MmRect(activityLabelRect.right + 1, activityTop, w - activityLabelRect.width - 2,
      BookLayoutMetrics.activityRowHeight);
  final activityLineY = activityTop + BookLayoutMetrics.activityRowHeight + 1;

  // 그림 칸 — 사진이 없으면 만들지 않고 원고지가 그 자리를 쓴다.
  final photos = entry.photos.take(kBookMaxPhotosPerPage).toList();
  final contentTop = activityLineY + BookLayoutMetrics.activityToPictureGap;
  MmRect? pictureBox;
  final slots = <PhotoSlot>[];
  var gridTop = contentTop;
  if (photos.isNotEmpty) {
    pictureBox = MmRect(left, contentTop, w, BookLayoutMetrics.pictureBoxHeight);
    final rects = photoSlotRects(pictureBox.inset(BookLayoutMetrics.pictureBoxPadding), photos.length);
    for (final (i, rect) in rects.indexed) {
      slots.add(buildPhotoSlot(photos[i], rect, minDpi: spec.minPhotoDpi));
    }
    gridTop = pictureBox.bottom + BookLayoutMetrics.pictureToGridGap;
  }

  final firstFit = _gridFit(spec, gridTop, gridBottom);
  final continuationGridTop =
      top + BookLayoutMetrics.continuationHeaderHeight + BookLayoutMetrics.continuationHeaderGap;
  final continuationFit = _gridFit(spec, continuationGridTop, gridBottom);
  final chunks = paginateManuscript(
    layoutManuscriptLines(entry.text),
    firstPageRows: firstFit.rows,
    continuationRows: continuationFit.rows,
  );

  ManuscriptGrid grid(double gridTop, ({double cell, int rows}) fit, List<List<String>> cells) => ManuscriptGrid(
        rect: MmRect(left, gridTop, fit.cell * kManuscriptColumns, fit.cell * fit.rows),
        cellMm: fit.cell,
        columns: kManuscriptColumns,
        rows: fit.rows,
        cells: cells,
      );

  pages.add(DiaryEntryPage(
    pageNumber: pages.length + 1,
    diaryId: entry.id,
    dateLabel: dateLabel,
    headerRect: header,
    headerDividerX: dividerX,
    dateLabelRect: dateLabelRect,
    dateTextRect: dateTextRect,
    weatherLabelRect: weatherLabelRect,
    weatherIcons: weatherIcons,
    weatherMark: mark,
    activityLabelRect: activityLabelRect,
    activityTextRect: activityTextRect,
    activityText: entry.activities.join(' · '),
    activityLineY: activityLineY,
    pictureBox: pictureBox,
    photos: slots,
    grid: grid(gridTop, firstFit, chunks.first),
  ));

  for (final cells in chunks.skip(1)) {
    pages.add(ContinuationPage(
      pageNumber: pages.length + 1,
      diaryId: entry.id,
      dateLabel: dateLabel,
      headerRect: MmRect(left, top, w, BookLayoutMetrics.continuationHeaderHeight),
      grid: grid(continuationGridTop, continuationFit, cells),
    ));
  }
}

MemoPage _memoPage(BookSpec spec, int pageNumber) {
  final left = spec.safeMm;
  final top = spec.safeMm;
  final w = spec.contentWidthMm;
  final bottom = top + spec.contentHeightMm - BookLayoutMetrics.footerHeight;
  const spacing = 10.0;
  final lines = <double>[];
  for (var y = top + 20; y <= bottom; y += spacing) {
    lines.add(y);
  }
  return MemoPage(
    pageNumber: pageNumber,
    labelRect: MmRect(left, top, w, 9),
    lineYs: lines,
    lineStartX: left,
    lineEndX: left + w,
  );
}

/// 활동별 횟수 — 많은 순, 같으면 먼저 기록된 순.
List<ActivityCount> topActivities(List<BookDiaryEntry> sortedEntries, {int limit = 3}) {
  final counts = <String, int>{};
  final firstSeen = <String, int>{};
  for (final entry in sortedEntries) {
    for (final label in entry.activities.toSet()) {
      counts[label] = (counts[label] ?? 0) + 1;
      firstSeen.putIfAbsent(label, () => firstSeen.length);
    }
  }
  final labels = counts.keys.toList()
    ..sort((a, b) {
      final diff = counts[b]! - counts[a]!;
      return diff != 0 ? diff : firstSeen[a]! - firstSeen[b]!;
    });
  return [for (final label in labels.take(limit)) ActivityCount(label, counts[label]!)];
}

SummaryPage _summaryPage(BookSpec spec, List<BookDiaryEntry> sorted, String periodLabel, int pageNumber) {
  final left = spec.safeMm;
  final top = spec.safeMm;
  final w = spec.contentWidthMm;
  final h = spec.contentHeightMm;
  return SummaryPage(
    pageNumber: pageNumber,
    periodLabel: periodLabel,
    diaryCount: sorted.length,
    topActivities: topActivities(sorted),
    titleRect: MmRect(left, top + h * 0.18, w, 16),
    bodyRect: MmRect(left + w * 0.12, top + h * 0.18 + 26, w * 0.76, 70),
    // 맨 아래 쪽 번호 자리(footerHeight) 바로 위.
    footerRect: MmRect(left, top + h - BookLayoutMetrics.footerHeight - 6, w, 6),
  );
}
