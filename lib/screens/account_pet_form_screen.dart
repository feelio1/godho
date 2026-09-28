import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/pet.dart';
import '../models/signup_pet.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../widgets/breed_picker_sheet.dart';
import '../widgets/date_picker_sheet.dart';
import '../widgets/form_field_label.dart';

/// [AccountPetFormScreen]이 pop으로 돌려주는 값 — 저장(추가/수정)인지
/// 삭제인지를 구분한다. 저장이면 [pet]에 폼 값이, 사진을 새로 골랐으면
/// [newPhotoFile]에 그 파일이, 기존 사진을 지우기로 했으면 [removePhoto]가
/// true로 담긴다. 실제 Firestore/Storage 쓰기는 호출부(가입 플로우는
/// 나중에 한 번에, 진료기록 화면은 즉시)가 맡는다 — 이 화면은 입력만
/// 책임진다(기존 가입 폼과 같은 책임 분리).
class AccountPetFormResult {
  final SignupPet? pet;
  final File? newPhotoFile;
  final bool removePhoto;

  const AccountPetFormResult.saved(this.pet, {this.newPhotoFile, this.removePhoto = false});

  const AccountPetFormResult.deleted()
      : pet = null,
        newPhotoFile = null,
        removePhoto = false;

  bool get isDelete => pet == null;
}

/// 계정(Firestore) 반려동물 1마리 입력/수정 폼 — 가입 플로우 2단계에서
/// 쓰던 폼을 공용 화면으로 뺐다(펫클 "계정 반려동물 추가/수정" 지시서 1).
/// [existing]이 없으면 새로 추가, 있으면 그 값으로 미리 채워 수정한다.
/// 종류/품종/체중/생년월은 필수, 이름/성별/중성화/사진은 선택.
///
/// [existing]이 있을 때만 앱바에 삭제 버튼이 뜨고, 확인 다이얼로그를 거쳐야
/// 실제로 삭제 신호([AccountPetFormResult.deleted])를 pop한다(지시서 2:
/// "삭제도 넣되 확인 팝업 필수").
class AccountPetFormScreen extends StatefulWidget {
  final SignupPet? existing;

  const AccountPetFormScreen({super.key, this.existing});

  @override
  State<AccountPetFormScreen> createState() => _AccountPetFormScreenState();
}

