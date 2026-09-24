import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/config/kakao_map_config.dart';
import 'package:petcliniccheck/providers/bundle_provider.dart';
import 'package:petcliniccheck/providers/region_auto_detect.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'KAKAO_REST_KEY 없이 빌드됐을 때(테스트 실행 환경 기본값) detectNormalizedRegion은 '
    'REST 경로를 건너뛰고 곧장 hospitals.json 최단거리 병원 폴백으로 지역을 찾는다 '
    '(위치 자동감지 디버깅 지시서 C — "키 없음"이 null로 바로 끝나면 안 되고 반드시 '
    '폴백으로 이어져야 한다)',
    (tester) async {
      // KAKAO_REST_KEY는 --dart-define으로만 채워지므로, dart-define 없이
      // 도는 flutter test 환경에서는 항상 비어 있다 — 이 테스트가 실제로
      // "키 없음" 경로를 검사하고 있다는 전제 자체를 함께 확인해 둔다.
      expect(isKakaoRestConfigured, isFalse);

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      // hospitals.json 실제 asset I/O — FakeAsync pump()가 못 돌리므로 실제
      // 비동기 존으로 나가서 기다린다(widget_test.dart와 같은 패턴).
      await tester.runAsync(() => capturedRef.read(bundleProvider.future));

      // 검단 인근 좌표 — 지도 인접 병원 표시 지시서에서 쓴 것과 동일한
      // 좌표를 재사용해, 그때 확인한 "유효한 (시도,구)" 폴백 결과가 이
      // 경로에서도 그대로 나오는지 확인한다.
      final normalized = await detectNormalizedRegion(capturedRef, 37.5985, 126.6790);

      expect(normalized, isNotNull, reason: '키 없음 → 폴백까지 실패해야만 null이어야 한다');
    },
  );
}
