import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/models/medical_record.dart';
import 'package:petcliniccheck/providers/auth_provider.dart';
import 'package:petcliniccheck/providers/effective_medical_records_provider.dart';
import 'package:petcliniccheck/providers/medical_record_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'effectiveRecordsForPetProvider — 게스트(로컬) 반려동물이면 기존 recordsForPetProvider를 '
    '그대로 반영한다("진료기록·예약 Firestore 저장" 지시서 B-2). 계정(로그인) 쪽은 실제 User '
    '인스턴스를 이 테스트 환경에서 만들 수 없어(firebase_auth_mocks가 kakao SDK와 충돌 — 이전 '
    '단계에서 확인된 제약) UserRepository.streamRecords 자체는 user_repository_test.dart가 '
    'fake_cloud_firestore로 직접 검증한다',
    () {
      test('로컬 반려동물 id면 recordsForPetProvider와 같은 값을 낸다', () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer(
          overrides: [authStateProvider.overrideWith((ref) => Stream<User?>.value(null))],
        );
        addTearDown(container.dispose);

        await container.read(medicalRecordsProvider.notifier).upsert(
              MedicalRecord(id: 'r1', petId: 'local-1', date: DateTime(2024, 1, 1), hospitalName: '병원A'),
            );

        final sub = container.listen(effectiveRecordsForPetProvider('local-1'), (previous, next) {});
        final records = await container.read(effectiveRecordsForPetProvider('local-1').future);
        sub.close();

        expect(records, hasLength(1));
        expect(records.single.hospitalName, '병원A');
      });

      test('다른 로컬 반려동물의 기록은 섞이지 않는다', () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer(
          overrides: [authStateProvider.overrideWith((ref) => Stream<User?>.value(null))],
        );
        addTearDown(container.dispose);

        await container.read(medicalRecordsProvider.notifier).upsert(
              MedicalRecord(id: 'r1', petId: 'local-1', date: DateTime(2024, 1, 1), hospitalName: '병원A'),
            );

        final sub = container.listen(effectiveRecordsForPetProvider('local-2'), (previous, next) {});
        final records = await container.read(effectiveRecordsForPetProvider('local-2').future);
        sub.close();

        expect(records, isEmpty);
      });

      test('로그아웃 상태(uid 없음)에서 계정(account:) petId를 조회하면 빈 목록이다', () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer(
          overrides: [authStateProvider.overrideWith((ref) => Stream<User?>.value(null))],
        );
        addTearDown(container.dispose);

        final sub = container.listen(effectiveRecordsForPetProvider('account:doc-1'), (previous, next) {});
        final records = await container.read(effectiveRecordsForPetProvider('account:doc-1').future);
        sub.close();

        expect(records, isEmpty);
      });
    },
  );
}
