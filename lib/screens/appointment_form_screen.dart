import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/appointment.dart';
import '../models/reminder_offset.dart';
import '../notifications/notification_service.dart';
import '../providers/appointment_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../widgets/date_picker_sheet.dart';
import '../widgets/form_field_label.dart';
import '../widgets/hospital_picker_field.dart';
import '../widgets/picker_sheet_chrome.dart';
import '../widgets/time_picker_sheet.dart';

String _newLocalId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 31)}';

/// 방문 목적 칩에 쓰는 자주 쓰는 문구 — [Appointment.reason]은 여전히
/// 자유 입력 문자열이라(모델 변경 없음), 칩은 그 필드를 빠르게 채워주는
/// 단축 입력일 뿐이다.
const _visitPurposeChoices = ['예방접종', '정기검진', '재진', '미용', '기타'];

const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// 미리 알림 프리셋(스프린트 14 시안 17_리마인더 피커: 정시/1·3시간 전은
/// 예약 시각 기준 상대 시간, 나머지는 고정 오전 9시). 예약당 알림은 이제
/// 이 목록에서 하나만 고른다 — [ReminderOffset]/알림 스케줄링 로직 자체는
/// 그대로이고(여전히 daysBefore+hour+minute), 여기서 값을 계산만 한다.
class _ReminderPreset {
  final String label;
  final ReminderOffset Function(DateTime date, TimeOfDay time) resolve;
  const _ReminderPreset(this.label, this.resolve);
}

ReminderOffset _relativeOffset(DateTime date, TimeOfDay time, Duration before) {
  final appointmentDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  final target = appointmentDateTime.subtract(before);
  final appointmentDay = DateTime(date.year, date.month, date.day);
  final targetDay = DateTime(target.year, target.month, target.day);
  return ReminderOffset(
    daysBefore: appointmentDay.difference(targetDay).inDays,
    hour: target.hour,
    minute: target.minute,
  );
}

final List<_ReminderPreset> _reminderPresets = [
  _ReminderPreset('정시에 알림', (date, time) => _relativeOffset(date, time, Duration.zero)),
  _ReminderPreset('1시간 전', (date, time) => _relativeOffset(date, time, const Duration(hours: 1))),
  _ReminderPreset('3시간 전', (date, time) => _relativeOffset(date, time, const Duration(hours: 3))),
  _ReminderPreset('하루 전 · 오전 9:00', (date, time) => const ReminderOffset(daysBefore: 1, hour: 9, minute: 0)),
  _ReminderPreset('이틀 전 · 오전 9:00', (date, time) => const ReminderOffset(daysBefore: 2, hour: 9, minute: 0)),
  _ReminderPreset('일주일 전 · 오전 9:00', (date, time) => const ReminderOffset(daysBefore: 7, hour: 9, minute: 0)),
];

/// 진료 예약 추가·수정 폼(스프린트 9 지시서 3, 스프린트 14 Petcli 시안
/// 06_예약알림 실제 이미지 반영). 병원은 우리 DB에서 검색해 고르거나
/// 직접 입력할 수 있다(진료기록 폼과 같은 위젯 재사용).
class AppointmentFormScreen extends ConsumerStatefulWidget {
  final String petId;
  final Appointment? existing;

  const AppointmentFormScreen({super.key, required this.petId, this.existing});

  @override
  ConsumerState<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends ConsumerState<AppointmentFormScreen> {
  late DateTime _date;
  late TimeOfDay _time;
  late final TextEditingController _hospitalController;
  late final TextEditingController _reasonController;
  late final TextEditingController _memoController;
  String? _selectedHospitalId;
  bool _showSuggestions = false;

  /// 시안엔 예약당 미리 알림이 하나뿐이라(리마인더 피커가 단일 선택
  /// 목록), 기존에 여러 개 저장된 예약이 있다면 첫 번째만 반영한다.
  ReminderOffset? _reminder;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final initialDateTime = existing?.dateTime ?? DateTime.now().add(const Duration(days: 1));
    _date = DateTime(initialDateTime.year, initialDateTime.month, initialDateTime.day);
    _time = TimeOfDay(hour: initialDateTime.hour, minute: initialDateTime.minute);
    _hospitalController = TextEditingController(text: existing?.hospitalName ?? '');
    _reasonController = TextEditingController(text: existing?.reason ?? '');
    _memoController = TextEditingController(text: existing?.memo ?? '');
    _selectedHospitalId = existing?.hospitalId;
    _reminder = existing != null && existing.reminders.isNotEmpty ? existing.reminders.first : null;
  }

