import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/region_filter.dart';
import '../providers/bundle_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/picker_sheet_chrome.dart';

/// 지역 선택 바텀시트 — 좌(시도)/우(시군구) 투페인(스프린트 14, Petcli
/// 시안 바텀시트 피커 공통 톤: 그랩바+제목+X버튼). 시/도·시/군/구 값은
/// [HospitalRepository.sidoList]/`sigunguListFor`에서 뽑은 실제 데이터
/// 그대로다(하드코딩 아님) — 선택 로직·반환값(`RegionFilter`)은 이전의
/// 화면 전환형 선택 화면과 완전히 같다.
Future<RegionFilter?> showRegionPickerSheet(BuildContext context) {
  return showModalBottomSheet<RegionFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _RegionPickerSheet(),
  );
}

class _RegionPickerSheet extends ConsumerStatefulWidget {
  const _RegionPickerSheet();

  @override
  ConsumerState<_RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends ConsumerState<_RegionPickerSheet> {
  String? _selectedSido;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final sidoList = repo.sidoList;
    final selectedSido = _selectedSido;
    final sigunguList = selectedSido != null ? repo.sigunguListFor(selectedSido) : const <String>[];

    return PickerSheetChrome(
      title: '지역 선택',
      heightFactor: 0.7,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              children: [
                _PickerRow(
                  label: '전체',
                  selected: false,
                  onTap: () => Navigator.of(context).pop(const RegionFilter.all()),
                ),
                const Divider(height: 1),
                for (final sido in sidoList)
                  _PickerRow(
                    label: sido,
                    selected: sido == selectedSido,
                    trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textPlaceholder),
                    onTap: () => setState(() => _selectedSido = sido),
                  ),
              ],
            ),
          ),
          Container(width: 1, color: AppColors.borderMuted),
          Expanded(
            child: selectedSido == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '왼쪽에서 시/도를 먼저 선택하세요',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      _PickerRow(
                        label: '$selectedSido 전체',
                        selected: false,
                        onTap: () => Navigator.of(context).pop(RegionFilter(sido: selectedSido)),
                      ),
                      const Divider(height: 1),
                      for (final sigungu in sigunguList)
                        _PickerRow(
                          label: sigungu,
                          selected: false,
                          onTap: () => Navigator.of(context)
                              .pop(RegionFilter(sido: selectedSido, sigungu: sigungu)),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget? trailing;
  final VoidCallback onTap;

  const _PickerRow({
    required this.label,
    required this.selected,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? AppColors.primarySoft : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.primaryTextTone : AppColors.textPrimary,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check, size: 18, color: AppColors.primary)
            else
              ?trailing,
          ],
        ),
      ),
    );
  }
}
