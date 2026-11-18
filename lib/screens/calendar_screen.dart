import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../diary/diary_calendar.dart';
import '../diary/models/diary.dart';
import '../diary/providers/diary_providers.dart';
import '../diary/screens/diary_detail_screen.dart';
import '../models/appointment.dart';
import '../models/medical_record.dart';
import '../models/pet.dart';
import '../models/reminder_offset.dart';
import '../providers/effective_appointments_provider.dart';
import '../providers/effective_medical_records_provider.dart';
import '../providers/pet_tab_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../utils/appointment_calendar.dart';
import '../utils/medical_record_calendar.dart';
import '../utils/record_appointment_flow.dart';
import 'appointment_form_screen.dart';
import 'medical_record_form_screen.dart';

/// 캘린더 보기의 반려동물별 본문 — 원래 독립 탭이던 `CalendarScreen`의
/// 내용이다("탭 개편" 지시서 B). 예약 "알림"이 아니라 우리 아이 진료
/// 정보를 과거·미래 통틀어 한눈에 보는 본문으로("캘린더 하단탭화 + 진료
/// 연대기" 지시서 A), 그 화면의 Scaffold/AppBar/게스트 게이팅/반려동물
/// 선택/포커스 요청 처리는 이제 `PetTabScreen`(우리 아이 탭)이 한 번만
/// 가지므로, 여기서는 선택된 반려동물 하나에 대한 본문만 그대로 맡는다
/// (내부 로직 변경 없음 — 비공개였던 이 위젯을 공개로 옮긴 것뿐). 진료
/// 기록·예약은 각자의 기존 저장소를 그대로 읽어 합칠 뿐, 이 화면 전용
/// 데이터는 없다 — 진료기록 보기에 기록하면 여기에도 바로 뜨고, 반대도
/// 마찬가지다(하나의 데이터, 두 개의 뷰).
class PetCalendarBody extends ConsumerStatefulWidget {
  final Pet pet;

  /// 홈의 "우리 아이" 카드에서 넘어온 포커스 날짜 — 있으면 오늘 대신 이
  /// 날짜로 시작한다("출시 전 마무리" 지시서 C).
  final DateTime? initialDate;

  const PetCalendarBody({super.key, required this.pet, this.initialDate});

  @override
  ConsumerState<PetCalendarBody> createState() => _PetCalendarBodyState();
}

