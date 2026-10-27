import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/pet.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/inline_error_message.dart';
import '../../widgets/mascot_image.dart';
import '../../widgets/mascot_message.dart';
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

class _DiaryCard extends StatelessWidget {
  final Diary diary;

  const _DiaryCard({required this.diary});

  @override
  Widget build(BuildContext context) {
    final preview = diary.text.trim();
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
              child: diary.photos.isEmpty
                  ? Container(
                      width: 64,
                      height: 64,
                      color: AppColors.surfaceLight,
                      alignment: Alignment.center,
                      child: const MascotImage(size: 32),
                    )
                  : CachedNetworkImage(
                      imageUrl: diary.photos.first.displayThumbPath,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        width: 64,
                        height: 64,
                        color: AppColors.surfaceLight,
                        alignment: Alignment.center,
                        child: const MascotImage(size: 32),
                      ),
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
