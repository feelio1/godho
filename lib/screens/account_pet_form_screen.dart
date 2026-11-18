import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../ads/app_open_ad_suppression.dart';
import '../models/pet.dart';
import '../models/pet_weight_band.dart';
import '../models/signup_pet.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../widgets/breed_picker_sheet.dart';
import '../widgets/date_picker_sheet.dart';
import '../widgets/form_field_label.dart';
import '../widgets/unsaved_changes_guard.dart';

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

/// 계정(Firestore) 반려동물 1마리 입력/수정 폼 — 가입 플로우·추가·수정이
/// 함께 쓴다(펫클 "계정 반려동물 추가/수정" 지시서 1). [existing]이 없으면
/// 새로 추가, 있으면 그 값으로 미리 채워 수정한다.
///
/// 2차 업데이트(D): 순서는 이름 → 종류 → 품종 → 생년월 → 체중. 필수는
/// 이름·종류뿐이다. 품종은 고르지 않으면 [kUnknownBreed]("모름/믹스")로,
/// 생년월은 "모름"(빈 값)으로 저장한다. 체중은 숫자 대신 구간 4개 중
/// 하나([PetWeightBand], 선택)를 고르고, 가짜 kg 값을 만들지 않는다 — 옛
/// 데이터의 kg 값은 지우지 않고 그대로 들고 간다. 오류는 저장 뒤 스낵바가
/// 아니라 해당 칸 아래에 보인다. 바뀐 내용이 있으면 뒤로가기 때 묻는다.
///
/// [existing]이 있을 때만 삭제 버튼이 뜨고, 확인 다이얼로그를 거쳐야
/// 실제로 삭제 신호([AccountPetFormResult.deleted])를 pop한다.
class AccountPetFormScreen extends StatefulWidget {
  final SignupPet? existing;

  const AccountPetFormScreen({super.key, this.existing});

  @override
  State<AccountPetFormScreen> createState() => _AccountPetFormScreenState();
}

