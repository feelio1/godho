import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/appointment.dart';
import '../models/medical_record.dart';
import '../models/pet.dart';
import '../providers/auth_provider.dart';
import '../providers/effective_appointments_provider.dart';
import '../providers/effective_medical_records_provider.dart';
import '../providers/effective_pets_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../utils/appointment_calendar.dart';
import '../utils/medical_record_calendar.dart';
import '../widgets/guest_gate.dart';
import '../widgets/no_pets_message.dart';
import '../widgets/pet_switcher.dart';
import 'account_pet_actions.dart';
import 'appointment_form_screen.dart';
import 'medical_record_form_screen.dart';

/// "캘린더" 탭 — 예약 "알림"이 아니라 우리 아이 진료 정보를 과거·미래
/// 통틀어 한눈에 보는 화면("캘린더 하단탭화 + 진료 연대기" 지시서 A). 진료
/// 기록·예약은 각자의 기존 로컬 저장소([medicalRecordsProvider]/
/// [appointmentsProvider])를 그대로 읽어 합칠 뿐, 이 화면 전용 데이터는
/// 없다 — 진료기록 화면에 기록하면 여기에도 바로 뜨고, 반대도 마찬가지다
/// (하나의 데이터, 두 개의 뷰).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  String? _selectedPetId;

  Future<void> _addAccountPet(String uid) async {
    final petId = await AccountPetActions.add(context, ref, uid);
    if (petId == null || !mounted) return;
    setState(() => _selectedPetId = 'account:$petId');
  }

  @override
  Widget build(BuildContext context) {
    // 로그인 상태면 계정(Firestore) 반려동물이, 게스트면 기존 로컬
    // 반려동물이 뜬다 — 진료기록 화면과 같은 소스(effectivePetsProvider)라
    // 두 화면에서 항상 같은 반려동물 목록을 본다.
    final uid = ref.watch(authStateProvider).value?.uid;

    // 캘린더는 로그인 필요 기능이다("로그인 게이팅" 지시서 1) — 게스트는
    // 탭 내용 대신 로그인하면 뭐가 좋은지 안내만 본다. 로그인하면
    // authStateProvider가 바뀌어 이 build()가 다시 실행되며 바로 실제
    // 내용으로 넘어간다 — 별도 "로그인 후 이어가기" 처리가 필요 없다.
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('캘린더')),
        body: const GuestFeatureNotice(
          title: '로그인하면 캘린더를 쓸 수 있어요',
          message: '로그인하면 우리 아이 진료기록·예약을 기기가 바뀌어도 이어서 볼 수 있어요.',
        ),
      );
    }

    final petsAsync = ref.watch(effectivePetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '반려동물 추가',
            onPressed: () => _addAccountPet(uid),
          ),
        ],
      ),
      body: petsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('불러오지 못했습니다: $error')),
        data: (pets) {
          if (pets.isEmpty) {
            return NoPetsMessage(
              isLoggedIn: true,
              onAddAccountPet: () => _addAccountPet(uid),
            );
          }
          final selected = pets.firstWhere(
            (p) => p.id == _selectedPetId,
            orElse: () => pets.first,
          );
          return Column(
            children: [
              if (pets.length > 1)
                PetSwitcher(
                  pets: pets,
                  selectedId: selected.id,
                  onSelect: (id) => setState(() => _selectedPetId = id),
                ),
              Expanded(child: _PetCalendarBody(key: ValueKey(selected.id), pet: selected)),
            ],
          );
        },
      ),
    );
  }
}

class _PetCalendarBody extends ConsumerStatefulWidget {
  final Pet pet;

  const _PetCalendarBody({super.key, required this.pet});

  @override
  ConsumerState<_PetCalendarBody> createState() => _PetCalendarBodyState();
}

class _PetCalendarBodyState extends ConsumerState<_PetCalendarBody> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    _focusedDay = today;
    _selectedDay = today;
  }

  /// 과거 날짜를 고르면 그 날짜로 진료기록을, 오늘·미래를 고르면 예약을
  /// 추가한다 — 기존 진료기록/예약 폼을 그대로 재사용한다("캘린더
  /// 하단탭화 + 진료 연대기" 지시서 3).
  void _addForSelectedDay() {
    if (isPastDay(_selectedDay)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MedicalRecordFormScreen(petId: widget.pet.id, initialDate: _selectedDay),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AppointmentFormScreen(petId: widget.pet.id, initialDate: _selectedDay),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 계정(로그인) 반려동물이면 Firestore, 게스트/로컬이면 기존 로컬
    // 저장소 — 진료기록 화면과 같은 provider라 어느 쪽에서 기록해도 서로
    // 자동 반영된다("진료기록·예약 Firestore 저장" 지시서 B-2).
    final records = ref.watch(effectiveRecordsForPetProvider(widget.pet.id)).value ?? const [];
    final appointments = ref.watch(effectiveAppointmentsForPetProvider(widget.pet.id)).value ?? const [];
    final recordsByDate = groupRecordsByDate(records);
    final appointmentsByDate = groupAppointmentsByDate(appointments);

    final selectedRecords = recordsByDate[_selectedDay] ?? const [];
    final selectedAppointments = appointmentsByDate[_selectedDay] ?? const [];
    final selectedIsPast = isPastDay(_selectedDay);

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
            return [...?recordsByDate[key], ...?appointmentsByDate[key]];
          },
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
          ),
          // 진료기록(회색 점)과 예약(블루 점)을 색으로 구분한다 — 둘 다
          // 있는 날은 점 두 개(지시서 2 "과거/미래를 색으로 구분").
          calendarBuilders: CalendarBuilders<Object>(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;
              final hasRecord = events.any((e) => e is MedicalRecord);
              final hasAppointment = events.any((e) => e is Appointment);
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasRecord) const _MarkerDot(color: AppColors.neutral),
                    if (hasRecord && hasAppointment) const SizedBox(width: 3),
                    if (hasAppointment) const _MarkerDot(color: AppColors.primary),
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
              icon: Icon(selectedIsPast ? Icons.edit_note : Icons.add, size: 18),
              label: Text(selectedIsPast ? '이 날짜로 진료기록 추가' : '이 날짜로 예약 추가'),
            ),
          ),
        ),
        Expanded(
          child: (selectedRecords.isEmpty && selectedAppointments.isEmpty)
              ? Center(
                  child: Text(
                    selectedIsPast ? '이 날짜엔 기록이 없어요' : '이 날짜엔 예약이 없어요',
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
