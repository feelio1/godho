import 'package:flutter/material.dart';

import '../models/pet.dart';

/// 반려동물이 2마리 이상일 때만 뜨는 전환 칩 — 진료기록·캘린더 화면이
/// 똑같은 모양의 스위처를 쓴다(펫클 "계정 반려동물 추가/수정" 지시서 1
/// "여러 마리 등록·전환 가능", "캘린더 하단탭화 + 진료 연대기" 지시서에서
/// 공용 위젯으로 뺌). 게스트는 항상 1마리라 이 위젯 자체가 그려지지 않는다.
class PetSwitcher extends StatelessWidget {
  final List<Pet> pets;
  final String selectedId;
  final ValueChanged<String> onSelect;

  const PetSwitcher({super.key, required this.pets, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        itemCount: pets.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final pet = pets[i];
          return ChoiceChip(
            label: Text(pet.name),
            selected: pet.id == selectedId,
            onSelected: (_) => onSelect(pet.id),
          );
        },
      ),
    );
  }
}
