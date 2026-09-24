import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/data/fee_bundle_loader.dart';
import 'package:petcliniccheck/models/fee_bundle.dart';
import 'package:petcliniccheck/utils/fee_no_data_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late final FeeBundle bundle;

  setUpAll(() async {
    bundle = await const FeeBundleLoader().load();
  });

  test(
    '검단구(신설 구)는 hospitals.json엔 있어도 fees.json 조사 시점보다 나중에 '
    '생겨 아직 없다 — 다른 구 값으로 대체하지 않고 없음으로 판정해야 한다',
    () {
      expect(bundle.hasAnyDataFor('인천', '검단구'), isFalse);
    },
  );

  test('검단구 안내 문구는 신설 시점을 밝힌 전용 문구다', () {
    final subtitle = feeNoRegionDataSubtitle('인천 검단구', '검단구');
    expect(subtitle, contains('2026년 7월'));
    expect(subtitle, contains('검단구'));
  });

  test('신설 구 목록에 없는, 일반적으로 fees에 없는 구는 사유 없는 공통 문구를 쓴다', () {
    final subtitle = feeNoRegionDataSubtitle('테스트 지역', '존재하지않는구');
    expect(subtitle, '테스트 지역은 공개된 진료비 조사 자료가 아직 없어요.');
  });

  test('기존에 데이터가 있던 구(인천 서구)는 회귀 없이 여전히 정상 조회된다', () {
    expect(bundle.hasAnyDataFor('인천', '서구'), isTrue);
    final value = bundle.lookup(sido: '인천', sigungu: '서구', itemId: 'consult_first');
    expect(value, isNotNull);
  });
}
