import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../utils/network_error.dart';
import '../widgets/inline_error_message.dart';

/// 내 정보 > 기본 정보 — 가입 때 선택으로 바뀐 성별·연령대를 나중에
/// 입력·수정·비우는 곳(2차 업데이트 결정 1). 고른 칩을 다시 누르면 선택이
/// 풀리고, 저장하면 비운 값은 null로 남는다. 통계에만 쓰이고 다른 사람에게
/// 보이지 않는다는 안내는 가입 화면과 같다.
class BasicInfoScreen extends ConsumerWidget {
  const BasicInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('기본 정보')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => InlineErrorMessage(error: error, onRetry: () => ref.invalidate(currentUserProfileProvider)),
        data: (profile) => profile == null
            ? const Center(child: Text('로그인 정보를 불러오지 못했어요', style: TextStyle(color: AppColors.textSecondary)))
            : _BasicInfoForm(profile: profile),
      ),
    );
  }
}

class _BasicInfoForm extends ConsumerStatefulWidget {
  final AppUser profile;

  const _BasicInfoForm({required this.profile});

  @override
  ConsumerState<_BasicInfoForm> createState() => _BasicInfoFormState();
}

class _BasicInfoFormState extends ConsumerState<_BasicInfoForm> {
  late Gender? _gender;
  late AgeGroup? _ageGroup;
  bool _saving = false;

  static const _genderOptions = [Gender.male, Gender.female];

  @override
  void initState() {
    super.initState();
    // 예전 데이터의 "선택 안 함"은 고르지 않은 것과 같게 보인다.
    _gender = widget.profile.gender == Gender.unspecified ? null : widget.profile.gender;
    _ageGroup = widget.profile.ageGroup;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateBasicInfo(
            widget.profile.uid,
            ageGroup: _ageGroup,
            gender: _gender,
          );
      ref.invalidate(currentUserProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장했어요')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(actionFailureMessage(e, '저장'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        const Text(
          '선택 항목이에요. 서비스 개선 통계에만 쓰이고, 다른 사람에게 보이지 않아요.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.section),
        const _Label('성별'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in _genderOptions)
              ChoiceChip(
                label: Text(g.label),
                selected: _gender == g,
                onSelected: (_) => setState(() => _gender = _gender == g ? null : g),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.formField),
        const _Label('연령대'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final group in AgeGroup.values)
              ChoiceChip(
                label: Text(group.label),
                selected: _ageGroup == group,
                onSelected: (_) => setState(() => _ageGroup = _ageGroup == group ? null : group),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.section * 1.5),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('저장'),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textLabel)),
            const SizedBox(width: 6),
            const Text(
              '선택',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPlaceholder),
            ),
          ],
        ),
      );
}
