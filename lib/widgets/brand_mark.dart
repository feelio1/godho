import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 앱 브랜드 마크 — 네이비 사각 아이콘(+) + "펫클" 글자("펫클 앱 디자인"
/// 캔버스 시안 헤더 그대로). 실제 로고 이미지가 준비되면 이 위젯
/// 내부만 이미지로 바꾸면 되고, 브랜드를 쓰는 화면은 이 위젯만
/// 참조하므로 호출부를 하나하나 고칠 필요가 없다.
class BrandMark extends StatelessWidget {
  final double fontSize;
  final Color? color;

  const BrandMark({super.key, this.fontSize = 20, this.color});

  @override
  Widget build(BuildContext context) {
    final iconSize = fontSize * 1.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(iconSize * 0.27),
          ),
          child: Icon(Icons.add, size: iconSize * 0.55, color: Colors.white),
        ),
        SizedBox(width: iconSize * 0.27),
        Text(
          '펫클',
          style: TextStyle(
            fontFamily: 'IBM Plex Sans KR',
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.02 * fontSize,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
