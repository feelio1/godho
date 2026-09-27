import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/app_user.dart';
import 'package:petcliniccheck/models/pet.dart';
import 'package:petcliniccheck/models/signup_pet.dart';
import 'package:petcliniccheck/providers/signup_flow_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('초기 상태는 전부 비어 있다(선택 입력·최소 0마리)', () {
    final state = container.read(signupFlowProvider);
    expect(state.ageGroup, isNull);
    expect(state.gender, isNull);
    expect(state.agreedStats, isFalse);
    expect(state.pets, isEmpty);
  });

  test('나이·성별 화면에서 값을 입력하면 상태에 반영된다', () {
    container.read(signupFlowProvider.notifier).setAgeGender(
          ageGroup: AgeGroup.twenties,
          gender: Gender.female,
          agreedStats: true,
        );

    final state = container.read(signupFlowProvider);
    expect(state.ageGroup, AgeGroup.twenties);
    expect(state.gender, Gender.female);
    expect(state.agreedStats, isTrue);
  });

  test('"건너뛰기"는 값을 모두 null/false로 넘기지만 통계 동의를 강요하지 않는다', () {
    container.read(signupFlowProvider.notifier).setAgeGender(agreedStats: false);

    final state = container.read(signupFlowProvider);
    expect(state.ageGroup, isNull);
    expect(state.gender, isNull);
    expect(state.agreedStats, isFalse);
  });

  test('반려동물 추가는 누적되고, 제거는 해당 인덱스만 지운다(다중 등록)', () {
    final notifier = container.read(signupFlowProvider.notifier);
    const dog = SignupPet(species: PetSpecies.dog, breed: '말티즈', weightKg: 3.2, birth: '2023-05');
    const cat = SignupPet(species: PetSpecies.cat, breed: '코리안숏헤어', weightKg: 4.0, birth: '2022-11');

    notifier.addPet(dog);
    notifier.addPet(cat);
    expect(container.read(signupFlowProvider).pets, hasLength(2));

    notifier.removePetAt(0);
    final remaining = container.read(signupFlowProvider).pets;
    expect(remaining, hasLength(1));
    expect(remaining.single.breed, '코리안숏헤어');
  });

  test('reset은 나이·성별·반려동물을 전부 비운다(가입 완료 후 다음 로그인 대비)', () {
    final notifier = container.read(signupFlowProvider.notifier);
    notifier.setAgeGender(ageGroup: AgeGroup.thirties, agreedStats: true);
    notifier.addPet(const SignupPet(species: PetSpecies.dog, breed: '푸들', weightKg: 2.0, birth: '2020-01'));

    notifier.reset();

    final state = container.read(signupFlowProvider);
    expect(state.ageGroup, isNull);
    expect(state.agreedStats, isFalse);
    expect(state.pets, isEmpty);
  });
}