class _PetCalendarBodyState extends ConsumerState<PetCalendarBody> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final start = widget.initialDate != null ? dateOnly(widget.initialDate!) : dateOnly(DateTime.now());
    _focusedDay = start;
    _selectedDay = start;
    _syncSelectedDayToTab(start);
  }

  /// 같은 반려동물이 선택된 채로(= [PetCalendarBody]가 새로 만들어지지
  /// 않은 채로) 새 포커스 날짜가 또 들어온 경우 — [initState]는 다시
  /// 불리지 않으므로 여기서 한 번 더 반영한다.
  @override
  void didUpdateWidget(PetCalendarBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != null && widget.initialDate != oldWidget.initialDate) {
      final target = dateOnly(widget.initialDate!);
      setState(() {
        _selectedDay = target;
        _focusedDay = target;
      });
      _syncSelectedDayToTab(target);
    }
  }

  /// AppBar의 "+" 버튼(캘린더 세그먼트)이 지금 선택된 날짜를 알 수 있게
  /// [petTabCalendarSelectedDayProvider]에 반영한다("일기를 기본 보기로"
  /// 지시서) — 이 화면 자체의 동작·모습은 그대로다. 빌드가 끝난 뒤
  /// 반영해야 다른 위젯의 빌드 중에 상태를 바꾸는 오류를 피한다.
  void _syncSelectedDayToTab(DateTime day) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(petTabCalendarSelectedDayProvider.notifier).state = day;
    });
  }

  /// 과거·오늘을 고르면 그 날짜로 진료기록을, 미래를 고르면 예약을
  /// 추가한다 — 모든 진입점이 공유하는 통합 입구를 그대로 쓴다("진료기록·
  /// 예약 통합 입력" 지시서 5). 어느 쪽으로 열렸든 폼 상단 세그먼트로
  /// 다시 바꿀 수 있다.
  /// 달력 위 화살표 — 달력이 다룰 수 있는 범위(앞뒤 5년) 안에서만 움직인다.
  void _moveMonth(int delta) {
    final target = DateTime(_focusedDay.year, _focusedDay.month + delta, 1);
    final now = DateTime.now();
    if (target.isBefore(DateTime(now.year - 5)) || target.isAfter(DateTime(now.year + 5, 12, 1))) return;
    setState(() => _focusedDay = target);
  }

  void _addForSelectedDay() {
    openRecordOrAppointmentEntry(context, petId: widget.pet.id, initialDate: _selectedDay);
  }

  @override
  Widget build(BuildContext context) {
    // 계정(로그인) 반려동물이면 Firestore, 게스트/로컬이면 기존 로컬
    // 저장소 — 진료기록 화면과 같은 provider라 어느 쪽에서 기록해도 서로
    // 자동 반영된다("진료기록·예약 Firestore 저장" 지시서 B-2).
    final records = ref.watch(effectiveRecordsForPetProvider(widget.pet.id)).value ?? const [];
    final appointments = ref.watch(effectiveAppointmentsForPetProvider(widget.pet.id)).value ?? const [];
    // 일기는 로그인 전용이라 게스트/로컬 반려동물은 항상 빈 목록이다
    // (diariesForPetProvider가 알아서 가린다, "방향 개편" 지시서 C) —
    // 기존 예약·기록 로직은 전혀 건드리지 않고 마커·목록만 더한다
    // (지시서 E).
    final diaries = ref.watch(diariesForPetProvider(widget.pet.id)).value ?? const [];
    final recordsByDate = groupRecordsByDate(records);
    final appointmentsByDate = groupAppointmentsByDate(appointments);
    final diariesByDate = groupDiariesByDate(diaries);

    final selectedRecords = recordsByDate[_selectedDay] ?? const [];
    final selectedAppointments = appointmentsByDate[_selectedDay] ?? const [];
    final selectedDiaries = diariesByDate[_selectedDay] ?? const [];
    // 과거·오늘은 진료기록, 미래만 예약 — 폼의 날짜 기반 자동 전환과 같은
    // 기준("진료기록·예약 통합 입력" 지시서 2, 5).
    final selectedIsFuture = isFutureDay(_selectedDay);

    final upcoming = appointments.where((a) => a.isUpcoming).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final isEmptyDay = selectedRecords.isEmpty && selectedAppointments.isEmpty && selectedDiaries.isEmpty;

    // "장구름의 수첩"(3차 업데이트 J-5): 흰 카드 안 달력(날짜 칸 52dp) — 표시는
    // 색+모양으로 구분(진료기록 = 네이비 작은 네모, 예약 = 네이비 테두리
    // 동그라미, 일기 = 꿀색 점), 오늘 = 네이비 테두리, 선택한 날 = 네이비 채움.
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, AppSpacing.page, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        DateFormat('yyyy년 M월').format(_focusedDay),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(
                      tooltip: '이전 달',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _moveMonth(-1),
                    ),
                    IconButton(
                      tooltip: '다음 달',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _moveMonth(1),
                    ),
                  ],
                ),
                TableCalendar<Object>(
                  locale: 'ko_KR',
                  headerVisible: false,
                  rowHeight: 56,
                  daysOfWeekHeight: 30,
                  // 과거 진료기록도 마커로 보여야 하니 범위를 넉넉히 잡는다.
                  firstDay: DateTime(DateTime.now().year - 5),
                  lastDay: DateTime(DateTime.now().year + 5, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: (day) {
                    final key = dateOnly(day);
                    return [...?recordsByDate[key], ...?appointmentsByDate[key], ...?diariesByDate[key]];
                  },
                  onDaySelected: (selected, focused) {
                    final day = dateOnly(selected);
                    setState(() {
                      _selectedDay = day;
                      _focusedDay = focused;
                    });
                    _syncSelectedDayToTab(day);
                  },
                  onPageChanged: (focused) => setState(() => _focusedDay = focused),
                  availableGestures: AvailableGestures.horizontalSwipe,
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    weekendStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  calendarStyle: const CalendarStyle(outsideDaysVisible: false, markersAutoAligned: false),
                  calendarBuilders: CalendarBuilders<Object>(
                    defaultBuilder: (context, day, _) => _DayCell(day: day),
                    todayBuilder: (context, day, _) => _DayCell(day: day, today: true),
                    selectedBuilder: (context, day, _) => _DayCell(day: day, selected: true),
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return null;
                      final selected = isSameDay(_selectedDay, day);
                      return Positioned(
                        bottom: 9,
                        child: _DayMarkers(
                          hasRecord: events.any((e) => e is MedicalRecord),
                          hasAppointment: events.any((e) => e is Appointment),
                          hasDiary: events.any((e) => e is Diary),
                          onNavy: selected,
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 20, color: AppColors.borderMuted),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RecordMark(),
                    SizedBox(width: 6),
                    _LegendLabel('진료기록'),
                    SizedBox(width: 16),
                    _AppointmentMark(),
                    SizedBox(width: 6),
                    _LegendLabel('예약'),
                    SizedBox(width: 16),
                    _DiaryMark(),
                    SizedBox(width: 6),
                    _LegendLabel('일기'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              DateFormat('M월 d일 (E)', 'ko_KR').format(_selectedDay),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 8),
            if (isSameDay(_selectedDay, dateOnly(DateTime.now())))
              const _CalendarTag(label: '오늘', color: AppColors.primary),
          ],
        ),
        const SizedBox(height: 12),
        if (isEmptyDay)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              selectedIsFuture ? '이 날짜엔 예약이 없어요' : '이 날짜엔 기록이 없어요',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final (i, tile) in [
                  for (final r in selectedRecords) _DayRecordTile(record: r, petId: widget.pet.id),
                  for (final a in selectedAppointments) _DayAppointmentTile(appointment: a, petId: widget.pet.id),
                  for (final d in selectedDiaries) _DayDiaryTile(diary: d),
                ].indexed) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: AppSpacing.cardLarge,
                      endIndent: AppSpacing.cardLarge,
                      color: AppColors.borderMuted,
                    ),
                  tile,
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _addForSelectedDay,
          icon: const Icon(Icons.add, size: 20),
          label: Text(selectedIsFuture ? '이 날짜로 예약 추가' : '이 날짜로 진료기록 추가'),
        ),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 28),
          const Text(
            '다가오는 예약',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          for (final a in upcoming.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _UpcomingAppointmentCard(appointment: a, petId: widget.pet.id),
            ),
        ],
      ],
    );
  }
}

