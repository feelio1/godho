import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../providers/signup_flow_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../widgets/signup_steps.dart';
import 'info_screens.dart';
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
  ConsumerState<SignupAgeGenderScreen> createState() =>
      _SignupAgeGenderScreenState();
}

class _SignupAgeGenderScreenState extends ConsumerState<SignupAgeGenderScreen> {
  AgeGroup? _ageGroup;
  Gender? _gender;
  bool _agreedAge14 = false;
  bool _agreedTerms = false;
  bool _agreedPrivacy = false;
  bool _agreedStats = false;

  /// 남/여만 필수 선택지로 둔다 — 이 화면은 이제 건너뛸 수 없으므로
  /// "선택 안 함"은 고를 수 있는 값으로 노출하지 않는다("자체
  /// 회원가입·로그인·비밀번호 재설정" 지시서 1-2/3).
  static const List<Gender> _requiredGenderOptions = [
    Gender.male,
    Gender.female,
  ];

  bool get _allAgreed => _agreedTerms && _agreedPrivacy && _agreedStats;

  void _setAll(bool value) {
    setState(() {
      _agreedTerms = value;
      _agreedPrivacy = value;
      _agreedStats = value;
    });
  }

  bool get _canProceed =>
      _ageGroup != null &&
      _gender != null &&
      _agreedAge14 &&
      _agreedTerms &&
      _agreedPrivacy;

  void _next() {
    if (!_canProceed) return;
    ref
        .read(signupFlowProvider.notifier)
        .setAgeGender(
          ageGroup: _ageGroup,
          gender: _gender,
          agreedStats: _agreedStats,
        );
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignupPetScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  0,
                  AppSpacing.page,
                  24,
                ),
                children: [
                  const SignupSteps(step: 2, label: '기본 정보'),
                  const SizedBox(height: 4),
                  const Text(
                    '기본 정보를 알려주세요',
                    style: TextStyle(
                      fontSize: 23,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '서비스 개선 통계에만 쓰이고, 다른 사람에게 보이지 않아요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  Row(
                    children: [
                      const Text(
                        '성별',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textLabel,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '필수',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
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
                  const SizedBox(height: AppSpacing.formField),
                  Row(
                    children: [
                      const Text(
                        '연령대',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textLabel,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '필수',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
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
                  const SizedBox(height: AppSpacing.section),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      border: Border.all(color: AppColors.primary, width: 1.5),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    // CheckboxListTile은 자신의 배경/잉크 효과를 가장 가까운
                    // Material에 그리는데, 색이 있는 DecoratedBox로 감싸면 그
                    // 효과가 가려진다는 프레임워크 경고(assertion)가 뜬다 — 직접
                    // Checkbox+Row로 구성해 피한다.
                    child: InkWell(
                      key: const ValueKey('consent_age14'),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      onTap: () => setState(() => _agreedAge14 = !_agreedAge14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _agreedAge14,
                              onChanged: (v) =>
                                  setState(() => _agreedAge14 = v ?? false),
                            ),
                            const Expanded(
                              child: Text(
                                '만 14세 이상입니다 (필수)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.borderCard),
                      ),
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          key: const ValueKey('consent_all'),
                          value: _allAgreed,
                          onChanged: (v) => _setAll(v ?? false),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            '전체 동의',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _ConsentRow(
                          key: const ValueKey('consent_terms'),
                          required: true,
                          label: '이용약관 동의',
                          value: _agreedTerms,
                          onChanged: (v) => setState(() => _agreedTerms = v),
                          onViewTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TermsScreen(),
                            ),
                          ),
                        ),
                        _ConsentRow(
                          key: const ValueKey('consent_privacy'),
                          required: true,
                          label: '개인정보 수집·이용 동의',
                          value: _agreedPrivacy,
                          onChanged: (v) => setState(() => _agreedPrivacy = v),
                          onViewTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          ),
                        ),
                        _ConsentRow(
                          key: const ValueKey('consent_stats'),
                          required: false,
                          label: '이용 통계 활용 동의',
                          value: _agreedStats,
                          onChanged: (v) => setState(() => _agreedStats = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '선택 항목에 동의하지 않아도 가입과 모든 기능을 이용할 수 있어요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textPlaceholder,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                12,
                AppSpacing.page,
                24,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _canProceed ? _next : null,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                  ),
                  child: const Text(
                    '다음',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 동의 항목 한 줄 — 필수/선택 배지 + "보기" 링크(있을 때).
class _ConsentRow extends StatelessWidget {
  final bool required;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onViewTap;

  const _ConsentRow({
    super.key,
    required this.required,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onViewTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
            Text(
              required ? '필수' : '선택',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: required ? AppColors.primary : AppColors.textPlaceholder,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            if (onViewTap != null)
              TextButton(
                onPressed: onViewTap,
                child: const Text(
                  '보기',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
