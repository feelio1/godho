import 'package:flutter/material.dart';

import '../models/region_filter.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// 검색 세트 카드(스프린트 14, Petcli 시안 공용 컴포넌트): 흰 카드 위에
/// (위) 회색 인셋 검색 필드 + (아래) 가로 스크롤 지역 칩. 홈/검색결과/
/// 검색결과없음 화면이 함께 쓴다. 검색어·지역 상태 자체는 기존
/// `searchQueryProvider`/`regionProvider`를 그대로 쓰고, 이 위젯은 순수
/// 표시·입력 UI만 담당한다 — 새 데이터/로직을 추가하지 않는다.
///
/// 지역 칩 목록은 `HospitalRepository.sidoList`(데이터에서 뽑은 실제
/// 시/도 목록, 하드코딩 아님) 그대로다. "전체" 칩과 현재 선택된 시/도
/// 칩만 액센트(핀 아이콘 + caret)로 강조하고, 이미 활성인 시/도 칩을
/// 다시 누르면 시/군/구까지 좁힐 수 있는 전체 지역 선택 화면을 연다.
class SearchSetCard extends StatelessWidget {
  final String hintText;

  /// 이 화면에서 바로 검색어를 입력받을 때(검색결과 화면)의 컨트롤러.
  /// null이면 필드를 눌러도 편집되지 않고 [onFieldTap]만 반응한다(홈
  /// 화면 — 탭하면 검색 화면으로 이동).
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFieldTap;
  final bool autofocus;

  final RegionFilter region;
  final List<String> sidoOptions;

  /// 지역 칩을 바로 눌렀을 때 — [RegionFilter.all()] 또는 특정 시/도
  /// 전체로 즉시 전환한다(기존 `regionProvider.selectRegion` 재사용).
  final ValueChanged<RegionFilter> onSelectRegion;

  /// 이미 활성인 시/도 칩을 다시 눌렀을 때 — 시/군/구까지 좁히는 전체
  /// 지역 선택 화면을 연다.
  final VoidCallback onOpenRegionPicker;

  const SearchSetCard({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.onFieldTap,
    this.autofocus = false,
    required this.region,
    required this.sidoOptions,
    required this.onSelectRegion,
    required this.onOpenRegionPicker,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: appCardDecoration(shadow: AppShadows.searchSet),
      padding: const EdgeInsets.all(AppSpacing.cardLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SearchField(
            hintText: hintText,
            controller: controller,
            onChanged: onChanged,
            onTap: onFieldTap,
            autofocus: autofocus,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sidoOptions.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _RegionChip(
                    label: '전체',
                    active: region.isNationwide,
                    onTap: () => onSelectRegion(const RegionFilter.all()),
                  );
                }
                final sido = sidoOptions[index - 1];
                final active = region.sido == sido;
                return _RegionChip(
                  label: sido,
                  active: active,
                  showCaret: active,
                  onTap: active ? onOpenRegionPicker : () => onSelectRegion(RegionFilter(sido: sido)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool autofocus;

  const _SearchField({
    required this.hintText,
    this.controller,
    this.onChanged,
    this.onTap,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: onTap != null,
      onTap: onTap,
      autofocus: autofocus,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        isDense: true,
        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textPlaceholder),
      ),
    );
  }
}

class _RegionChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool showCaret;
  final VoidCallback onTap;

  const _RegionChip({
    required this.label,
    required this.active,
    this.showCaret = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primarySoft : AppColors.inputFill,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) ...[
              const Icon(Icons.place, size: 13, color: AppColors.primaryTextTone),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? AppColors.primaryTextTone : AppColors.textSecondary,
              ),
            ),
            if (showCaret) ...[
              const SizedBox(width: 2),
              const Icon(Icons.expand_more, size: 14, color: AppColors.primaryTextTone),
            ],
          ],
        ),
      ),
    );
  }
}
