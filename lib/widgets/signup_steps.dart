import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 가입 플로우 3단계 진행 표시 — "펫클 앱 디자인" 캔버스 시안
/// (SignupEmail/SignupProfile/SignupPet.dc.html)의 3칸 바 + "N / 3 · 제목"
/// 모노 캡션. SignupEmailScreen → SignupAgeGenderScreen → SignupPetScreen
/// 세 화면이 함께 쓴다.
class SignupSteps extends StatelessWidget {
  final int step; // 1, 2, 3
  final String label;

  const SignupSteps({super.key, required this.step, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) {
            final on = i < step;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                height: 4,
                decoration: BoxDecoration(
                  color: on ? AppColors.primary : AppColors.borderCard,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(
          '$step / 3 · $label',
          style: AppTextStyles.mono(size: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
