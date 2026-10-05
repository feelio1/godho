import 'package:flutter/material.dart';

import '../models/hospital.dart';
import '../models/hospital_status.dart';
import '../theme/app_colors.dart';

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

/// 상태 칩 — "펫클 앱 디자인" 캔버스 시안의 `.chip`(중립 회색, radius 6)
/// 그대로. 폐업·정보부족은 시안의 빨강이 아니라 계속 회색이다(CLAUDE.md
/// 평가 금지 원칙 — 의도적으로 시안과 다르게 적용). 점(dot) 표시는 시안에
/// 없어 제거했다.
class StatusBadge extends StatelessWidget {
  final HospitalStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return _Chip(
      label: status.label,
      textColor: AppColors.forStatusText(status),
      bgColor: AppColors.forStatusBg(status),
    );
  }
}

/// 병원명 옆에 놓는 운영기간/상태 표시 — 스프린트 16 지시서: 영업중 초록
/// "영업" 배지가 "지금 이 시간 영업 중"으로 오해되는 문제를 없앤다.
/// 실제로는 영업시간 데이터가 없어 실시간 영업 여부를 알 수 없고,
/// 검색/목록도 기본적으로 영업중만 보여주므로 "영업" 배지 자체는 정보값이
/// 적다.
///
/// - 영업중(open)이고 운영기간을 알 수 있으면: 시안의 `.chip.brand`
///   (브랜드 블루) 칩으로 "운영 N년차"를 보여준다 — 1년차든 12년차든 같은
///   색을 쓰므로 "오래될수록 더 믿을 만하다"는 평가가 섞이지 않는다
///   (CLAUDE.md 원칙 2).
/// - 운영기간을 알 수 없으면(신규/데이터 부족): 중립 회색 칩으로 "공개
///   데이터가 적어요"를 그대로 보여준다 — 평가가 아니라 안내.
/// - 폐업(closed)/정보부족(unknown) 상태: 기존 중립 [StatusBadge]를 그대로
///   유지한다 — 헛걸음 방지를 위해 폐업은 반드시 구분되어야 한다.
class HospitalStatusTag extends StatelessWidget {
  final Hospital hospital;

  const HospitalStatusTag({super.key, required this.hospital});

  @override
  Widget build(BuildContext context) {
    if (hospital.status != HospitalStatus.open) {
      return StatusBadge(status: hospital.status);
    }
    final label = hospitalOperatingLabel(hospital);
    final hasYears = hospital.operatingYears != null && hospital.operatingYears != 0;
    return _Chip(
      label: label,
      textColor: hasYears ? AppColors.openText : AppColors.closedText,
      bgColor: hasYears ? AppColors.openBg : AppColors.closedBg,
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color bgColor;

  const _Chip({required this.label, required this.textColor, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
