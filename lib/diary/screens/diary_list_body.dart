import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../diary_book/providers/diary_book_switch.dart';
import '../../diary_book/screens/diary_book_setup_screen.dart';
import '../../models/pet.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/inline_error_message.dart';
import '../../widgets/mascot_image.dart';
import '../../widgets/mascot_message.dart';
import '../diary_calendar.dart' show diaryRecordedDays;
import '../diary_photo_display_merge.dart';
import '../diary_photo_display_widgets.dart';
import '../diary_photo_upload_queue.dart';
import '../diary_photo_upload_queue_service.dart';
import '../models/diary.dart';
import '../providers/diary_providers.dart';
import 'diary_detail_screen.dart';
import 'diary_form_screen.dart';
import 'diary_reminder_prompt_sheet.dart';
import 'diary_weather_icons.dart';

/// "우리 아이" 탭의 일기 보기("방향 개편" 지시서 D) — 선택된 반려동물이
/// 포함된 일기만, 최신순 카드 목록. 반려동물이 여러 마리면 "전체" 보기로
/// 전환할 수 있다. 게스트 게이팅·AppBar·반려동물 선택은 `PetTabScreen`이
/// 한 번만 가지므로, 여기서는 목록 본문만 맡는다(캘린더·진료기록 보기와
/// 같은 관례).
class DiaryListBody extends ConsumerStatefulWidget {
  final Pet selectedPet;
  final List<Pet> allPets;

  const DiaryListBody({super.key, required this.selectedPet, required this.allPets});

  @override
  ConsumerState<DiaryListBody> createState() => _DiaryListBodyState();
}

