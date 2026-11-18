import 'package:flutter/material.dart';

/// 숫자(가격·날짜·거리) 글자 — 예전엔 IBM Plex Mono였지만 쉼표 앞뒤가
/// 벌어져 보여서, 본문과 같은 IBM Plex Sans KR에 tabular figures(자릿수
/// 폭 고정)만 켠다(3차 업데이트 J-1, "장구름의 수첩"). 함수 이름은 호출부를
/// 그대로 두려고 유지한다 — 화면에서 IBM Plex Mono를 쓰는 곳은 없다(폰트
/// 파일·라이선스는 번들에 남겨 둔다).
class AppTextStyles {
  const AppTextStyles._();

  static const fontFamily = 'IBM Plex Sans KR';

  /// 숫자 자릿수를 맞추는 글꼴 기능 — 숫자가 많은 텍스트에 붙인다.
  static const tabular = [FontFeature.tabularFigures()];

  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontFeatures: tabular,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  /// 출처·기준일 같은 작은 캡션 — 12px, 중립 톤.
  static TextStyle src(Color color) => mono(size: 12, color: color, height: 1.5);

  /// 손글씨(나눔손글씨 펜) — 일기·우리 아이 영역의 한 줄 문구.
  static TextStyle hand({required double size, Color? color, double? height}) => TextStyle(
        fontFamily: 'Nanum Pen Script',
        fontSize: size,
        color: color,
        height: height,
      );
}
