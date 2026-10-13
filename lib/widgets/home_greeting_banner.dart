import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/effective_pets_provider.dart';
import '../screens/account_ui.dart';
import '../theme/app_colors.dart';
import 'mascot_image.dart';

/// 홈 헤더 바로 아래 "온기" 영역("출시 전 마무리" 지시서 B) — 장구름 +
/// 한 줄 인사. 크림 배경([AppColors.warmBackground])은 이 자리에만 쓰고,
/// 병원 데이터 카드는 계속 흰 배경이다(신뢰가 중요한 영역과 분리).
/// 과장된 감성 문구 대신 제품 원칙(평가 안 함)이나 담백한 인사 한 줄만
/// 담아 홈이 길어지지 않게 높이를 작게 유지한다.
class HomeGreetingBanner extends ConsumerWidget {
  const HomeGreetingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final petsAsync = user != null ? ref.watch(effectivePetsProvider) : null;
    final pets = petsAsync?.value ?? const [];
    final petName = pets.isNotEmpty ? pets.first.name : null;

    final message = user == null
        ? '병원을 평가하지 않아요. 공개된 사실로 방문 전에 확인하세요.'
        : petName != null
            ? '${accountLabel(user)}님, 오늘도 $petName와 함께해요'
            : '병원을 평가하지 않아요. 공개된 사실로 방문 전에 확인하세요.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warmBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const MascotImage(size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textLabel),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
