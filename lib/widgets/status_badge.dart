import 'package:flutter/material.dart';

import '../models/hospital.dart';
import '../models/hospital_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// 운영기간 표기 — 뭉뚱그린 구간(운영 X년 이상)이 아니라 정확한 "운영
/// N년차"(영업중)/"YYYY–YYYY 운영"(폐업 — 개설~폐업 연도 범위)으로
/// 보여준다. 신규/정보 부족(continuousSince 없거나 1년 미만)은 CLAUDE.md
/// 원칙대로 "공개 데이터가 적어요"로 솔직히 표기한다(운영기간이 부족=
/// 나쁘다는 뜻이 아니다). 병원 카드·상세 화면이 함께 쓴다.
///
/// 스프린트 16: 폐업 병원의 운영기간은 "운영 N년"(기간 길이)이 아니라
/// "2005–2019 운영"(실제 연도 범위)으로 보여준다 — 언제 운영했는지가
/// 더 구체적인 사실이라 헛걸음 방지에 더 도움이 된다. 연도는
/// `continuousSince`(병합 구간을 반영한 실제 연속 운영 시작)를 쓴다 —
/// `operatingYears`도 같은 값을 기준으로 계산하므로 두 표기가 서로
/// 어긋나지 않는다.
String hospitalOperatingLabel(Hospital hospital) {
  final years = hospital.operatingYears;
  if (years == null || years == 0) return '공개 데이터가 적어요';
  if (hospital.status == HospitalStatus.closed) {
    final startYear = hospital.continuousSince!.year;
    final endYear = (hospital.closeDate ?? DateTime.now()).year;
    return '$startYear–$endYear 운영';
  }
  return '운영 ${years + 1}년차';
}

/// 상태 pill — 영업중은 그린 점+텍스트, 폐업·정보부족은 회색(빨강 금지,
/// CLAUDE.md 평가 금지 원칙). Petcli 시안 스펙의 정확한 bg/text/dot 색을
/// 그대로 쓴다(알파 블렌딩이 아니라 지정된 고정 색).
class StatusBadge extends StatelessWidget {
  final HospitalStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.forStatusText(status);
    final bgColor = AppColors.forStatusBg(status);
    final dotColor = AppColors.forStatusDot(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              status.label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: textColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 병원명 옆에 놓는 상태 표시 — 스프린트 16 지시서: 영업중 초록 "영업"
/// 배지가 "지금 이 시간 영업 중"으로 오해되는 문제를 없앤다. 실제로는
/// 영업시간 데이터가 없어 실시간 영업 여부를 알 수 없고, 검색/목록도
/// 기본적으로 영업중만 보여주므로 "영업" 배지 자체는 정보값이 적다.
///
/// - 영업중(open): 배지 없이 그 자리에 운영 N년차를 중립 색(회색)으로
///   표시한다 — "오래돼서 믿을 만" 같은 평가가 아니라 단순 사실.
/// - 폐업(closed)/정보부족(unknown): 기존 회색 [StatusBadge]를 그대로
///   유지한다 — 헛걸음 방지를 위해 폐업은 반드시 구분되어야 한다.
class HospitalStatusTag extends StatelessWidget {
  final Hospital hospital;

  const HospitalStatusTag({super.key, required this.hospital});

  @override
  Widget build(BuildContext context) {
    if (hospital.status != HospitalStatus.open) {
      return StatusBadge(status: hospital.status);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.borderMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        hospitalOperatingLabel(hospital),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: const TextStyle(
          color: AppColors.textLabel,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
