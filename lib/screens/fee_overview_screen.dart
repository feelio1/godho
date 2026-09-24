import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/fee.dart';
import '../models/fee_bundle.dart';
import '../models/region_filter.dart';
import '../providers/fee_provider.dart';
import '../providers/location_provider.dart';
import '../providers/region_detection_status.dart';
import '../providers/region_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../widgets/fee_item_card.dart';
import '../widgets/fee_item_picker_sheet.dart';
import '../widgets/fee_weight_picker_sheet.dart';
import '../widgets/mascot_message.dart';
import '../widgets/region_indicator.dart';
import 'region_select_screen.dart';

/// 진료비 시세 전체 페이지(화면 21) — 지역·체중 기준 칩, 항목 검색,
/// 카테고리 탭, 항목 카드, 출처/기준일 고지. 진료비는 항상 "이 지역
/// 시세"지 특정 병원의 가격이 아니다(CLAUDE.md 진료비 원칙 2) — 화면
/// 어디에도 병원 이름을 달지 않는다.
class FeeOverviewScreen extends ConsumerStatefulWidget {
  /// 병원 상세의 "다른 항목 보기"처럼 특정 항목을 바로 보여주고 싶을 때.
  final String? initialItemId;

  const FeeOverviewScreen({super.key, this.initialItemId});

  @override
  ConsumerState<FeeOverviewScreen> createState() => _FeeOverviewScreenState();
}

class _FeeOverviewScreenState extends ConsumerState<FeeOverviewScreen> {
  String? _selectedCategory;
  String? _highlightedItemId;
  bool _initializedFromArg = false;

  @override
  void initState() {
    super.initState();
    // 진료비 시세는 "주변 병원" 탭과 마찬가지로 위치 정보가 있어야 바로
    // 쓸모 있는 기능이라, 이 화면에 진입했는데 지역이 아직 없으면 그때
    // 위치 권한을 요청한다(CLAUDE.md: 앱 시작 시 강제 요청 금지 — 여기는
    // 명시적으로 이 화면에 들어온 시점이라 예외가 아니라 같은 패턴이다).
    // 이미 지역이 있으면(수동 선택 포함) 아무 것도 하지 않는다.
    final region = ref.read(regionProvider).value?.filter;
    if (region == null || region.sigungu == null) {
      ref.read(regionDetectionReasonProvider.notifier).state = RegionDetectionReason.detecting;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(locationProvider.notifier).requestAndFetch();
      });
    }
  }

  Future<void> _changeRegion() async {
    final picked = await showRegionPickerSheet(context);
    if (picked != null) {
      await ref.read(regionProvider.notifier).selectRegion(picked);
    }
  }

  Future<void> _changeWeight(FeeWeightBucket current) async {
    final picked = await showFeeWeightPickerSheet(context, selected: current);
    if (picked != null) {
      ref.read(feeWeightProvider.notifier).select(picked);
    }
  }

  Future<void> _openItemPicker(FeeBundle bundle) async {
    final picked = await showFeeItemPickerSheet(
      context,
      bundle: bundle,
      selectedItemId: _highlightedItemId,
    );
    if (picked != null) {
      setState(() {
        _selectedCategory = picked.category;
        _highlightedItemId = picked.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final feeBundleAsync = ref.watch(feeBundleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('진료비 시세')),
      body: SafeArea(
        child: feeBundleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('시세 정보를 불러오지 못했습니다: $error')),
          data: (bundle) => _buildBody(context, bundle),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, FeeBundle bundle) {
    final region = ref.watch(regionProvider).value?.filter ?? const RegionFilter.all();
    final weightState = ref.watch(feeWeightProvider);

    // 화면 26 — 시/군/구까지 정해지지 않으면 "이 지역 시세"를 보여줄 수
    // 없다(CLAUDE.md 진료비 원칙 2: 진료비는 지역 시세지 전국 평균이
    // 아니다). 시/도만 고른 "OO 전체" 상태도 같은 취급.
    if (region.sigungu == null) {
      final reason = ref.watch(regionDetectionReasonProvider);
      return _LocationRequiredView(reason: reason, onSelectRegion: _changeRegion);
    }
    final sido = region.sido!;
    final sigungu = region.sigungu!;

    if (!_initializedFromArg) {
      _initializedFromArg = true;
      final initialItem = widget.initialItemId != null ? bundle.itemById(widget.initialItemId!) : null;
      _selectedCategory = initialItem?.category ?? bundle.categories.first;
      _highlightedItemId = initialItem?.id;
    }
    final selectedCategory = _selectedCategory ?? bundle.categories.first;

    final itemsWithData = bundle.itemsWithData(
      category: selectedCategory,
      sido: sido,
      sigungu: sigungu,
      weight: weightState.bucket,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 0),
          child: Row(
            children: [
              RegionIndicator(region: region, onTap: _changeRegion),
              const SizedBox(width: 8),
              _WeightChip(bucket: weightState.bucket, onTap: () => _changeWeight(weightState.bucket)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 0),
          child: _FeeSearchField(onTap: () => _openItemPicker(bundle)),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            scrollDirection: Axis.horizontal,
            itemCount: bundle.categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = bundle.categories[index];
              final active = category == selectedCategory;
              return ChoiceChip(
                label: Text(category),
                selected: active,
                onSelected: (_) => setState(() {
                  _selectedCategory = category;
                }),
                selectedColor: AppColors.primarySoft,
                labelStyle: TextStyle(
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? AppColors.primaryTextTone : AppColors.textSecondary,
                ),
                side: BorderSide(color: active ? AppColors.primary : AppColors.borderCard),
                backgroundColor: AppColors.surfaceLight,
              );
            },
          ),
        ),
        Expanded(
          child: itemsWithData.isEmpty
              ? _NoFeeDataView(regionLabel: region.label, onSelectRegion: _changeRegion)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    12,
                    AppSpacing.page,
                    4,
                  ),
                  itemCount: itemsWithData.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = itemsWithData[index];
                    final value = bundle.lookup(
                      sido: sido,
                      sigungu: sigungu,
                      itemId: item.id,
                      weight: weightState.bucket,
                    )!;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: item.id == _highlightedItemId
                            ? Border.all(color: AppColors.primary, width: 2)
                            : null,
                      ),
                      child: FeeItemCard(item: item, value: value),
                    );
                  },
                ),
        ),
        _SourceFooter(bundle: bundle, region: region, weight: weightState.bucket),
      ],
    );
  }
}

