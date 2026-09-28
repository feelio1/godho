import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/signup_flow_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'account_pet_form_screen.dart';

/// 가입 플로우 2단계(필수, 펫클 2단계 지시서 3-2) — 기존 반려동물 등록
/// 화면(05)의 항목을 재사용하되, 여기서는 종류/품종/체중/생년월이
/// 필수다(로컬 [Pet] 등록 화면과 달리). 최소 1마리부터 "완료"가
/// 활성화되고, "반려동물 추가"로 여러 마리를 등록할 수 있다.
///
/// 실제 입력 폼은 [AccountPetFormScreen](펫클 "계정 반려동물 추가/수정"
/// 지시서에서 공용 화면으로 뺌)을 그대로 쓴다 — 가입 중엔 아직 uid로
/// Firestore에 쓸 수 있는 시점(사용자 문서가 없음)이 아니라서, 여기서는
/// 그 화면이 돌려준 값을 즉시 저장하지 않고 [signupFlowProvider]에
/// 모아뒀다가 "완료"에서 한 번에 쓴다(진료기록 화면의 즉시 저장과 다른
/// 점 — 가입 중이라는 맥락 차이일 뿐 화면 자체는 같다).
class SignupPetScreen extends ConsumerStatefulWidget {
  const SignupPetScreen({super.key});

  @override
  ConsumerState<SignupPetScreen> createState() => _SignupPetScreenState();
}

class _SignupPetScreenState extends ConsumerState<SignupPetScreen> {
  bool _saving = false;

  Future<void> _addPet() async {
    final result = await Navigator.of(context).push<AccountPetFormResult>(
      MaterialPageRoute(builder: (_) => const AccountPetFormScreen()),
    );
    // 가입 중엔 아직 등록된 반려동물이 없으니 삭제 신호는 올 수 없다 —
    // pet이 있을 때만 누적한다.
    if (result != null && !result.isDelete && result.pet != null) {
      ref.read(signupFlowProvider.notifier).addPet(result.pet!, photoFile: result.newPhotoFile);
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
      for (final pending in state.pets) {
        final petId = await userRepo.addPet(firebaseUser.uid, pending.pet);
        // 가입 중 사진을 고른 경우: 문서가 생긴 뒤에야 저장 경로(petId)를
        // 알 수 있어 순서가 항상 생성 → 업로드 → URL 갱신이다.
        if (pending.photoFile != null) {
          final url = await userRepo.uploadPetPhoto(firebaseUser.uid, petId, pending.photoFile!);
          if (url != null) {
            await userRepo.updatePet(firebaseUser.uid, petId, pending.pet.copyWith(photoUrl: url));
          }
        }
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
                        pending: pets[i],
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
  final PendingSignupPet pending;
  final VoidCallback onRemove;

  const _PetSummaryCard({required this.pending, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final pet = pending.pet;
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
