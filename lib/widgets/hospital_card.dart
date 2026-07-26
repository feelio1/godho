import 'package:flutter/material.dart';

import '../models/hospital.dart';
import 'status_badge.dart';

class HospitalCard extends StatelessWidget {
  final Hospital hospital;
  final int sameAddressRecordCount;
  final double? distanceKm;
  final bool hasUserLocation;
  final VoidCallback onTap;
  final bool? isInCompare;
  final VoidCallback? onCompareToggle;

  const HospitalCard({
    super.key,
    required this.hospital,
    required this.sameAddressRecordCount,
    this.distanceKm,
    this.hasUserLocation = false,
    required this.onTap,
    this.isInCompare,
    this.onCompareToggle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final chips = <String>[
      hospital.operatingPeriodLabel,
      if (sameAddressRecordCount > 1) '동일 주소 기록 $sameAddressRecordCount건',
      // 좌표가 없는 병원은 목록에서 빼지 않되, 거리 대신 "거리 정보 없음"으로
      // 표시한다 (스프린트 2 지시서 3).
      if (hasUserLocation)
        distanceKm != null ? '${distanceKm!.toStringAsFixed(1)}km' : '거리 정보 없음',
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hospital.name,
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: hospital.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                hospital.roadAddr,
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: chips
                    .map((c) => Chip(
                          label: Text(c, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ))
                    .toList(),
              ),
              if (onCompareToggle != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onCompareToggle,
                    icon: Icon(
                      isInCompare == true ? Icons.check_circle : Icons.add_circle_outline,
                      size: 16,
                    ),
                    label: Text(isInCompare == true ? '비교 담음' : '비교 추가'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
