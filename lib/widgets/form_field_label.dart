import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 폼 필드 라벨: 13.5sp 굵게, 입력칸 위에 붙는다(3차 업데이트 J-1 — placeholder로
/// 라벨을 대신하지 않는다). 예약·진료기록·반려동물 등록 폼이
/// 공유한다.
class FormFieldLabel extends StatelessWidget {
  final String text;

  const FormFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      ),
    );
  }
}
