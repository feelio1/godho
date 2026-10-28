import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_settings.dart';
import '../../notifications/notification_service.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../diary_reminder_prompt.dart';
import '../providers/diary_providers.dart';

void _log(String message) {
  // release 빌드에서는 아무것도 찍지 않는다(기존 타이밍 로그와 같은
  // 관례) — "일기 재수정" 지시서 3-5: 표시/미표시 이유를 진단할 수
  // 있게 남긴다.
  if (kDebugMode) debugPrint('[DiaryReminderPrompt] $message');
}

/// 실제 일기 수가 3편 이상이면 아직 안 물었을 때 한 번만 알림 동의를
/// 묻는다("일기 재수정" 지시서 3) — 저장 화면이 아니라 "우리 아이" 탭의
/// 일기 목록으로 돌아온 뒤 호출된다(일기 목록을 처음 열 때, 그리고
/// 그 화면에서 새 일기를 저장하고 돌아왔을 때). 기기 로컬에 남아 있던
/// 옛 "물었음" 값은 더는 보지 않는다(옛 버그 버전이 시트 없이 기록했을
/// 수 있어 — 지시서 3-3) — 원격 필드(`diaryReminderAskedAt`)만 판단에
/// 쓴다. "물었음" 기록 자체도 시트가 실제로 뜨고 사용자가 버튼을
/// 누르거나 닫은 뒤에만 한다(지시서 3-2) — 그래야 시트가 뜨지 못한
/// 상황에서는 다음에 다시 물을 수 있다.
Future<void> maybeShowDiaryReminderPrompt(BuildContext context, WidgetRef ref) async {
  final uid = ref.read(authStateProvider).value?.uid;
  if (uid == null) {
    _log('로그인 안 됨 — 건너뜀');
    return;
  }
  const settings = AppSettings();
  final userRepo = ref.read(userRepositoryProvider);
  final reminderEnabled = await settings.diaryReminderEnabled();
  final alreadyAsked = await userRepo.diaryReminderAsked(uid);
  final diaryPage = await ref.read(diaryRepositoryProvider).fetchDiaries(uid, limit: 3);
  final diaryCount = diaryPage.diaries.length;
  final should = shouldPromptDiaryReminder(
    diaryCount: diaryCount,
    alreadyAsked: alreadyAsked,
    reminderEnabled: reminderEnabled,
  );
  _log('일기 수: $diaryCount, 알림 켜짐: $reminderEnabled, 원격 물었음: $alreadyAsked → 표시: $should');
  if (!should || !context.mounted) return;

  final wantsToTurnOn = await showModalBottomSheet<bool>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('매일 이 시간에 일기 알림을 받을까요?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              '정한 시간에 오늘 하루를 일기로 남겨보도록 알려드려요. 언제든 내 정보 > 설정에서 끌 수 있어요.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    child: const Text('괜찮아요'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: const Text('시간 정하고 켜기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  // 시트가 실제로 뜨고 버튼을 누르거나(또는 바깥을 탭해) 닫힌 뒤에만
  // "물었음"을 기록한다("일기 재수정" 지시서 3-2) — 실패해도 화면·저장
  // 흐름에 영향이 없도록 별도 try로 감싼다(지시서 3-4).
  try {
    await userRepo.markDiaryReminderAsked(uid);
  } catch (e) {
    _log('"물었음" 기록 실패(무시): $e');
  }

  if (wantsToTurnOn != true || !context.mounted) return;

  final picked = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(
      hour: AppSettings.diaryReminderDefaultHour,
      minute: AppSettings.diaryReminderDefaultMinute,
    ),
  );
  if (picked == null) return;

  // 알림 권한이 없으면 여기서 요청한다 — 거부되면 "켜짐" 상태로
  // 저장하지 않는다.
  final granted = await NotificationService.instance.requestPermission();
  if (!granted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정에서 알림을 허용해주세요.')),
      );
    }
    return;
  }

  await settings.setDiaryReminderEnabled(true);
  await settings.setDiaryReminderTime(hour: picked.hour, minute: picked.minute);
  await NotificationService.instance.refillDiaryReminderWindow(hour: picked.hour, minute: picked.minute);
}