class _AccountPetFormScreenState extends State<AccountPetFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _breedController;
  late final TextEditingController _weightController;
  late PetSpecies _species;
  late PetSex _sex;
  late bool _neutered;
  DateTime? _birthMonth;
  File? _newPhotoFile;
  bool _removePhoto = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _breedController = TextEditingController(text: existing?.breed ?? '');
    _weightController = TextEditingController(text: existing != null ? _formatWeight(existing.weightKg) : '');
    _species = existing?.species ?? PetSpecies.dog;
    _sex = existing?.sex ?? PetSex.unknown;
    _neutered = existing?.neutered ?? false;
    _birthMonth = existing != null ? _parseBirthMonth(existing.birth) : null;
  }

  static String _formatWeight(double weightKg) =>
      weightKg == weightKg.roundToDouble() ? weightKg.toInt().toString() : weightKg.toString();

  static DateTime? _parseBirthMonth(String birth) {
    final parts = birth.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return null;
    return DateTime(year, month);
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
        setState(() {
          _newPhotoFile = File(picked.path);
          _removePhoto = false;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진을 불러오지 못했습니다.')),
        );
      }
    }
  }

  void _clearPhoto() {
    setState(() {
      _newPhotoFile = null;
      _removePhoto = true;
    });
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

  Future<void> _pickBirthMonth() async {
    final now = DateTime.now();
    final picked = await showAppDatePickerSheet(
      context,
      initialDate: _birthMonth ?? DateTime(now.year - 1, now.month),
      firstDate: DateTime(now.year - 40),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthMonth = picked);
  }

  Future<void> _confirmDelete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final petLabel = existing.name?.trim().isNotEmpty == true ? existing.name!.trim() : existing.species.label;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('반려동물 삭제'),
        content: Text('$petLabel의 정보와 사진을 삭제합니다. 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(const AccountPetFormResult.deleted());
    }
  }

  void _submit() {
    final breed = _breedController.text.trim();
    final weight = double.tryParse(_weightController.text.trim());
    if (breed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('품종을 선택해주세요.')));
      return;
    }
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('체중을 입력해주세요.')));
      return;
    }
    if (_birthMonth == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('생년월을 선택해주세요.')));
      return;
    }
    final name = _nameController.text.trim();
    Navigator.of(context).pop(
      AccountPetFormResult.saved(
        SignupPet(
          id: widget.existing?.id,
          species: _species,
          breed: breed,
          weightKg: weight,
          birth: DateFormat('yyyy-MM').format(_birthMonth!),
          name: name.isEmpty ? null : name,
          sex: _sex == PetSex.unknown ? null : _sex,
          neutered: _neutered,
          // 사진 최종 값(새로 올릴지/지울지/그대로 둘지)은 호출부가
          // newPhotoFile·removePhoto를 보고 정한다 — 여기서는 기존 값만
          // 그대로 들고 간다(잃어버리지 않게).
          photoUrl: widget.existing?.photoUrl,
        ),
        newPhotoFile: _newPhotoFile,
        removePhoto: _removePhoto,
      ),
    );
  }

  ImageProvider? get _avatarImage {
    if (_newPhotoFile != null) return FileImage(_newPhotoFile!);
    if (!_removePhoto && widget.existing?.photoUrl != null) {
      return NetworkImage(widget.existing!.photoUrl!);
    }
    return null;
  }

  bool get _hasPhoto => _avatarImage != null;

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '반려동물 정보 수정' : '반려동물 정보'),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: '삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
        ],
      ),
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
                      backgroundImage: _avatarImage,
                      child: !_hasPhoto ? const Icon(Icons.pets, size: 44, color: AppColors.primaryDark) : null,
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
              child: _hasPhoto
                  ? TextButton(onPressed: _clearPhoto, child: const Text('사진 삭제'))
                  : Text(
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
                  const FormFieldLabel('종류'),
                  _SegmentRow<PetSpecies>(
                    value: _species,
                    options: const [PetSpecies.dog, PetSpecies.cat],
                    labelOf: (s) => s.label,
                    onChanged: (s) => setState(() => _species = s),
                  ),
                  const SizedBox(height: AppSpacing.formField),
                  const FormFieldLabel('품종 *'),
                  _SelectField(
                    icon: Icons.pets_outlined,
                    label: _breedController.text.trim().isEmpty ? '품종 선택' : _breedController.text.trim(),
                    placeholder: _breedController.text.trim().isEmpty,
                    onTap: _pickBreed,
                  ),
                  const SizedBox(height: AppSpacing.formField),
                  const FormFieldLabel('체중 *'),
                  TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.0',
                      suffixText: 'kg',
                      suffixStyle: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.formField),
                  const FormFieldLabel('생년월 *'),
                  _SelectField(
                    icon: Icons.calendar_today_outlined,
                    label: _birthMonth != null ? DateFormat('yyyy년 M월').format(_birthMonth!) : '설정 안 함',
                    placeholder: _birthMonth == null,
                    onTap: _pickBirthMonth,
                  ),
                  const SizedBox(height: AppSpacing.formField),
                  const FormFieldLabel('이름 (선택)'),
                  TextField(controller: _nameController, decoration: const InputDecoration(hintText: '반려동물 이름')),
                  const SizedBox(height: AppSpacing.formField),
                  const FormFieldLabel('성별 (선택)'),
                  _SegmentRow<PetSex>(
                    value: _sex,
                    options: const [PetSex.unknown, PetSex.male, PetSex.female],
                    labelOf: (s) => s.label,
                    onChanged: (s) => setState(() => _sex = s),
                  ),
                  const SizedBox(height: AppSpacing.formField),
                  Row(
                    children: [
                      const Expanded(child: Text('중성화 수술')),
                      Switch(value: _neutered, onChanged: (v) => setState(() => _neutered = v)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _submit, child: Text(isEditing ? '저장' : '추가')),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _SelectField extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool placeholder;
  final VoidCallback onTap;

  const _SelectField({
    required this.icon,
    required this.label,
    required this.placeholder,
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
            const Icon(Icons.expand_more, size: 18, color: AppColors.textPlaceholder),
          ],
        ),
      ),
    );
  }
}
