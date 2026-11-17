import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/data/user_repository.dart';
import 'package:petcliniccheck/diary/data/diary_repository.dart';
import 'package:petcliniccheck/diary/models/diary.dart';
import 'package:petcliniccheck/diary/providers/diary_providers.dart';
import 'package:petcliniccheck/diary/screens/today_diary_row.dart';
import 'package:petcliniccheck/models/fee.dart';
import 'package:petcliniccheck/models/hospital.dart';
import 'package:petcliniccheck/models/hospital_status.dart';
import 'package:petcliniccheck/models/pet.dart';
import 'package:petcliniccheck/models/pet_weight_band.dart';
import 'package:petcliniccheck/models/signup_pet.dart';
import 'package:petcliniccheck/providers/auth_provider.dart';
import 'package:petcliniccheck/providers/bundle_provider.dart';
import 'package:petcliniccheck/providers/effective_pets_provider.dart';
import 'package:petcliniccheck/screens/account_pet_form_screen.dart';
import 'package:petcliniccheck/screens/home_screen.dart';
import 'package:petcliniccheck/screens/pet_tab_screen.dart';
import 'package:petcliniccheck/screens/signup_done_screen.dart';
import 'package:petcliniccheck/shop/models/product.dart';
import 'package:petcliniccheck/shop/providers/shop_providers.dart';
import 'package:petcliniccheck/shop/recommend.dart';
import 'package:petcliniccheck/utils/pet_guard.dart';
import 'package:petcliniccheck/widgets/hospital_card.dart';
import 'package:petcliniccheck/widgets/unsaved_changes_guard.dart';

/// 실제 FirebaseAuth [User]는 만들 수 없어 uid만 돌려주는 가짜를 쓴다.
class _FakeUser implements User {
  @override
  String get uid => 'u1';

  @override
  String? get displayName => null;

  @override
  String? get email => 'member@example.com';

  @override
  String? get photoURL => null;

  @override
  bool get isAnonymous => false;

  @override
  List<UserInfo> get providerData => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 일기가 하나도 없는 저장소 — 0마리 회원은 일기를 쓴 적이 없다.
class _EmptyDiaryRepository implements DiaryRepository {
  @override
  Future<DiaryPage> fetchDiaries(String uid, {int limit = 20, Object? cursor}) async => const DiaryPage(diaries: []);

  @override
  Future<List<Diary>> fetchDiariesForMonth(String uid, DateTime month) async => const [];

