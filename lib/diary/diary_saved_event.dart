import 'package:flutter_riverpod/legacy.dart';

/// 일기 저장 신호(4차 업데이트 K-3) — 일기 쓰기 화면이 저장에 성공하면 닫기
/// 직전에 올린다. 어느 화면에서 일기 쓰기를 열었든(홈·우리 아이·가입 완료·
/// 알림) 저장 뒤 안내(첫 장 시트·스낵바·일기 알림 권유)를 한 곳
/// ([DiarySavedListener])에서 처리하려고 쓴다.
class DiarySavedEvent {
  final String diaryId;

  /// 새로 만든 일기인지(수정이면 false).
  final bool isNew;

  /// 같은 일기를 연달아 저장해도 매번 새 신호가 되게.
  final int serial;

  const DiarySavedEvent({required this.diaryId, required this.isNew, required this.serial});
}

final diarySavedEventProvider = StateProvider<DiarySavedEvent?>((ref) => null);
