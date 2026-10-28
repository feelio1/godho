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

  const DiaryBookPreviewScreen({super.key, required this.input, this.spec = BookSpec.a5});

  @override
  ConsumerState<DiaryBookPreviewScreen> createState() => _DiaryBookPreviewScreenState();
}

class _DiaryBookPreviewScreenState extends ConsumerState<DiaryBookPreviewScreen> {
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
    final lowRes = layout.lowResolutionPageNumbers;
    final aspect = widget.spec.widthMm / widget.spec.heightMm;
    return Column(
      children: [
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
                            child: _PageImage(
                              key: ValueKey('page-$pageIndex'),
                              future: _pageImage(pageIndex),
                              label: '${pageIndex + 1}쪽',
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
                    '${lowRes.join(', ')}쪽에 해상도가 낮은 사진이 있어요. 인쇄하면 흐릿하게 보일 수 있어요.',
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
                        _PageImage(future: _thumbImage(index), label: '${index + 1}'),
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
