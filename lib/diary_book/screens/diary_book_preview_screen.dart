import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../book_input.dart';
import '../book_layout.dart';
import '../book_layout_engine.dart';
import '../book_spec.dart';
import '../diary_book_pdf_service.dart';
import '../diary_book_source.dart';

/// 미리보기 화면에만 겹쳐 그리는 워터마크 문구 — PDF(인쇄 파일)에는 그리지
/// 않는다. 캡처본을 인쇄 주문 없이 쓰기 어렵게 하되, 자기 일기를 보여주는 건
/// 막지 않는다(캡처 차단은 하지 않음). "펫클" 표기는 넣지 않는다(책 내지 규칙).
const String kPreviewWatermarkCaption = '미리보기 · 인쇄본에는 표시되지 않아요';
const String kPreviewWatermarkDiagonal = '미리보기';

/// 쪽 묶음 — 한쪽 보기는 쪽마다, 펼침면은 표지·뒷면을 홑으로 두고 그 사이를
/// 둘씩(2–3, 4–5, …) 묶는다. 값은 0부터 세는 쪽 인덱스.
List<List<int>> diaryBookViews(int pageCount, {required bool spread}) {
  if (!spread) return [for (var i = 0; i < pageCount; i++) [i]];
  final views = <List<int>>[if (pageCount > 0) [0]];
  var i = 1;
  while (i < pageCount) {
    if (i == pageCount - 1) {
      views.add([i]);
      i++;
    } else {
      views.add([i, i + 1]);
      i += 2;
    }
  }
  return views;
}

/// 그림일기 미리보기 — 앱이 만든 PDF를 그대로 보여준다(미리보기 = 나중에
/// 인쇄할 파일). 주문·결제·PDF 저장/공유는 이번 단계에 없다.
class DiaryBookPreviewScreen extends ConsumerStatefulWidget {
  final BookInput input;
  final BookSpec spec;

  /// 다른 기기에서 아직 올라가는 중이라 이번 미리보기에서 빠진 사진 수.
  final int missingPhotoCount;

  const DiaryBookPreviewScreen({
    super.key,
    required this.input,
    this.spec = BookSpec.a5,
    this.missingPhotoCount = 0,
  });

  @override
  ConsumerState<DiaryBookPreviewScreen> createState() => _DiaryBookPreviewScreenState();
}

class _DiaryBookPreviewScreenState extends ConsumerState<DiaryBookPreviewScreen> {
  // 캡처본을 인쇄에 쓰기 어렵게 하려는 상한 — 올리지 말 것. 인쇄용 고해상도는
  // 주문 시 별도 생성. 확대(InteractiveViewer)해도 더 높은 dpi로 다시 그리지
  // 않고, 미리보기 PDF(앱 캐시)를 공유·저장·외부 열기로 내보내는 경로도 없다.
  static const _pageDpi = 110.0;
  static const _thumbDpi = 24.0;
  static const _maxCachedPages = 8;

  BookLayout? _layout;
  DiaryBookPdf? _pdf;
  Object? _error;
  DiaryBookProgress? _progress;
  bool _spread = false;
  int _viewIndex = 0;
  final _pageController = PageController();

