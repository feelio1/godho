import 'package:cloud_firestore/cloud_firestore.dart';

/// 일기 작성 시점의 날씨 — 선택 입력, 어느 쪽도 고르지 않으면 null
/// ("확인 안 됨을 솔직히" 원칙과 같은 결 — 날씨를 추정하지 않는다).
enum DiaryWeather {
  sunny('맑음'),
  partlyCloudy('구름 조금'),
  cloudy('흐림'),
  rainy('비'),
  snowy('눈');

  final String label;

  const DiaryWeather(this.label);

  static DiaryWeather? fromFirestore(String? value) {
    for (final e in DiaryWeather.values) {
      if (e.name == value) return e;
    }
    return null;
  }
}

/// 오늘 한 활동 — 고정 태그만, 다중 선택("방향 개편" 지시서 C).
enum DiaryActivity {
  walk('산책'),
  play('놀이'),
  treat('간식'),
  grooming('미용'),
  bath('목욕'),
  hospital('병원'),
  outing('외출·여행'),
  other('기타');

  final String label;

  const DiaryActivity(this.label);

  static DiaryActivity? fromFirestore(String? value) {
    for (final e in DiaryActivity.values) {
      if (e.name == value) return e;
    }
    return null;
  }
}

/// 활동 태그 칩을 내가 자주 쓴 순서로 보여주기 위한 정렬("일기 활성화"
/// 지시서 E) — [recentDiaries](호출부가 최근 50편을 건넨다)에서 많이
/// 쓴 태그부터, 같은 횟수면 원래(선언) 순서를 그대로 유지한다. 기록이
/// 없으면(또는 전부 0번) 기본 순서 그대로다.
List<DiaryActivity> sortActivitiesByRecentUsage(List<Diary> recentDiaries) {
  final counts = <DiaryActivity, int>{};
  for (final diary in recentDiaries) {
    for (final activity in diary.activities) {
      counts[activity] = (counts[activity] ?? 0) + 1;
    }
  }
  final sorted = [...DiaryActivity.values];
  sorted.sort((a, b) {
    final diff = (counts[b] ?? 0) - (counts[a] ?? 0);
    if (diff != 0) return diff;
    return DiaryActivity.values.indexOf(a) - DiaryActivity.values.indexOf(b);
  });
  return sorted;
}

/// 일기 사진 한 장 — `path`는 Firebase Storage 업로드 후 받은 다운로드
/// URL이다(저장 경로 자체가 아니라 바로 띄울 수 있는 주소). 가로·세로
/// 픽셀 크기를 함께 저장해 두면 나중에 책 인쇄 등에서 원본 비율로 배치할
/// 수 있다 — 업로드 전 실제 디코딩한 값을 쓴다(추정하지 않음).
///
/// [thumbPath]는 목록·캘린더·홈 카드 등 작게 보이는 곳에 쓰는 썸네일의
/// 다운로드 URL("일기 활성화" 지시서 A — 비용 관리). 썸네일 없이 올려둔
/// 기존 일기는 null이고, 그런 경우 [displayThumbPath]가 원본으로 대체
/// 표시한다(하위호환, 별도 마이그레이션 없음).
class DiaryPhoto {
  final String path;
  final String? thumbPath;
  final int width;
  final int height;

  const DiaryPhoto({required this.path, this.thumbPath, required this.width, required this.height});

  /// 작게 보이는 곳에서 쓸 주소 — 썸네일이 없으면 원본으로 대체한다.
  String get displayThumbPath => thumbPath ?? path;

