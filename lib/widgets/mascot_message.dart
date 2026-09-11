import 'package:flutter/material.dart';

import 'mascot_image.dart';

/// Shared "mascot + message" block for empty/loading/stub states (홈 인사,
/// 빈 상태, 로딩, 지도 준비중 등) — keeps the friendly tone consistent
/// wherever 장구름 appears outside the data-trust areas.
class MascotMessage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double mascotSize;
  final Widget? trailing;

  /// 검색 결과 없음(empty_search.png), 빈 진료기록/저장(empty_record.png)
  /// 처럼 상황에 맞는 장구름 그림으로 바꿀 수 있다. 기본은 janggureum.png.
  final String assetPath;

  const MascotMessage({
    super.key,
    required this.title,
    this.subtitle,
    this.mascotSize = 72,
    this.trailing,
    this.assetPath = MascotImage.defaultAssetPath,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MascotImage(size: mascotSize, assetPath: assetPath),
        const SizedBox(height: 16),
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: textTheme.bodySmall, textAlign: TextAlign.center),
        ],
        if (trailing != null) ...[
          const SizedBox(height: 16),
          trailing!,
        ],
      ],
    );
  }
}
