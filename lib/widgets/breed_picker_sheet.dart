import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'picker_sheet_chrome.dart';

/// 자주 등록되는 품종 목록(스프린트 14 시안 13_품종 피커) — 실제 품종
/// 데이터베이스가 없어 자주 쓰는 이름 몇 개 + "직접 입력·기타"로 구성한
/// UI 전용 단축 목록이다. [Pet.breed]는 여전히 평범한 문자열 필드라, 이
/// 목록에 없는 품종은 기존처럼 자유 입력으로 남길 수 있다.
const List<String> commonDogBreeds = [
  '비숑 프리제',
  '말티즈',
  '푸들 (토이/미니어처)',
  '포메라니안',
  '시츄',
  '치와와',
  '요크셔테리어',
  '골든 리트리버',
];

const List<String> commonCatBreeds = [
  '코리안숏헤어',
  '러시안블루',
  '스코티시폴드',
  '브리티시숏헤어',
  '페르시안',
  '먼치킨',
];

/// 품종 선택 바텀시트. [current]와 일치하는 항목엔 체크 표시. "직접
/// 입력·기타"를 누르면 null을 반환해 호출부가 기존 텍스트 필드를 그대로
/// 쓰게 한다(값을 지우지 않음 — 자유 입력 유지).
Future<String?> showBreedPickerSheet(BuildContext context, {required List<String> options, String? current}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BreedPickerSheet(options: options, current: current),
  );
}

class _BreedPickerSheet extends StatefulWidget {
  final List<String> options;
  final String? current;

  const _BreedPickerSheet({required this.options, this.current});

  @override
  State<_BreedPickerSheet> createState() => _BreedPickerSheetState();
}

class _BreedPickerSheetState extends State<_BreedPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options.where((b) => b.contains(_query)).toList();
    return PickerSheetChrome(
      title: '품종 선택',
      heightFactor: 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(hintText: '품종 검색', prefixIcon: Icon(Icons.search, size: 20)),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final breed in filtered)
                  ListTile(
                    title: Text(
                      breed,
                      style: TextStyle(
                        fontWeight: breed == widget.current ? FontWeight.w800 : FontWeight.w600,
                        color: breed == widget.current ? AppColors.primaryTextTone : AppColors.textPrimary,
                      ),
                    ),
                    trailing: breed == widget.current
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(breed),
                  ),
                ListTile(
                  title: const Text('직접 입력 · 기타', style: TextStyle(color: AppColors.textSecondary)),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