class _WeightChip extends StatelessWidget {
  final FeeWeightBucket bucket;
  final VoidCallback onTap;

  const _WeightChip({required this.bucket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderCard),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monitor_weight_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              '${bucket.label} 기준',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

class _FeeSearchField extends StatelessWidget {
  final VoidCallback onTap;

  const _FeeSearchField({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextField(
      readOnly: true,
      onTap: onTap,
      decoration: const InputDecoration(
        hintText: '진료 항목 검색',
        isDense: true,
        prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textPlaceholder),
      ),
    );
  }
}

/// 화면 26 — 지역(시/군/구)이 정해지지 않은 상태. 위치 자동감지 디버깅
/// 지시서 A: 왜 안 됐는지("조용한 실패" 금지)를 사유별로 다르게 보여
/// 준다 — 어느 경우든 "지역 선택하기" 수동 경로는 항상 함께 둔다.
class _LocationRequiredView extends StatelessWidget {
  final RegionDetectionReason reason;
  final VoidCallback onSelectRegion;

  const _LocationRequiredView({required this.reason, required this.onSelectRegion});

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (reason) {
      RegionDetectionReason.locationServiceDisabled => (
          '위치 서비스가 꺼져 있어요',
          '기기 설정에서 위치(GPS)를 켜거나, 지역을 직접 선택해주세요',
        ),
      RegionDetectionReason.permissionDenied => (
          '위치 권한이 필요해요',
          '위치 권한을 허용하면 우리 동네를 자동으로 찾아드려요. 지금은 지역을 직접 선택해주세요',
        ),
      RegionDetectionReason.positionUnavailable => (
          '위치를 찾지 못했어요',
          '잠시 후 다시 시도하거나, 지역을 직접 선택해주세요',
        ),
      RegionDetectionReason.regionNotFound => (
          '이 위치의 지역 정보를 찾지 못했어요',
          '공개된 데이터 범위 밖일 수 있어요. 지역을 직접 선택해주세요',
        ),
      RegionDetectionReason.idle ||
      RegionDetectionReason.detecting ||
      RegionDetectionReason.success =>
        (
          '우리 동네를 알려주세요',
          '지역을 선택하면 우리 동네 진료비 시세와 병원을 볼 수 있어요',
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: MascotMessage(
          title: title,
          subtitle: subtitle,
          overlayIcon: Icons.place_outlined,
          trailing: reason == RegionDetectionReason.detecting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : FilledButton.icon(
                  onPressed: onSelectRegion,
                  icon: const Icon(Icons.place_outlined, size: 18),
                  label: const Text('지역 선택하기'),
                ),
        ),
      ),
    );
  }
}

/// 화면 25 — 선택한 지역·카테고리에 조사된 진료비 데이터가 하나도 없음.
class _NoFeeDataView extends StatelessWidget {
  final String regionLabel;
  final VoidCallback onSelectRegion;

  const _NoFeeDataView({required this.regionLabel, required this.onSelectRegion});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: MascotMessage(
          title: '아직 조사된 진료비 데이터가 없어요',
          subtitle: '$regionLabel은 공개된 조사 자료가 아직 없어요. 다른 지역을 확인해보세요.',
          overlayIcon: Icons.info_outline,
          trailing: OutlinedButton(
            onPressed: onSelectRegion,
            child: const Text('다른 지역 선택'),
          ),
        ),
      ),
    );
  }
}

class _SourceFooter extends StatelessWidget {
  final FeeBundle bundle;
  final RegionFilter region;
  final FeeWeightBucket weight;

  const _SourceFooter({required this.bundle, required this.region, required this.weight});

  @override
  Widget build(BuildContext context) {
    final baseDate = bundle.baseDate;
    final formattedDate = baseDate != null ? DateFormat('yyyy. MM. dd').format(baseDate) : '확인 불가';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderMuted)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${region.label} · ${weight.label} 기준',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            '출처 · ${bundle.source} · 기준일 $formattedDate',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textPlaceholder),
          ),
          const Text(
            '실제 진료비는 병원에 확인하세요',
            style: TextStyle(fontSize: 11.5, color: AppColors.textPlaceholder),
          ),
        ],
      ),
    );
  }
}
