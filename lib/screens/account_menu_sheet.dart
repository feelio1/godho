import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/signup_pet.dart';
import '../providers/effective_pets_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'account_pet_actions.dart';
import 'account_ui.dart';

/// 홈의 "OO님" 배지를 탭하면 뜨는 계정 메뉴(마이페이지) — 예전엔 로그아웃
/// 한 줄뿐이었지만, 여기에 계정 반려동물(Firestore `users/{uid}/pets`)
/// 관리를 통합한다("계정 메뉴에 반려동물 관리 통합" 지시서 1). 반려동물을
/// 추가/삭제하면 [accountSignupPetsProvider]가 invalidate되고, 그 provider를
/// 보는 진료기록 화면 등 다른 화면에도 전역 Riverpod provider라 즉시
/// 반영된다(지시서 2) — 이 시트 자체가 그 화면들을 직접 갱신할 필요가
/// 없다.
void showAccountMenuSheet(BuildContext context, WidgetRef ref, User user) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _AccountMenuSheet(user: user, homeContext: context),
  );
}

class _AccountMenuSheet extends ConsumerWidget {
  final User user;

  /// 홈 화면 자체의 context — 로그아웃은 이 시트를 먼저 닫은 뒤 확인
  /// 다이얼로그를 띄워야 하는데, 시트가 닫히고 나면 시트 자신의 context는
  /// 더 이상 쓸 수 없어 홈의 context를 따로 들고 있는다(펫클 3단계
  /// 지시서에서도 같은 이유로 sheetContext/context를 구분했다).
  final BuildContext homeContext;

  const _AccountMenuSheet({required this.user, required this.homeContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = user.uid;
    final petsAsync = ref.watch(accountSignupPetsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderCard,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text('${accountLabel(user)}님', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 12),
                  children: [
                    Row(
                      children: [
                        const Text('내 반려동물', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => AccountPetActions.add(context, ref, uid),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('추가'),
                        ),
                      ],
                    ),
                    petsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('불러오지 못했습니다: $error')),
                      ),
                      data: (pets) {
                        if (pets.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('등록된 반려동물이 없어요', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                          );
                        }
                        return Column(
                          children: pets
                              .map((pet) => Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: _AccountPetRow(pet: pet, uid: uid),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('로그아웃'),
                onTap: () {
                  Navigator.pop(context);
                  confirmAndSignOut(homeContext, ref);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 반려동물 한 마리 행 — 사진(있으면 원격 URL)·이름·종류/품종/체중, 수정
/// 아이콘(전체 폼)과 빠른 삭제 아이콘(확인 팝업만 거침)을 나란히 둔다.
class _AccountPetRow extends ConsumerWidget {
  final SignupPet pet;
  final String uid;

  const _AccountPetRow({required this.pet, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = pet.name?.trim().isNotEmpty == true ? pet.name!.trim() : pet.species.label;
    final subtitle = '${pet.breed.isNotEmpty ? pet.breed : pet.species.label} · ${pet.weightKg}kg · ${pet.birth}';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primarySoft,
            backgroundImage: pet.photoUrl != null ? NetworkImage(pet.photoUrl!) : null,
            child: pet.photoUrl == null ? const Icon(Icons.pets, color: AppColors.primaryDark) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            tooltip: '수정',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => AccountPetActions.editOrDelete(context, ref, uid, pet),
          ),
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => AccountPetActions.confirmAndDelete(context, ref, uid, pet),
          ),
        ],
      ),
    );
  }
}
