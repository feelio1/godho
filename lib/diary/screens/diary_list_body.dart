import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/pet.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/inline_error_message.dart';
import '../../widgets/mascot_image.dart';
import '../../widgets/mascot_message.dart';
import '../diary_calendar.dart' show diaryRecordedDays;
import '../diary_photo_display_merge.dart';
import '../diary_photo_display_widgets.dart';
import '../diary_photo_upload_queue.dart';
import '../diary_photo_upload_queue_service.dart';
import '../models/diary.dart';
import '../providers/diary_providers.dart';
import 'diary_detail_screen.dart';
import 'diary_form_screen.dart';
import 'diary_weather_icons.dart';

/// "우리 아이" 탭의 일기 보기("방향 개편" 지시서 D) — 선택된 반려동물이
/// 포함된 일기만, 최신순 카드 목록. 반려동물이 여러 마리면 "전체" 보기로
/// 전환할 수 있다. 게스트 게이팅·AppBar·반려동물 선택은 `PetTabScreen`이
/// 한 번만 가지므로, 여기서는 목록 본문만 맡는다(캘린더·진료기록 보기와
/// 같은 관례).
class DiaryListBody extends ConsumerStatefulWidget {
  final Pet selectedPet;
  final List<Pet> allPets;

  const DiaryListBody({super.key, required this.selectedPet, required this.allPets});

  @override
  ConsumerState<DiaryListBody> createState() => _DiaryListBodyState();
}

class _DiaryListBodyState extends ConsumerState<DiaryListBody> {
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    // 백그라운드 업로드 대기열이 바뀌면(사진 완료·실패) 목록을 다시
    // 불러 "올리는 중" 표시를 자동으로 교체한다("일기 재수정" 지시서
    // 2-3).
    DiaryPhotoUploadQueueService.instance.changeTick.addListener(_onQueueChanged);
  }

  @override
  void dispose() {
    DiaryPhotoUploadQueueService.instance.changeTick.removeListener(_onQueueChanged);
    super.dispose();
  }

  void _onQueueChanged() {
    if (!mounted) return;
    ref.invalidate(diariesPageProvider);
    ref.invalidate(diariesForPetProvider);
    ref.invalidate(diariesForMonthProvider);
    ref.invalidate(diaryPendingPhotosProvider);
  }

  void _openForm() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DiaryFormScreen(defaultPetIds: [widget.selectedPet.id])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diariesAsync = _showAll
        ? ref.watch(diariesPageProvider).whenData((page) => page.diaries)
        : ref.watch(diariesForPetProvider(widget.selectedPet.id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 0),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, size: 13, color: AppColors.textSecondary),
              SizedBox(width: 4),
              Text('일기는 나만 볼 수 있어요', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const _MonthlyDiaryTracker(),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 6),
          child: Row(
            children: [
              if (widget.allPets.length > 1) ...[
                Expanded(
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text(widget.selectedPet.name),
                        selected: !_showAll,
                        onSelected: (_) => setState(() => _showAll = false),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('전체'),
                        selected: _showAll,
                        onSelected: (_) => setState(() => _showAll = true),
                      ),
                    ],
                  ),
                ),
              ] else
                const Spacer(),
              FilledButton.icon(
                onPressed: _openForm,
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('일기 쓰기'),
              ),
            ],
          ),
        ),
        Expanded(
          child: diariesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => InlineErrorMessage(
              error: error,
              onRetry: () => ref.invalidate(diariesPageProvider),
            ),
            data: (diaries) {
              if (diaries.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: MascotMessage(
                      title: '오늘 ${widget.selectedPet.name}의 하루를 남겨보세요',
                      subtitle: '오늘 하루 있었던 일을 사진과 함께 가볍게 남겨두세요.',
                      assetPath: MascotImage.emptyRecordAssetPath,
                      overlayIcon: Icons.edit_note,
                      trailing: FilledButton.icon(
                        onPressed: _openForm,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('첫 일기 쓰기'),
                      ),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 24),
                itemCount: diaries.length,
                separatorBuilder: (context, i) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _DiaryCard(diary: diaries[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// "이번 달 ○일 기록했어요" + 날짜 점줄("일기 활성화" 지시서 J) — 기록한
/// 날만 채운 점으로 보여준다. 연속·끊김 표시는 없다(CLAUDE.md: "연속
/// ○일" 같은 압박형 장치 금지).
class _MonthlyDiaryTracker extends ConsumerWidget {
  const _MonthlyDiaryTracker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month, 1);
    final diaries = ref.watch(diariesForMonthProvider(month)).value ?? const <Diary>[];
    final recordedDays = diaryRecordedDays(diaries);
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 달 ${recordedDays.length}일 기록했어요',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var day = 1; day <= daysInMonth; day++)
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: recordedDays.contains(DateTime(now.year, now.month, day))
                        ? AppColors.diaryAccent
                        : AppColors.borderInput,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiaryCard extends ConsumerWidget {
  final Diary diary;

  const _DiaryCard({required this.diary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = diary.text.trim();
    final localPending = diary.pendingPhotoCount > 0
        ? ref.watch(diaryPendingPhotosProvider(diary.id)).value ?? const <DiaryPhotoQueueItem>[]
        : const <DiaryPhotoQueueItem>[];
    final displayPhotos = mergeDiaryPhotosForDisplay(
      uploaded: diary.photos,
      localPending: localPending,
      pendingPhotoCount: diary.pendingPhotoCount,
    );
    final thumb = displayPhotos.isEmpty ? null : displayPhotos.first;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DiaryDetailScreen(diaryId: diary.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.card),
        decoration: BoxDecoration(
          color: AppColors.warmBackground,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.field),
              child: thumb == null
                  ? Container(
                      width: 64,
                      height: 64,
                      color: AppColors.surfaceLight,
                      alignment: Alignment.center,
                      child: const MascotImage(size: 32),
                    )
                  : DiaryDisplayImage(
                      photo: thumb,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      // 보이는 크기(64·기기 배율)만큼만 디코딩한다 —
                      // 상세 PageView와 같은 절약("일기 수정" 지시서 2-3).
                      memCacheWidth: (64 * MediaQuery.of(context).devicePixelRatio).round(),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('M월 d일 (E)', 'ko_KR').format(diary.date),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      if (diary.weather != null) ...[
                        const SizedBox(width: 6),
                        Icon(diaryWeatherIcon(diary.weather!), size: 15, color: AppColors.textSecondary),
                      ],
                    ],
                  ),
                  if (diary.activities.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: diary.activities
                          .map((a) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(a.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              ))
                          .toList(),
                    ),
                  ],
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