  @override
  void dispose() {
    _hospitalController.dispose();
    _reasonController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePickerSheet(
      context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(_date.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showAppTimePickerSheet(context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickReminder() async {
    final result = await showModalBottomSheet<_ReminderPreset?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PickerSheetChrome(
        title: '미리 알림',
        heightFactor: 0.55,
        child: ListView(
          children: [
            for (final preset in _reminderPresets)
              Builder(builder: (context) {
                final resolved = preset.resolve(_date, _time);
                final selected = _reminder == resolved;
                return ListTile(
                  title: Text(
                    preset.label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? AppColors.primaryTextTone : AppColors.textPrimary,
                    ),
                  ),
                  trailing: selected ? const Icon(Icons.check, color: AppColors.primary) : null,
                  onTap: () => Navigator.of(context).pop(preset),
                );
              }),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() => _reminder = result.resolve(_date, _time));
    }
  }

  /// 미리 알림 필드에 보여줄 문구 — 지금 값이 프리셋 중 하나와 정확히
  /// 같으면 그 프리셋의 자연어 라벨("하루 전 · 오전 9:00")을, 아니면
  /// (기존에 저장된, 프리셋에 없는 값이면) ReminderOffset.label 그대로.
  String _reminderDisplayLabel() {
    final reminder = _reminder;
    if (reminder == null) return '설정 안 함';
    for (final preset in _reminderPresets) {
      if (preset.resolve(_date, _time) == reminder) return preset.label;
    }
    return reminder.label;
  }

  Future<void> _save() async {
    final hospitalName = _hospitalController.text.trim();
    if (hospitalName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('병원 이름을 입력하거나 검색해서 선택해주세요.')),
      );
      return;
    }
    final dateTime = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

    // 알림 권한은 예약 알림을 처음 설정하는 이 시점에만 요청한다(앱 시작
    // 시 강제 요청 금지 — CLAUDE.md 취지의 연장, 스프린트 9 지시서 3).
    final reminder = _reminder;
    if (reminder != null) {
      await NotificationService.instance.requestPermission();
    }

    final appointment = Appointment(
      id: widget.existing?.id ?? _newLocalId(),
      petId: widget.petId,
      dateTime: dateTime,
      hospitalId: _selectedHospitalId,
      hospitalName: hospitalName,
      reason: _reasonController.text.trim(),
      memo: _memoController.text.trim(),
      reminders: reminder != null ? [reminder] : const [],
    );
    await ref.read(appointmentsProvider.notifier).upsert(appointment);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    await ref.read(appointmentsProvider.notifier).remove(existing.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('예약 알림'),
        actions: [
          if (widget.existing != null)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const FormFieldLabel('병원'),
            HospitalPickerField(
              controller: _hospitalController,
              selectedHospitalId: _selectedHospitalId,
              showSuggestions: _showSuggestions,
              onTextChanged: (_) => setState(() {
                _selectedHospitalId = null;
                _showSuggestions = true;
              }),
              onHospitalSelected: (h) => setState(() {
                _selectedHospitalId = h.id;
                _hospitalController.text = h.name;
                _showSuggestions = false;
              }),
              onSelectionCleared: () => setState(() => _selectedHospitalId = null),
              onFieldTapped: () => setState(() => _showSuggestions = true),
            ),
            const SizedBox(height: AppSpacing.formField),
            const FormFieldLabel('방문 목적'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _visitPurposeChoices
                  .map((choice) => ChoiceChip(
                        label: Text(choice),
                        selected: _reasonController.text == choice,
                        onSelected: (_) => setState(() => _reasonController.text = choice),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.formField),
            Row(
              children: [
                Expanded(
                  child: _DateTimeField(
                    label: '날짜',
                    value: '${DateFormat('M.d').format(_date)} (${_weekdayLabels[_date.weekday - 1]})',
                    icon: Icons.calendar_today_outlined,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateTimeField(
                    label: '시간',
                    value: _time.format(context),
                    icon: Icons.access_time_outlined,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.formField),
            const FormFieldLabel('미리 알림'),
            _DateTimeField(
              label: '',
              hideLabel: true,
              value: _reminderDisplayLabel(),
              icon: Icons.notifications_outlined,
              onTap: _pickReminder,
            ),
            const SizedBox(height: AppSpacing.formField),
            const FormFieldLabel('메모 (선택)'),
            TextField(
              controller: _memoController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: '공복 필요 · 이전 접종기록 지참'),
            ),
            const SizedBox(height: AppSpacing.section),
            if (_reminder != null)
              _ReminderPreviewBanner(reminder: _reminder!, appointmentDate: _date, appointmentTime: _time),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('알림 저장')),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool hideLabel;

  const _DateTimeField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.hideLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideLabel) FormFieldLabel(label),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.field),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.textPlaceholder),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.expand_more, size: 18, color: AppColors.textPlaceholder),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "9월 23일(화) 오전 9:00에 미리 알려드려요" 한 줄 미리보기(스프린트 14
/// 시안). [ReminderOffset.fireTimeFor]로 실제 알림 시각을 그대로 계산해
/// 보여줄 뿐 별도 데이터는 갖지 않는다.
class _ReminderPreviewBanner extends StatelessWidget {
  final ReminderOffset reminder;
  final DateTime appointmentDate;
  final TimeOfDay appointmentTime;

  const _ReminderPreviewBanner({
    required this.reminder,
    required this.appointmentDate,
    required this.appointmentTime,
  });

  @override
  Widget build(BuildContext context) {
    final appointmentDateTime = DateTime(
      appointmentDate.year,
      appointmentDate.month,
      appointmentDate.day,
      appointmentTime.hour,
      appointmentTime.minute,
    );
    final fireTime = reminder.fireTimeFor(appointmentDateTime);
    final timeOfDay = TimeOfDay(hour: fireTime.hour, minute: fireTime.minute);
    final dateLabel = '${DateFormat('M월 d일').format(fireTime)}(${_weekdayLabels[fireTime.weekday - 1]})';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$dateLabel ${timeOfDay.format(context)}에 미리 알려드려요',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryTextTone),
            ),
          ),
        ],
      ),
    );
  }
}
