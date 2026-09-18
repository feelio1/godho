import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'mascot_image.dart';

/// Shared "mascot + message" block for empty/loading/stub states (홈 인사,
/// 빈 상태, 로딩, 지도 준비중 등) — keeps the friendly tone consistent
/// wherever 장구름 appears outside the data-trust areas.
///
/// 스프린트 14(Petcli 시안 "빈 상태" 공용 컴포넌트): 장구름을 112px
/// 원형 틴트 배지 안에 넣고, 필요하면 우하단에 작은 아이콘을 얹는다
/// (검색 없음=돋보기, 저장 없음=북마크 등 상황을 한눈에 보여준다).
class MascotMessage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double mascotSize;
  final Widget? trailing;

  /// 검색 결과 없음(empty_search.png), 빈 진료기록/저장(empty_record.png)
  /// 처럼 상황에 맞는 장구름 그림으로 바꿀 수 있다. 기본은 janggureum.png.
  final String assetPath;

  /// 배지 우하단에 얹는 작은 상황 아이콘(예: 검색 없음=Icons.search_off,
  /// 저장 없음=Icons.bookmark_outline). 생략하면 배지만 보여준다.
  final IconData? overlayIcon;

  const MascotMessage({
    super.key,
    required this.title,
    this.subtitle,
    this.mascotSize = 60,
    this.trailing,
    this.assetPath = MascotImage.defaultAssetPath,
    this.overlayIcon,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 112,
          height: 112,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: MascotImage(size: mascotSize, assetPath: assetPath),
              ),
              if (overlayIcon != null)
                Positioned(
                  right: 0,
                  bottom: 2,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderCard, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Icon(overlayIcon, size: 17, color: AppColors.primary),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: textTheme.bodySmall?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w500, height: 1.4),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (trailing != null) ...[
          const SizedBox(height: 18),
          trailing!,
        ],
      ],
    );
  }
}
