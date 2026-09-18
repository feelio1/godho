import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 앱 브랜드 이름 — 지금은 "Petcli" 텍스트로 표시한다. 나중에 실제 로고
/// 이미지가 준비되면 이 위젯 내부만 이미지로 바꾸면 되고, 브랜드 이름을
/// 쓰는 모든 화면은 이 위젯만 참조하므로 호출부를 하나하나 고칠 필요가
/// 없다(스프린트 14 지시서: "로고 이미지로 나중에 교체할 수 있도록 분리된
/// 위젯으로").
class BrandMark extends StatelessWidget {
  final double fontSize;
  final Color? color;

  const BrandMark({super.key, this.fontSize = 22, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Petcli',
      style: TextStyle(
        fontFamily: 'Gothic A1',
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        color: color ?? AppColors.textPrimary,
      ),
    );
  }
}
