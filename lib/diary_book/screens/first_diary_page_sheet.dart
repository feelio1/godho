import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../diary/diary_saved_event.dart';
import '../../diary/models/diary.dart';
import '../../diary/providers/diary_providers.dart';
import '../../diary/screens/diary_reminder_prompt_sheet.dart';
import '../../providers/auth_provider.dart';
import '../../providers/effective_pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/keep_words.dart';
import '../providers/diary_book_switch.dart';
import 'diary_page_screen.dart';

/// 일기 저장 뒤 무엇을 보여 줄지.
enum DiarySavedFollowUp {
  /// 계정의 첫 일기 — "첫 장이 생겼어요" 시트.
  firstPageSheet,

  /// 두 번째 일기부터 — 스낵바 "그림일기 장으로 볼 수 있어요 · 보기" 한 번.
  viewSnackbar,

  /// 아무것도(수정·스위치 닫힘).
  none,
}

/// 저장 뒤 안내 판정(4차 업데이트 K-3) — 그림일기 스위치가 닫혔거나 수정이면
/// 아무것도 안 띄운다. 새 일기이고 계정 기준 일기가 1편이며 아직 시트를
/// 보여 준 적이 없으면(`firstDiaryPageShownAt` 없음) 시트, 그 밖엔 스낵바.
DiarySavedFollowUp decideDiarySavedFollowUp({
  required bool isNew,
  required bool bookVisible,
  required int diaryCount,
  required bool firstPageAlreadyShown,
}) {
  if (!bookVisible || !isNew) return DiarySavedFollowUp.none;
  if (diaryCount == 1 && !firstPageAlreadyShown) return DiarySavedFollowUp.firstPageSheet;
  return DiarySavedFollowUp.viewSnackbar;
}

/// 저장 신호를 듣고 일기 쓰기 화면이 닫힌 뒤 안내를 띄운다 — 메인 화면에
/// 한 번 둔다. 첫 장 시트를 띄운 저장에서는 일기 알림 권유를 다음 기회로
/// 미룬다(같이 뜨지 않게).
class DiarySavedListener extends ConsumerStatefulWidget {
  final Widget child;

  /// 일기 쓰기 화면이 닫히는 애니메이션을 기다리는 시간.
  final Duration settleDelay;

  const DiarySavedListener({super.key, required this.child, this.settleDelay = const Duration(milliseconds: 450)});

  @override
  ConsumerState<DiarySavedListener> createState() => _DiarySavedListenerState();
}

class _DiarySavedListenerState extends ConsumerState<DiarySavedListener> {
  @override
  Widget build(BuildContext context) {
    ref.listen<DiarySavedEvent?>(diarySavedEventProvider, (previous, next) {
      if (next == null || next.serial == previous?.serial) return;
      unawaited(_handleLater(next));
    });
    return widget.child;
  }

  Future<void> _handleLater(DiarySavedEvent event) async {
    await Future<void>.delayed(widget.settleDelay);
    if (!mounted) return;
    await handleDiarySaved(context, ref, event);
  }
}

Future<void> handleDiarySaved(BuildContext context, WidgetRef ref, DiarySavedEvent event) async {
  final uid = ref.read(authStateProvider).value?.uid;
  if (uid == null) return;
  var followUp = DiarySavedFollowUp.none;
  try {
    final bookVisible = ref.read(diaryBookVisibleProvider);
    if (bookVisible && event.isNew) {
      final page = await ref.read(diaryRepositoryProvider).fetchDiaries(uid, limit: 2);
      final shown = await ref.read(userRepositoryProvider).firstDiaryPageShown(uid);
      followUp = decideDiarySavedFollowUp(
        isNew: event.isNew,
        bookVisible: bookVisible,
        diaryCount: page.diaries.length,
        firstPageAlreadyShown: shown,
      );
    }
    if (!context.mounted) return;
    switch (followUp) {
      case DiarySavedFollowUp.firstPageSheet:
        final diary = await ref.read(diaryRepositoryProvider).fetchDiary(uid, event.diaryId);
        if (diary == null || !context.mounted) return;
        await ref.read(userRepositoryProvider).markFirstDiaryPageShown(uid);
        if (!context.mounted) return;
        await showFirstDiaryPageSheet(context, ref, diary);
        return; // 일기 알림 권유는 다음 기회로.
      case DiarySavedFollowUp.viewSnackbar:
        final diary = await ref.read(diaryRepositoryProvider).fetchDiary(uid, event.diaryId);
        if (diary != null && context.mounted) {
          final navigator = Navigator.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('그림일기 장으로 볼 수 있어요'),
              action: SnackBarAction(
                label: '보기',
                onPressed: () => navigator.push(MaterialPageRoute(builder: (_) => DiaryPageScreen(diary: diary))),
              ),
            ),
          );
        }
      case DiarySavedFollowUp.none:
        break;
    }
  } catch (e) {
    debugPrint('[handleDiarySaved] 저장 뒤 안내 실패(무시): $e');
  }
  if (event.isNew && context.mounted) await maybeShowDiaryReminderPrompt(context, ref);
}

/// "{이름}의 그림일기 첫 장이 생겼어요" 시트 — 썸네일 + [크게 보기]·[공유하기]·[닫기].
Future<void> showFirstDiaryPageSheet(BuildContext context, WidgetRef ref, Diary diary) {
  final pets = ref.read(effectivePetsProvider).value ?? const [];
  final petName = pets.where((p) => diary.petIds.contains(p.id)).firstOrNull?.name ?? '우리 아이';
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.page),
        child: Column(
          key: const ValueKey('first_diary_page_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              keepWords('$petName의 그림일기 첫 장이 생겼어요'),
              textAlign: TextAlign.center,
              style: AppTextStyles.hand(size: 30, color: AppColors.textPrimary, height: 1.25),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.softPanel,
                borderRadius: BorderRadius.circular(AppRadius.panel),
              ),
              child: DiaryPageThumbnail(diary: diary, height: 260),
            ),
            const SizedBox(height: 10),
            const Text(
              '일기를 쓸 때마다 한 장씩 늘어나요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => DiaryPageScreen(diary: diary)));
              },
              child: const Text('크게 보기'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => shareDiaryPage(sheetContext, ref, diary),
              icon: const Icon(Icons.ios_share, size: 20),
              label: const Text('공유하기'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    ),
  );
}
