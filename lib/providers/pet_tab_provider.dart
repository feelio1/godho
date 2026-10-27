import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/appointment_calendar.dart';

/// "우리 아이" 탭 안의 [일기|캘린더|진료기록] 세그먼트("탭 개편" 지시서 B,
/// "방향 개편" 지시서 D에서 일기 추가) — 기본은 일기이고, 마지막으로 본
/// 세그먼트는 기기에 저장해 앱을 다시 켜도 이어본다("일기를 기본 보기로"
/// 지시서). 저장값이 없거나 알 수 없는 값이면 일기로 돌아간다.
enum PetTabView { diary, calendar, records }

const _petTabViewPrefsKey = 'pet_tab_view_v1';

final petTabViewProvider = StateProvider<PetTabView>((ref) => PetTabView.diary);

/// [PetTabScreen]이 처음 만들어질 때 한 번 불러 저장된 마지막 세그먼트를
/// 반영한다. 저장값이 없거나(처음 쓰는 경우) 알 수 없는 문자열이면
/// 아무것도 하지 않아 기본값(일기)이 그대로 유지된다.
Future<void> restorePersistedPetTabView(StateController<PetTabView> controller) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_petTabViewPrefsKey);
  for (final value in PetTabView.values) {
    if (value.name == raw) {
      controller.state = value;
      return;
    }
  }
}

/// 세그먼트가 바뀔 때마다 호출해 다음 실행에서도 이어보게 한다.
Future<void> persistPetTabView(PetTabView view) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_petTabViewPrefsKey, view.name);
}

/// 캘린더 보기에서 지금 선택된 날짜 — AppBar의 "+" 버튼이 캘린더 세그먼트일
/// 때 통합 입력(기록/예약)을 이 날짜로 연다("일기를 기본 보기로" 지시서).
/// 캘린더 화면([PetCalendarBody])이 스스로 갱신하고, 다른 화면은 읽기만
/// 한다.
final petTabCalendarSelectedDayProvider = StateProvider<DateTime>((ref) => dateOnly(DateTime.now()));
