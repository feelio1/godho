import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/effective_pets_provider.dart';
import '../screens/account_pet_actions.dart';

/// 일기·진료기록·예약을 쓰려는데 로그인 회원의 반려동물이 0마리일 때 —
/// 반려동물 등록 화면을 먼저 띄운다(2차 업데이트 C, 가입 때 등록이 선택이
/// 됨). 이미 있으면 첫 반려동물 id를, 새로 등록했으면 그 id를, 등록을
/// 취소했으면 null을 돌려준다. [registered]가 true면 방금 등록한 것.
Future<({String petId, bool registered})?> ensurePetForWriting(BuildContext context, WidgetRef ref) async {
  // 로그인 상태를 아직 못 읽었으면(앱 시작 직후 알림 탭 등) 첫 값을 기다린다.
  final uid = (await ref.read(authStateProvider.future))?.uid;
  final pets = await ref.read(effectivePetsProvider.future);
  if (pets.isNotEmpty) return (petId: pets.first.id, registered: false);
  if (uid == null || !context.mounted) return null;
  final docId = await AccountPetActions.add(context, ref, uid);
  if (docId == null) return null;
  return (petId: 'account:$docId', registered: true);
}
