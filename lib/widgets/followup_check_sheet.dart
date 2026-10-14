import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/appointment.dart';
import '../theme/app_colors.dart';
import 'mascot_image.dart';

/// 지난 예약 "진료 받으셨어요?" 확인 바텀시트("지난 예약 확인" 지시서
/// 3) — 담백하게 묻기만 하고, 실제 네비게이션·저장은 호출부(콜백)가
/// 맡는다. 재촉·죄책감 문구 없이 사실(날짜·병원·진료 내용)만 보여준다.
class FollowUpCheckSheet extends StatelessWidget {
  final String petName;
  final Appointment appointment;
  final VoidCallback onRecorded;
  final VoidCallback onSkipped;
  final VoidCallback onLater;

  const FollowUpCheckSheet({
    super.key,
    required this.petName,
    required this.appointment,
    required this.onRecorded,
    required this.onSkipped,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('M월 d일 (E)', 'ko_KR').format(appointment.dateTime);
    final reason = appointment.reason.trim();

    // 목록형 피커(PickerSheetChrome)와 달리 내용 길이가 짤막하고
    // 고정적이라, 화면 비율로 높이를 정하지 않고 내용 크기에 맞춘다
    // (guest_gate.dart의 확인 시트와 같은 뼈대).
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MascotImage(size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$petName, $dateLabel ${appointment.hospitalName} 진료 받으셨어요?',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.4),
                  ),
                ),
              ],
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(reason, style: const TextStyle(color: AppColors.textSecondary)),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: onRecorded, child: const Text('네, 기록 남길게요')),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: onSkipped, child: const Text('안 갔어요')),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(onPressed: onLater, child: const Text('나중에')),
            ),
          ],
        ),
      ),
    );
  }
}
