import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/pet.dart';
import '../providers/pet_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../widgets/breed_picker_sheet.dart';
import '../widgets/date_picker_sheet.dart';
import '../widgets/form_field_label.dart';

String _newLocalId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 31)}';

/// 반려동물 프로필 등록/수정 폼(스프린트 14, Petcli 시안 05_반려동물등록
/// 실제 이미지 그대로 구성). [existing]이 없으면 새로 등록.
class PetProfileFormScreen extends ConsumerStatefulWidget {
  final Pet? existing;

  const PetProfileFormScreen({super.key, this.existing});

  @override
  ConsumerState<PetProfileFormScreen> createState() => _PetProfileFormScreenState();
}

class _PetProfileFormScreenState extends ConsumerState<PetProfileFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _breedController;
  late final TextEditingController _weightController;
  late PetSpecies _species;
  late PetSex _sex;
  late bool _neutered;
  DateTime? _birthday;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _breedController = TextEditingController(text: existing?.breed ?? '');
    _weightController = TextEditingController(text: existing?.weightKg?.toString() ?? '');
    _species = existing?.species ?? PetSpecies.dog;
    _sex = existing != null && existing.sex != PetSex.unknown ? existing.sex : PetSex.male;
    _neutered = existing?.neutered ?? false;
    _birthday = existing?.birthday;
    _photoPath = existing?.photoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
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
    final picked = await showAppDatePickerSheet(
      context,
      initialDate: _birthday ?? DateTime(now.year - 1, now.month, now.day),
      firstDate: DateTime(now.year - 40),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _pickBreed() async {
    final options = _species == PetSpecies.cat ? commonCatBreeds : commonDogBreeds;
    final picked = await showBreedPickerSheet(
      context,
      options: options,
      current: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
    );
    if (picked != null) setState(() => _breedController.text = picked);
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
    return '만 $years살';
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
      sex: _sex,
      neutered: _neutered,
      weightKg: double.tryParse(_weightController.text.trim()),
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
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: AppColors.primarySoft,
                      backgroundImage: _photoPath != null ? FileImage(File(_photoPath!)) : null,
                      child: _photoPath == null
                          ? const Icon(Icons.pets, size: 44, color: AppColors.primaryDark)
                          : null,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '사진 추가',
                style: TextStyle(color: AppColors.textPlaceholder, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardLarge),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderCard),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FormFieldLabel('이름'),
                  TextField(controller: _nameController, decoration: const InputDecoration(hintText: '반려동물 이름')),
                  const SizedBox(height: AppSpacing.formField),
                  const FormFieldLabel('종류'),
                  _SegmentRow<PetSpecies>(
                    value: _species,
                    options: PetSpecies.values,
                    labelOf: (s) => s.label,
                    onChanged: (s) => setState(() => _species = s),
                  ),
                  const SizedBox(height: AppSpacing.formField),
                  const FormFieldLabel('품종'),
                  _SelectField(
                    icon: Icons.pets_outlined,
                    label: _breedController.text.trim().isEmpty ? '품종 선택' : _breedController.text.trim(),
                    placeholder: _breedController.text.trim().isEmpty,
                    onTap: _pickBreed,
                  ),
                  const SizedBox(height: AppSpacing.formField),
                  const FormFieldLabel('성별'),
                  _SegmentRow<PetSex>(
                    value: _sex,
                    options: const [PetSex.male, PetSex.female],
                    labelOf: (s) => s.label,
                    onChanged: (s) => setState(() => _sex = s),
                  ),
                  const SizedBox(height: AppSpacing.formField),
                  Row(
                    children: [
                      Expanded(
                        child: Text('중성화 수술', style: Theme.of(context).textTheme.bodyLarge),
                      ),
                      Switch(value: _neutered, onChanged: (v) => setState(() => _neutered = v)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.formField),
                  const FormFieldLabel('생년월일'),
                  _SelectField(
                    icon: Icons.calendar_today_outlined,
                    label: _birthday != null ? _formatDate(_birthday!) : '설정 안 함',
                    placeholder: _birthday == null,
                    trailingText: _birthday != null ? _ageLabel(_birthday!) : null,
                    onTap: _pickBirthday,
                  ),
                  const SizedBox(height: AppSpacing.formField),
                  const FormFieldLabel('몸무게'),
                  TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.0',
                      suffixText: 'kg',
                      suffixStyle: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('등록 완료')),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

/// 흰 바탕 위 "종류/성별"에 쓰는 2~3단 세그먼트(활성=흰 pill+액센트 텍스트).
class _SegmentRow<T> extends StatelessWidget {
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const _SegmentRow({
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        children: options.map((option) {
          final selected = option == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.surfaceLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.field - 2),
                  boxShadow: selected ? AppShadows.segment : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labelOf(option),
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppColors.primaryTextTone : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 탭하면 바텀시트가 열리는 선택형 필드(품종/생년월일 등).
class _SelectField extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool placeholder;
  final String? trailingText;
  final VoidCallback onTap;

  const _SelectField({
    required this.icon,
    required this.label,
    required this.placeholder,
    this.trailingText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: placeholder ? AppColors.textPlaceholder : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText!,
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.expand_more, size: 18, color: AppColors.textPlaceholder),
          ],
        ),
      ),
    );
  }
}
