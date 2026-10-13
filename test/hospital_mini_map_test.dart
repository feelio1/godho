import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/hospital.dart';
import 'package:petcliniccheck/models/hospital_status.dart';
import 'package:petcliniccheck/widgets/hospital_mini_map.dart';

// 이 테스트는 --dart-define 없이 돌아가므로 isKakaoMapConfigured가 항상
// false다 — 그래서 좌표가 있어도 없어도 SizedBox.shrink()만 확인할 수
// 있다(실제 카카오맵 네이티브 위젯은 플랫폼 채널이 없는 테스트 환경에서
// 띄울 수 없다). "좌표 없으면 숨김"과 "카카오맵 설정 없으면 숨김" 두
// 분기 모두 결국 이 SizedBox.shrink() 경로로 합쳐지므로, 여기서는 둘 다
// 크래시 없이 빈 위젯을 돌려주는지를 확인한다.
Hospital _hospital({double? lat, double? lng}) => Hospital(
      id: 'h1',
      name: '가온동물병원',
      status: HospitalStatus.open,
      sido: '인천',
      sigungu: '서구',
      roadAddr: '인천 서구 어딘가 1',
      jibunAddr: '인천 서구 어딘가 1',
      lat: lat,
      lng: lng,
    );

void main() {
  testWidgets('좌표가 없는 병원은 미니맵 영역을 그리지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HospitalMiniMap(hospital: _hospital())),
      ),
    );

    expect(find.byType(SizedBox), findsOneWidget);
    final box = tester.widget<SizedBox>(find.byType(SizedBox));
    expect(box.height, 0);
    expect(box.width, 0);
  });

  testWidgets('카카오맵 키가 설정되지 않은 빌드에서는 좌표가 있어도 미니맵을 그리지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HospitalMiniMap(hospital: _hospital(lat: 37.5, lng: 126.6)),
        ),
      ),
    );

    expect(find.byType(SizedBox), findsOneWidget);
    final box = tester.widget<SizedBox>(find.byType(SizedBox));
    expect(box.height, 0);
    expect(box.width, 0);
  });
}
