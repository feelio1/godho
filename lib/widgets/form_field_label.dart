import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 폼 필드 라벨(스프린트 14, Petcli 시안 공용 컴포넌트): 12.5 / w800 /
/// `#475569`, 입력 필드 바로 위에 붙는다. 예약·진료기록·반려동물 등록 폼이
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
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textLabel),
      ),
    );
  }
}
