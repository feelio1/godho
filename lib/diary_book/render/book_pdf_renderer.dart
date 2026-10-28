import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../book_input.dart';
import '../book_layout.dart';
import '../book_spec.dart';

/// [BookLayout] → PDF. 배치는 레이아웃 엔진이 정한 mm 좌표를 그대로 옮겨
/// 그리기만 한다(미리보기와 나중의 인쇄용 파일이 같은 렌더러를 쓴다).
/// Flutter에 의존하지 않아 백그라운드 isolate와 단위 테스트에서 그대로 돈다.
///
/// 선·테두리·원고지·날씨 아이콘은 벡터 도형으로 직접 그리고, 이모지 글꼴은
/// 쓰지 않는다. 사진은 쪽을 그릴 때마다 [BookPhotoLoader]로 하나씩 읽는다.
class BookRenderFonts {
  /// 손글씨(나눔손글씨 펜) — 날짜·오늘 한 일·원고지·제목.
  final Uint8List handwriting;

  /// 인쇄된 칸 제목(IBM Plex Sans KR).
  final Uint8List label;

  const BookRenderFonts({required this.handwriting, required this.label});
}

/// 사진 id → JPEG/PNG 바이트. 못 읽으면 null(그 칸은 빈 회색 칸으로 둔다).
typedef BookPhotoLoader = Uint8List? Function(String photoId);

/// 쪽을 하나 그릴 때마다 (그린 쪽 수, 전체 쪽 수)로 불린다.
typedef BookRenderProgress = void Function(int done, int total);

class BookPalette {
  static const navy = PdfColor.fromInt(0xFF1B4D8C);
  static const navyLight = PdfColor.fromInt(0xFF8FA8CC);
  static const cream = PdfColor.fromInt(0xFFFFF8EC);
  static const creamFrame = PdfColor.fromInt(0xFFFFF4E0);
  static const paperDot = PdfColor.fromInt(0xFFF3E6CF);
  static const coral = PdfColor.fromInt(0xFFE07A5F);
  static const ink = PdfColor.fromInt(0xFF3A3A3A);
  static const muted = PdfColor.fromInt(0xFF8A8A8A);
  static const placeholder = PdfColor.fromInt(0xFFE8E2D6);
  static const sun = PdfColor.fromInt(0xFFF2B33D);
  static const cloud = PdfColor.fromInt(0xFFB9C7DA);
  static const snow = PdfColor.fromInt(0xFF3D7CC9);
}

const double _mm = PdfPageFormat.mm;

/// 렌더러 버전 — 그리는 방식이 바뀌면 올려서 캐시된 미리보기를 무효화한다.
const int kBookRendererVersion = 1;

Future<Uint8List> renderBookPdf(
  BookLayout layout, {
  required BookSpec spec,
  required BookRenderFonts fonts,
  required BookPhotoLoader loadPhoto,
  BookRenderProgress? onProgress,
}) async {
  final hand = pw.Font.ttf(ByteData.sublistView(fonts.handwriting));
  final label = pw.Font.ttf(ByteData.sublistView(fonts.label));
  final r = _Renderer(spec: spec, hand: hand, label: label, loadPhoto: loadPhoto);
  final doc = pw.Document(title: layout.pages.whereType<CoverPage>().firstOrNull?.title, creator: 'Petcli');
  final format = PdfPageFormat(spec.widthMm * _mm, spec.heightMm * _mm, marginAll: 0);
  final total = layout.pages.length;
  for (final page in layout.pages) {
    doc.addPage(pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.zero,
      // 실제 배치·그리기는 save() 때 쪽 순서대로 일어난다 — 진행 표시와
      // 사진 읽기를 여기서 해 사진을 한 번에 다 들고 있지 않게 한다.
      build: (context) {
        final widget = r.page(page);
        onProgress?.call(page.pageNumber, total);
        return widget;
      },
    ));
  }
  return doc.save();
}

/// mm(왼쪽 위 원점) 좌표로 그리는 캔버스 — pdf 캔버스는 왼쪽 아래 원점·pt.
class _MmCanvas {
  final PdfGraphics g;
  final double pageHeightMm;

