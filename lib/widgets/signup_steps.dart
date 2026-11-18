import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 가입 플로우 3단계 진행 표시("장구름의 수첩", 3차 업데이트 J-7) — 앱바에
/// 뒤로 버튼과 나란히 3칸 진행 막대 + "n / 3". [label]은 화면 읽기용.
/// SignupEmailScreen → SignupAgeGenderScreen → SignupPetScreen이 함께 쓴다.
class SignupSteps extends StatelessWidget {
  final int step; // 1, 2, 3
  final String label;

  const SignupSteps({super.key, required this.step, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '가입 $step / 3 단계 · $label',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < step ? AppColors.primary : AppColors.borderCard,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Text('$step / 3', style: AppTextStyles.mono(size: 14, weight: FontWeight.w700, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
