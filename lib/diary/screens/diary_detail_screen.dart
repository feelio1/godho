import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../utils/network_error.dart';
import '../../widgets/inline_error_message.dart';
import '../models/diary.dart';
import '../providers/diary_providers.dart';
import 'diary_form_screen.dart';
import 'diary_weather_icons.dart';

/// 일기 상세("방향 개편" 지시서 D) — 사진 좌우 넘김(탭하면 전체 화면),
/// 날짜·날씨·태그·글, 수정/삭제.
class DiaryDetailScreen extends ConsumerWidget {
  final String diaryId;

  const DiaryDetailScreen({super.key, required this.diaryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diaryAsync = ref.watch(diaryProvider(diaryId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('일기'),
        actions: [
          diaryAsync.maybeWhen(
            data: (diary) => diary == null
                ? const SizedBox.shrink()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          final saved = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(builder: (_) => DiaryFormScreen(existing: diary)),
                          );
                          if (saved == true) ref.invalidate(diaryProvider(diaryId));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, ref, diary),
                      ),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: diaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => InlineErrorMessage(
          error: error,
          onRetry: () => ref.invalidate(diaryProvider(diaryId)),
        ),
        data: (diary) => diary == null
            ? const Center(child: Text('일기를 찾을 수 없어요'))
            : _DiaryDetailBody(diary: diary),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Diary diary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('일기 삭제'),
        content: const Text('이 일기와 첨부한 사진을 삭제합니다. 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    try {
      await ref.read(diaryRepositoryProvider).deleteDiary(uid, diary.id);
      ref.invalidate(diariesPageProvider);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(actionFailureMessage(e, '삭제'))),
        );
      }
    }
  }
}

class _DiaryDetailBody extends StatelessWidget {
  final Diary diary;

  const _DiaryDetailBody({required this.diary});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        if (diary.photos.isNotEmpty) ...[
          _PhotoPager(photos: diary.photos),
          const SizedBox(height: AppSpacing.section),
        ],
        Row(
          children: [
            Text(
              DateFormat('yyyy.MM.dd (E)', 'ko_KR').format(diary.date),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            if (diary.weather != null) ...[
              const SizedBox(width: 8),
              Icon(diaryWeatherIcon(diary.weather!), size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 2),
              Text(diary.weather!.label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ],
        ),
        if (diary.activities.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: diary.activities
                .map((a) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                      child: Text(a.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryTextTone)),
                    ))
                .toList(),
          ),
        ],
        if (diary.text.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          Text(diary.text, style: const TextStyle(fontSize: 14.5, height: 1.6, color: AppColors.textPrimary)),
        ],
      ],
    );
  }
}

class _PhotoPager extends StatefulWidget {
  final List<DiaryPhoto> photos;

  const _PhotoPager({required this.photos});

  @override
  State<_PhotoPager> createState() => _PhotoPagerState();
}

class _PhotoPagerState extends State<_PhotoPager> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullScreen(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _FullScreenPhotoViewer(photos: widget.photos, initialIndex: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: SizedBox(
            height: 280,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => _openFullScreen(i),
                child: CachedNetworkImage(
                  imageUrl: widget.photos[i].path,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorWidget: (context, url, error) => Container(color: AppColors.surfaceMutedLight),
                ),
              ),
            ),
          ),
        ),
        if (widget.photos.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.photos.length; i++)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page ? AppColors.primary : AppColors.borderInput,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FullScreenPhotoViewer extends StatelessWidget {
  final List<DiaryPhoto> photos;
  final int initialIndex;

  const _FullScreenPhotoViewer({required this.photos, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: photos.length,
        itemBuilder: (context, i) => InteractiveViewer(
          child: Center(
            child: CachedNetworkImage(imageUrl: photos[i].path, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
