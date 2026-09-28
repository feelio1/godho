import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/appointment.dart';
import '../providers/appointment_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../utils/appointment_calendar.dart';
import 'appointment_form_screen.dart';

/// 예약 알림을 달력(월 뷰)으로 보는 화면("예약 진료 캘린더" 지시서). 예약
/// 데이터·저장 방식·로컬 알림 로직은 전혀 손대지 않는다 — [appointmentsForPetProvider]로
/// 같은 로컬 저장소를 그대로 읽어 "보기"만 하나 더 얹는다. 새 하단탭을
/// 만들지 않고 진료기록 화면의 "예약 알림" 탭에서 진입한다.
class AppointmentCalendarScreen extends ConsumerStatefulWidget {
  final String petId;

  const AppointmentCalendarScreen({super.key, required this.petId});

  @override
  ConsumerState<AppointmentCalendarScreen> createState() => _AppointmentCalendarScreenState();
}

class _AppointmentCalendarScreenState extends ConsumerState<AppointmentCalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    _focusedDay = today;
    _selectedDay = today;
  }

  List<Appointment> _appointmentsOn(Map<DateTime, List<Appointment>> byDate, DateTime day) =>
      byDate[dateOnly(day)] ?? const [];

  @override
  Widget build(BuildContext context) {
    final appointments = ref.watch(appointmentsForPetProvider(widget.petId));
    final byDate = groupAppointmentsByDate(appointments);
    final selectedAppointments = _appointmentsOn(byDate, _selectedDay);

    return Scaffold(
      appBar: AppBar(title: const Text('예약 캘린더')),
      floatingActionButton: FloatingActionButton(
        tooltip: '예약 추가',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AppointmentFormScreen(petId: widget.petId)),
        ),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: [
            TableCalendar<Appointment>(
              locale: 'ko_KR',
              // 지난 예약도 마커로 보이려면 범위를 넉넉히 잡아야 한다 —
              // 2년 전부터 5년 뒤까지면 실사용 범위를 충분히 덮는다.
              firstDay: DateTime(_focusedDay.year - 2),
              lastDay: DateTime(_focusedDay.year + 5),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: (day) => _appointmentsOn(byDate, day),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = dateOnly(selected);
                  _focusedDay = focused;
                });
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
                markerDecoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                markerSize: 5,
                markersMaxCount: 3,
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, AppSpacing.page, 6),
              child: Row(
                children: [
                  Text(
                    DateFormat('M월 d일 (E)', 'ko_KR').format(_selectedDay),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(width: 8),
                  if (isSameDay(_selectedDay, dateOnly(DateTime.now())))
                    _CalendarTag(label: '오늘', color: AppColors.primary),
                ],
              ),
            ),
            Expanded(
              child: selectedAppointments.isEmpty
                  ? Center(
                      child: Text(
                        '이 날짜엔 예약이 없어요',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 24),
                      children: selectedAppointments
                          .map((a) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _CalendarAppointmentTile(appointment: a, petId: widget.petId),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
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

/// 진료기록 화면의 [_AppointmentTile]과 같은 정보(병원명·목적·시간·메모)를
/// 보여주는 카드 — 탭하면 같은 [AppointmentFormScreen]으로 수정하러 간다
/// (예약 알림 설정 폼을 새로 만들지 않고 그대로 재사용, 지시서 2).
class _CalendarAppointmentTile extends StatelessWidget {
  final Appointment appointment;
  final String petId;

  const _CalendarAppointmentTile({required this.appointment, required this.petId});

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
                    style: textTheme.bodySmall?.copyWith(color: AppColors.neutral),
                  ),
                  if (appointment.isUpcoming) ...[
                    const SizedBox(width: 8),
                    _CalendarTag(label: '다가오는 예약', color: AppColors.primaryTextTone),
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
