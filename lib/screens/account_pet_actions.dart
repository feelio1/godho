import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/signup_pet.dart';
import '../providers/auth_provider.dart';
import '../providers/effective_pets_provider.dart';
import '../theme/app_colors.dart';
import 'account_pet_form_screen.dart';

/// 계정(Firestore) 반려동물 추가/수정/삭제의 공통 로직 — 진료기록 화면과
/// 홈의 계정 메뉴 양쪽에서 똑같이 쓴다("계정 메뉴에 반려동물 관리 통합"
/// 지시서). 화면마다 각자 구현하면 Firestore 쓰기 순서(문서 생성 → 사진
/// 업로드 → URL 갱신)나 실패 처리가 어긋날 수 있어 한곳에 모았다.
/// [accountSignupPetsProvider]는 전역 Riverpod provider라 invalidate하면
/// 이 화면이 아니어도 그 provider를 보는 모든 화면(진료기록 등)에 즉시
/// 반영된다.
class AccountPetActions {
  const AccountPetActions._();

  /// 추가 — 성공하면 새로 생긴 Firestore 문서 id를, 취소·실패하면 null을
  /// 돌려준다(호출부가 방금 추가한 반려동물을 바로 선택하고 싶을 때 씀).
  static Future<String?> add(BuildContext context, WidgetRef ref, String uid) async {
    final result = await Navigator.of(context).push<AccountPetFormResult>(
      MaterialPageRoute(builder: (_) => const AccountPetFormScreen()),
    );
    if (result == null || result.isDelete || result.pet == null) return null;

    final userRepo = ref.read(userRepositoryProvider);
    try {
      final petId = await userRepo.addPet(uid, result.pet!);
      if (result.newPhotoFile != null) {
        final url = await userRepo.uploadPetPhoto(uid, petId, result.newPhotoFile!);
        if (url != null) {
          await userRepo.updatePet(uid, petId, result.pet!.copyWith(photoUrl: url));
        }
      }
      ref.invalidate(accountSignupPetsProvider);
      return petId;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('반려동물 추가에 실패했어요. 잠시 후 다시 시도해주세요. ($e)')),
        );
      }
      return null;
    }
  }

  /// 수정 화면을 열고, 결과에 따라 수정 또는 삭제를 반영한다. 삭제했으면
  /// true를 돌려준다(호출부가 선택 상태를 초기화하는 등에 씀).
  ///
  /// 삭제해도 Firestore 문서(프로필)만 지운다 — 이 반려동물 앞으로 로컬에
  /// 남아있는 진료기록/예약(petId: "account:{docId}")은 건드리지 않고
  /// 조용히 보존한다. 사용자 확인을 거친 정책이다: 프로필만 지우면 그
  /// 기록들은 화면 어디에도 다시 뜨지 않는 "고아" 상태로 기기에만 남는다
  /// ("계정 메뉴에 반려동물 관리 통합" 지시서 4).
  static Future<bool> editOrDelete(
    BuildContext context,
    WidgetRef ref,
    String uid,
    SignupPet existing,
  ) async {
    final result = await Navigator.of(context).push<AccountPetFormResult>(
      MaterialPageRoute(builder: (_) => AccountPetFormScreen(existing: existing)),
    );
    if (result == null) return false;

    final docId = existing.id!;
    final userRepo = ref.read(userRepositoryProvider);
    try {
      if (result.isDelete) {
        await userRepo.deletePet(uid, docId);
        ref.invalidate(accountSignupPetsProvider);
        return true;
      }
      if (result.pet == null) return false;
      var updated = result.pet!;
      if (result.newPhotoFile != null) {
        final url = await userRepo.uploadPetPhoto(uid, docId, result.newPhotoFile!);
        if (url != null) updated = updated.copyWith(photoUrl: url);
      } else if (result.removePhoto) {
        await userRepo.deletePetPhoto(uid, docId);
        updated = updated.copyWith(clearPhotoUrl: true);
      }
      await userRepo.updatePet(uid, docId, updated);
      ref.invalidate(accountSignupPetsProvider);
      return false;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장에 실패했어요. 잠시 후 다시 시도해주세요. ($e)')),
        );
      }
      return false;
    }
  }

  /// 목록에서 바로 지우는 빠른 삭제 — 수정 화면을 열지 않고 확인 팝업만
  /// 거쳐 지운다(계정 메뉴 반려동물 목록의 삭제 아이콘, "삭제는 확인 팝업
  /// 필수" 지시서). [editOrDelete]와 삭제 정책(프로필만 삭제, 로컬 기록
  /// 보존)은 동일하다.
  static Future<void> confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    String uid,
    SignupPet pet,
  ) async {
    final label = pet.name?.trim().isNotEmpty == true ? pet.name!.trim() : pet.species.label;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('반려동물 삭제'),
        content: Text(
          '$label의 정보와 사진을 삭제합니다. 이 작업은 되돌릴 수 없습니다.\n'
          '이 반려동물 앞으로 이 기기에 남아 있는 진료기록·예약은 지워지지 않지만, 더 이상 화면에 표시되지 않습니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final userRepo = ref.read(userRepositoryProvider);
    try {
      await userRepo.deletePet(uid, pet.id!);
      ref.invalidate(accountSignupPetsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제에 실패했어요. 잠시 후 다시 시도해주세요. ($e)')),
        );
      }
    }
  }
}
