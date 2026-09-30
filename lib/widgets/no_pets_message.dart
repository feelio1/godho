import 'package:flutter/material.dart';

import '../screens/pet_profile_form_screen.dart';
import 'mascot_image.dart';
import 'mascot_message.dart';

/// 반려동물이 한 마리도 없을 때 진료기록·캘린더 화면이 공통으로 보여주는
/// 빈 상태 — 로그인이면 계정 반려동물 추가로, 게스트면 로컬 반려동물 등록
/// 화면으로 보낸다(펫클 3단계 지시서 2와 같은 분기). 두 화면이 각자
/// 구현하면 문구·동작이 갈릴 위험이 있어 한곳에 모았다("캘린더 하단탭화 +
/// 진료 연대기" 지시서).
class NoPetsMessage extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onAddAccountPet;

  const NoPetsMessage({super.key, required this.isLoggedIn, required this.onAddAccountPet});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: isLoggedIn
            ? MascotMessage(
                title: '아직 등록된 반려동물이 없어요',
                subtitle: '반려동물을 추가하면 진료 기록과 몸무게를 남길 수 있어요',
                assetPath: MascotImage.emptyRecordAssetPath,
                overlayIcon: Icons.pets,
                trailing: FilledButton.icon(
                  onPressed: onAddAccountPet,
                  icon: const Icon(Icons.add),
                  label: const Text('반려동물 추가'),
                ),
              )
            : MascotMessage(
                title: '아직 등록된 반려동물이 없어요',
                subtitle: '프로필을 등록하면 진료 기록과 몸무게를 기기에 남길 수 있어요',
                assetPath: MascotImage.emptyRecordAssetPath,
                overlayIcon: Icons.pets,
                trailing: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PetProfileFormScreen()),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('반려동물 등록하기'),
                ),
              ),
      ),
    );
  }
}
