import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/hospital.dart';
import '../models/hospital_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import 'status_badge.dart';

/// 병원 한 곳 — "장구름의 수첩"(3차 업데이트 J-3) 검색 결과 행: 병원 이름
/// 17sp 굵게 + 오른쪽 거리(위치를 알 때만) / 주소 / 상태(영업 중 = 네이비
/// 점, 폐업·확인 안 됨 = 회색 칩) · "문 연 날 YYYY.MM.DD" / (2건 이상일 때)
/// "같은 주소 인허가 기록 N건". 지역 시세는 카드마다 반복하지 않고 검색
/// 결과 위 띠 하나로 보여준다. 폐업은 경고가 아니라 사실이라 회색 톤.
///
/// [inList]가 true면 테두리 없는 행(흰 카드 한 장 안의 목록 — 행 사이
/// 구분선은 부모가 그린다), false면 혼자 서는 흰 카드(저장한 병원 등).
class HospitalCard extends StatelessWidget {
  final Hospital hospital;
  final int sameAddressRecordCount;
  final double? distanceKm;
  final bool hasUserLocation;
  final VoidCallback onTap;
  final bool inList;

  /// 기본은 없음. 저장 화면처럼 "이미 저장됨"을 나타내고 싶은 곳은 채워진
  /// 북마크 아이콘을 넘긴다.
  final IconData? trailingIcon;

  const HospitalCard({
    super.key,
    required this.hospital,
    required this.sameAddressRecordCount,
    this.distanceKm,
    this.hasUserLocation = false,
    required this.onTap,
    this.trailingIcon,
    this.inList = false,
  });

  static String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()}m';
    return '${km.toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    final isClosed = hospital.status == HospitalStatus.closed;
    final distanceLabel = hasUserLocation && distanceKm != null ? _formatDistance(distanceKm!) : null;
    final openDate = hospital.openDate;
    final dateText = switch (hospital.status) {
      HospitalStatus.open => openDate != null ? '문 연 날 ${DateFormat('yyyy.MM.dd').format(openDate)}' : null,
      HospitalStatus.unknown => openDate != null ? '${openDate.year}년 개설 기록' : null,
      HospitalStatus.closed =>
        openDate != null
            ? '${DateFormat('yyyy.MM').format(openDate)} – '
                  '${hospital.closeDate != null ? DateFormat('yyyy.MM').format(hospital.closeDate!) : '확인 안 됨'}'
            : null,
    };

    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.cardLarge, vertical: inList ? 18 : AppSpacing.cardLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  hospital.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isClosed ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (distanceLabel != null) ...[
                const SizedBox(width: 8),
                Text(
                  distanceLabel,
                  style: AppTextStyles.mono(size: 14, weight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
              if (trailingIcon != null) ...[
                const SizedBox(width: 6),
                Icon(trailingIcon, size: 20, color: AppColors.primary),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hospital.displayAddr,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              HospitalStatusMark(status: hospital.status),
              if (dateText != null) Text(dateText, style: AppTextStyles.mono(size: 14, color: AppColors.textSecondary)),
            ],
          ),
          if (sameAddressRecordCount > 1) ...[
            const SizedBox(height: 6),
            Text(
              '같은 주소 인허가 기록 $sameAddressRecordCount건',
              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );

    if (inList) {
      return InkWell(onTap: onTap, child: content);
    }
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppRadius.card), child: content),
    );
  }
}
