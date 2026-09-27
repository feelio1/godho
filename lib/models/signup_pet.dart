import 'package:cloud_firestore/cloud_firestore.dart';

import 'pet.dart';

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
  final double weightKg;

  /// "YYYY-MM" — 예: "2023-05".
  final String birth;

  final String? name;
  final PetSex? sex;
  final bool? neutered;
  final String? photoUrl;

  const SignupPet({
    this.id,
    required this.species,
    required this.breed,
    required this.weightKg,
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
      weightKg: (data['weightKg'] as num?)?.toDouble() ?? 0,
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
        'birth': birth,
        'name': name,
        'sex': sex?.name,
        'neutered': neutered,
        'photoUrl': photoUrl,
        'createdAt': Timestamp.now(),
      };
}
