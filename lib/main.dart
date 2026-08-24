import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import 'ads/app_open_ad_gate.dart';
import 'config/kakao_map_config.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isKakaoMapConfigured) {
    await KakaoMapSdk.instance.initialize(kakaoNativeKey);
  }

  // 항상 초기화한다 — 설정된 광고 단위 ID가 없으면 구글의 공개 테스트 ID로
  // 대체되므로(admob_config.dart 참고), 키 미설정 상태에서도 안전하게
  // 빌드·실행되고 테스트 광고가 정상적으로 표시된다.
  await MobileAds.instance.initialize();

  runApp(const ProviderScope(child: PetClinicCheckApp()));
}

class PetClinicCheckApp extends StatelessWidget {
  const PetClinicCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '펫병원체크',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const AppOpenAdGate(child: MainShell()),
    );
  }
}
