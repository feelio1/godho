import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../ads/app_open_ad_suppression.dart';
import '../../diary/models/diary.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../diary_page_image_service.dart';
import 'diary_book_setup_screen.dart';

/// 공유 시트 호출 — 테스트에서 바꿔 끼운다.
typedef DiaryPageSharer = Future<void> Function(List<XFile> files);

final diaryPageSharerProvider = Provider<DiaryPageSharer>(
  (ref) => (files) async {
    await SharePlus.instance.share(ShareParams(files: files));
  },
);

/// 그 일기의 그림일기 장 PNG(가로 1080px, 쪽이 여러 장이면 여러 장)를 시스템
/// 공유 시트로 보낸다(4차 업데이트 K-4) — 사용자가 버튼을 눌렀을 때만.
/// 렌더링한 이미지라 원본 사진의 EXIF·위치 정보는 들어가지 않는다. 공유
/// 앱에 다녀오는 동안 앱 오프닝 광고가 뜨지 않게 억제한다.
Future<void> shareDiaryPage(BuildContext context, WidgetRef ref, Diary diary) async {
  final uid = ref.read(authStateProvider).value?.uid;
  if (uid == null) return;
  final suppression = ref.read(adSuppressionProvider);
  final sharer = ref.read(diaryPageSharerProvider);
  final service = ref.read(diaryPageImageServiceProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await suppression.during(() async {
      final built = await diaryPageEntryFor(diary, uid);
      final files = await service.generate(built.entry, share: true);
      await sharer([for (final f in files) XFile(f.path, mimeType: 'image/png')]);
    });
  } catch (e) {
    debugPrint('[shareDiaryPage] 공유 실패: $e');
    messenger?.showSnackBar(const SnackBar(content: Text('그림일기 장을 공유하지 못했어요. 다시 시도해 주세요.')));
  }
}

/// 일기 한 편의 그림일기 장 보기(4차 업데이트 K-2) — 전체 화면, 핀치 확대,
/// 하단 [공유하기]·[그림일기 전체 보기]. 내 일기 한 장 보기라 미리보기
/// 워터마크는 그리지 않는다.
class DiaryPageScreen extends ConsumerWidget {
  final Diary diary;

  const DiaryPageScreen({super.key, required this.diary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final imagesAsync = uid == null ? null : ref.watch(diaryPageImagesProvider((diary: diary, uid: uid, share: false)));

    return Scaffold(
      appBar: AppBar(title: const Text('그림일기 장')),
      body: imagesAsync == null
          ? const SizedBox.shrink()
          : imagesAsync.when(
              loading: () => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('그림일기 장 그리는 중…', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '그림일기 장을 만들지 못했어요. 다시 시도해 주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () =>
                            ref.invalidate(diaryPageImagesProvider((diary: diary, uid: uid!, share: false))),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (images) => Column(
                children: [
                  if (images.missingPhotoCount > 0) DiaryPageMissingPhotosNotice(count: images.missingPhotoCount),
                  Expanded(
                    child: PageView(
                      children: [
                        for (final file in images.files)
                          InteractiveViewer(
                            maxScale: 4,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.page),
                                child: Image.file(file, fit: BoxFit.contain, semanticLabel: '그림일기 장'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (images.files.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '옆으로 넘기면 이어지는 장이 있어요 (${images.files.length}장)',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('diary_page_share'),
                  onPressed: () => shareDiaryPage(context, ref, diary),
                  icon: const Icon(Icons.ios_share, size: 20),
                  label: const Text('공유하기'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          DiaryBookSetupScreen(initialPetId: diary.petIds.isEmpty ? null : diary.petIds.first),
                    ),
                  ),
                  child: const Text('그림일기 전체 보기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "사진 n장은 아직 올라가는 중이라 빠졌어요" — 회색 정보 톤, 0장이면 그리지 않는다.
class DiaryPageMissingPhotosNotice extends StatelessWidget {
  final int count;

  const DiaryPageMissingPhotosNotice({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.softPanel, borderRadius: BorderRadius.circular(12)),
      child: Text(
        '사진 $count장은 아직 올라가는 중이라 빠졌어요',
        style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
      ),
    );
  }
}

/// 첫 장 시트 등에서 쓰는 그림일기 장 썸네일(첫 쪽) — 만드는 중이면 자리만.
class DiaryPageThumbnail extends ConsumerWidget {
  final Diary diary;
  final double height;

  const DiaryPageThumbnail({super.key, required this.diary, this.height = 220});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final images = uid == null
        ? null
        : ref.watch(diaryPageImagesProvider((diary: diary, uid: uid, share: false))).value;
    final File? first = images == null || images.files.isEmpty ? null : images.files.first;
    return SizedBox(
      height: height,
      child: first == null
          ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
          : Image.file(first, fit: BoxFit.contain, semanticLabel: '그림일기 장'),
    );
  }
}
