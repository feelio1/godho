import 'package:flutter/material.dart';

import '../models/diary.dart';

/// 날씨 아이콘 — 모델(diary.dart)은 순수 Dart만 쓰므로(다른 모델들과
/// 같은 관례) 화면 쪽 아이콘 매핑은 여기 둔다.
IconData diaryWeatherIcon(DiaryWeather weather) => switch (weather) {
      DiaryWeather.sunny => Icons.wb_sunny_outlined,
      DiaryWeather.partlyCloudy => Icons.wb_cloudy_outlined,
      DiaryWeather.cloudy => Icons.cloud_outlined,
      DiaryWeather.rainy => Icons.water_drop_outlined,
      DiaryWeather.snowy => Icons.ac_unit,
    };
