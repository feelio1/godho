import 'package:flutter/material.dart';

import '../screens/appointment_form_screen.dart';
import '../screens/medical_record_form_screen.dart';
import 'appointment_calendar.dart';

/// 진료기록·예약 통합 입력 폼 상단의 [진료기록|예약] 세그먼트가 가리키는
/// 종류("진료기록·예약 통합 입력" 지시서 2). 모델(`MedicalRecord`/
/// `Appointment`)과는 무관한, 지금 어느 폼이 열려 있는지만 나타내는
/// 값이다.
enum RecordOrAppointmentKind { record, appointment }

/// 진료기록 탭 "추가"·홈 우리 아이 카드 "첫 기록 남기기"·캘린더 날짜 추가
/// 등 모든 진입점이 공유하는 단일 입구 — 날짜가 미래면 예약 폼을, 과거·
/// 오늘이면 진료기록 폼을 연다. 어느 쪽으로 열렸든 폼 상단 세그먼트로
/// 다시 바꿀 수 있어 "잘못 들어왔다"는 느낌 없이 이어진다.
void openRecordOrAppointmentEntry(
  BuildContext context, {
  required String petId,
  DateTime? initialDate,
}) {
  final date = initialDate ?? DateTime.now();
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => isFutureDay(date)
          ? AppointmentFormScreen(petId: petId, initialDate: date)
          : MedicalRecordFormScreen(petId: petId, initialDate: date),
    ),
  );
}

/// 기록⇄예약 전환으로 버려질 입력값(체중·비용·사진 또는 미리 알림)이 있을
/// 때만 띄우는 확인 팝업 — 취소하면 전환하지 않는다.
Future<bool> confirmKindSwitch(BuildContext context, String message) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('계속')),
      ],
    ),
  );
  return confirmed ?? false;
}
