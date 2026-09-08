/// 반려동물 종. 목록·라벨을 늘릴 땐 이 enum만 확장하면 된다.
enum PetSpecies {
  dog('강아지'),
  cat('고양이'),
  other('기타');

  final String label;

  const PetSpecies(this.label);

  static PetSpecies fromJson(String? value) => PetSpecies.values.firstWhere(
        (e) => e.name == value,
        orElse: () => PetSpecies.other,
      );
}

/// 반려동물 프로필. 지금은 화면상 1마리만 다루지만, 구조 자체는 여러 마리를
/// 담을 수 있게 목록으로 저장한다(스프린트 8 지시서 2 — "우선 1마리, 구조는
/// 여러 마리 확장 가능하게"). 후속 Firebase 이관을 대비해 순수 데이터 +
/// JSON 직렬화만 갖고, 저장 방식(로컬/서버)에는 관여하지 않는다.
class Pet {
  final String id;
  final String name;
  final PetSpecies species;
  final String? breed;
  final DateTime? birthday;

  /// 로컬 파일 경로(기기 내). 서버 업로드 없음 — CLAUDE.md 계정·서버 없음.
  final String? photoPath;

  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.birthday,
    this.photoPath,
  });

  Pet copyWith({
    String? name,
    PetSpecies? species,
    String? breed,
    DateTime? birthday,
    String? photoPath,
    bool clearBreed = false,
    bool clearBirthday = false,
    bool clearPhoto = false,
  }) {
    return Pet(
      id: id,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: clearBreed ? null : (breed ?? this.breed),
      birthday: clearBirthday ? null : (birthday ?? this.birthday),
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
        id: json['id'] as String,
        name: json['name'] as String,
        species: PetSpecies.fromJson(json['species'] as String?),
        breed: json['breed'] as String?,
        birthday: json['birthday'] != null ? DateTime.tryParse(json['birthday'] as String) : null,
        photoPath: json['photoPath'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'species': species.name,
        'breed': breed,
        'birthday': birthday?.toIso8601String(),
        'photoPath': photoPath,
      };
}
