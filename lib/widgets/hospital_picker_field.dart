import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hospital_repository.dart';
import '../models/hospital.dart';
import '../models/region_filter.dart';
import '../providers/bundle_provider.dart';
import '../providers/designated_provider.dart';
import '../providers/location_provider.dart';
import '../providers/recent_provider.dart';
import '../screens/region_select_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'region_indicator.dart';

/// 병원 이름 입력 필드 — 우리 DB에서 검색해 고르거나 이름을 직접 입력할 수
/// 있다. 진료기록·예약 두 폼이 함께 쓴다(스프린트 8에서 진료기록 폼에
/// 처음 만들었던 검색 로직을 스프린트 9에서 공용 위젯으로 뺐다 — "필드
/// 라벨 명확히" 지시를 두 폼에 동시에 반영하기 위함).
///
/// 상태(입력 텍스트, 선택된 병원 id)는 부모 화면이 들고 있고, 이 위젯은
/// 그 상태를 받아 그리기만 한다.
///
/// 스프린트 15 지시서 3: 검색만 되던 것에 지역 필터·"내 주변" 정렬·
/// 최근/지정 병원 우선 노출을 추가한다. 필터/정렬 선택은 이 위젯만의
/// 화면 상태라 부모에 새 콜백을 만들지 않고 내부(`State`)에 둔다 — 실제
/// 병원을 고르거나 직접 입력하는 흐름은 기존 콜백 그대로다. 지역 선택은
/// [showRegionPickerSheet](병원상세 등에서 쓰는 그 시트)를, "내 주변"은
/// 기존 [locationProvider]를, 최근/지정 노출은 기존
/// [recentHospitalsProvider]/[designatedHospitalsProvider]를 그대로
/// 재사용한다 — 검색·지역 로직 자체는 건드리지 않는다.
class HospitalPickerField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String? selectedHospitalId;
  final bool showSuggestions;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<Hospital> onHospitalSelected;
  final VoidCallback onSelectionCleared;
  final VoidCallback onFieldTapped;

  const HospitalPickerField({
    super.key,
    required this.controller,
    required this.selectedHospitalId,
    required this.showSuggestions,
    required this.onTextChanged,
    required this.onHospitalSelected,
    required this.onSelectionCleared,
    required this.onFieldTapped,
  });

  @override
  ConsumerState<HospitalPickerField> createState() => _HospitalPickerFieldState();
}

class _HospitalPickerFieldState extends ConsumerState<HospitalPickerField> {
  static const _maxPinned = 4;
  static const _maxSearchResults = 6;
  static const _maxBrowseResults = 8;

  RegionFilter _regionFilter = const RegionFilter.all();
  bool _nearMeActive = false;

  Future<void> _pickRegion() async {
    final picked = await showRegionPickerSheet(context);
    if (picked == null || !mounted) return;
    setState(() => _regionFilter = picked);
  }

  void _toggleNearMe() {
    if (_nearMeActive) {
      setState(() => _nearMeActive = false);
      return;
    }
    // 처음 켤 때만 위치를 요청한다 — 다른 화면의 "내 주변"과 같은 패턴
    // (CLAUDE.md: 위치 권한을 앱 시작 시가 아니라 명시적 진입 시에만).
    ref.read(locationProvider.notifier).requestAndFetch();
    setState(() => _nearMeActive = true);
  }

