import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/effective_pets_provider.dart';
import '../../screens/account_pet_actions.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/keep_words.dart';
import '../../widgets/mascot_image.dart';
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

/// 홈 "우리 아이" 영역 — 버터색 둥근 띠("장구름의 수첩", 3차 업데이트
/// J-2): 왼쪽 구름이 얼굴, 가운데 손글씨 한 줄 + "일기는 나만 볼 수
/// 있어요", 오른쪽 버튼. 로그인 + 반려동물이 있을 때 오늘 일기가 없으면
/// [일기 쓰기](오늘·이 반려동물이 미리 선택된 작성 화면), 있으면 [일기 보기]
/// (상세). 압박 문구("연속 ○일" 등)는 쓰지 않는다. 로그인했지만 반려동물이
/// 0마리면(2차 업데이트 C) 등록 안내 + [등록]. 게스트는 아무것도 그리지 않는다.
class TodayDiaryRow extends ConsumerWidget {
  const TodayDiaryRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) return const SizedBox.shrink();

    final pets = ref.watch(effectivePetsProvider).value;
    if (pets == null) return const SizedBox.shrink();
    if (pets.isEmpty) {
      return _Strip(
        text: '우리 아이를 등록하면 일기를 남길 수 있어요',
        caption: '일기와 진료기록은 나만 볼 수 있어요',
        action: '등록',
        onTap: () => AccountPetActions.add(context, ref, uid),
      );
    }
    final pet = pets.first;

    final diary = ref.watch(todayDiaryProvider(pet.id)).value;

    return _Strip(
      text: diary == null ? '${pet.name}의 오늘, 한 줄만 남겨 볼까요?' : '${pet.name}의 오늘 일기를 남겼어요',
      caption: '일기는 나만 볼 수 있어요',
      action: diary == null ? '일기 쓰기' : '일기 보기',
      onTap: () {
        if (diary == null) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => DiaryFormScreen(defaultPetIds: [pet.id])));
        } else {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => DiaryDetailScreen(diaryId: diary.id)));
        }
      },
    );
  }
}

class _Strip extends StatelessWidget {
  final String text;
  final String caption;
  final String action;
  final VoidCallback onTap;

  const _Strip({required this.text, required this.caption, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      decoration: BoxDecoration(color: AppColors.warmBackground, borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Row(
        children: [
          const MascotImage(size: 60),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  keepWords(text),
                  style: AppTextStyles.hand(size: 22, color: AppColors.textPrimary, height: 1.25),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(caption, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}
