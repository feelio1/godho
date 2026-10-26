import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/effective_pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/appointment_calendar.dart' show dateOnly;
import '../models/diary.dart';
import '../providers/diary_providers.dart';
import 'diary_detail_screen.dart';
import 'diary_form_screen.dart';

/// 오늘 이 반려동물의 일기가 있는지 — 최신 페이지(20개) 안에서 찾는다.
/// 일기를 하루에 여러 번 쓰는 경우는 드물어 보통 페이지 안에 있다.
final todayDiaryProvider = FutureProvider.autoDispose.family<Diary?, String>((ref, petId) async {
  final today = dateOnly(DateTime.now());
  final diaries = await ref.watch(diariesForPetProvider(petId).future);
  for (final diary in diaries) {
    if (dateOnly(diary.date) == today) return diary;
  }
  return null;
});

/// 홈 "우리 아이" 영역의 "오늘의 일기 한 줄"("방향 개편" 지시서 B-3
/// 자리, F에서 연결) — [OurPetCard]와 같은 조건(로그인 + 반려동물 있을
/// 때)에서만 보이고, 그 외엔 아무것도 그리지 않는다. 오늘 일기가 없으면
/// [쓰기](오늘·이 반려동물이 미리 선택된 작성 화면), 있으면 [보기](상세)
/// 로 이어진다.
class TodayDiaryRow extends ConsumerWidget {
  const TodayDiaryRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) return const SizedBox.shrink();

    final pets = ref.watch(effectivePetsProvider).value ?? const [];
    if (pets.isEmpty) return const SizedBox.shrink();
    final pet = pets.first;

    final diary = ref.watch(todayDiaryProvider(pet.id)).value;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              diary == null ? '오늘 ${pet.name}의 하루를 남겨보세요' : '오늘 일기를 남겼어요',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () {
              if (diary == null) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DiaryFormScreen(defaultPetIds: [pet.id])),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DiaryDetailScreen(diaryId: diary.id)),
                );
              }
            },
            child: Text(diary == null ? '쓰기' : '보기'),
          ),
        ],
      ),
    );
  }
}
