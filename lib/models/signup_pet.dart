import 'package:cloud_firestore/cloud_firestore.dart';

import 'pet.dart';
import 'pet_weight_band.dart';

/// 품종을 고르지 않았을 때 저장하는 값(2차 업데이트 — 품종은 선택 입력).
const String kUnknownBreed = '모름/믹스';

/// 가입 플로우에서 등록하는 반려동물 — `users/{uid}/pets/{petId}` 문서.
///
/// 로컬 [Pet]과 별개 모델이다: 저장소(로컬 SharedPreferences vs 클라우드
/// Firestore)뿐 아니라 스키마도 다르다(생년월은 [Pet.birthday]처럼 정확한
/// 하루가 아니라 "YYYY-MM" 월 단위로만 받는다 — 펫클 2단계 지시서 2). 로컬
/// 기록을 클라우드로 옮기는 통합은 4단계(이관) 대상이라 지금은 일부러
/// 합치지 않는다.
class SignupPet {
  final String? id;
  final PetSpecies species;
  final String breed;

  /// 옛 가입 데이터의 실제 체중(kg) — 지금 폼은 [weightBand]만 고른다. 옛
  /// 값은 지우지 않고(수정해도 그대로 들고 간다) 구간 계산에만 쓴다.
  final double? weightKg;

  /// 체중 구간 — 선택 입력, 모르면 null.
  final PetWeightBand? weightBand;

  /// "YYYY-MM" — 예: "2023-05". 모르면 빈 문자열(선택 입력).
  final String birth;

  final String? name;
  final PetSex? sex;
  final bool? neutered;
  final String? photoUrl;

  const SignupPet({
    this.id,
    required this.species,
    required this.breed,
    this.weightKg,
    this.weightBand,
    required this.birth,
    this.name,
    this.sex,
    this.neutered,
    this.photoUrl,
  });

  factory SignupPet.fromFirestore(String id, Map<String, dynamic> data) {
    return SignupPet(
      id: id,
      species: PetSpecies.fromJson(data['species'] as String?),
      breed: data['breed'] as String? ?? '',
      weightKg: _positiveOrNull((data['weightKg'] as num?)?.toDouble()),
      weightBand: PetWeightBand.fromName(data['weightBand'] as String?),
      birth: data['birth'] as String? ?? '',
      name: data['name'] as String?,
      sex: data['sex'] != null ? PetSex.fromJson(data['sex'] as String?) : null,
      neutered: data['neutered'] as bool?,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'species': species.name,
        'breed': breed,
        'weightKg': weightKg,
        'weightBand': weightBand?.name,
        'birth': birth,
        'name': name,
        'sex': sex?.name,
        'neutered': neutered,
        'photoUrl': photoUrl,
        'createdAt': Timestamp.now(),
      };

  /// 수정 시 `createdAt`을 덮어쓰지 않도록 [toFirestore]에서 그 키만
  /// 뺀 맵 — [UserRepository.updatePet]이 쓴다.
  Map<String, dynamic> toFirestoreUpdate() => toFirestore()..remove('createdAt');

  /// 사진 업로드는 문서 생성 이후(petId를 알아야) 이뤄지므로, 폼이 돌려준
  /// 값에 업로드 결과 URL만 나중에 얹을 때 쓴다(펫클 "계정 반려동물
  /// 추가/수정" 지시서).
  SignupPet copyWith({String? id, String? photoUrl, bool clearPhotoUrl = false}) {
    return SignupPet(
      id: id ?? this.id,
      species: species,
      breed: breed,
      weightKg: weightKg,
      weightBand: weightBand,
      birth: birth,
      name: name,
      sex: sex,
      neutered: neutered,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
    );
  }

  /// 고른 구간, 없으면 옛 [weightKg]로 계산한 구간, 둘 다 없으면 null.
  PetWeightBand? get weightBandOrDerived => effectiveWeightBand(band: weightBand, weightKg: weightKg);

  /// 목록 한 줄 요약 — "강아지 · 말티즈 · 5kg 미만 · 2023.05". 모르는 값은 빼고,
  /// 체중·생년월을 모르면 "체중 모름"·"생년월 모름" 대신 그냥 생략한다.
  String get summary {
    final parts = <String>[
      species.label,
      if (breed.trim().isNotEmpty) breed.trim(),
      ?weightBandOrDerived?.label,
      if (birth.trim().isNotEmpty) birth.trim().replaceAll('-', '.'),
    ];
    return parts.join(' · ');
  }
}

double? _positiveOrNull(double? value) => value == null || value <= 0 ? null : value;
