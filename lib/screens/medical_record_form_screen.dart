import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/medical_record.dart';
import '../providers/medical_record_provider.dart';
import '../widgets/hospital_picker_field.dart';
import '../widgets/photo_attach_field.dart';

String _newLocalId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 31)}';

/// 진료/방문 기록 추가·수정 폼(스프린트 8 지시서 2, 스프린트 9에서 필드
/// 라벨·사진 첨부 UI 개선). 병원은 우리 DB에서 검색해 고르거나 직접 입력할
/// 수 있다. 몸무게·진료비는 기록으로만 남기고 판정·평가 문구는 어디에도
/// 붙이지 않는다(건강·안전 원칙).
class MedicalRecordFormScreen extends ConsumerStatefulWidget {
  final String petId;
  final MedicalRecord? existing;

  const MedicalRecordFormScreen({super.key, required this.petId, this.existing});

  @override
  ConsumerState<MedicalRecordFormScreen> createState() => _MedicalRecordFormScreenState();
}

class _MedicalRecordFormScreenState extends ConsumerState<MedicalRecordFormScreen> {
  late DateTime _date;
  late final TextEditingController _hospitalController;
  late final TextEditingController _memoController;
  late final TextEditingController _weightController;
  late final TextEditingController _costController;
  String? _selectedHospitalId;
  String? _photoPath;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _date = existing?.date ?? DateTime.now();
    _hospitalController = TextEditingController(text: existing?.hospitalName ?? '');
    _memoController = TextEditingController(text: existing?.memo ?? '');
    _weightController = TextEditingController(text: existing?.weightKg?.toString() ?? '');
    _costController = TextEditingController(text: existing?.costWon?.toString() ?? '');
    _selectedHospitalId = existing?.hospitalId;
    _photoPath = existing?.photoPath;
  }

  @override
  void dispose() {
    _hospitalController.dispose();
    _memoController.dispose();
    _weightController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        setState(() => _photoPath = picked.path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진을 불러오지 못했습니다.')),
        );
      }
    }
  }

  void _save() {
    final hospitalName = _hospitalController.text.trim();
    if (hospitalName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('병원 이름을 입력하거나 검색해서 선택해주세요.')),
      );
      return;
    }
    final weight = double.tryParse(_weightController.text.trim());
    final cost = int.tryParse(_costController.text.trim().replaceAll(',', ''));

    final record = MedicalRecord(
      id: widget.existing?.id ?? _newLocalId(),
      petId: widget.petId,
      date: _date,
      hospitalId: _selectedHospitalId,
      hospitalName: hospitalName,
      memo: _memoController.text.trim(),
      weightKg: weight,
      costWon: cost,
      photoPath: _photoPath,
    );
    ref.read(medicalRecordsProvider.notifier).upsert(record);
    Navigator.of(context).pop();
  }

  void _delete() {
    final existing = widget.existing;
    if (existing == null) return;
    ref.read(medicalRecordsProvider.notifier).remove(existing.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '진료 기록 추가' : '진료 기록 수정'),
        actions: [
          if (widget.existing != null)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('날짜'),
              subtitle: Text(DateFormat('yyyy.MM.dd').format(_date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
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
              controller: _memoController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '진료 내용 메모 (선택)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '몸무게 (kg, 선택)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _costController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '진료비 (원, 선택)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PhotoAttachField(
              photoPath: _photoPath,
              onPick: _pickPhoto,
              onClear: () => setState(() => _photoPath = null),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}
