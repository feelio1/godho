import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/models/region_filter.dart';
import 'package:petcliniccheck/providers/region_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'applyGpsRegionIfUnset은 build()가 아직 끝나지 않았을 때 호출돼도 나중에 반영된다 '
    '(위치 자동감지 디버깅 지시서 E — 이전엔 state.value를 즉시 읽어 build 완료 전이면 '
    '조용히 아무 일도 안 하고 다시는 재시도되지 않았다: 앱 시작 직후 위치가 지역보다 '
    '먼저 도착하면 정확히 이 경쟁조건에 걸려 감지된 지역이 버려졌다)',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(regionProvider.notifier);
      // build()가 SharedPreferences를 비동기로 읽는 동안(아직 완료되기 전)
      // 바로 호출한다 — 수정 전 코드였다면 여기서 state.value가 null이라
      // 조용히 리턴했을 것이다.
      final applied = notifier.applyGpsRegionIfUnset(
        const RegionFilter(sido: '인천', sigungu: '서구'),
      );

      await applied;

      final state = container.read(regionProvider).value;
      expect(state, isNotNull);
      expect(state!.filter, const RegionFilter(sido: '인천', sigungu: '서구'));
      expect(state.isUserSelected, isFalse);
    },
  );

  test('사용자가 이미 지역을 직접 선택했으면 자동 감지 결과로 덮어쓰지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(regionProvider.notifier);
    await notifier.selectRegion(const RegionFilter(sido: '서울', sigungu: '종로구'));

    await notifier.applyGpsRegionIfUnset(const RegionFilter(sido: '인천', sigungu: '서구'));

    final state = container.read(regionProvider).value;
    expect(state!.filter, const RegionFilter(sido: '서울', sigungu: '종로구'));
    expect(state.isUserSelected, isTrue);
  });
}
