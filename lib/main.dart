import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import 'ads/app_open_ad_gate.dart';
import 'config/kakao_map_config.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1단계 토대: 연결만 한다(로그인/게이팅/이벤트 로깅 없음 — 이후 단계).
  // google-services.json이 없거나 초기화가 실패해도 게스트 기능(검색·
  // 시세·지도·진료기록)은 그대로 떠야 하므로 실패를 앱 전체로 전파하지
  // 않는다.
  try {
    await Firebase.initializeApp();
    debugPrint('[Firebase] 초기화 성공');
  } catch (e) {
    debugPrint('[Firebase] 초기화 실패(게스트 기능은 정상 동작): $e');
  }

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
      title: 'Petcli',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // 전체가 한국어 앱이라 시간 선택 등 Flutter 기본 위젯(TimeOfDay.format
      // 등)도 "오후 9:27" 같은 한국어 표기를 쓰게 로케일을 고정한다 — 지역화
      // 델리게이트가 없으면 영어 "9:27 PM"로 표시돼 화면 전체 톤과 어긋난다.
      locale: const Locale('ko'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ko')],
      home: const AppOpenAdGate(child: MainShell()),
    );
  }
}