class _DiaryListBodyState extends ConsumerState<DiaryListBody> {
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    // 백그라운드 업로드 대기열이 바뀌면(사진 완료·실패) 목록을 다시
    // 불러 "올리는 중" 표시를 자동으로 교체한다("일기 재수정" 지시서
    // 2-3).
    DiaryPhotoUploadQueueService.instance.changeTick.addListener(_onQueueChanged);
    // 일기 알림 동의 질문은 저장 화면이 아니라 이 목록을 열 때(그리고
    // 아래 _openForm에서 새 일기를 저장하고 돌아왔을 때) 보여준다
    // ("일기 재수정" 지시서 3-1) — 저장 화면이 바로 닫히는 시점과
    // 겹쳐 시트 컨텍스트가 불안정해지는 문제를 피한다.
    WidgetsBinding.instance.addPostFrameCallback((_) => maybeShowDiaryReminderPrompt(context, ref));
  }

  @override
  void dispose() {
    DiaryPhotoUploadQueueService.instance.changeTick.removeListener(_onQueueChanged);
    super.dispose();
  }

  void _onQueueChanged() {
    if (!mounted) return;
    ref.invalidate(diariesPageProvider);
    ref.invalidate(diariesForPetProvider);
    ref.invalidate(diariesForMonthProvider);
    ref.invalidate(diaryPendingPhotosProvider);
  }

  /// 새 일기를 저장하고 돌아오면("일기 재수정" 지시서 3-1) 다시 한 번
  /// 알림 동의 조건을 확인한다 — 실제 판단·표시는
  /// [maybeShowDiaryReminderPrompt]가 맡는다(이미 물었거나 조건이 안
  /// 맞으면 조용히 아무 일도 하지 않는다).
  Future<void> _openForm() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => DiaryFormScreen(defaultPetIds: [widget.selectedPet.id])));
    if (saved == true && mounted) await maybeShowDiaryReminderPrompt(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final diariesAsync = _showAll
        ? ref.watch(diariesPageProvider).whenData((page) => page.diaries)
        : ref.watch(diariesForPetProvider(widget.selectedPet.id));

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page - 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text('일기는 나만 볼 수 있어요', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ),
                  // 그림일기 진입점 — config/book 스위치가 열렸을 때만(fail-closed).
                  if (ref.watch(diaryBookVisibleProvider))
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => DiaryBookSetupScreen(initialPetId: widget.selectedPet.id)),
                      ),
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: const Text('그림일기 만들기'),
                    ),
                ],
              ),
            ),
            const _MonthlyDiaryTracker(),
            if (widget.allPets.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 0),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(widget.selectedPet.name),
                      selected: !_showAll,
                      onSelected: (_) => setState(() => _showAll = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('전체'),
                      selected: _showAll,
                      onSelected: (_) => setState(() => _showAll = true),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: diariesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    InlineErrorMessage(error: error, onRetry: () => ref.invalidate(diariesPageProvider)),
                data: (diaries) {
                  if (diaries.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: MascotMessage(
                          title: '오늘 ${widget.selectedPet.name}의 하루를 남겨보세요',
                          subtitle: '오늘 하루 있었던 일을 사진과 함께 가볍게 남겨두세요.',
                          assetPath: MascotImage.emptyRecordAssetPath,
                          overlayIcon: Icons.edit_note,
                          trailing: FilledButton.icon(
                            onPressed: _openForm,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('첫 일기 쓰기'),
                          ),
                        ),
                      ),
                    );
                  }
                  // 달이 바뀌는 곳마다 "2026년 11월" 제목을 끼운다(목록 순서는 그대로).
                  final items = <Object>[];
                  DateTime? month;
                  for (final diary in diaries) {
                    final m = DateTime(diary.date.year, diary.date.month);
                    if (m != month) {
                      items.add(m);
                      month = m;
                    }
                    items.add(diary);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 6, AppSpacing.page, 96),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      if (item is DateTime) {
                        return Padding(
                          padding: EdgeInsets.only(top: i == 0 ? 10 : 24, bottom: 12),
                          child: Text(
                            DateFormat('yyyy년 M월').format(item),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _DiaryCard(diary: item as Diary),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        // [일기 쓰기] — 네이비 알약 56dp, 연필 아이콘.
        Positioned(
          right: AppSpacing.page,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'diary_write_fab',
            onPressed: _openForm,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('일기 쓰기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

/// "이번 달 ○일 기록했어요" + 날짜 점줄("일기 활성화" 지시서 J) — 기록한
/// 날만 채운 점으로 보여준다. 연속·끊김 표시는 없다(CLAUDE.md: "연속
/// ○일" 같은 압박형 장치 금지).
class _MonthlyDiaryTracker extends ConsumerWidget {
  const _MonthlyDiaryTracker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month, 1);
    final diaries = ref.watch(diariesForMonthProvider(month)).value ?? const <Diary>[];
    final recordedDays = diaryRecordedDays(diaries);
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 달 ${recordedDays.length}일 기록했어요',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var day = 1; day <= daysInMonth; day++)
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: recordedDays.contains(DateTime(now.year, now.month, day))
                        ? AppColors.diaryAccent
                        : AppColors.notebookLine,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 일기 한 편 — 그림일기 장처럼("장구름의 수첩", 3차 업데이트 J-5): 1.5px 잉크색
/// 테두리 카드(반지름 10), 위 칸에 손글씨 날짜 + 날씨 아이콘(고른 것만 버터색
/// 동그라미), 사진 칸(여러 장이면 "1 / 3"), 손글씨 글을 점선 줄 위에(최대 4줄),
/// 아래 활동 도장. 그림일기 PDF 렌더러와는 무관한 목록 화면 모양이다.
class _DiaryCard extends ConsumerWidget {
  final Diary diary;

  const _DiaryCard({required this.diary});

  static const _ink = AppColors.textPrimary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = diary.text.trim();
    final localPending = diary.pendingPhotoCount > 0
        ? ref.watch(diaryPendingPhotosProvider(diary.id)).value ?? const <DiaryPhotoQueueItem>[]
        : const <DiaryPhotoQueueItem>[];
    final displayPhotos = mergeDiaryPhotosForDisplay(
      uploaded: diary.photos,
      localPending: localPending,
      pendingPhotoCount: diary.pendingPhotoCount,
    );
    final thumb = displayPhotos.isEmpty ? null : displayPhotos.first;

    return Material(
      color: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _ink, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => DiaryDetailScreen(diaryId: diary.id))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('M월 d일 EEEE', 'ko_KR').format(diary.date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.hand(size: 26, color: _ink),
                    ),
                  ),
                  for (final weather in DiaryWeather.values)
                    _WeatherMark(weather: weather, selected: diary.weather == weather),
                ],
              ),
            ),
            const Divider(height: 1.5, thickness: 1.5, color: _ink),
            if (thumb != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    foregroundDecoration: BoxDecoration(
                      border: Border.all(color: _ink, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) => DiaryDisplayImage(
                              photo: thumb,
                              fit: BoxFit.cover,
                              // 보이는 크기(기기 배율)만큼만 디코딩한다.
                              memCacheWidth: (constraints.maxWidth * MediaQuery.of(context).devicePixelRatio).round(),
                            ),
                          ),
                          if (displayPhotos.length > 1)
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _ink.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(
                                  '1 / ${displayPhotos.length}',
                                  style: AppTextStyles.mono(size: 13, weight: FontWeight.w700, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (preview.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _LinedHandText(text: preview),
              ),
            if (diary.activities.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final a in diary.activities)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.diaryAccent, width: 1.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          a.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.diaryAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _WeatherMark extends StatelessWidget {
  final DiaryWeather weather;
  final bool selected;

  const _WeatherMark({required this.weather, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: selected ? '날씨 ${weather.label}' : null,
      excludeSemantics: !selected,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(left: 2),
        decoration: selected
            ? BoxDecoration(
                color: AppColors.warmBackground,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.diaryAccent),
              )
            : null,
        child: Icon(
          diaryWeatherIcon(weather),
          size: 18,
          color: selected ? AppColors.diaryAccent : AppColors.textPlaceholder,
        ),
      ),
    );
  }
}

/// 손글씨 글을 공책처럼 점선 줄 위에 — 최대 4줄 미리보기.
class _LinedHandText extends StatelessWidget {
  final String text;

  const _LinedHandText({required this.text});

  static const _maxLines = 4;
  static const _fontSize = 22.0;
  static const _lineHeight = 1.85;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.hand(size: _fontSize, color: AppColors.textPrimary, height: _lineHeight);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: _maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final lines = painter.computeLineMetrics().length.clamp(1, _maxLines);
        final lineHeight = painter.preferredLineHeight;
        painter.dispose();
        return CustomPaint(
          foregroundPainter: _DashedLinesPainter(lines: lines, lineHeight: lineHeight),
          child: Text(text, maxLines: _maxLines, overflow: TextOverflow.ellipsis, style: style),
        );
      },
    );
  }
}

class _DashedLinesPainter extends CustomPainter {
  final int lines;
  final double lineHeight;

  _DashedLinesPainter({required this.lines, required this.lineHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.notebookLine
      ..strokeWidth = 1.2;
    for (var i = 1; i <= lines; i++) {
      final y = lineHeight * i - 1;
      for (var x = 0.0; x < size.width; x += 7) {
        canvas.drawLine(Offset(x, y), Offset((x + 4).clamp(0, size.width), y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinesPainter oldDelegate) =>
      oldDelegate.lines != lines || oldDelegate.lineHeight != lineHeight;
}
