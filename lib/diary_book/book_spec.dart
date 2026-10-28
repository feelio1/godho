/// 그림일기 판형 — 인쇄업체 규격이 정해지면 숫자만 바꾼다. 레이아웃
/// 엔진은 이 값만 보고 좌표를 계산하므로 판형이 바뀌어도 코드는 그대로다.
///
/// 이 폴더(`lib/diary_book/`)의 엔진 파일들은 Flutter·Firebase에 의존하지
/// 않는 순수 Dart다 — 단위 테스트와 백그라운드 isolate에서 그대로 쓴다.
class BookSpec {
  /// 재단 후 완성 크기(mm).
  final double widthMm;
  final double heightMm;

  /// 재단 여백(mm) — 인쇄용 파일에만 더한다. 미리보기 PDF는 재단 여백 없이
  /// 완성 크기 그대로 만든다(인쇄용은 다음 단계).
  final double bleedMm;

  /// 안전 여백(mm) — 글자·사진 등 잘리면 안 되는 요소는 이 안쪽에만 둔다.
  final double safeMm;

  /// 총 쪽수 범위 — 모자라면 "메모" 쪽으로 채우고, 넘치면 오류로 돌려준다
  /// (일기를 자동으로 빼거나 자르지 않는다).
  final int minPages;
  final int maxPages;

  /// 이 해상도(dpi) 미만으로 인쇄될 사진이 있으면 그 쪽에 경고를 단다.
  final double minPhotoDpi;

  const BookSpec({
    required this.widthMm,
    required this.heightMm,
    required this.bleedMm,
    required this.safeMm,
    this.minPages = 4,
    this.maxPages = 120,
    this.minPhotoDpi = 150,
  });

  /// 기본 판형: A5 세로 148×210mm, 재단 여백 3mm, 안전 여백 10mm.
  static const a5 = BookSpec(widthMm: 148, heightMm: 210, bleedMm: 3, safeMm: 10);

  double get contentWidthMm => widthMm - safeMm * 2;
  double get contentHeightMm => heightMm - safeMm * 2;

  /// 캐시 키 등에 쓰는 안정적인 문자열.
  String get cacheKey => '$widthMm×$heightMm/b$bleedMm/s$safeMm/p$minPages-$maxPages/d$minPhotoDpi';
}
