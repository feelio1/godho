import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/appointment.dart';
import 'package:petcliniccheck/utils/followup_appointment.dart';

Appointment _appointment(
  String id,
  DateTime dateTime, {
  AppointmentFollowUp? followUp,
  String petId = 'p1',
}) =>
    Appointment(id: id, petId: petId, dateTime: dateTime, hospitalName: '병원', followUp: followUp);

void main() {
  final now = DateTime(2026, 10, 15, 12, 0);

  group('selectFollowUpAppointment — "지난 예약 확인" 지시서 1, "기준 시각 변경" 지시서 1', () {
    test('예약 시각이 아직 안 지났으면(지연 없이) 대상이 아니다', () {
      final appointment = _appointment('a1', now.add(const Duration(minutes: 1)));
      expect(selectFollowUpAppointment([appointment], now: now), isNull);
    });

    test('예약 시각이 막 지났으면(1시간 유예 없이 바로) 대상이다', () {
      final appointment = _appointment('a1', now.subtract(const Duration(minutes: 1)));
      expect(selectFollowUpAppointment([appointment], now: now)?.id, 'a1');
    });

    test('30일보다 오래된 지난 예약은 묻지 않는다', () {
      final appointment = _appointment('a1', now.subtract(const Duration(days: 31)));
      expect(selectFollowUpAppointment([appointment], now: now), isNull);
    });

    test('정확히 30일 이내는 대상이다', () {
      final appointment = _appointment('a1', now.subtract(const Duration(days: 30)));
      expect(selectFollowUpAppointment([appointment], now: now)?.id, 'a1');
    });

    test('이미 처리된(followUp이 있는) 예약은 다시 묻지 않는다', () {
      final recorded = _appointment(
        'a1',
        now.subtract(const Duration(hours: 2)),
        followUp: AppointmentFollowUp.recorded,
      );
      final skipped = _appointment(
        'a2',
        now.subtract(const Duration(hours: 3)),
        followUp: AppointmentFollowUp.skipped,
      );
      expect(selectFollowUpAppointment([recorded, skipped], now: now), isNull);
    });

    test('여러 건이 대상이면 가장 오래된(날짜가 이른) 것 1건만 돌려준다', () {
      final older = _appointment('old', now.subtract(const Duration(days: 10)));
      final newer = _appointment('new', now.subtract(const Duration(days: 2)));
      final result = selectFollowUpAppointment([newer, older], now: now);
      expect(result?.id, 'old');
    });

    test('대상이 없으면 null', () {
      expect(selectFollowUpAppointment(const [], now: now), isNull);
    });

    test('미래 예약은 대상이 아니다', () {
      final appointment = _appointment('a1', now.add(const Duration(days: 1)));
      expect(selectFollowUpAppointment([appointment], now: now), isNull);
    });
  });

  group('shouldResetFollowUpSession — "복귀 시 과도한 재노출 방지" 지시서 2', () {
    test('한 번도 백그라운드로 간 적 없으면(pausedAt null) 새 세션이 아니다', () {
      expect(
        shouldResetFollowUpSession(pausedAt: null, resumedAt: now),
        isFalse,
      );
    });

    test('5분보다 짧게 비웠으면(사진 선택·로그인 창 등) 새 세션이 아니다', () {
      final pausedAt = now.subtract(const Duration(minutes: 4, seconds: 59));
      expect(
        shouldResetFollowUpSession(pausedAt: pausedAt, resumedAt: now),
        isFalse,
      );
    });

    test('정확히 5분 비웠으면 새 세션이다', () {
      final pausedAt = now.subtract(const Duration(minutes: 5));
      expect(
        shouldResetFollowUpSession(pausedAt: pausedAt, resumedAt: now),
        isTrue,
      );
    });

    test('5분보다 길게 비웠으면 새 세션이다', () {
      final pausedAt = now.subtract(const Duration(hours: 1));
      expect(
        shouldResetFollowUpSession(pausedAt: pausedAt, resumedAt: now),
        isTrue,
      );
    });

    test('threshold를 직접 넘기면 그 기준을 쓴다', () {
      final pausedAt = now.subtract(const Duration(minutes: 1));
      expect(
        shouldResetFollowUpSession(
          pausedAt: pausedAt,
          resumedAt: now,
          threshold: const Duration(seconds: 30),
        ),
        isTrue,
      );
    });
  });
}
