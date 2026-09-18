import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/pet.dart';
import '../providers/pet_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../widgets/form_field_label.dart';

String _newLocalId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 31)}';

/// 반려동물 프로필 등록/수정 폼. [existing]이 없으면 새로 등록.
class PetProfileFormScreen extends ConsumerStatefulWidget {
  final Pet? existing;

  const PetProfileFormScreen({super.key, this.existing});

  @override
  ConsumerState<PetProfileFormScreen> createState() => _PetProfileFormScreenState();
}

class _PetProfileFormScreenState extends ConsumerState<PetProfileFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _breedController;
  late PetSpecies _species;
  DateTime? _birthday;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _breedController = TextEditingController(text: existing?.breed ?? '');
    _species = existing?.species ?? PetSpecies.dog;
    _birthday = existing?.birthday;
    _photoPath = existing?.photoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
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

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 1, now.month, now.day),
      firstDate: DateTime(now.year - 40),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  /// 생일로부터 화면에만 보여주는 나이 계산 — 별도 저장 필드 없이 그때그때
  /// 계산한다(스프린트 14 시안: "생년월일(→자동 나이)").
  static String _ageLabel(DateTime birthday) {
    final now = DateTime.now();
    var years = now.year - birthday.year;
    var months = now.month - birthday.month;
    if (now.day < birthday.day) months -= 1;
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    if (years <= 0) return '생후 $months개월';
    if (months == 0) return '$years살';
    return '$years살 $months개월';
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요.')),
      );
      return;
    }
    final pet = Pet(
      id: widget.existing?.id ?? _newLocalId(),
      name: name,
      species: _species,
      breed: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
      birthday: _birthday,
      photoPath: _photoPath,
    );
    ref.read(petsProvider.notifier).upsert(pet);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? '반려동물 등록' : '반려동물 정보 수정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primarySoft,
                  backgroundImage: _photoPath != null ? FileImage(File(_photoPath!)) : null,
                  child: _photoPath == null
                      ? const Icon(Icons.pets, size: 36, color: AppColors.primaryDark)
                      : null,
                ),
              ),
            ),
            Center(
              child: TextButton(onPressed: _pickPhoto, child: const Text('사진 선택')),
            ),
            const SizedBox(height: AppSpacing.formField),
            const FormFieldLabel('이름'),
            TextField(controller: _nameController, decoration: const InputDecoration(hintText: '반려동물 이름')),
            const SizedBox(height: AppSpacing.formField),
            const FormFieldLabel('종'),
            SegmentedButton<PetSpecies>(
              segments: PetSpecies.values
                  .map((s) => ButtonSegment(value: s, label: Text(s.label)))
                  .toList(),
              selected: {_species},
              onSelectionChanged: (selection) => setState(() => _species = selection.first),
            ),
            const SizedBox(height: AppSpacing.formField),
            const FormFieldLabel('품종 (선택)'),
            TextField(
              controller: _breedController,
              decoration: const InputDecoration(hintText: '예: 말티즈, 코리안숏헤어'),
            ),
            const SizedBox(height: AppSpacing.formField),
            const FormFieldLabel('생일 (선택)'),
            InkWell(
              onTap: _pickBirthday,
              borderRadius: BorderRadius.circular(AppRadius.field),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textPlaceholder),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _birthday != null
                            ? '${DateFormat('yyyy.MM.dd').format(_birthday!)}  ·  ${_ageLabel(_birthday!)}'
                            : '설정 안 함',
                        style: TextStyle(
                          color: _birthday != null ? AppColors.textPrimary : AppColors.textPlaceholder,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_birthday != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _birthday = null),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('저장')),
            ),
          ],
        ),
      ),
    );
  }
}
