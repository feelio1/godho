/// 진료/방문 기록 한 건. 병원은 우리 DB에서 고른 병원(`hospitalId`)일 수도,
/// 직접 입력한 이름(`hospitalId`가 null)일 수도 있다 — 어느 쪽이든
/// `hospitalName`엔 항상 표시용 이름이 들어 있다.
///
/// 순수 데이터 + JSON 직렬화만 갖고 저장 방식(로컬/서버)에는 관여하지
/// 않는다 — 후속 Firebase 이관 시 이 클래스는 그대로 두고 저장소만
/// 교체하면 되도록 하기 위함(스프린트 8 지시서 3).
class MedicalRecord {
  final String id;
  final String petId;
  final DateTime date;
  final String? hospitalId;
  final String hospitalName;
  final String memo;
  final double? weightKg;
  final int? costWon;

  /// 로컬 파일 경로(기기 내, 예: 영수증 사진). 서버 업로드 없음.
  final String? photoPath;

  const MedicalRecord({
    required this.id,
    required this.petId,
    required this.date,
    this.hospitalId,
    required this.hospitalName,
    this.memo = '',
    this.weightKg,
    this.costWon,
    this.photoPath,
  });

  MedicalRecord copyWith({
    DateTime? date,
    String? hospitalId,
    String? hospitalName,
    String? memo,
    double? weightKg,
    int? costWon,
    String? photoPath,
    bool clearHospitalId = false,
    bool clearWeight = false,
    bool clearCost = false,
    bool clearPhoto = false,
  }) {
    return MedicalRecord(
      id: id,
      petId: petId,
      date: date ?? this.date,
      hospitalId: clearHospitalId ? null : (hospitalId ?? this.hospitalId),
      hospitalName: hospitalName ?? this.hospitalName,
      memo: memo ?? this.memo,
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      costWon: clearCost ? null : (costWon ?? this.costWon),
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }

  factory MedicalRecord.fromJson(Map<String, dynamic> json) => MedicalRecord(
        id: json['id'] as String,
        petId: json['petId'] as String,
        date: DateTime.parse(json['date'] as String),
        hospitalId: json['hospitalId'] as String?,
        hospitalName: json['hospitalName'] as String? ?? '',
        memo: json['memo'] as String? ?? '',
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        costWon: (json['costWon'] as num?)?.toInt(),
        photoPath: json['photoPath'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'petId': petId,
        'date': date.toIso8601String(),
        'hospitalId': hospitalId,
        'hospitalName': hospitalName,
        'memo': memo,
        'weightKg': weightKg,
        'costWon': costWon,
        'photoPath': photoPath,
      };
}
