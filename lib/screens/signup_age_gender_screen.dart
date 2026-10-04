import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../providers/signup_flow_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'signup_pet_screen.dart';

/// 가입 플로우 1단계 — 나이대·성별은 모든 신규 가입(소셜 포함)에서
/// 필수 입력이고 "건너뛰기"가 없다("자체 회원가입·로그인·비밀번호
/// 재설정" 지시서 3). 만 14세 이상 확인도 모든 신규 가입에 공통으로
/// 필수다("v1 출시 준비" 지시서 2). 통계 활용 동의만 선택으로 남는다.
/// 이미 가입된 기존 사용자에게 소급 재입력을 강제하는 것은 이 화면의
/// 책임이 아니다 — 로그인(기존 사용자) 경로는 이 화면을 거치지 않는다.
/// 과장·혜택 미끼 문구 금지(CLAUDE.md 제품 헌법) — "또래 반려인 기준"
/// 문구만 쓰고 할인 등은 절대 언급하지 않는다.
class SignupAgeGenderScreen extends ConsumerStatefulWidget {
  const SignupAgeGenderScreen({super.key});

  @override
  ConsumerState<SignupAgeGenderScreen> createState() => _SignupAgeGenderScreenState();
}

class _SignupAgeGenderScreenState extends ConsumerState<SignupAgeGenderScreen> {
  AgeGroup? _ageGroup;
  Gender? _gender;
  bool _agreedAge14 = false;
  bool _agreedStats = false;

  /// 남/여만 필수 선택지로 둔다 — 이 화면은 이제 건너뛸 수 없으므로
  /// "선택 안 함"은 고를 수 있는 값으로 노출하지 않는다("자체
  /// 회원가입·로그인·비밀번호 재설정" 지시서 1-2/3).
  static const List<Gender> _requiredGenderOptions = [Gender.male, Gender.female];

  bool get _canProceed => _ageGroup != null && _gender != null && _agreedAge14;

  void _next() {
    if (!_canProceed) return;
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
      appBar: AppBar(title: const Text('회원 정보')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const Text(
              '성별과 연령대를 알려주세요. 또래 반려인 기준의 정보를 보여드리는 데 쓰여요.',
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
                  onSelected: (_) => setState(() => _ageGroup = group),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.formField),
            const Text('성별', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textLabel)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _requiredGenderOptions.map((g) {
                final selected = _gender == g;
                return ChoiceChip(
                  label: Text(g.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _gender = g),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.section),
            CheckboxListTile(
              value: _agreedAge14,
              onChanged: (v) => setState(() => _agreedAge14 = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                '만 14세 이상입니다. (만 14세 미만은 가입할 수 없어요)',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
            CheckboxListTile(
              value: _agreedStats,
              onChanged: (v) => setState(() => _agreedStats = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('서비스 개선 및 통계 목적 활용에 동의 (선택)', style: TextStyle(fontSize: 13.5)),
            ),
            const SizedBox(height: AppSpacing.section),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _canProceed ? _next : null, child: const Text('다음')),
            ),
          ],
        ),
      ),
    );
  }
}
