import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/hospital.dart';
import '../models/hospital_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'hospital_avatar.dart';
import 'status_badge.dart';

/// 병원 카드(스프린트 14, Petcli 시안): 아바타(건물 아이콘, 틴트 배경) +
/// 병원명 + 상태 pill + 메타(개설·운영·거리) + "진료비 준비 중" 회색 칩 +
/// 우측 chevron(저장 화면 등에서는 채워진 북마크로 대체 가능). 폐업
/// 병원은 카드 전체가 옅은 회색으로 가라앉는다 — 경고가 아니라 그저
/// 인허가 기록상 사실이라는 뜻(CLAUDE.md 평가 금지 원칙).
class HospitalCard extends StatelessWidget {
  final Hospital hospital;
  final int sameAddressRecordCount;
  final double? distanceKm;
  final bool hasUserLocation;
  final VoidCallback onTap;
  final bool? isInCompare;
  final VoidCallback? onCompareToggle;

  /// 기본은 chevron(더 보기). 저장 화면처럼 "이미 저장됨"을 나타내고 싶은
  /// 곳은 채워진 북마크 아이콘을 넘긴다.
  final IconData trailingIcon;

  const HospitalCard({
    super.key,
    required this.hospital,
    required this.sameAddressRecordCount,
    this.distanceKm,
    this.hasUserLocation = false,
    required this.onTap,
    this.isInCompare,
    this.onCompareToggle,
    this.trailingIcon = Icons.chevron_right,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isClosed = hospital.status == HospitalStatus.closed;
    final years = hospital.operatingYears;

    // 운영 기간은 뭉뚱그린 구간(운영 X년 이상)이 아니라 실제 시안처럼
    // 정확한 "운영 N년차"(영업중)/"운영 N년"(폐업 — 개설~폐업 범위)으로
    // 보여준다. 신규/정보 부족(continuousSince 없거나 1년 미만)은
    // CLAUDE.md 원칙대로 "공개 데이터가 적어요"로 솔직히 표기한다
    // (운영기간이 부족=나쁘다는 뜻이 아니다).
    final String operatingLabel;
    if (years == null || years == 0) {
      operatingLabel = '공개 데이터가 적어요';
    } else if (isClosed) {
      operatingLabel = '운영 $years년';
    } else {
      operatingLabel = '운영 ${years + 1}년차';
    }

    final metaParts = <String>[
      if (hospital.openDate != null) '${DateFormat('yyyy.MM').format(hospital.openDate!)} 개설',
      operatingLabel,
      // 좌표가 없는 병원은 목록에서 빼지 않되, 거리 대신 "거리 정보 없음"으로
      // 표시한다 (스프린트 2 지시서 3).
      if (hasUserLocation)
        distanceKm != null ? '${distanceKm!.toStringAsFixed(1)}km' : '거리 정보 없음',
      if (sameAddressRecordCount > 1) '동일 주소 기록 $sameAddressRecordCount건',
    ];

    return Card(
      margin: EdgeInsets.zero,
      color: isClosed ? AppColors.closedCardBg : null,
      shape: isClosed
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColors.borderMuted),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  HospitalAvatar(size: 52, radius: isClosed ? AppRadius.avatar : AppRadius.avatar),
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
                                style: textTheme.titleSmall?.copyWith(
                                  color: isClosed ? AppColors.textSecondary : AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(status: hospital.status),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          metaParts.join(' · '),
                          style: textTheme.bodySmall?.copyWith(
                            color: isClosed ? AppColors.textPlaceholder : AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isClosed) ...[
                          const SizedBox(height: 2),
                          Text(
                            '지금은 문을 닫았어요',
                            style: textTheme.bodySmall?.copyWith(color: AppColors.textPlaceholder),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(trailingIcon, size: 20, color: AppColors.textPlaceholder),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text('진료비 준비 중', style: const TextStyle(fontSize: 11)),
                    backgroundColor: AppColors.inputFill,
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ),
                  if (onCompareToggle != null)
                    ActionChip(
                      onPressed: onCompareToggle,
                      avatar: Icon(
                        isInCompare == true ? Icons.check_circle : Icons.add_circle_outline,
                        size: 14,
                        color: isInCompare == true ? AppColors.primary : AppColors.textSecondary,
                      ),
                      label: Text(
                        isInCompare == true ? '비교 담음' : '비교 추가',
                        style: TextStyle(
                          fontSize: 11,
                          color: isInCompare == true ? AppColors.primaryTextTone : AppColors.textSecondary,
                        ),
                      ),
                      backgroundColor:
                          isInCompare == true ? AppColors.primarySoft : AppColors.inputFill,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
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