/// 달력 날짜 칸 — 선택한 날 = 네이비 채움(흰 글자), 오늘 = 네이비 테두리.
class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool today;
  final bool selected;

  const _DayCell({required this.day, this.today = false, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2),
      alignment: const Alignment(0, -0.45),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : null,
        border: today && !selected ? Border.all(color: AppColors.primary, width: 1.5) : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '${day.day}',
        style: AppTextStyles.mono(
          size: 16,
          weight: selected || today ? FontWeight.w700 : FontWeight.w500,
          color: selected ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _DayMarkers extends StatelessWidget {
  final bool hasRecord;
  final bool hasAppointment;
  final bool hasDiary;
  final bool onNavy;

  const _DayMarkers({
    required this.hasRecord,
    required this.hasAppointment,
    required this.hasDiary,
    this.onNavy = false,
  });

  @override
  Widget build(BuildContext context) {
    final marks = <Widget>[
      if (hasRecord) _RecordMark(onNavy: onNavy),
      if (hasAppointment) _AppointmentMark(onNavy: onNavy),
      if (hasDiary) _DiaryMark(onNavy: onNavy),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < marks.length; i++) ...[if (i > 0) const SizedBox(width: 3), marks[i]],
      ],
    );
  }
}

/// 진료기록 — 네이비 작은 네모.
class _RecordMark extends StatelessWidget {
  final bool onNavy;

  const _RecordMark({this.onNavy = false});

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      color: onNavy ? Colors.white : AppColors.primary,
      borderRadius: BorderRadius.circular(1.5),
    ),
  );
}

/// 예약 — 네이비 테두리 동그라미.
class _AppointmentMark extends StatelessWidget {
  final bool onNavy;

  const _AppointmentMark({this.onNavy = false});

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: onNavy ? Colors.white : AppColors.primary, width: 1.5),
    ),
  );
}

/// 일기 — 꿀색 점(네이비 칸 위에서는 버터색).
class _DiaryMark extends StatelessWidget {
  final bool onNavy;

  const _DiaryMark({this.onNavy = false});

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(color: onNavy ? AppColors.butter : AppColors.diaryAccent, shape: BoxShape.circle),
  );
}

class _LegendLabel extends StatelessWidget {
  final String text;

  const _LegendLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary));
}

class _CalendarTag extends StatelessWidget {
  final String label;
  final Color color;

