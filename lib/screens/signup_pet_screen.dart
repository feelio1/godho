import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/pet.dart';
import '../models/signup_pet.dart';
import '../providers/auth_provider.dart';
import '../providers/signup_flow_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../widgets/breed_picker_sheet.dart';
import '../widgets/date_picker_sheet.dart';
import '../widgets/form_field_label.dart';

/// 가입 플로우 2단계(필수, 펫클 2단계 지시서 3-2) — 기존 반려동물 등록
/// 화면(05)의 항목을 재사용하되, 여기서는 종류/품종/체중/생년월이
/// 필수다(로컬 [Pet] 등록 화면과 달리). 최소 1마리부터 "완료"가
/// 활성화되고, "반려동물 추가"로 여러 마리를 등록할 수 있다.
class SignupPetScreen extends ConsumerStatefulWidget {
  const SignupPetScreen({super.key});

  @override
  ConsumerState<SignupPetScreen> createState() => _SignupPetScreenState();
}

class _SignupPetScreenState extends ConsumerState<SignupPetScreen> {
  bool _saving = false;

  Future<void> _addPet() async {
    final pet = await Navigator.of(context).push<SignupPet>(
      MaterialPageRoute(builder: (_) => const _SignupPetFormScreen()),
    );
    if (pet != null) {
      ref.read(signupFlowProvider.notifier).addPet(pet);
    }
  }

  LoginType _loginTypeOf(String? providerId) {
    switch (providerId) {
      case 'apple.com':
        return LoginType.apple;
      case 'google.com':
      default:
        return LoginType.google;
    }
  }

  Future<void> _complete() async {
    final state = ref.read(signupFlowProvider);
    if (state.pets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('반려동물을 1마리 이상 등록해주세요.')),
      );
      return;
    }

    final firebaseUser = ref.read(authRepositoryProvider).currentUser;
    if (firebaseUser == null) {
      // 세션이 끊긴 드문 경우 — 처음부터 다시 로그인하게 한다.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 만료됐어요. 다시 로그인해주세요.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    setState(() => _saving = true);
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final now = DateTime.now();
      await userRepo.createUser(
        AppUser(
          uid: firebaseUser.uid,
          loginType: _loginTypeOf(firebaseUser.providerData.isNotEmpty ? firebaseUser.providerData.first.providerId : null),
          email: firebaseUser.email,
          displayName: firebaseUser.displayName,
          ageGroup: state.ageGroup,
          gender: state.gender,
          agreedStats: state.agreedStats,
          agreedStatsAt: state.agreedStats ? now : null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      for (final pet in state.pets) {
        await userRepo.addPet(firebaseUser.uid, pet);
      }
      ref.read(signupFlowProvider.notifier).reset();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가입이 완료됐어요.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장에 실패했어요. 잠시 후 다시 시도해주세요. ($e)')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(signupFlowProvider).pets;
    return Scaffold(
      appBar: AppBar(title: const Text('반려동물 등록')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  const Text(
                    '최소 1마리는 등록해야 다음으로 진행할 수 있어요.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  for (var i = 0; i < pets.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.formField),
                      child: _PetSummaryCard(
                        pet: pets[i],
                        onRemove: () => ref.read(signupFlowProvider.notifier).removePetAt(i),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _addPet,
                    icon: const Icon(Icons.add),
                    label: const Text('반려동물 추가'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (pets.isEmpty || _saving) ? null : _complete,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('완료'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetSummaryCard extends StatelessWidget {
  final SignupPet pet;
  final VoidCallback onRemove;

  const _PetSummaryCard({required this.pet, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: Row(
        children: [
          const Icon(Icons.pets, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name?.trim().isNotEmpty == true ? pet.name!.trim() : pet.species.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pet.species.label} · ${pet.breed} · ${pet.weightKg}kg · ${pet.birth}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.close, size: 20)),
        ],
      ),
    );
  }
}

/// 반려동물 1마리 입력 폼 — 종류/품종/체중/생년월 필수, 이름/성별/중성화
/// 선택(사진은 이 단계에서 업로드 저장소가 없어 다루지 않는다).
class _SignupPetFormScreen extends StatefulWidget {
  const _SignupPetFormScreen();

  @override
  State<_SignupPetFormScreen> createState() => _SignupPetFormScreenState();
}

class _SignupPetFormScreenState extends State<_SignupPetFormScreen> {
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  PetSpecies _species = PetSpecies.dog;
  PetSex _sex = PetSex.unknown;
  bool _neutered = false;
  DateTime? _birthMonth;

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    super.dispose();
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
      SignupPet(
        species: _species,
        breed: breed,
        weightKg: weight,
        birth: DateFormat('yyyy-MM').format(_birthMonth!),
        name: name.isEmpty ? null : name,
        sex: _sex == PetSex.unknown ? null : _sex,
        neutered: _neutered,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('반려동물 정보')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
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
            const SizedBox(height: AppSpacing.section),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _submit, child: const Text('추가')),
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
