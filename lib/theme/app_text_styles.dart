import 'package:flutter/material.dart';

/// "펫클 앱 디자인" 캔버스 시안의 `.mono`/`.src` — 가격·날짜·거리 같은
/// 숫자는 본문(IBM Plex Sans KR)과 다른 모노스페이스(IBM Plex Mono)로
/// 보여준다. 숫자 자릿수가 바뀌어도 폭이 흔들리지 않도록 tabular
/// figures를 켠다.
class AppTextStyles {
  const AppTextStyles._();

  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
  }) =>
      TextStyle(
        fontFamily: 'IBM Plex Mono',
        fontFeatures: const [FontFeature.tabularFigures()],
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  /// 출처·기준일 같은 작은 캡션("src" 클래스) — 11px, 중립 톤.
  static TextStyle src(Color color) => mono(size: 11, color: color, height: 1.5);
}
