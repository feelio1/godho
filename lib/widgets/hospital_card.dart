import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/hospital.dart';
import '../models/hospital_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import 'fee_context_chip.dart';
import 'status_badge.dart';

/// 병원 카드 — "펫클 앱 디자인" 캔버스 시안(Search.dc.html)의 검색결과
/// 카드 그대로: 병원명+주소(좌) · 거리(우, 모노스페이스) 상단 한 줄 +
/// 칩 한 줄(운영기간/상태 + 같은 주소 기록 건수, 폐업은 폐업 칩 + 등록
/// 연도 범위) + "이 지역 초진 시세" 칩(진료비 지시서 — 병원 자체 가격이
/// 아니라 소속 시/군/구 시세, 시안엔 없지만 기존 기능 유지) + 비교
/// 추가. 폐업 병원은 카드 전체가 옅은 회색으로 가라앉는다 — 경고가
/// 아니라 그저 인허가 기록상 사실이라는 뜻(CLAUDE.md 평가 금지 원칙).
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

  static String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()}m';
    return '${km.toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    final isClosed = hospital.status == HospitalStatus.closed;
    final distanceLabel = !hasUserLocation
        ? null
        : distanceKm != null
            ? _formatDistance(distanceKm!)
            : '거리 정보 없음';

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hospital.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isClosed ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hospital.roadAddr,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isClosed) ...[
                          const SizedBox(height: 2),
                          const Text(
                            '지금은 문을 닫았어요',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textPlaceholder),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (distanceLabel != null) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        distanceLabel,
                        style: distanceKm != null
                            ? AppTextStyles.mono(size: 13, color: AppColors.textLabel)
                            : const TextStyle(fontSize: 12, color: AppColors.textPlaceholder),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(trailingIcon, size: 18, color: AppColors.textPlaceholder),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  HospitalStatusTag(hospital: hospital),
                  if (isClosed && hospital.openDate != null)
                    _DateRangeChip(hospital: hospital)
                  else if (sameAddressRecordCount > 1)
                    Chip(label: Text('같은 주소 기록 $sameAddressRecordCount건')),
                  // 폐업 병원엔 시세 칩을 달지 않는다 — 회색 톤은 유지하되
                  // 헛걸음 방지를 위한 정보(폐업 표시)에 집중한다.
                  if (!isClosed) FeeContextChip(hospital: hospital),
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

/// 폐업 병원의 등록 연도 범위("2011.04 – 2021.06") — 숫자라 모노스페이스로
/// 보여준다(Search.dc.html의 폐업 카드 둘째 칩).
class _DateRangeChip extends StatelessWidget {
  final Hospital hospital;

  const _DateRangeChip({required this.hospital});

  @override
  Widget build(BuildContext context) {
    final start = DateFormat('yyyy.MM').format(hospital.openDate!);
    final end = hospital.closeDate != null ? DateFormat('yyyy.MM').format(hospital.closeDate!) : '현재';
    return Chip(label: Text('$start – $end', style: AppTextStyles.mono(size: 12, color: AppColors.textLabel)));
  }
}
