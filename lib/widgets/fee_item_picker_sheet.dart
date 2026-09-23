import 'package:flutter/material.dart';

import '../models/fee.dart';
import '../models/fee_bundle.dart';
import '../theme/app_colors.dart';
import 'picker_sheet_chrome.dart';

/// 진료 항목 선택 시트(화면 22) — 검색창 + 카테고리별 그룹 목록. 항목을
/// 고르면 그 [FeeItem]을 돌려준다(호출부가 21로 돌아가 해당 카테고리
/// 탭으로 전환하고 카드를 강조한다).
Future<FeeItem?> showFeeItemPickerSheet(
  BuildContext context, {
  required FeeBundle bundle,
  String? selectedItemId,
}) {
  return showModalBottomSheet<FeeItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FeeItemPickerSheet(bundle: bundle, selectedItemId: selectedItemId),
  );
}

class _FeeItemPickerSheet extends StatefulWidget {
  final FeeBundle bundle;
  final String? selectedItemId;

  const _FeeItemPickerSheet({required this.bundle, this.selectedItemId});

  @override
  State<_FeeItemPickerSheet> createState() => _FeeItemPickerSheetState();
}

class _FeeItemPickerSheetState extends State<_FeeItemPickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final filtered = query.isEmpty
        ? widget.bundle.items
        : widget.bundle.items.where((item) => item.name.contains(query)).toList();

    return PickerSheetChrome(
      title: '진료 항목',
      heightFactor: 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '전체 ${widget.bundle.items.length}개',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: '항목 검색',
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textPlaceholder),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      "'$query' 검색 결과가 없어요",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView(
                    children: [
                      for (final category in widget.bundle.categories)
                        ..._categoryGroup(
                          context,
                          category,
                          filtered.where((item) => item.category == category).toList(),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _categoryGroup(BuildContext context, String category, List<FeeItem> items) {
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(
          category,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPlaceholder),
        ),
      ),
      for (final item in items)
        _ItemRow(
          item: item,
          selected: item.id == widget.selectedItemId,
          onTap: () => Navigator.of(context).pop(item),
        ),
    ];
  }
}

class _ItemRow extends StatelessWidget {
  final FeeItem item;
  final bool selected;
  final VoidCallback onTap;

  const _ItemRow({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? AppColors.primarySoft : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.primaryTextTone : AppColors.textPrimary,
                ),
              ),
            ),
            if (selected) const Icon(Icons.check, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
