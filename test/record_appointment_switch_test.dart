import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/providers/auth_provider.dart';
import 'package:petcliniccheck/providers/bundle_provider.dart';
import 'package:petcliniccheck/screens/appointment_form_screen.dart';
import 'package:petcliniccheck/screens/medical_record_form_screen.dart';
import 'package:petcliniccheck/utils/record_appointment_flow.dart';

// hospitals.json(실제 asset) 로딩이 필요한 HospitalPickerField가 두 폼에
// 모두 들어있다 — 같은 파일 안에서 testWidgets마다 따로 real-asset을
// 로드하면 두 번째부터 끝나지 않는 현상이 이미 여러 테스트에서
// 재현됐다. 그래서 container를 setUpAll에서 "딱 한 번" 만들어 모든
// testWidgets가 공유한다(setUpAll은 testWidgets의 fake-async 존 밖이라
// tester.runAsync 없이 바로 await해도 된다). bundleProvider를 미리
// resolve해두는 것도 중요하다 — HospitalPickerField가 의존하는
// repositoryProvider는 bundleProvider가 아직 loading이면 requireValue에서
// 바로 던지므로, 첫 프레임이 뜨기 전에 미리 받아둬야 한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUpAll(() async {
    // 이 테스트 환경에선 FirebaseAuth를 초기화할 수 없다(실제 User를
    // 만들 수 없는 제약은 이 레포 테스트 전반에서 이미 문서화돼 있음) —
    // authStateProvider를 게스트(null)로 고정해 Firebase 플러그인 부재로
    // 인한 자동 재시도 타이머가 테스트 종료 뒤까지 남는 것을 막는다.
    container = ProviderContainer(
      overrides: [authStateProvider.overrideWith((ref) => Stream<User?>.value(null))],
    );
    SharedPreferences.setMockInitialValues({});
    await container.read(bundleProvider.future);
  });

  tearDownAll(() {
    container.dispose();
  });

  testWidgets(
    '진료기록⇄예약 통합 입력: 신규는 세그먼트로 전환되고 입력값이 유지된다',
    (tester) async {
      // 폼이 길어 기본 테스트 화면 크기에선 일부 필드가 스크롤해야 보인다 —
      // 세그먼트 탭이 다른 위젯에 가려지는 것을 피하려고 화면을 넉넉히
      // 키운다(ListView(children:)라 스크롤 여부와 무관하게 위젯 자체는
      // 항상 트리에 있지만, tap()은 실제로 히트테스트가 되는 위치에서만
      // 눌러야 한다).
      await tester.binding.setSurfaceSize(const Size(400, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MedicalRecordFormScreen(petId: 'local1')),
        ),
      );
      await tester.pumpAndSettle();

      // 신규 모드엔 세그먼트가 보이고, 날짜가 오늘이라 둘 다 고를 수 있다.
      expect(find.byType(SegmentedButton<RecordOrAppointmentKind>), findsOneWidget);
      expect(find.text('진료기록'), findsOneWidget);
      expect(find.text('예약'), findsOneWidget);
      final initialSegmented =
          tester.widget<SegmentedButton<RecordOrAppointmentKind>>(
        find.byType(SegmentedButton<RecordOrAppointmentKind>),
      );
      for (final segment in initialSegmented.segments) {
        expect(segment.enabled, isTrue);
      }

      // 병원·메모·방문 목적(기타 직접입력)을 채운다. 병원 이름은 실제
      // hospitals.json 어떤 항목과도 매칭되지 않을 영문 문자열을 쓴다 —
      // 한글 병원명으로 검색하면 실제 검색 결과 목록(ListTile)이 함께
      // 떠서 이 테스트와 무관한 기존 위젯의 디버그 경고가 끼어든다.
      await tester.enterText(
        find.descendant(of: find.byType(TextField), matching: find.byType(EditableText)).first,
        'ZZZTESTHOSPITAL',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '어떤 진료를 받았는지 남겨보세요',
        ),
        '정기 검진',
      );
      final kijtaChip = find.widgetWithText(ChoiceChip, '기타');
      await tester.ensureVisible(kijtaChip);
      await tester.pumpAndSettle();
      await tester.tap(kijtaChip);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '방문 목적을 입력해주세요',
        ),
        '피부염',
      );
      await tester.pumpAndSettle();

      // 체중을 입력한 채 "예약"으로 넘어가려 하면 버려진다는 확인이 뜬다.
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '0.0',
        ),
        '3.2',
      );
      await tester.tap(find.text('예약'));
      await tester.pumpAndSettle();
      expect(find.text('체중·비용·사진은 예약에 저장되지 않아요. 계속할까요?'), findsOneWidget);

      // 취소하면 그대로 진료기록 폼에 남는다.
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(MedicalRecordFormScreen), findsOneWidget);

      // 다시 "예약"을 누르고 이번엔 계속하면 예약 폼으로 넘어가고, 병원·
      // 메모·방문 목적(→진료 내용) 값이 그대로 유지된다.
      await tester.tap(find.text('예약'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('계속'));
      await tester.pumpAndSettle();

      expect(find.byType(AppointmentFormScreen), findsOneWidget);
      expect(find.byType(MedicalRecordFormScreen), findsNothing);
      expect(find.text('ZZZTESTHOSPITAL'), findsOneWidget);
      expect(find.text('피부염'), findsOneWidget);
      // 몸무게는 예약에 없는 필드라 버려졌다(값이 안 보인다).
      expect(find.text('3.2'), findsNothing);

      // 세그먼트만 눌러 넘어왔으니 날짜는 그대로 오늘이다 — 오늘은
      // 기록·예약 둘 다 유효해 "진료기록" 옵션이 막혀 있지 않다.
      final appointmentSegmented = tester.widget<SegmentedButton<RecordOrAppointmentKind>>(
        find.byType(SegmentedButton<RecordOrAppointmentKind>),
      );
      final recordSegment = appointmentSegmented.segments
          .firstWhere((s) => s.label is Text && (s.label as Text).data == '진료기록');
      expect(recordSegment.enabled, isTrue);
    },
  );

  testWidgets(
    '날짜가 과거인 신규 진료기록 폼에서는 "예약" 옵션이 막혀 있다(미래 날짜에서 "진료기록"을 막은 것과 대칭)',
    (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MedicalRecordFormScreen(
              petId: 'local1',
              initialDate: DateTime.now().subtract(const Duration(days: 3)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final segmented = tester.widget<SegmentedButton<RecordOrAppointmentKind>>(
        find.byType(SegmentedButton<RecordOrAppointmentKind>),
      );
      final appointmentOption = segmented.segments
          .firstWhere((s) => s.label is Text && (s.label as Text).data == '예약');
      final recordOption = segmented.segments
          .firstWhere((s) => s.label is Text && (s.label as Text).data == '진료기록');
      expect(appointmentOption.enabled, isFalse);
      expect(recordOption.enabled, isTrue);
    },
  );

  testWidgets(
    '날짜가 미래인 신규 예약 폼에서는 "진료기록" 옵션이 막혀 있다',
    (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: AppointmentFormScreen(
              petId: 'local1',
              initialDate: DateTime.now().add(const Duration(days: 5)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final segmented = tester.widget<SegmentedButton<RecordOrAppointmentKind>>(
        find.byType(SegmentedButton<RecordOrAppointmentKind>),
      );
      final recordOption = segmented.segments
          .firstWhere((s) => s.label is Text && (s.label as Text).data == '진료기록');
      expect(recordOption.enabled, isFalse);
    },
  );
}
