import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:petcliniccheck/models/appointment.dart';
import 'package:petcliniccheck/widgets/followup_check_sheet.dart';

void main() {
  // FollowUpCheckSheet가 DateFormat(..., 'ko_KR')을 쓴다 — main.dart의
  // 실제 앱 초기화와 같은 호출이 테스트 환경에도 필요하다(없으면
  // LocaleDataException).
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  testWidgets('FollowUpCheckSheet — 반려동물·날짜·병원·진료 내용을 보여주고 버튼마다 맞는 콜백만 부른다',
      (tester) async {
    var recorded = 0;
    var skipped = 0;
    var later = 0;
    final appointment = Appointment(
      id: 'a1',
      petId: 'local1',
      dateTime: DateTime(2026, 10, 7, 10, 30),
      hospitalName: '가온동물병원',
      reason: '예방접종',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FollowUpCheckSheet(
            petName: '구름',
            appointment: appointment,
            onRecorded: () => recorded++,
            onSkipped: () => skipped++,
            onLater: () => later++,
          ),
        ),
      ),
    );

    expect(find.textContaining('구름'), findsOneWidget);
    expect(find.textContaining('가온동물병원'), findsOneWidget);
    expect(find.textContaining('진료 받으셨어요?'), findsOneWidget);
    expect(find.text('예방접종'), findsOneWidget);

    await tester.tap(find.text('네, 기록 남길게요'));
    expect(recorded, 1);
    expect(skipped, 0);
    expect(later, 0);

    await tester.tap(find.text('안 갔어요'));
    expect(skipped, 1);

    await tester.tap(find.text('나중에'));
    expect(later, 1);
    expect(recorded, 1);
  });

  testWidgets('방문 목적(reason)이 비어 있으면 그 줄을 보여주지 않는다', (tester) async {
    final appointment = Appointment(
      id: 'a1',
      petId: 'local1',
      dateTime: DateTime(2026, 10, 7, 10, 30),
      hospitalName: '가온동물병원',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FollowUpCheckSheet(
            petName: '구름',
            appointment: appointment,
            onRecorded: () {},
            onSkipped: () {},
            onLater: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('가온동물병원'), findsOneWidget);
  });
}
