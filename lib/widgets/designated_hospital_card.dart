import 'package:flutter/material.dart';

import '../models/hospital.dart';
import '../theme/app_colors.dart';
import '../utils/external_links.dart';
import 'status_badge.dart';

/// 홈 상단 "지정 병원" 섹션의 카드. 목록에서 바로 전화·길찾기·상세로 갈 수
/// 있어야 한다는 스프린트 8 지시서 1을 따른다. 영업시간/실시간 영업여부는
/// 표시하지 않는다(데이터 없음 — 추정 금지) — 대신 상세 화면의 외부 링크로
/// 안내한다.
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                  const SizedBox(width: 8),
                  StatusBadge(status: hospital.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                hospital.roadAddr,
                style: textTheme.bodySmall?.copyWith(color: AppColors.neutral),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniAction(
                      icon: Icons.call_outlined,
                      label: '전화',
                      enabled: hospital.phone != null,
                      onTap: () => ExternalLinks.call(hospital.phone!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniAction(
                      icon: Icons.directions_outlined,
                      label: '길찾기',
                      onTap: () => ExternalLinks.openDirections(hospital),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniAction(
                      icon: Icons.info_outline,
                      label: '상세보기',
                      onTap: onTap,
                    ),
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

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