  List<Hospital> _resolveIds(HospitalRepository repo, List<String> ids, Set<String> seen) {
    final list = <Hospital>[];
    for (final id in ids) {
      final h = repo.byId(id);
      if (h == null || !seen.add(h.id)) continue;
      list.add(h);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final query = widget.controller.text.trim();
    final position = _nearMeActive ? ref.watch(locationProvider).value : null;
    final lat = position?.latitude;
    final lng = position?.longitude;

    Widget? panel;
    if (widget.showSuggestions) {
      panel = query.isEmpty
          ? _buildBrowsePanel(repo, lat, lng)
          : _buildSearchPanel(repo, query, lat, lng);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            hintText: '병원 검색 또는 이름 직접 입력',
            prefixIcon: const Icon(Icons.storefront_outlined, size: 20, color: AppColors.textPlaceholder),
            suffixIcon: widget.selectedHospitalId != null
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: '선택 해제하고 직접 입력',
                    onPressed: widget.onSelectionCleared,
                  )
                : const Icon(Icons.expand_more, size: 18, color: AppColors.textPlaceholder),
          ),
          onChanged: widget.onTextChanged,
          onTap: widget.onFieldTapped,
        ),
        if (widget.showSuggestions) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              RegionIndicator(region: _regionFilter, onTap: _pickRegion),
              const SizedBox(width: 8),
              _NearMeChip(active: _nearMeActive, onTap: _toggleNearMe),
            ],
          ),
        ],
        ?panel,
      ],
    );
  }

  Widget _buildSearchPanel(HospitalRepository repo, String query, double? lat, double? lng) {
    var results = repo.search(query);
    results = repo.filterByRegion(results, _regionFilter);
    if (_nearMeActive) {
      results = repo.sortHospitals(results, SortOption.distance, currentLat: lat, currentLng: lng);
    }
    results = results.take(_maxSearchResults).toList();
    if (results.isEmpty) return const SizedBox.shrink();
    return _PickerPanel(
      children: [
        _PickerSection(
          hospitals: results,
          showDistance: _nearMeActive,
          lat: lat,
          lng: lng,
          onTap: widget.onHospitalSelected,
        ),
      ],
    );
  }

  Widget _buildBrowsePanel(HospitalRepository repo, double? lat, double? lng) {
    final designatedIds = ref.watch(designatedHospitalsProvider).value ?? const <String>[];
    final recentIds = ref.watch(recentHospitalsProvider).value ?? const <String>[];

    final seen = <String>{};
    var designated = _resolveIds(repo, designatedIds, seen).take(_maxPinned).toList();
    var recent = _resolveIds(repo, recentIds, seen).take(_maxPinned).toList();
    if (_nearMeActive) {
      designated = repo.sortHospitals(designated, SortOption.distance, currentLat: lat, currentLng: lng);
      recent = repo.sortHospitals(recent, SortOption.distance, currentLat: lat, currentLng: lng);
    }

    var browse = <Hospital>[];
    if (!_regionFilter.isNationwide || _nearMeActive) {
      final candidates = repo
          .filterByRegion(repo.all, _regionFilter)
          .where((h) => !seen.contains(h.id))
          .toList();
      browse = _nearMeActive
          ? repo.sortHospitals(candidates, SortOption.distance, currentLat: lat, currentLng: lng)
          : (candidates..sort((a, b) => a.name.compareTo(b.name)));
      browse = browse.take(_maxBrowseResults).toList();
    }

    final browseLabel = _regionFilter.isNationwide ? '내 주변 병원' : '${_regionFilter.label} 병원';

    final sections = <Widget>[
      if (designated.isNotEmpty)
        _PickerSection(
          label: '지정 병원',
          hospitals: designated,
          showDistance: _nearMeActive,
          lat: lat,
          lng: lng,
          onTap: widget.onHospitalSelected,
        ),
      if (recent.isNotEmpty)
        _PickerSection(
          label: '최근 조회',
          hospitals: recent,
          showDistance: _nearMeActive,
          lat: lat,
          lng: lng,
          onTap: widget.onHospitalSelected,
        ),
      if (browse.isNotEmpty)
        _PickerSection(
          label: browseLabel,
          hospitals: browse,
          showDistance: _nearMeActive,
          lat: lat,
          lng: lng,
          onTap: widget.onHospitalSelected,
        ),
    ];

    if (sections.isEmpty) return const SizedBox.shrink();
    return _PickerPanel(children: sections);
  }
}

class _NearMeChip extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _NearMeChip({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primarySoft : null,
          border: Border.all(color: active ? AppColors.primary : AppColors.borderCard),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.near_me_outlined, size: 15, color: active ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              '내 주변',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.primaryTextTone : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerPanel extends StatelessWidget {
  final List<Widget> children;

  const _PickerPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border.all(color: AppColors.borderCard),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _PickerSection extends StatelessWidget {
  final String? label;
  final List<Hospital> hospitals;
  final bool showDistance;
  final double? lat;
  final double? lng;
  final ValueChanged<Hospital> onTap;

  const _PickerSection({
    this.label,
    required this.hospitals,
    required this.showDistance,
    required this.lat,
    required this.lng,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
            child: Text(
              label!,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textPlaceholder),
            ),
          ),
        for (final h in hospitals)
          ListTile(
            dense: true,
            title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              h.roadAddr,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            trailing: showDistance && HospitalRepository.distanceKm(lat, lng, h.lat, h.lng) != null
                ? Text(
                    '${HospitalRepository.distanceKm(lat, lng, h.lat, h.lng)!.toStringAsFixed(1)}km',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  )
                : null,
            onTap: () => onTap(h),
          ),
      ],
    );
  }
}
