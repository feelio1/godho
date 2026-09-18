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

/// 반려동물 성별(스프린트 14 시안 05_반려동물등록에 맞춰 추가). 기존
/// 저장된 데이터엔 이 값이 없을 수 있어 `fromJson`은 null이면 [unknown]으로
/// 안전하게 처리한다.
enum PetSex {
  male('남아'),
  female('여아'),
  unknown('확인 안 함');

  final String label;

  const PetSex(this.label);

  static PetSex fromJson(String? value) => PetSex.values.firstWhere(
        (e) => e.name == value,
        orElse: () => PetSex.unknown,
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
  final PetSex sex;
  final bool neutered;
  final double? weightKg;

  /// 로컬 파일 경로(기기 내). 서버 업로드 없음 — CLAUDE.md 계정·서버 없음.
  final String? photoPath;

  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.birthday,
    this.sex = PetSex.unknown,
    this.neutered = false,
    this.weightKg,
    this.photoPath,
  });

  Pet copyWith({
    String? name,
    PetSpecies? species,
    String? breed,
    DateTime? birthday,
    PetSex? sex,
    bool? neutered,
    double? weightKg,
    String? photoPath,
    bool clearBreed = false,
    bool clearBirthday = false,
    bool clearWeight = false,
    bool clearPhoto = false,
  }) {
    return Pet(
      id: id,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: clearBreed ? null : (breed ?? this.breed),
      birthday: clearBirthday ? null : (birthday ?? this.birthday),
      sex: sex ?? this.sex,
      neutered: neutered ?? this.neutered,
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
        id: json['id'] as String,
        name: json['name'] as String,
        species: PetSpecies.fromJson(json['species'] as String?),
        breed: json['breed'] as String?,
        birthday: json['birthday'] != null ? DateTime.tryParse(json['birthday'] as String) : null,
        sex: PetSex.fromJson(json['sex'] as String?),
        neutered: json['neutered'] as bool? ?? false,
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        photoPath: json['photoPath'] as String?,
      );

  /// 생일 기준 화면 표시용 나이 — 별도로 저장하지 않고 그때그때 계산한다
  /// (스프린트 14 시안: "생년월일(→자동 나이)").
  String? get ageLabel {
    final b = birthday;
    if (b == null) return null;
    final now = DateTime.now();
    var years = now.year - b.year;
    var months = now.month - b.month;
    if (now.day < b.day) months -= 1;
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    if (years <= 0) return '생후 $months개월';
    return '만 $years살';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'species': species.name,
        'breed': breed,
        'birthday': birthday?.toIso8601String(),
        'sex': sex.name,
        'neutered': neutered,
        'weightKg': weightKg,
        'photoPath': photoPath,
      };
}
