import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/effective_pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../utils/appointment_calendar.dart' show dateOnly;
import '../../widgets/mascot_image.dart';
import '../providers/diary_providers.dart';
import 'diary_detail_screen.dart';

/// 홈 "그날의 기록" 카드("일기 활성화" 지시서 I) — 1년 전 오늘 일기가
/// 있으면 그것, 없으면 한 달 전 오늘, 둘 다 없으면 아무것도 그리지 않는다
/// ([OurPetCard]·[TodayDiaryRow]와 같은 관례 — 로그인+대상 일기가 있을
/// 때만 스스로 나타난다). 반려동물이 무지개다리를 건넜는지 같은 상태
/// 정보가 없으므로 문구는 담백하게("그날의 ○○") — 과한 감탄·이모지 없음.
class OnThisDayDiaryCard extends ConsumerWidget {
  const OnThisDayDiaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) return const SizedBox.shrink();

    final diary = ref.watch(onThisDayDiaryProvider).value;
    if (diary == null) return const SizedBox.shrink();

    final pets = ref.watch(effectivePetsProvider).value ?? const [];
    String petName = '반려동물';
    for (final pet in pets) {
      if (diary.petIds.contains(pet.id)) {
        petName = pet.name;
        break;
      }
    }

    final today = dateOnly(DateTime.now());
    final yearAgo = DateTime(today.year - 1, today.month, today.day);
    final isYearAgo = dateOnly(diary.date) == yearAgo;
    final label = isYearAgo ? '1년 전 오늘' : '한 달 전 오늘';
    final preview = diary.text.trim().split('\n').first;
    final thumbPath = diary.photos.isEmpty ? null : diary.photos.first.displayThumbPath;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
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
                child: thumbPath == null
                    ? Container(
                        width: 48,
                        height: 48,
                        color: AppColors.surfaceLight,
                        alignment: Alignment.center,
                        child: const MascotImage(size: 26),
                      )
                    : CachedNetworkImage(
                        imageUrl: thumbPath,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          width: 48,
                          height: 48,
                          color: AppColors.surfaceLight,
                          alignment: Alignment.center,
                          child: const MascotImage(size: 26),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label · 그날의 $petName',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        preview,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
