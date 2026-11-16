import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/models/hospital_status.dart';
import 'package:petcliniccheck/providers/bundle_provider.dart';
import 'package:petcliniccheck/providers/region_provider.dart';
import 'package:petcliniccheck/providers/search_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test(
    '검색어가 없으면 선택 지역의 영업중 목록을 바로 보여주고, 입력하면 그 목록을 좁힌다',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(bundleProvider.future);
      await container.read(regionProvider.future);

      final allOpenNationwide = container.read(searchResultsProvider);
      expect(allOpenNationwide, isNotEmpty);
      expect(allOpenNationwide.every((h) => h.status != HospitalStatus.closed), isTrue);

      container.read(searchQueryProvider.notifier).state = '서울';
      final narrowed = container.read(searchResultsProvider);
      expect(narrowed, isNotEmpty);
      expect(narrowed.length, lessThan(allOpenNationwide.length));
      expect(
        narrowed.every(
          // 이름·도로명·지번·시도·시군구 중 어딘가에 검색어가 들어 있다.
          (h) => [h.name, h.roadAddr, h.jibunAddr, h.sido, h.sigungu].any((v) => v.contains('서울')),
        ),
        isTrue,
      );

      // 폐업도 보기를 켜면 검색어 없이도 폐업 기록이 함께 나온다.
      container.read(searchQueryProvider.notifier).state = '';
      container.read(includeClosedProvider.notifier).state = true;
      final withClosed = container.read(searchResultsProvider);
      expect(withClosed.length, greaterThan(allOpenNationwide.length));
    },
  );
}
