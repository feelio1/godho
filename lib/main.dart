import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import 'ads/app_open_ad_gate.dart';
import 'config/kakao_map_config.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_gate.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 예약 캘린더(table_calendar)가 'ko_KR' 로케일로 월/요일 이름을 그려야
  // 해서 명시적으로 초기화해둔다 — 안 하면 실기기에서 로케일 데이터 미초기화
  // 예외로 캘린더가 뜨자마자 죽을 수 있다("예약 진료 캘린더" 지시서 4).
  await initializeDateFormatting('ko_KR', null);

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
    // 키가 있어도 네이티브 초기화 자체가 실패할 수 있다(키 형식 오류,
    // 앱 키해시 미등록 등) — 예전엔 이 호출이 예외를 던지면 runApp()
    // 전체가 막혀 앱이 시작도 못 하고 튕겼다("지도 수정" 지시서 1-2).
    // 다른 네이티브 SDK 초기화(Firebase, KakaoSdk.init)와 같은 방어
    // 패턴으로, 실패해도 로그만 남기고 지도 탭만 "준비 중" 스텁으로
    // 안전하게 대체한다(kakaoMapSdkInitialized로 화면에서 확인).
    try {
      await KakaoMapSdk.instance.initialize(kakaoNativeKey);
      kakaoMapSdkInitialized = true;
      debugPrint('[KakaoMap] 지도 SDK 초기화 성공');
    } catch (e, st) {
      debugPrint('[KakaoMap] 지도 SDK 초기화 실패(주변 병원 탭은 준비 중 안내로 대체): $e\n$st');
    }
    // 2단계(로그인) 지시서 1: 로그인용 카카오 SDK(kakao_flutter_sdk_user)는
    // 지도 SDK와 별개 모듈이라 따로 초기화해야 한다 — 같은 네이티브 키를
    // 재사용한다. 카카오 로그인 버튼은 항상 "준비 중" 안내로 안전하게
    // 끝나므로(Cloud Function 미배포), 초기화 실패도 앱 전체를 막지 않게
    // 방어한다.
    try {
      await KakaoSdk.init(nativeAppKey: kakaoNativeKey);
    } catch (e) {
      debugPrint('[KakaoSdk] 로그인용 초기화 실패(카카오 로그인 버튼만 영향): $e');
    }
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
      // 온보딩(최초 1회, 로그인 불필요)이 앱 본편보다 먼저 뜬다 — 게이트
      // 자체는 상태(계정 반려동물, 지역 선택 등)를 전혀 건드리지 않고 그냥
      // "이번이 처음이냐"만 본다("캘린더 하단탭화 + 진료 연대기" 지시서 B).
      home: const OnboardingGate(child: AppOpenAdGate(child: MainShell())),
    );
  }
}