  factory DiaryPhoto.fromFirestore(Map<String, dynamic> data) => DiaryPhoto(
        path: data['path'] as String? ?? '',
        thumbPath: data['thumbPath'] as String?,
        width: (data['width'] as num?)?.toInt() ?? 0,
        height: (data['height'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toFirestore() => {
        'path': path,
        if (thumbPath != null) 'thumbPath': thumbPath,
        'width': width,
        'height': height,
      };
}

/// 사진 최대 장수("방향 개편" 지시서 C) — 책 인쇄를 염두에 둔 원본 품질
/// 유지와 별개로, 한 편의 일기에 담을 수 있는 사진 수는 제한한다.
const int kDiaryMaxPhotos = 5;

/// 이미 [current]장이 있는 상태에서 [toAdd]를 더할 때, [kDiaryMaxPhotos]를
/// 넘지 않도록 앞에서부터 자른다 — 갤러리에서 한 번에 여러 장을 고를 때
/// 폼 화면이 쓴다. 이미 가득 찼으면(또는 [current]가 한도를 넘었으면)
/// 빈 목록을 돌려준다.
List<T> capPhotoAdditions<T>(int current, List<T> toAdd, {int limit = kDiaryMaxPhotos}) {
  final remaining = limit - current;
  if (remaining <= 0) return const [];
  return toAdd.take(remaining).toList();
}

/// 글 최대 길이.
const int kDiaryMaxTextLength = 2000;

/// `users/{uid}/diaries/{diaryId}` 문서 — 반려동물 일기 한 편("방향
/// 개편" 지시서 C). 로그인 전용 기능이라(게스트 로컬 저장 없음) 로컬
/// JSON 직렬화(`fromJson`/`toJson`)는 두지 않고 Firestore 직렬화만
/// 갖는다(`AppUser`와 같은 관례 — 이 코드베이스에서 서버 전용 모델은
/// 늘 이 쌍만 가진다).
///
/// [petIds]는 앱 전역에서 쓰는 반려동물 식별자 형식 그대로 저장한다 —
/// 계정 반려동물이면 `account:{docId}`(진료기록·캘린더 화면과 동일,
/// `effective_pets_provider.dart` 참고) — 그래야 "이 반려동물의 일기만
/// 보기" 필터가 변환 없이 바로 `pet.id`와 비교된다. 하루에 여러 편 작성을
/// 허용하므로 날짜만으로는 유일하지 않다.
class Diary {
  final String id;
  final DateTime date;
  final List<String> petIds;
  final DiaryWeather? weather;
  final List<DiaryActivity> activities;
  final String text;
  final List<DiaryPhoto> photos;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Diary({
    required this.id,
    required this.date,
    required this.petIds,
    this.weather,
    this.activities = const [],
    this.text = '',
    this.photos = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Diary copyWith({
    DateTime? date,
    List<String>? petIds,
    DiaryWeather? weather,
    List<DiaryActivity>? activities,
    String? text,
    List<DiaryPhoto>? photos,
    bool clearWeather = false,
  }) {
    return Diary(
      id: id,
      date: date ?? this.date,
      petIds: petIds ?? this.petIds,
      weather: clearWeather ? null : (weather ?? this.weather),
      activities: activities ?? this.activities,
      text: text ?? this.text,
      photos: photos ?? this.photos,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory Diary.fromFirestore(String id, Map<String, dynamic> data) => Diary(
        id: id,
        date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        petIds: (data['petIds'] as List<dynamic>? ?? const []).map((e) => e as String).toList(),
        weather: DiaryWeather.fromFirestore(data['weather'] as String?),
        activities: (data['activities'] as List<dynamic>? ?? const [])
            .map((e) => DiaryActivity.fromFirestore(e as String?))
            .whereType<DiaryActivity>()
            .toList(),
        text: data['text'] as String? ?? '',
        photos: (data['photos'] as List<dynamic>? ?? const [])
            .map((e) => DiaryPhoto.fromFirestore(e as Map<String, dynamic>))
            .toList(),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toFirestore() => {
        'date': Timestamp.fromDate(date),
        'petIds': petIds,
        'weather': weather?.name,
        'activities': activities.map((e) => e.name).toList(),
        'text': text,
        'photos': photos.map((e) => e.toFirestore()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  /// 수정 시 `createdAt`을 덮어쓰지 않도록 [toFirestore]에서 그 키만 뺀
  /// 맵 — `MedicalRecord`/`SignupPet`과 같은 패턴.
  Map<String, dynamic> toFirestoreUpdate() => toFirestore()..remove('createdAt');
}
