import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/region_filter.dart';
import '../providers/bundle_provider.dart';
import '../providers/location_provider.dart';
import '../providers/region_auto_detect.dart';
import '../theme/app_colors.dart';
import '../widgets/picker_sheet_chrome.dart';

/// 지역 선택 바텀시트 — 좌(시도)/우(시군구) 투페인(스프린트 14, Petcli
/// 시안 바텀시트 피커 공통 톤: 그랩바+제목+X버튼) 위에 "현재 위치로
/// 설정" 액션을 얹었다(위치 기반 지역 자동감지 지시서 — 상단 지역 칩은
/// 언제든 수동 변경 가능해야 하고, 그중엔 "현재 위치로" 재설정도 포함).
/// 시/도·시/군/구 값은 [HospitalRepository.sidoList]/`sigunguListFor`에서
/// 뽑은 실제 데이터 그대로다(하드코딩 아님) — 선택 로직·반환값
/// (`RegionFilter`)은 이전의 화면 전환형 선택 화면과 완전히 같다.
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
  bool _locating = false;

  /// 위치 권한 요청 → 좌표 확보 → detectNormalizedRegion(카카오 REST
  /// 역지오코딩 1순위, 최단거리 병원 폴백 2순위, 둘 다 정규화 검증까지)
  /// → 성공하면 그 지역으로 시트를 닫는다. 실패하면 스낵바로 안내하고
  /// 시트는 그대로 둬 수동 선택을 이어갈 수 있게 한다.
  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      await ref.read(locationProvider.notifier).requestAndFetch();
      final position = ref.read(locationProvider).value;
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치를 확인할 수 없습니다. 위치 권한을 확인해주세요.')),
          );
        }
        return;
      }
      final normalized = await detectNormalizedRegion(ref, position.latitude, position.longitude);
      if (normalized == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('현재 위치의 지역 정보를 찾지 못했습니다. 지역을 직접 선택해주세요.')),
          );
        }
        return;
      }
      if (mounted) {
        Navigator.of(context).pop(RegionFilter(sido: normalized.sido, sigungu: normalized.sigungu));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final sidoList = repo.sidoList;
    final selectedSido = _selectedSido;
    final sigunguList = selectedSido != null ? repo.sigunguListFor(selectedSido) : const <String>[];

    return PickerSheetChrome(
      title: '지역 선택',
      heightFactor: 0.7,
      child: Column(
        children: [
          _CurrentLocationRow(loading: _locating, onTap: _locating ? null : _useCurrentLocation),
          const Divider(height: 1),
          Expanded(
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
          ),
        ],
      ),
    );
  }
}

class _CurrentLocationRow extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;

  const _CurrentLocationRow({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            const Icon(Icons.my_location, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '현재 위치로 설정',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryTextTone),
              ),
            ),
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
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
