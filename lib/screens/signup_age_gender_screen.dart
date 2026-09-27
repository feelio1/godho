import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../providers/signup_flow_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'signup_pet_screen.dart';

/// 가입 플로우 1단계(펫클 2단계 지시서 3-1) — 나이대·성별은 전부 선택
/// 입력이고 "건너뛰기"로 그대로 통과할 수 있다. 과장·혜택 미끼 문구
/// 금지(CLAUDE.md 제품 헌법) — "또래 반려인 기준" 문구만 쓰고 할인 등은
/// 절대 언급하지 않는다.
class SignupAgeGenderScreen extends ConsumerStatefulWidget {
  const SignupAgeGenderScreen({super.key});

  @override
  ConsumerState<SignupAgeGenderScreen> createState() => _SignupAgeGenderScreenState();
}

class _SignupAgeGenderScreenState extends ConsumerState<SignupAgeGenderScreen> {
  AgeGroup? _ageGroup;
  Gender? _gender;
  bool _agreedStats = false;

  void _next() {
    ref.read(signupFlowProvider.notifier).setAgeGender(
          ageGroup: _ageGroup,
          gender: _gender,
          agreedStats: _agreedStats,
        );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignupPetScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원 정보 (선택)')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const Text(
              '입력하시면 또래 반려인 기준의 더 정확한 정보를 보여드릴 수 있어요 (선택)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.section),
            const Text('나이대', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textLabel)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AgeGroup.values.map((group) {
                final selected = _ageGroup == group;
                return ChoiceChip(
                  label: Text(group.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _ageGroup = selected ? null : group),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.formField),
            const Text('성별', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textLabel)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Gender.values.map((g) {
                final selected = _gender == g;
                return ChoiceChip(
                  label: Text(g.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _gender = selected ? null : g),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.section),
            CheckboxListTile(
              value: _agreedStats,
              onChanged: (v) => setState(() => _agreedStats = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('서비스 개선 및 통계 목적 활용에 동의', style: TextStyle(fontSize: 13.5)),
            ),
            const SizedBox(height: AppSpacing.section),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _next, child: const Text('다음')),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _ageGroup = null;
                    _gender = null;
                    _agreedStats = false;
                  });
                  _next();
                },
                child: const Text('건너뛰기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