  _MmCanvas(this.g, this.pageHeightMm);

  double x(double mm) => mm * _mm;
  double y(double mm) => (pageHeightMm - mm) * _mm;

  void fillRect(MmRect r, PdfColor color) {
    g
      ..setFillColor(color)
      ..drawRect(x(r.x), y(r.bottom), r.width * _mm, r.height * _mm)
      ..fillPath();
  }

  void roundRect(MmRect r, double radiusMm, {PdfColor? fill, PdfColor? stroke, double strokeMm = 0.4}) {
    g.drawRRect(x(r.x), y(r.bottom), r.width * _mm, r.height * _mm, radiusMm * _mm, radiusMm * _mm);
    if (fill != null && stroke != null) {
      g
        ..setFillColor(fill)
        ..setStrokeColor(stroke)
        ..setLineWidth(strokeMm * _mm)
        ..fillAndStrokePath();
    } else if (fill != null) {
      g
        ..setFillColor(fill)
        ..fillPath();
    } else if (stroke != null) {
      g
        ..setStrokeColor(stroke)
        ..setLineWidth(strokeMm * _mm)
        ..strokePath();
    }
  }

  void line(double x1, double y1, double x2, double y2) => g.drawLine(x(x1), y(y1), x(x2), y(y2));

  void stroke(PdfColor color, double widthMm) {
    g
      ..setStrokeColor(color)
      ..setLineWidth(widthMm * _mm)
      ..strokePath();
  }

  void circle(double cx, double cy, double r) => g.drawEllipse(x(cx), y(cy), r * _mm, r * _mm);

  void fill(PdfColor color) {
    g
      ..setFillColor(color)
      ..fillPath();
  }

  void moveTo(double px, double py) => g.moveTo(x(px), y(py));
  void lineTo(double px, double py) => g.lineTo(x(px), y(py));
  void curveTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      g.curveTo(x(x1), y(y1), x(x2), y(y2), x(x3), y(y3));
}

class _Renderer {
  final BookSpec spec;
  final pw.Font hand;
  final pw.Font label;
  final BookPhotoLoader loadPhoto;

  _Renderer({required this.spec, required this.hand, required this.label, required this.loadPhoto});

  pw.TextStyle _hand(double pt, PdfColor color) =>
      pw.TextStyle(font: hand, fontSize: pt, color: color, fontFallback: [label]);

  pw.TextStyle _label(double pt, PdfColor color) => pw.TextStyle(font: label, fontSize: pt, color: color);

  pw.Widget page(BookPage page) {
    final painters = <void Function(_MmCanvas)>[];
    final overlays = <pw.Widget>[];
    switch (page) {
      case CoverPage():
        _cover(page, painters, overlays);
      case DiaryPage():
        painters.add(_paper);
        _diary(page, painters, overlays);
      case ContinuationPage():
        painters.add(_paper);
        _continuation(page, painters, overlays);
      case MemoPage():
        painters.add(_paper);
        _memo(page, painters, overlays);
      case SummaryPage():
        painters.add(_paper);
        _summary(page, overlays);
    }
    final pageLabel = page.pageLabel;
    if (pageLabel != null) {
      final rect = MmRect(spec.safeMm, spec.heightMm - spec.safeMm - 5, spec.contentWidthMm, 5);
      overlays.add(_text(rect, pageLabel, _label(7, BookPalette.muted)));
    }
    return pw.Stack(
      fit: pw.StackFit.expand,
      children: [
        pw.CustomPaint(
          size: PdfPoint(spec.widthMm * _mm, spec.heightMm * _mm),
          painter: (canvas, size) {
            final c = _MmCanvas(canvas, spec.heightMm);
            for (final paint in painters) {
              paint(c);
            }
          },
        ),
        ...overlays,
      ],
    );
  }

  // ── 공통 ────────────────────────────────────────────────────────────

