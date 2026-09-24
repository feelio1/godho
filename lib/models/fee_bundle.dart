import 'fee.dart';

/// 진료비 시세 정적 번들(assets/fees.json) — tool/build_fees.py가 공개
/// 조사 원자료(CSV)에서 만든다. Firestore 미사용, 앱 시작 시 한 번 로드해
/// 메모리에서 조회한다(CLAUDE.md 데이터 원칙과 동일한 패턴).
class FeeBundle {
  final String source;
  final DateTime? baseDate;
  final List<String> categories;
  final List<FeeItem> items;

  /// sido -> sigungu -> itemId -> weightKey("default"|"u5"|"u10"|"u20") -> 값.
  final Map<String, Map<String, Map<String, Map<String, FeeValue>>>> _fees;

  const FeeBundle({
    required this.source,
    required this.baseDate,
    required this.categories,
    required this.items,
    // 필드가 private(_fees)이라 파라미터 이름까지 맞추면 fromJson
    // 호출부의 named-arg(_fees: ...)가 어색해진다 — 공개 파라미터 이름
    // (fees)을 그대로 두고 초기화 리스트에서만 연결한다.
    required Map<String, Map<String, Map<String, Map<String, FeeValue>>>> fees,
  }) : _fees = fees; // ignore: prefer_initializing_formals

  factory FeeBundle.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    final itemsJson = json['items'] as List<dynamic>? ?? const [];
    final feesJson = json['fees'] as Map<String, dynamic>? ?? const {};

    final fees = feesJson.map((sido, sigunguJson) {
      final sigunguMap = (sigunguJson as Map<String, dynamic>).map((sigungu, itemsJson) {
        final itemMap = (itemsJson as Map<String, dynamic>).map((itemId, weightsJson) {
          final weightMap = (weightsJson as Map<String, dynamic>).map(
            (weightKey, value) =>
                MapEntry(weightKey, FeeValue.fromJson(value as Map<String, dynamic>)),
          );
          return MapEntry(itemId, weightMap);
        });
        return MapEntry(sigungu, itemMap);
      });
      return MapEntry(sido, sigunguMap);
    });

    return FeeBundle(
      source: meta['source'] as String? ?? '',
      baseDate: DateTime.tryParse(meta['baseDate'] as String? ?? ''),
      categories: (json['categories'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      items: itemsJson.map((e) => FeeItem.fromJson(e as Map<String, dynamic>)).toList(),
      fees: fees,
    );
  }

  FeeItem? itemById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<FeeItem> itemsForCategory(String category) =>
      items.where((item) => item.category == category).toList();

  /// (시도, 시군구, 항목, 체중구간)의 시세를 찾는다. 데이터가 없으면
  /// null — 앱은 이 경우 값을 추정하지 않고 "데이터 없음"으로 솔직히
  /// 표기한다(CLAUDE.md 원칙 5).
  ///
  /// 체중 무관 항목은 [weight]를 무시하고 항상 같은 값을 돌려준다.
  FeeValue? lookup({
    required String sido,
    required String sigungu,
    required String itemId,
    FeeWeightBucket weight = FeeWeightBucket.u5,
  }) {
    final item = itemById(itemId);
    if (item == null) return null;
    final weightKey = item.weightBased ? weight.name : 'default';
    return _fees[sido]?[sigungu]?[itemId]?[weightKey];
  }

  /// (시도, 시군구)에 조사된 항목이 하나라도 있는지 — 개별 항목의 표본
  /// 유무(sampleLow)와는 다른, "이 구 자체가 fees 조사 범위에 있는지"를
  /// 보는 지역 단위 판정이다. hospitals.json은 최신 행정구역(예: 신설된
  /// 검단구)을 반영해도 fees.json 조사 시점이 그보다 이르면 그 구가
  /// 통째로 빠져 있을 수 있다 — 이 경우 다른 구 값으로 대체하지 않고
  /// "이 구는 아직 조사 자료가 없다"고 솔직히 구분하기 위한 메서드다
  /// (CLAUDE.md 원칙 5, 홈 자동 시세 표시 지시서 변경 2).
  bool hasAnyDataFor(String sido, String sigungu) {
    final itemMap = _fees[sido]?[sigungu];
    return itemMap != null && itemMap.isNotEmpty;
  }

  /// [category] 안에서 (시도, 시군구, 체중구간) 기준 실제 데이터가 있는
  /// 항목만 골라준다 — 항목별로 조사 커버리지가 달라(예: MRI는 표본이
  /// 훨씬 적음) 카테고리 안에서도 일부만 존재할 수 있다.
  List<FeeItem> itemsWithData({
    required String category,
    required String sido,
    required String sigungu,
    FeeWeightBucket weight = FeeWeightBucket.u5,
  }) {
    return itemsForCategory(category)
        .where((item) =>
            lookup(sido: sido, sigungu: sigungu, itemId: item.id, weight: weight) != null)
        .toList();
  }
}