  /// 큰 쪽 이미지는 최근 몇 장만 메모리에 둔다(긴 책에서도 메모리 피크를
  /// 낮게). 썸네일은 작아서 전부 둔다.
  final _pageImages = <int, Future<Uint8List>>{}; // 삽입 순서 유지(최근 본 쪽이 뒤)
  final _thumbImages = <int, Future<Uint8List>>{};

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _error = null;
      _pdf = null;
      _progress = null;
    });
    try {
      final result = layoutBook(widget.input, spec: widget.spec);
      if (result is! BookLayoutOk) throw StateError('layout: $result');
      _layout = result.layout;
      final pdf = await ref.read(diaryBookPdfGeneratorProvider).generate(
            result.layout,
            spec: widget.spec,
            cacheKey: diaryBookCacheKey(widget.input, widget.spec),
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      if (!mounted) return;
      setState(() => _pdf = pdf);
    } catch (e) {
      debugPrint('[DiaryBookPreview] 생성 실패: $e');
      if (mounted) setState(() => _error = e);
    }
  }

  Future<Uint8List> _pageImage(int index) {
    final existing = _pageImages.remove(index);
    if (existing != null) {
      _pageImages[index] = existing;
      return existing;
    }
    final future = ref.read(diaryBookRasterizerProvider)(_pdf!.bytes, index, _pageDpi);
    _pageImages[index] = future;
    while (_pageImages.length > _maxCachedPages) {
      _pageImages.remove(_pageImages.keys.first);
    }
    return future;
  }

  Future<Uint8List> _thumbImage(int index) =>
      _thumbImages.putIfAbsent(index, () => ref.read(diaryBookRasterizerProvider)(_pdf!.bytes, index, _thumbDpi));

  void _setSpread(bool spread) {
    final views = diaryBookViews(_layout!.pageCount, spread: _spread);
    final firstPage = views[_viewIndex.clamp(0, views.length - 1)].first;
    final next = diaryBookViews(_layout!.pageCount, spread: spread);
    final nextIndex = next.indexWhere((v) => v.contains(firstPage));
    setState(() {
      _spread = spread;
      _viewIndex = nextIndex < 0 ? 0 : nextIndex;
    });
    _pageController.jumpToPage(_viewIndex);
  }

  void _jumpToPage(int pageIndex) {
    final views = diaryBookViews(_layout!.pageCount, spread: _spread);
    final target = views.indexWhere((v) => v.contains(pageIndex));
    if (target >= 0) {
      _pageController.animateToPage(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('그림일기 미리보기')),
      body: _error != null
          ? _ErrorView(onRetry: _generate)
          : _pdf == null
              ? _ProgressView(progress: _progress)
              : _buildPreview(context),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final layout = _layout!;
    final views = diaryBookViews(layout.pageCount, spread: _spread);
    final lowRes = layout.lowResolutionPageNames;
    final aspect = widget.spec.widthMm / widget.spec.heightMm;
    return Column(
      children: [
        // 다른 기기에서 아직 올라가는 중인 사진 — 회색 정보 톤, 0장이면 숨김.
        if (widget.missingPhotoCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 0),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '사진 ${widget.missingPhotoCount}장은 아직 올라가는 중이라 이번 미리보기에서 빠졌어요',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 4),
          child: Row(
            children: [
              Text('${layout.pageCount}쪽', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('한쪽')),
                  ButtonSegment(value: true, label: Text('펼침면')),
                ],
                selected: {_spread},
                onSelectionChanged: (s) => _setSpread(s.first),
                showSelectedIcon: false,
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: views.length,
            onPageChanged: (i) => setState(() => _viewIndex = i),
            itemBuilder: (context, i) => InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final pageIndex in views[i])
                        Flexible(
                          child: AspectRatio(
                            aspectRatio: aspect,
                            // 워터마크는 쪽 위에 겹쳐 쪽과 함께 확대·이동된다.
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _PageImage(
                                  key: ValueKey('page-$pageIndex'),
                                  future: _pageImage(pageIndex),
                                  label: layout.pages[pageIndex].displayName,
                                ),
                                _PreviewWatermark(spec: widget.spec),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (lowRes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${lowRes.join(', ')}에 해상도가 낮은 사진이 있어요. 인쇄하면 흐릿하게 보일 수 있어요.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 6),
            scrollDirection: Axis.horizontal,
            itemCount: layout.pageCount,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final page = layout.pages[index];
              final current = views[_viewIndex.clamp(0, views.length - 1)].contains(index);
              return GestureDetector(
                onTap: () => _jumpToPage(index),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: current ? AppColors.primary : AppColors.borderCard,
                      width: current ? 2 : 1,
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: aspect,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _PageImage(future: _thumbImage(index), label: page.displayName),
                        if (page.hasLowResolutionPhoto)
                          const Positioned(
                            right: 2,
                            top: 2,
                            child: Icon(
                              Icons.info_outline,
                              key: Key('diaryBookLowResIcon'),
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: null, child: Text('책으로 주문하기')),
                ),
                const SizedBox(height: 6),
                const Text('곧 주문할 수 있어요', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 쪽 위 워터마크 — (a) 하단 가운데 작은 안내 1줄, (b) 가운데 아주 옅은 대각선
/// "미리보기". 크기는 쪽 너비에 비례해 확대해도 쪽과 같은 비율로 보인다. 안내
/// 줄은 쪽 아래 안전 여백 띠(쪽 번호 아래) 가운데에 둬 원고지·쪽 번호를 가리지
/// 않는다. 중립 회색만 쓰고(빨강·주황 금지), 제스처는 막지 않는다.
class _PreviewWatermark extends StatelessWidget {
  final BookSpec spec;

  const _PreviewWatermark({required this.spec});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final bottomBand = h * spec.safeMm / spec.heightMm;
          return Stack(
            children: [
              Center(
                child: Transform.rotate(
                  angle: -30 * math.pi / 180,
                  child: Opacity(
                    opacity: 0.07,
                    child: Text(
                      kPreviewWatermarkDiagonal,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans KR',
                        fontSize: w * 0.22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: w * spec.safeMm / spec.widthMm,
                right: w * spec.safeMm / spec.widthMm,
                bottom: 0,
                height: bottomBand,
                child: Center(
                  child: Opacity(
                    opacity: 0.55,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        kPreviewWatermarkCaption,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans KR',
                          fontSize: w * 0.026,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PageImage extends StatelessWidget {
  final Future<Uint8List> future;
  final String label;

  const _PageImage({super.key, required this.future, required this.label});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true, semanticLabel: label);
        }
        return ColoredBox(
          color: AppColors.warmBackground,
          child: Center(
            child: snapshot.hasError
                ? Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))
                : const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      },
    );
  }
}

class _ProgressView extends StatelessWidget {
  final DiaryBookProgress? progress;

  const _ProgressView({required this.progress});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.page * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: p == null || p.total == 0 ? null : p.done / p.total),
            const SizedBox(height: 12),
            Text(p?.message ?? '그림일기 만드는 중', style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('그림일기를 만들지 못했어요', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
