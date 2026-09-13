import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hospital.dart';

/// Naver Map app scheme calls need the caller app's package name.
/// Must match android/app/build.gradle.kts applicationId.
const String _naverMapAppName = 'com.petcheck.petcliniccheck';

class ExternalLinks {
  const ExternalLinks._();

  /// 인허가 데이터의 전화번호를 실제로 걸 수 있는 형태로 정리한다. 숫자와
  /// 맨 앞의 '+'만 남기고 공백·하이픈·괄호 등은 제거한다. 정리한 결과에
  /// 숫자가 하나도 안 남으면(빈 문자열·null·문자만 있는 값 등) null —
  /// "전화번호 없음"과 동일하게 취급한다(스프린트 12 지시서 2).
  static String? sanitizedPhone(String? phone) {
    if (phone == null) return null;
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return null;
    final leadingPlus = trimmed.startsWith('+') ? '+' : '';
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return '$leadingPlus$digits';
  }

  /// 전화 걸기. 등록된 전화번호가 없거나(빈 값·형식이 깨져 숫자가 전혀
  /// 없는 경우) 다이얼러를 열 수 없으면, 버튼이 아무 반응 없이 끝나지
  /// 않도록 스낵바로 짧게 안내한다(스프린트 12 지시서 2 — "무반응 금지").
  /// 상세 화면·지정 병원 카드·비교 화면 등 전화 버튼이 있는 모든 곳이
  /// 이 메서드 하나를 거치므로 안내 문구가 항상 일관된다.
  static Future<void> call(BuildContext context, String? phone) async {
    final sanitized = sanitizedPhone(phone);
    if (sanitized == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('등록된 전화번호가 없습니다.')),
      );
      return;
    }
    final launched = await launchUrl(Uri(scheme: 'tel', path: sanitized));
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전화 앱을 열 수 없습니다.')),
      );
    }
  }

  /// 길찾기: opens the Naver Map app via its URL scheme, falling back to
  /// the Naver Map web search if the app is not installed.
  static Future<void> openDirections(Hospital hospital) async {
    final appUri = hospital.hasCoordinates
        ? Uri.parse('nmap://route/public'
            '?dlat=${hospital.lat}&dlng=${hospital.lng}'
            '&dname=${Uri.encodeComponent(hospital.name)}'
            '&appname=$_naverMapAppName')
        : Uri.parse('nmap://search'
            '?query=${Uri.encodeComponent(hospital.roadAddr)}'
            '&appname=$_naverMapAppName');

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
      return;
    }

    final query = hospital.roadAddr.isNotEmpty ? hospital.roadAddr : hospital.name;
    await launchUrl(
      Uri.parse('https://map.naver.com/p/search/${Uri.encodeComponent(query)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<void> openNaverMapReviews(Hospital hospital) async {
    final query = '${hospital.name} ${hospital.roadAddr}';
    await launchUrl(
      Uri.parse('https://map.naver.com/p/search/${Uri.encodeComponent(query)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<void> openKakaoMapReviews(Hospital hospital) async {
    final query = '${hospital.name} ${hospital.roadAddr}';
    await launchUrl(
      Uri.parse('https://map.kakao.com/?q=${Uri.encodeComponent(query)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<void> openAnimalProtectionSystem() async {
    await launchUrl(
      Uri.parse('https://www.animal.go.kr'),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<void> shareHospital(Hospital hospital) async {
    await SharePlus.instance.share(
      ShareParams(
        text: '${hospital.name}\n${hospital.roadAddr}\n'
            '펫병원체크에서 공개된 인허가 정보를 확인해보세요.',
      ),
    );
  }
}
