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

    return Column(
      children: [
        TableCalendar<Object>(
          locale: 'ko_KR',
          // 과거 진료기록도 마커로 보여야 하니 범위를 넉넉히 잡는다.
          firstDay: DateTime(_focusedDay.year - 5),
          lastDay: DateTime(_focusedDay.year + 5),
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
          onPageChanged: (focused) => _focusedDay = focused,
          availableGestures: AvailableGestures.horizontalSwipe,
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            weekendStyle: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: false,
            todayDecoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            todayTextStyle: TextStyle(color: AppColors.primaryTextTone, fontWeight: FontWeight.w800),
            selectedDecoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            selectedTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          // 진료기록(회색 점)·예약(블루 점)·일기(크림/앰버 점)을 색으로
          // 구분한다 — 여러 종류가 있는 날은 점 여러 개(지시서 2 "과거/
          // 미래를 색으로 구분", "방향 개편" 지시서 E에서 일기 점 추가).
          calendarBuilders: CalendarBuilders<Object>(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;
              final hasRecord = events.any((e) => e is MedicalRecord);
              final hasAppointment = events.any((e) => e is Appointment);
              final hasDiary = events.any((e) => e is Diary);
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasRecord) const _MarkerDot(color: AppColors.neutral),
                    if (hasRecord && (hasAppointment || hasDiary)) const SizedBox(width: 3),
                    if (hasAppointment) const _MarkerDot(color: AppColors.primary),
                    if (hasAppointment && hasDiary) const SizedBox(width: 3),
                    if (hasDiary) const _MarkerDot(color: AppColors.diaryAccent),
                  ],
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 0),
          child: Row(
            children: const [
              _LegendDot(color: AppColors.neutral, label: '진료기록'),
              SizedBox(width: 16),
              _LegendDot(color: AppColors.primary, label: '예약'),
              SizedBox(width: 16),
              _LegendDot(color: AppColors.diaryAccent, label: '일기'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 0),
          child: Row(
            children: [
              Text(
                DateFormat('M월 d일 (E)', 'ko_KR').format(_selectedDay),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(width: 8),
              if (isSameDay(_selectedDay, dateOnly(DateTime.now())))
                const _CalendarTag(label: '오늘', color: AppColors.primary),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 6),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addForSelectedDay,
              icon: Icon(selectedIsFuture ? Icons.add : Icons.edit_note, size: 18),
              label: Text(selectedIsFuture ? '이 날짜로 예약 추가' : '이 날짜로 진료기록 추가'),
            ),
          ),
        ),
        Expanded(
          child: (selectedRecords.isEmpty && selectedAppointments.isEmpty && selectedDiaries.isEmpty)
              ? Center(
                  child: Text(
                    selectedIsFuture ? '이 날짜엔 예약이 없어요' : '이 날짜엔 기록이 없어요',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 24),
                  children: [
                    ...selectedRecords.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DayRecordTile(record: r, petId: widget.pet.id),
                      ),
                    ),
                    ...selectedAppointments.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DayAppointmentTile(appointment: a, petId: widget.pet.id),
                      ),
                    ),
                    ...selectedDiaries.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DayDiaryTile(diary: d),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MarkerDot extends StatelessWidget {
  final Color color;

  const _MarkerDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ],
    );
  }
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
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// 진료기록 화면의 기록 카드와 같은 정보를 보여준다 — 탭하면 같은 수정
/// 폼으로 연결된다(지시서 4 "하나의 데이터, 두 개의 뷰").
class _DayRecordTile extends StatelessWidget {
  final MedicalRecord record;
  final String petId;

  const _DayRecordTile({required this.record, required this.petId});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final chips = <String>[
      if (record.weightKg != null) '${record.weightKg}kg',
      if (record.costWon != null) '${NumberFormat('#,###').format(record.costWon)}원',
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MedicalRecordFormScreen(petId: petId, existing: record)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.description_outlined, size: 18, color: AppColors.neutral),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.hospitalName,
                            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (record.category.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Chip(label: Text(record.category)),
                        ],
                      ],
                    ),
                    if (record.memo.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(record.memo, maxLines: 2, overflow: TextOverflow.ellipsis, style: textTheme.bodyMedium),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: chips
                            .map((c) => Chip(
                                  label: Text(c, style: AppTextStyles.mono(size: 11, color: AppColors.textLabel)),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.zero,
                                ))
                            .toList(),
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

/// 진료기록 화면에서 쓰던 예약 카드와 같은 정보 — 탭하면 같은
/// [AppointmentFormScreen]으로 수정하러 간다(지시서 4).
class _DayAppointmentTile extends StatelessWidget {
  final Appointment appointment;
  final String petId;

  const _DayAppointmentTile({required this.appointment, required this.petId});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.primarySoft,
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AppointmentFormScreen(petId: petId, existing: appointment),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    DateFormat('HH:mm').format(appointment.dateTime),
                    style: AppTextStyles.mono(size: 12.5, color: AppColors.neutral),
                  ),
                  if (appointment.isUpcoming) ...[
                    const SizedBox(width: 8),
                    const _CalendarTag(label: '다가오는 예약', color: AppColors.primaryTextTone),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                appointment.hospitalName,
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
              if (appointment.reason.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(appointment.reason, style: textTheme.bodyMedium),
              ],
              if (appointment.memo.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  appointment.memo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 일기 목록 카드와 같은 정보 — 탭하면 일기 상세로 이어진다("방향 개편"
/// 지시서 E).
class _DayDiaryTile extends StatelessWidget {
  final Diary diary;

  const _DayDiaryTile({required this.diary});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final preview = diary.text.trim();
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.warmBackground,
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DiaryDetailScreen(diaryId: diary.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.edit_note, size: 18, color: AppColors.diaryAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('일기', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: textTheme.bodyMedium),
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
