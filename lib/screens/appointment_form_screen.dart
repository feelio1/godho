import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/appointment.dart';
import '../models/reminder_offset.dart';
import '../notifications/notification_service.dart';
import '../providers/appointment_provider.dart';
import '../widgets/hospital_picker_field.dart';

String _newLocalId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 31)}';

const _reminderDayChoices = [0, 1, 2, 3, 7];

/// 진료 예약 추가·수정 폼(스프린트 9 지시서 3). 병원은 우리 DB에서 검색해
/// 고르거나 직접 입력할 수 있고(진료기록 폼과 같은 위젯 재사용), 알림은
/// "며칠 전 + 몇 시"를 사용자가 직접 여러 개 지정할 수 있다.
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
  late List<ReminderOffset> _reminders;

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
    _reminders = List.of(existing?.reminders ?? const []);
  }

  @override
  void dispose() {
    _hospitalController.dispose();
    _reasonController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(_date.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _addReminder() async {
    var daysBefore = 1;
    var time = const TimeOfDay(hour: 20, minute: 0);

    final result = await showDialog<ReminderOffset>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('알림 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('며칠 전에 알려드릴까요?'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _reminderDayChoices
                    .map((d) => ChoiceChip(
                          label: Text(d == 0 ? '당일' : '$d일 전'),
                          selected: daysBefore == d,
                          onSelected: (_) => setDialogState(() => daysBefore = d),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('몇 시에 알려드릴까요?'),
                subtitle: Text(time.format(dialogContext)),
                trailing: const Icon(Icons.access_time_outlined),
                onTap: () async {
                  final pickedTime = await showTimePicker(context: dialogContext, initialTime: time);
                  if (pickedTime != null) setDialogState(() => time = pickedTime);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                ReminderOffset(daysBefore: daysBefore, hour: time.hour, minute: time.minute),
              ),
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted && !_reminders.contains(result)) {
      setState(() => _reminders.add(result));
    }
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
    if (_reminders.isNotEmpty) {
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
      reminders: _reminders,
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
        title: Text(widget.existing == null ? '예약 추가' : '예약 수정'),
        actions: [
          if (widget.existing != null)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('예약 날짜'),
                    subtitle: Text(DateFormat('yyyy.MM.dd').format(_date)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: _pickDate,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('시간'),
                    subtitle: Text(_time.format(context)),
                    trailing: const Icon(Icons.access_time_outlined),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: '진료 내용 (선택, 예: 발치, 중성화)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _memoController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('알림', style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addReminder,
                  icon: const Icon(Icons.add_alert_outlined, size: 18),
                  label: const Text('알림 추가'),
                ),
              ],
            ),
            if (_reminders.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '알림을 추가하지 않으면 이 예약은 알림 없이 기록만 됩니다.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _reminders
                    .map((r) => Chip(
                          label: Text(r.label),
                          onDeleted: () => setState(() => _reminders.remove(r)),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}
