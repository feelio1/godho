import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hospital.dart';

/// Naver Map app scheme calls need the caller app's package name.
/// Must match android/app/build.gradle.kts applicationId.
const String _naverMapAppName = 'com.petcheck.petcliniccheck';

class ExternalLinks {
  const ExternalLinks._();

  static Future<void> call(String phone) async {
    await launchUrl(Uri(scheme: 'tel', path: phone));
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