  @override
  Future<Diary?> fetchDiary(String uid, String diaryId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}

/// 0마리 회원 — 로그인했지만 반려동물을 등록하지 않았다(가입 때 "나중에").
List<Override> _zeroPetMember({FakeFirebaseFirestore? firestore}) => [
  authStateProvider.overrideWith((ref) => Stream<User?>.value(_FakeUser())),
  userRepositoryProvider.overrideWithValue(UserRepository(firestore: firestore ?? FakeFirebaseFirestore())),
  diaryRepositoryProvider.overrideWithValue(_EmptyDiaryRepository()),
];

Product _product(String id, {double? min, double? max}) => Product(
  id: id,
  sellerId: 'aggaeng',
  name: id,
  category: ProductCategory.food,
  price: 10000,
  status: ProductStatus.active,
  petTypes: const [PetTypeTag.dog],
  weightMinKg: min,
  weightMaxKg: max,
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // AdMob 배너는 테스트에 플랫폼 구현이 없다 — 빈 응답(배너 미표시).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'plugins.flutter.io/google_mobile_ads',
      (message) async => const StandardMethodCodec().encodeSuccessEnvelope(null),
    );
  });

  group('D. 체중 구간(PetWeightBand)', () {
    test('kg → 구간 경계: 5 미만 / 5~10 / 10~20 / 20 이상', () {
      expect(PetWeightBand.fromKg(4.9), PetWeightBand.u5);
      expect(PetWeightBand.fromKg(5), PetWeightBand.u10);
      expect(PetWeightBand.fromKg(9.9), PetWeightBand.u10);
      expect(PetWeightBand.fromKg(10), PetWeightBand.u20);
      expect(PetWeightBand.fromKg(19.9), PetWeightBand.u20);
      expect(PetWeightBand.fromKg(20), PetWeightBand.o20);
    });

    test('진료비 버킷: 20kg 이상은 시세 데이터의 마지막 구간(10~20kg)으로', () {
      expect(PetWeightBand.u5.feeBucket, FeeWeightBucket.u5);
      expect(PetWeightBand.u10.feeBucket, FeeWeightBucket.u10);
      expect(PetWeightBand.u20.feeBucket, FeeWeightBucket.u20);
      expect(PetWeightBand.o20.feeBucket, FeeWeightBucket.u20);
    });

    test('옛 데이터(weightKg만 있는 Firestore 문서)는 그 kg에 맞는 구간으로 보이고, weightKg는 그대로 남는다', () {
      final legacy = SignupPet.fromFirestore('p1', {
        'species': 'dog',
        'breed': '말티즈',
        'weightKg': 7.2,
        'birth': '2023-05',
      });
      expect(legacy.weightBand, isNull, reason: '저장된 구간은 없다');
      expect(legacy.weightBandOrDerived, PetWeightBand.u10);
      expect(legacy.weightKg, 7.2);
      expect(legacy.summary, contains('5~10kg'));
      // 다시 저장해도 weightKg를 지우지 않는다.
      expect(legacy.toFirestore()['weightKg'], 7.2);

      final pet = accountPetToLocalPet(legacy);
      expect(pet.weightBandOrDerived, PetWeightBand.u10);
      expect(pet.weightBandOrDerived!.feeBucket, FeeWeightBucket.u10);
    });

    test('구간만 고른 새 데이터는 가짜 kg 없이 구간만 저장된다', () {
      const pet = SignupPet(species: PetSpecies.dog, breed: kUnknownBreed, weightBand: PetWeightBand.o20, birth: '');
      final data = pet.toFirestore();
      expect(data['weightBand'], 'o20');
      expect(data['weightKg'], isNull);
      final back = SignupPet.fromFirestore('p', data);
      expect(back.weightBand, PetWeightBand.o20);
      expect(back.weightKg, isNull);
      expect(back.summary, '강아지 · $kUnknownBreed · 20kg 이상');
    });

    test('체중도 구간도 없는 옛 문서(0·음수 포함)는 깨지지 않고 체중 모름', () {
      final none = SignupPet.fromFirestore('p', {'species': 'cat', 'breed': '', 'weightKg': 0});
      expect(none.weightKg, isNull);
      expect(none.weightBandOrDerived, isNull);
      expect(none.summary, '고양이');
    });
  });

  group('D. 쇼핑 추천 — 체중 조건', () {
    final small = _product('small', max: 10);
    final big = _product('big', min: 20);
    final any = _product('any');

    test('구간만 있으면 상품 체중 범위와 겹치는지로 본다', () {
      const pet = Pet(id: 'a', name: '구름이', species: PetSpecies.dog, weightBand: PetWeightBand.u5);
      expect(filterRecommendedProducts([small, big, any], [pet]).map((p) => p.id), ['small', 'any']);
      const bigPet = Pet(id: 'b', name: '바위', species: PetSpecies.dog, weightBand: PetWeightBand.o20);
      expect(filterRecommendedProducts([small, big, any], [bigPet]).map((p) => p.id), ['big', 'any']);
    });

    test('옛 데이터(kg만)는 kg이 범위 안인지로 본다', () {
      const pet = Pet(id: 'a', name: '구름이', species: PetSpecies.dog, weightKg: 25);
      expect(filterRecommendedProducts([small, big, any], [pet]).map((p) => p.id), ['big', 'any']);
    });

    test('체중을 모르면 체중 조건이 있는 상품은 빼고 나머지만', () {
      const pet = Pet(id: 'a', name: '구름이', species: PetSpecies.dog);
      expect(filterRecommendedProducts([small, big, any], [pet]).map((p) => p.id), ['any']);
    });

    test('반려동물이 없으면 추천 필터는 비고, 홈 미리보기는 판매 중 상품으로 채운다(일반 추천)', () {
      expect(filterRecommendedProducts([small, any], const []), isEmpty);
      expect(selectHomeShopPreview(activeProducts: [small, any], pets: const []).map((p) => p.id), ['small', 'any']);
    });
  });

  group('D. 반려동물 입력 폼', () {
    Future<AccountPetFormResult?> openForm(WidgetTester tester, {SignupPet? existing}) async {
      AccountPetFormResult? result;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<AccountPetFormResult>(
                      MaterialPageRoute(builder: (_) => AccountPetFormScreen(existing: existing)),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    Future<void> tapSubmit(WidgetTester tester, String label) async {
      final button = find.widgetWithText(FilledButton, label);
      await tester.scrollUntilVisible(button, 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('순서는 이름 → 종류 → 품종 → 생년월 → 체중, 체중은 4개 구간 + 안내', (tester) async {
      await openForm(tester);
      final ys = [
        for (final t in ['이름', '종류', '품종', '생년월', '체중']) tester.getTopLeft(find.text(t).first).dy,
      ];
      expect([...ys]..sort(), ys);
      for (final band in PetWeightBand.values) {
        expect(find.byKey(ValueKey('weight_${band.name}')), findsOneWidget);
        expect(find.text(band.label), findsOneWidget);
      }
      expect(find.text('진료비 시세를 몸무게 구간에 맞춰 보여드려요'), findsOneWidget);
      expect(find.text('예: 구름이'), findsOneWidget);
    });

    testWidgets('이름이 비면 스낵바가 아니라 입력칸 아래 오류로 알린다', (tester) async {
      await openForm(tester);
      await tapSubmit(tester, '추가');
      expect(find.text('이름을 입력해주세요'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AccountPetFormScreen), findsOneWidget);
    });

    testWidgets('이름·종류만으로 저장된다 — 품종은 "모름/믹스", 생년월·체중은 비움', (tester) async {
      AccountPetFormResult? result;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await Navigator.of(
                  context,
                ).push<AccountPetFormResult>(MaterialPageRoute(builder: (_) => const AccountPetFormScreen())),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('pet_name')), '구름이');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('weight_u10')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('weight_u10')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('weight_u10')));
      await tester.pumpAndSettle();
      await tapSubmit(tester, '추가');

      final pet = result!.pet!;
      expect(pet.name, '구름이');
      expect(pet.breed, kUnknownBreed);
      expect(pet.birth, '');
      expect(pet.weightBand, PetWeightBand.u10);
      expect(pet.weightKg, isNull, reason: '구간만 저장하고 가짜 kg을 만들지 않는다');
    });

    testWidgets('옛 데이터(7.2kg) 수정: 5~10kg 구간이 골라져 있고, 그대로 저장하면 weightKg가 남는다', (tester) async {
      const legacy = SignupPet(
        id: 'p1',
        species: PetSpecies.dog,
        breed: '말티즈',
        weightKg: 7.2,
        birth: '2023-05',
        name: '보리',
      );
      AccountPetFormResult? result;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await Navigator.of(context).push<AccountPetFormResult>(
                  MaterialPageRoute(builder: (_) => const AccountPetFormScreen(existing: legacy)),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final selected = tester.widget<OutlinedButton>(find.byKey(const ValueKey('weight_u10')));
      final other = tester.widget<OutlinedButton>(find.byKey(const ValueKey('weight_u5')));
      expect(
        selected.style?.side?.resolve({}),
        isNot(other.style?.side?.resolve({})),
        reason: '7.2kg → 5~10kg 칸이 선택된 모양',
      );

      await tapSubmit(tester, '저장');
      expect(result!.pet!.weightKg, 7.2, reason: '옛 weightKg는 지우지 않는다');
      expect(result!.pet!.weightBand, PetWeightBand.u10);
      expect(result!.pet!.breed, '말티즈');
    });

    testWidgets('H. 바꾼 게 없으면 바로 닫히고, 바꾸면 나가기 전에 묻는다', (tester) async {
      await openForm(tester);
      // 바꾼 것 없음 → 묻지 않고 닫힌다.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AccountPetFormScreen), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('pet_name')), '구름이');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('작성 중인 내용이 있어요. 나가시겠어요?'), findsOneWidget);
      await tester.tap(find.text('계속 쓰기'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountPetFormScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('나가기'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountPetFormScreen), findsNothing);
    });
  });

  group('H. UnsavedChangesGuard', () {
    testWidgets('코드에서 직접 pop(저장 후 닫기)은 막지 않는다', (tester) async {
      var dirty = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (inner) => UnsavedChangesGuard(
                    isDirty: () => dirty,
                    child: Scaffold(
                      appBar: AppBar(),
                      body: TextButton(onPressed: () => Navigator.of(inner).pop(), child: const Text('save')),
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(find.text('작성 중인 내용이 있어요. 나가시겠어요?'), findsNothing);
      expect(find.text('save'), findsNothing);
      dirty = false;
    });
  });

  group('C. 반려동물 0마리 회원', () {
    testWidgets('우리 아이 탭: 세그먼트 없이 등록 안내 + [반려동물 등록]', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: _zeroPetMember(),
          child: const MaterialApp(home: PetTabScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('우리 아이를 등록하면 일기와 진료기록을 남길 수 있어요'), findsOneWidget);
      expect(find.byKey(const ValueKey('pet_tab_register')), findsOneWidget);
      expect(find.text('캘린더'), findsNothing);
      expect(find.text('진료기록'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('pet_tab_register')));
      await tester.pumpAndSettle();
      expect(find.byType(AccountPetFormScreen), findsOneWidget);
    });

    testWidgets('홈 일기 줄: 일기 쓰기 대신 등록 안내 한 줄', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _zeroPetMember(),
          child: const MaterialApp(home: Scaffold(body: TodayDiaryRow())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('우리 아이를 등록하면 일기를 남길 수 있어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('일기 쓰기 진입: 먼저 반려동물 등록 화면을 거쳐, 등록하면 그 아이로 이어 쓴다', (tester) async {
      final firestore = FakeFirebaseFirestore();
      ({String petId, bool registered})? outcome;
      final container = ProviderContainer(overrides: _zeroPetMember(firestore: firestore));
      addTearDown(container.dispose);
      // 앱에서는 홈·탭이 반려동물 목록을 늘 구독하고 있다 — 같은 조건.
      container.listen(effectivePetsProvider, (_, _) {});
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () async => outcome = await ensurePetForWriting(context, ref),
                  child: const Text('일기 쓰기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('일기 쓰기'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountPetFormScreen), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('pet_name')), '구름이');
      final add = find.widgetWithText(FilledButton, '추가');
      await tester.scrollUntilVisible(add, 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();

      expect(outcome, isNotNull);
      expect(outcome!.registered, isTrue);
      expect(outcome!.petId, startsWith('account:'));
      final docs = await firestore.collection('users').doc('u1').collection('pets').get();
      expect(docs.docs.single.data()['name'], '구름이');
    });

    testWidgets('홈 화면이 0마리 회원으로 열려도 깨지지 않고, 우리 아이 자리에 등록 안내가 보인다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [..._zeroPetMember(), shopEnabledProvider.overrideWith((ref) => Stream.value(true))],
          // 앱에서는 MainShell이 병원 번들을 다 읽은 뒤에 홈을 그린다 — 같은 순서.
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) =>
                    ref.watch(bundleProvider).hasValue ? const HomeScreen() : const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('동물병원 가기 전에\n확인하세요'), findsOneWidget);
      expect(find.text('우리 아이를 등록하면 일기를 남길 수 있어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('C. 가입 완료 화면', () {
    testWidgets('반려동물 있음: "첫 일기 쓰기" / "홈으로"', (tester) async {
      var primary = 0;
      var home = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SignupDoneScreen(hasPets: true, onPrimary: () => primary++, onHome: () => home++),
        ),
      );
      await tester.tap(find.text('첫 일기 쓰기'));
      await tester.tap(find.text('홈으로'));
      expect((primary, home), (1, 1));
    });

    testWidgets('반려동물 없음: "반려동물 등록하기" / "홈으로"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignupDoneScreen(hasPets: false, onPrimary: () {}, onHome: () {}),
        ),
      );
      expect(find.text('반려동물 등록하기'), findsOneWidget);
      expect(find.text('홈으로'), findsOneWidget);
      expect(find.text('첫 일기 쓰기'), findsNothing);
    });
  });

  group('E. 검색결과 카드', () {
    testWidgets('"비교 추가" 칩이 없다(비교는 상세의 "비교 담기"로)', (tester) async {
      final hospital = Hospital(
        id: 'h1',
        name: '구름동물병원',
        status: HospitalStatus.open,
        sido: '서울특별시',
        sigungu: '마포구',
        roadAddr: '서울특별시 마포구 어딘가로 1',
        jibunAddr: '',
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HospitalCard(hospital: hospital, sameAddressRecordCount: 1, onTap: () {}),
            ),
          ),
        ),
      );
      expect(find.text('비교 추가'), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
    });
  });
}