class _AccountPetFormScreenState extends State<AccountPetFormScreen> {
  late final TextEditingController _nameController;
  late PetSpecies _species;
  String? _breed;
  DateTime? _birthMonth;
  PetWeightBand? _weightBand;
  late PetSex _sex;
  bool? _neutered;
  File? _newPhotoFile;
  bool _removePhoto = false;
  String? _nameError;
  late final String _initialSignature;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _species = existing?.species ?? PetSpecies.dog;
    final breed = existing?.breed.trim() ?? '';
    _breed = breed.isEmpty || breed == kUnknownBreed ? null : breed;
    _birthMonth = existing != null ? _parseBirthMonth(existing.birth) : null;
    // 옛 데이터(kg만 있음)는 그 값으로 구간을 계산해 보여준다.
    _weightBand = existing?.weightBandOrDerived;
    _sex = existing?.sex ?? PetSex.unknown;
    _neutered = existing?.neutered;
    _initialSignature = _signature();
  }

  static DateTime? _parseBirthMonth(String birth) {
    final parts = birth.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return null;
    return DateTime(year, month);
  }

  /// 뒤로가기 확인용 — 화면을 연 때와 지금 입력값을 비교한다.
  String _signature() => [
        _nameController.text.trim(),
        _species.name,
        _breed,
        _birthMonth?.toIso8601String(),
        _weightBand?.name,
        _sex.name,
        _neutered,
        _newPhotoFile?.path,
        _removePhoto,
      ].join('|');

  bool get _isDirty => _signature() != _initialSignature;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ProviderScope.containerOf(context, listen: false).read(adSuppressionProvider).during(() => ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 80,
      ));
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
    final picked = await showBreedPickerSheet(context, options: options, current: _breed);
    if (picked != null) setState(() => _breed = picked);
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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = '이름을 입력해주세요');
      return;
    }
    final existing = widget.existing;
    Navigator.of(context).pop(
      AccountPetFormResult.saved(
        SignupPet(
          id: existing?.id,
          species: _species,
          breed: _breed ?? kUnknownBreed,
          // 옛 실제 체중(kg)은 지우지 않는다 — 구간을 새로 골라도 구간만 바뀐다.
          weightKg: existing?.weightKg,
          weightBand: _weightBand,
          birth: _birthMonth != null ? DateFormat('yyyy-MM').format(_birthMonth!) : '',
          name: name,
          sex: _sex == PetSex.unknown ? null : _sex,
          neutered: _neutered,
          // 사진 최종 값(새로 올릴지/지울지/그대로 둘지)은 호출부가
          // newPhotoFile·removePhoto를 보고 정한다 — 여기서는 기존 값만
          // 그대로 들고 간다(잃어버리지 않게).
          photoUrl: existing?.photoUrl,
        ),
        newPhotoFile: _newPhotoFile,
        removePhoto: _removePhoto,
      ),
    );
  }

  ImageProvider? get _avatarImage {
    if (_newPhotoFile != null) return FileImage(_newPhotoFile!);
    if (!_removePhoto && widget.existing?.photoUrl != null) {
      return CachedNetworkImageProvider(widget.existing!.photoUrl!);
    }
    return null;
  }

  bool get _hasPhoto => _avatarImage != null;

  // 반려동물 추가·수정 중에는 앱 오프닝 광고를 띄우지 않는다 — 화면이 사라지면
  // (어떤 경로든) 억제도 같이 풀린다. 바뀐 게 있으면 뒤로가기 때 묻는다.
  @override
  Widget build(BuildContext context) => AppOpenAdSuppressor(
        child: UnsavedChangesGuard(isDirty: () => _isDirty, child: _buildScreen(context)),
      );

  Widget _buildScreen(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '반려동물 정보 수정' : '반려동물 정보')),
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
                  const _FieldTitle('이름', required: true),
                  TextField(
                    key: const ValueKey('pet_name'),
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(hintText: '예: 구름이', errorText: _nameError),
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                  ),
                  const SizedBox(height: AppSpacing.formField),
                  const _FieldTitle('종류', required: true),
                  _SegmentRow<PetSpecies>(
                    value: _species,
                    options: const [PetSpecies.dog, PetSpecies.cat],
                    labelOf: (s) => s.label,
                    onChanged: (s) => setState(() => _species = s),
                  ),
                  const SizedBox(height: AppSpacing.formField),
                  const _FieldTitle('품종'),
                  _SelectField(
                    icon: Icons.pets_outlined,
                    label: _breed ?? '$kUnknownBreed (고르지 않으면)',
                    placeholder: _breed == null,
                    onTap: _pickBreed,
                  ),
                  const SizedBox(height: AppSpacing.formField),
                  const _FieldTitle('태어난 해·달'),
                  Row(
                    children: [
                      Expanded(
                        child: _SelectField(
                          icon: Icons.calendar_today_outlined,
                          label: _birthMonth != null ? DateFormat('yyyy.MM').format(_birthMonth!) : '연·월 고르기',
                          placeholder: _birthMonth == null,
                          onTap: _pickBirthMonth,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PetFormChoiceButton(
                          label: '모름',
                          selected: _birthMonth == null,
                          onTap: () => setState(() => _birthMonth = null),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.formField),
                  const _FieldTitle('몸무게'),
                  _WeightBandGrid(
                    value: _weightBand,
                    onChanged: (band) => setState(() => _weightBand = band),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '진료비 시세를 몸무게 구간에 맞춰 보여드려요',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  const _GroupTitle('더 알려주셔도 돼요(선택)'),
                  const FormFieldLabel('성별'),
                  _SegmentRow<PetSex>(
                    value: _sex,
                    options: const [PetSex.unknown, PetSex.male, PetSex.female],
                    labelOf: (s) => s.label,
                    onChanged: (s) => setState(() => _sex = s),
                  ),
                  const SizedBox(height: AppSpacing.formField),
                  const FormFieldLabel('중성화'),
                  _SegmentRow<bool?>(
                    value: _neutered,
                    options: const [true, false, null],
                    labelOf: (v) => v == true
                        ? '했어요'
                        : v == false
                            ? '안 했어요'
                            : '모름',
                    onChanged: (v) => setState(() => _neutered = v),
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: AppSpacing.section),
                    Center(
                      child: TextButton(
                        onPressed: _confirmDelete,
                        child: const Text(
                          '이 반려동물 삭제',
                          style: TextStyle(color: AppColors.textSecondary, decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                  ],
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

/// 칸 제목 + 필수 표시(필수인 칸만).
class _FieldTitle extends StatelessWidget {
  final String label;
  final bool required;

  const _FieldTitle(this.label, {this.required = false});

  @override
  Widget build(BuildContext context) {
    // 라벨은 칸 위에 13.5sp 굵게, 고르지 않아도 되는 칸만 "(선택)".
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: label,
          children: [
            if (!required)
              const TextSpan(text: ' (선택)', style: TextStyle(fontWeight: FontWeight.w400, color: AppColors.textSecondary)),
          ],
        ),
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      ),
    );
  }
}

/// 체중 구간 4개(2열) — 고른 걸 다시 누르면 "모름"으로 되돌린다.
class _WeightBandGrid extends StatelessWidget {
  final PetWeightBand? value;
  final ValueChanged<PetWeightBand?> onChanged;

  const _WeightBandGrid({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget cell(PetWeightBand band) {
      final selected = band == value;
      return Expanded(
        child: OutlinedButton(
          key: ValueKey('weight_${band.name}'),
          onPressed: () => onChanged(selected ? null : band),
          style: OutlinedButton.styleFrom(
            backgroundColor: selected ? AppColors.primarySoft : AppColors.surfaceLight,
            foregroundColor: selected ? AppColors.primaryTextTone : AppColors.textPrimary,
            side: BorderSide(color: selected ? AppColors.primary : AppColors.borderInput, width: selected ? 2 : 1),
            shape: const StadiumBorder(),
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            band.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );
    }

    const bands = PetWeightBand.values;
    return Column(
      children: [
        Row(children: [cell(bands[0]), const SizedBox(width: 10), cell(bands[1])]),
        const SizedBox(height: 8),
        Row(children: [cell(bands[2]), const SizedBox(width: 10), cell(bands[3])]),
      ],
    );
  }
}

class _GroupTitle extends StatelessWidget {
  final String label;

  const _GroupTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.formField),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
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
    // 선택 버튼("장구름의 수첩", 3차 업데이트 J-7): 선택 = 2px 네이비 테두리 +
    // primarySoft + 굵은 글자, 안 선택 = 1px borderInput + 흰 바탕.
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: PetFormChoiceButton(
              label: labelOf(options[i]),
              selected: options[i] == value,
              onTap: () => onChanged(options[i]),
            ),
          ),
        ],
      ],
    );
  }
}

/// 반려동물 입력 폼의 알약 선택 버튼(높이 52dp).
class PetFormChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const PetFormChoiceButton({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surfaceLight,
        shape: StadiumBorder(
          side: selected
              ? const BorderSide(color: AppColors.primary, width: 2)
              : const BorderSide(color: AppColors.borderInput),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
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
          color: AppColors.surfaceLight,
          border: Border.all(color: AppColors.borderInput),
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