  /// 크림 종이 + 아주 옅은 점무늬(인쇄에 거슬리지 않게 대비를 낮춘다).
  void _paper(_MmCanvas c) {
    c.fillRect(MmRect(0, 0, spec.widthMm, spec.heightMm), BookPalette.cream);
    const step = 4.0;
    for (var y = step / 2; y < spec.heightMm; y += step) {
      for (var x = step / 2; x < spec.widthMm; x += step) {
        c.circle(x, y, 0.16);
      }
    }
    c.fill(BookPalette.paperDot);
  }

  pw.Widget _at(MmRect r, pw.Widget child) => pw.Positioned(
        left: r.x * _mm,
        top: r.y * _mm,
        child: pw.SizedBox(width: r.width * _mm, height: r.height * _mm, child: child),
      );

  pw.Widget _text(
    MmRect r,
    String text,
    pw.TextStyle style, {
    pw.Alignment alignment = pw.Alignment.center,
  }) =>
      _at(
        r,
        pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: alignment,
          child: pw.Text(text, style: style),
        ),
      );

  /// 사진 한 칸 — 엔진이 정한 crop 영역만 칸에 보이게 확대·이동 후 잘라낸다.
  pw.Widget _photo(PhotoSlot slot, double radiusMm) {
    final w = slot.rect.width * _mm;
    final h = slot.rect.height * _mm;
    pw.Widget content;
    final bytes = loadPhoto(slot.photo.id);
    pw.ImageProvider? image;
    if (bytes != null) {
      try {
        image = pw.MemoryImage(bytes);
      } catch (_) {
        image = null;
      }
    }
    if (image == null) {
      content = pw.Container(color: BookPalette.placeholder);
    } else if (slot.crop.width >= 1 && slot.crop.height >= 1) {
      content = pw.Image(image, width: w, height: h, fit: pw.BoxFit.cover);
    } else {
      final displayW = w / slot.crop.width;
      final displayH = h / slot.crop.height;
      content = pw.Stack(
        overflow: pw.Overflow.clip,
        children: [
          pw.Positioned(
            left: -slot.crop.left * displayW,
            top: -slot.crop.top * displayH,
            child: pw.Image(image, width: displayW, height: displayH, fit: pw.BoxFit.fill),
          ),
        ],
      );
    }
    return _at(
      slot.rect,
      pw.ClipRRect(
        horizontalRadius: radiusMm * _mm,
        verticalRadius: radiusMm * _mm,
        child: pw.SizedBox(width: w, height: h, child: content),
      ),
    );
  }

  void _gridLines(_MmCanvas c, ManuscriptGrid grid) {
    final r = grid.rect;
    for (var row = 1; row < grid.rows; row++) {
      final y = r.y + row * grid.cellMm;
      c.line(r.x, y, r.right, y);
    }
    for (var col = 1; col < grid.columns; col++) {
      final x = r.x + col * grid.cellMm;
      c.line(x, r.y, x, r.bottom);
    }
    c.stroke(BookPalette.navyLight, 0.18);
    c.g.drawRect(c.x(r.x), c.y(r.bottom), r.width * _mm, r.height * _mm);
    c.stroke(BookPalette.navy, 0.35);
  }

  void _gridText(ManuscriptGrid grid, List<pw.Widget> overlays) {
    final style = _hand(grid.cellMm * _mm * 0.66, BookPalette.ink);
    for (var row = 0; row < grid.rows; row++) {
      for (var col = 0; col < grid.columns; col++) {
        final ch = grid.cells[row][col];
        if (ch.isEmpty) continue;
        overlays.add(_text(grid.cellRect(row, col).inset(grid.cellMm * 0.08), ch, style));
      }
    }
  }

  // ── 표지 ────────────────────────────────────────────────────────────

  void _cover(CoverPage page, List<void Function(_MmCanvas)> painters, List<pw.Widget> overlays) {
    painters.add((c) {
      c.fillRect(MmRect(0, 0, spec.widthMm, spec.heightMm), BookPalette.navy);
      c.roundRect(page.frameRect, 6, fill: BookPalette.creamFrame);
      if (page.photo == null) c.roundRect(page.frameRect.inset(3), 4, fill: BookPalette.placeholder);
    });
    if (page.photo != null) overlays.add(_photo(page.photo!, 4));
    overlays.add(_text(page.titleRect, page.title, _hand(34, BookPalette.cream)));
    overlays.add(_text(page.periodRect, page.periodLabel, _label(11, BookPalette.cream)));
  }

  // ── 내지 ────────────────────────────────────────────────────────────

  void _diary(DiaryPage page, List<void Function(_MmCanvas)> painters, List<pw.Widget> overlays) {
    painters.add((c) {
      c.roundRect(page.headerRect, 2.5, fill: BookPalette.cream, stroke: BookPalette.navy);
      c.line(page.headerDividerX, page.headerRect.y, page.headerDividerX, page.headerRect.bottom);
      c.stroke(BookPalette.navy, 0.4);
      for (final icon in page.weatherIcons) {
        _weatherIcon(c, icon);
      }
      final mark = page.weatherMark;
      if (mark != null) {
        c.circle(mark.centerX, mark.centerY, mark.radiusMm);
        c.stroke(BookPalette.coral, 0.4);
      }
      // 오늘 한 일 아래 점선.
      c.g.setLineDashPattern([1.2 * _mm, 1.0 * _mm]);
      c.line(page.activityLabelRect.x, page.activityLineY, page.headerRect.right, page.activityLineY);
      c.stroke(BookPalette.navy, 0.25);
      c.g.setLineDashPattern();
      if (page.pictureBox != null) {
        c.roundRect(page.pictureBox!, 3, fill: BookPalette.cream, stroke: BookPalette.navy);
      }
      _gridLines(c, page.grid);
    });
    _gridText(page.grid, overlays);
    overlays
      ..add(_text(page.dateLabelRect, '날짜', _label(7.5, BookPalette.navy)))
      ..add(_text(page.dateTextRect, page.dateLabel, _hand(17, BookPalette.ink), alignment: pw.Alignment.centerLeft))
      ..add(_text(page.weatherLabelRect, '날씨', _label(7.5, BookPalette.navy)))
      ..add(_text(page.activityLabelRect, '오늘 한 일', _label(7.5, BookPalette.navy),
          alignment: pw.Alignment.centerLeft));
    if (page.activityText.isNotEmpty) {
      overlays.add(_text(page.activityTextRect, page.activityText, _hand(16, BookPalette.ink),
          alignment: pw.Alignment.centerLeft));
    }
    for (final slot in page.photos) {
      overlays.add(_photo(slot, 1.5));
    }
  }

  void _continuation(ContinuationPage page, List<void Function(_MmCanvas)> painters, List<pw.Widget> overlays) {
    painters.add((c) {
      c.roundRect(page.headerRect, 2, stroke: BookPalette.navyLight, strokeMm: 0.3);
      _gridLines(c, page.grid);
    });
    _gridText(page.grid, overlays);
    final h = page.headerRect;
    overlays
      ..add(_text(MmRect(h.x + 3, h.y, h.width * 0.7, h.height), page.dateLabel, _hand(14, BookPalette.ink),
          alignment: pw.Alignment.centerLeft))
      ..add(_text(MmRect(h.right - 20, h.y, 17, h.height), '(이어서)', _label(7, BookPalette.muted),
          alignment: pw.Alignment.centerRight));
  }

  void _memo(MemoPage page, List<void Function(_MmCanvas)> painters, List<pw.Widget> overlays) {
    painters.add((c) {
      c.g.setLineDashPattern([1.2 * _mm, 1.0 * _mm]);
      for (final y in page.lineYs) {
        c.line(page.lineStartX, y, page.lineEndX, y);
      }
      c.stroke(BookPalette.navyLight, 0.2);
      c.g.setLineDashPattern();
    });
    overlays.add(_text(page.labelRect, '메모', _hand(20, BookPalette.navy), alignment: pw.Alignment.centerLeft));
  }

  void _summary(SummaryPage page, List<pw.Widget> overlays) {
    final activities = page.topActivities.isEmpty
        ? '기록된 활동이 없어요'
        : page.topActivities.map((a) => '${a.label} ${a.count}번').join(' · ');
    pw.Widget row(String title, String value) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 14),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: _label(8, BookPalette.navy)),
              pw.SizedBox(height: 3),
              pw.Text(value, style: _hand(18, BookPalette.ink)),
            ],
          ),
        );
    overlays
      ..add(_text(page.titleRect, '함께한 날들', _hand(30, BookPalette.navy)))
      ..add(_at(
        page.bodyRect,
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            row('기간', page.periodLabel),
            row('일기', '${page.diaryCount}편'),
            row('가장 많이 한 활동', activities),
          ],
        ),
      ))
      ..add(_text(page.footerRect, kBookFooterText, _label(6.5, BookPalette.muted)));
  }

  // ── 날씨 아이콘(벡터) ────────────────────────────────────────────────

  void _weatherIcon(_MmCanvas c, WeatherIconSlot icon) {
    final cx = icon.centerX;
    final cy = icon.centerY;
    final s = icon.sizeMm;
    switch (icon.weather) {
      case BookWeather.sunny:
        _sun(c, cx, cy, s, BookPalette.navy);
      case BookWeather.partlyCloudy:
        _sun(c, cx - s * 0.18, cy - s * 0.15, s * 0.7, BookPalette.sun);
        _cloud(c, cx + s * 0.08, cy + s * 0.12, s * 0.8, BookPalette.cloud);
      case BookWeather.cloudy:
        _cloud(c, cx, cy, s, BookPalette.cloud);
      case BookWeather.rainy:
        _umbrella(c, cx, cy, s);
      case BookWeather.snowy:
        final r = s * 0.42;
        for (var i = 0; i < 3; i++) {
          final a = math.pi / 3 * i + math.pi / 2;
          c.line(cx - r * math.cos(a), cy - r * math.sin(a), cx + r * math.cos(a), cy + r * math.sin(a));
        }
        c.stroke(BookPalette.snow, 0.35);
    }
  }

  void _sun(_MmCanvas c, double cx, double cy, double s, PdfColor color) {
    final r = s * 0.2;
    c.circle(cx, cy, r);
    c.fill(color);
    for (var i = 0; i < 8; i++) {
      final a = math.pi / 4 * i;
      c.line(cx + r * 1.5 * math.cos(a), cy + r * 1.5 * math.sin(a), cx + r * 2.2 * math.cos(a),
          cy + r * 2.2 * math.sin(a));
    }
    c.stroke(color, 0.3);
  }

  void _cloud(_MmCanvas c, double cx, double cy, double s, PdfColor color) {
    final u = s / 4;
    c
      ..circle(cx - u * 0.9, cy + u * 0.3, u * 0.8)
      ..circle(cx, cy - u * 0.2, u * 1.1)
      ..circle(cx + u * 1.0, cy + u * 0.35, u * 0.75);
    c.g.drawRect(c.x(cx - u * 0.9), c.y(cy + u * 1.1), u * 1.9 * _mm, u * 0.8 * _mm);
    c.fill(color);
  }

  void _umbrella(_MmCanvas c, double cx, double cy, double s) {
    final r = s * 0.45;
    const k = 0.5523;
    final top = cy - r * 0.35;
    c
      ..moveTo(cx - r, top + r * 0.6)
      ..curveTo(cx - r, top + r * 0.6 - k * r, cx - k * r, top - r * 0.4, cx, top - r * 0.4)
      ..curveTo(cx + k * r, top - r * 0.4, cx + r, top + r * 0.6 - k * r, cx + r, top + r * 0.6);
    c.g.closePath();
    c.fill(BookPalette.navy);
    c.line(cx, top + r * 0.6, cx, cy + r * 0.9);
    c.line(cx, cy + r * 0.9, cx - r * 0.3, cy + r * 0.9);
    c.stroke(BookPalette.navy, 0.3);
  }
}
