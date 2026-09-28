import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/signup_pet.dart';

/// 가입 중 고른 반려동물 사진은 아직 Firestore 문서(petId)가 없어 바로
/// 업로드할 수 없다 — 로컬 파일만 들고 있다가 "완료"에서 문서를 만든
/// 뒤에야 업로드한다(펫클 "계정 반려동물 추가/수정" 지시서 1과 같은
/// 순서: 생성 → 업로드 → URL 갱신).
class PendingSignupPet {
  final SignupPet pet;
  final File? photoFile;

  const PendingSignupPet(this.pet, {this.photoFile});
}

/// 가입 플로우(나이·성별 화면 → 반려동물 화면) 동안 화면 사이에서 값을
/// 들고 있는 상태 — 마지막 "완료"에서 한 번에 Firestore로 쓴다(펫클
/// 2단계 지시서 3). 로그인 자체와는 무관해 [AuthRepository]를 몰라도
/// 되고, 순수 상태 전이만 있어 백엔드 없이 테스트하기 쉽다.
class SignupFlowState {
  final AgeGroup? ageGroup;
  final Gender? gender;
  final bool agreedStats;
  final List<PendingSignupPet> pets;

  const SignupFlowState({
    this.ageGroup,
    this.gender,
    this.agreedStats = false,
    this.pets = const [],
  });

  SignupFlowState copyWith({
    AgeGroup? ageGroup,
    Gender? gender,
    bool? agreedStats,
    List<PendingSignupPet>? pets,
  }) {
    return SignupFlowState(
      ageGroup: ageGroup ?? this.ageGroup,
      gender: gender ?? this.gender,
      agreedStats: agreedStats ?? this.agreedStats,
      pets: pets ?? this.pets,
    );
  }
}

class SignupFlowNotifier extends Notifier<SignupFlowState> {
  @override
  SignupFlowState build() => const SignupFlowState();

  /// 3-1(나이·성별) 화면의 "다음"/"건너뛰기" — 건너뛰어도 값은 모두 null,
  /// agreedStats는 false로 그대로 넘어간다(입력 강요 금지).
  void setAgeGender({AgeGroup? ageGroup, Gender? gender, required bool agreedStats}) {
    state = state.copyWith(ageGroup: ageGroup, gender: gender, agreedStats: agreedStats);
  }

  void addPet(SignupPet pet, {File? photoFile}) {
    state = state.copyWith(pets: [...state.pets, PendingSignupPet(pet, photoFile: photoFile)]);
  }

  void removePetAt(int index) {
    final updated = [...state.pets]..removeAt(index);
    state = state.copyWith(pets: updated);
  }

  /// Firestore 저장까지 끝난 뒤 다음 로그인/가입 시도를 위해 비운다.
  void reset() {
    state = const SignupFlowState();
  }
}

final signupFlowProvider = NotifierProvider<SignupFlowNotifier, SignupFlowState>(SignupFlowNotifier.new);