  const _CalendarTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// 선택한 날의 항목 한 줄 — 아이콘 상자 + 제목 + 보조 글 + 오른쪽 금액.
class _DayItemRow extends StatelessWidget {
  final IconData icon;
  final Color boxColor;
  final Color iconColor;
  final Widget title;
  final String subtitle;
  final String? trailing;
  final VoidCallback onTap;

  const _DayItemRow({
    required this.icon,
    required this.boxColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardLarge),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: boxColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Text(
                trailing!,
                style: AppTextStyles.mono(size: 16, weight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Text _rowTitle(String text) => Text(
  text,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
);

/// 진료기록 — 탭하면 같은 수정 폼으로 연결된다(지시서 4 "하나의 데이터, 두 개의 뷰").
class _DayRecordTile extends StatelessWidget {
  final MedicalRecord record;
  final String petId;

  const _DayRecordTile({required this.record, required this.petId});

  @override
  Widget build(BuildContext context) {
    final title = record.category.isNotEmpty ? record.category : (record.memo.isNotEmpty ? record.memo : '진료');
    final details = [record.hospitalName, if (record.weightKg != null) '${record.weightKg}kg'];
    return _DayItemRow(
      icon: Icons.medical_information_outlined,
      boxColor: AppColors.primarySoft,
      iconColor: AppColors.primary,
      title: _rowTitle(title),
      subtitle: details.join(' · '),
      trailing: record.costWon != null ? '${NumberFormat('#,###').format(record.costWon)}원' : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MedicalRecordFormScreen(petId: petId, existing: record),
        ),
      ),
    );
  }
}

/// 예약 — 탭하면 같은 [AppointmentFormScreen]으로 수정하러 간다(지시서 4).
class _DayAppointmentTile extends StatelessWidget {
  final Appointment appointment;
  final String petId;

  const _DayAppointmentTile({required this.appointment, required this.petId});

  @override
  Widget build(BuildContext context) {
    return _DayItemRow(
      icon: Icons.event_outlined,
      boxColor: AppColors.primarySoft,
      iconColor: AppColors.primary,
      title: _rowTitle(appointment.reason.isNotEmpty ? appointment.reason : '예약'),
      subtitle: '${DateFormat('a h:mm', 'ko_KR').format(appointment.dateTime)} · ${appointment.hospitalName}',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AppointmentFormScreen(petId: petId, existing: appointment),
        ),
      ),
    );
  }
}

/// 일기 — 손글씨 한 줄 미리보기, 탭하면 일기 상세로("방향 개편" 지시서 E).
class _DayDiaryTile extends StatelessWidget {
  final Diary diary;

  const _DayDiaryTile({required this.diary});

  @override
  Widget build(BuildContext context) {
    final preview = diary.text.trim();
    return _DayItemRow(
      icon: Icons.edit_outlined,
      boxColor: AppColors.warmBackground,
      iconColor: AppColors.diaryAccent,
      title: Text(
        preview.isNotEmpty ? preview : '일기',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.hand(size: 22, color: AppColors.textPrimary),
      ),
      subtitle: '일기',
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DiaryDetailScreen(diaryId: diary.id))),
    );
  }
}

/// "다가오는 예약" — 1.5px 네이비 테두리 카드, 왼쪽 날짜 상자, 알림 시각 한 줄.
class _UpcomingAppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final String petId;

  const _UpcomingAppointmentCard({required this.appointment, required this.petId});

  static String _reminderLabel(ReminderOffset r) {
    final day = switch (r.daysBefore) {
      0 => '당일',
      1 => '하루 전',
      final n => '$n일 전',
    };
    final time = DateFormat(
      'a h시${r.minute == 0 ? '' : ' m분'}',
      'ko_KR',
    ).format(DateTime(2000, 1, 1, r.hour, r.minute));
    return '$day $time에 알려드려요';
  }

  @override
  Widget build(BuildContext context) {
    final dt = appointment.dateTime;
    return Material(
      color: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AppointmentFormScreen(petId: petId, existing: appointment),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardLarge),
          child: Row(
            children: [
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    Text(
                      '${dt.month}월',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                    Text(
                      '${dt.day}',
                      style: AppTextStyles.mono(size: 22, weight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _rowTitle(appointment.reason.isNotEmpty ? appointment.reason : '예약'),
                    const SizedBox(height: 3),
                    Text(
                      '${DateFormat('EEEE a h:mm', 'ko_KR').format(dt)} · ${appointment.hospitalName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    if (appointment.reminders.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.notifications_none, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _reminderLabel(appointment.reminders.first),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
