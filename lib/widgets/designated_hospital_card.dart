import 'package:flutter/material.dart';

import '../models/hospital.dart';
import '../theme/app_colors.dart';
import '../utils/external_links.dart';
import 'hospital_thumbnail.dart';
import 'status_badge.dart';

/// 홈 상단 "지정 병원" 섹션의 카드. 목록에서 바로 전화·길찾기로 갈 수
/// 있어야 한다는 스프린트 8 지시서 1을 따른다(카드를 탭하면 상세로 이동 —
/// 별도 "상세보기" 버튼은 중복이라 스프린트 10에서 정리). 영업시간/실시간
/// 영업여부는 표시하지 않는다(데이터 없음 — 추정 금지) — 대신 상세 화면의
/// 외부 링크로 안내한다.
class DesignatedHospitalCard extends StatelessWidget {
  final Hospital hospital;
  final VoidCallback onTap;

  const DesignatedHospitalCard({super.key, required this.hospital, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.primarySoft,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HospitalThumbnail(width: 56, height: 56, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hospital.name,
                            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        StatusBadge(status: hospital.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hospital.roadAddr,
                      style: textTheme.bodySmall?.copyWith(color: AppColors.neutral),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CircleAction(
                    icon: Icons.call,
                    tooltip: '전화',
                    filled: true,
                    onTap: () => ExternalLinks.call(context, hospital.phone),
                  ),
                  const SizedBox(height: 6),
                  _CircleAction(
                    icon: Icons.directions_outlined,
                    tooltip: '길찾기',
                    onTap: () => ExternalLinks.openDirections(hospital),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return filled
        ? IconButton.filled(
            tooltip: tooltip,
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
            ),
          )
        : IconButton.outlined(
            tooltip: tooltip,
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4)),
              minimumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
            ),
          );
  }
}
