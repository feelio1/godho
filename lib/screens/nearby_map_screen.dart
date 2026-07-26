import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/naver_map_config.dart';
import '../models/hospital.dart';
import '../models/hospital_status.dart';
import '../models/operating_period.dart';
import '../models/region_filter.dart';
import '../providers/bundle_provider.dart';
import '../providers/compare_provider.dart';
import '../providers/location_provider.dart';
import '../providers/region_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/status_badge.dart';
import 'detail_screen.dart';

/// 인천시청 — 위치 권한이 없거나 아직 확인되지 않았을 때의 기본 지도 중심.
const NLatLng _defaultCenter = NLatLng(37.4563, 126.7052);

class NearbyMapScreen extends ConsumerStatefulWidget {
  const NearbyMapScreen({super.key});

  @override
  ConsumerState<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends ConsumerState<NearbyMapScreen> {
  @override
  void initState() {
    super.initState();
    // 위치 권한은 이 탭 최초 진입 시에만 요청합니다 (CLAUDE.md 하지 말 것 항목
    // 준수). 지도 SDK 키 유무와 무관하게 거리/가까운 순 정렬은 이 탭에서 계속
    // 동작해야 하므로, isNaverMapConfigured 여부와 상관없이 요청한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationProvider.notifier).requestAndFetch();
    });
  }

  Color _markerColor(Hospital hospital) {
    if (hospital.status == HospitalStatus.unknown) {
      return AppColors.neutral.withValues(alpha: 0.45); // 상태확인 = 옅은색
    }
    if (hospital.operatingPeriodCategory == OperatingPeriodCategory.newHospital) {
      return AppColors.neutral; // 신규 = 회색
    }
    return AppColors.open; // 영업 = 기본색
  }

  void _showHospitalSheet(Hospital hospital) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hospital.name,
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  StatusBadge(status: hospital.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(hospital.roadAddr),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        final added =
                            ref.read(compareListProvider.notifier).add(hospital.id);
                        if (!added && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('비교는 최대 3곳까지 담을 수 있습니다.')),
                          );
                        }
                      },
                      child: const Text('비교 추가'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DetailScreen(hospitalId: hospital.id),
                          ),
                        );
                      },
                      child: const Text('상세보기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isNaverMapConfigured) {
      return const _MapStub();
    }

    final repo = ref.watch(repositoryProvider);
    final location = ref.watch(locationProvider).value;
    final region = ref.watch(regionProvider).value?.filter ?? const RegionFilter.all();

    // 전국 규모(약 1만 곳)에서 지도에 표시할 후보를 선택된 지역으로 먼저
    // 좁힌다 — 검색 결과와 동일한 지역 필터를 공유한다.
    final markerHospitals = repo
        .filterByRegion(repo.all, region)
        .where((h) => h.hasCoordinates && h.status != HospitalStatus.closed)
        .toList();

    final initialTarget =
        location != null ? NLatLng(location.latitude, location.longitude) : _defaultCenter;

    return Scaffold(
      appBar: AppBar(title: const Text('주변 병원')),
      body: NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(target: initialTarget, zoom: 13),
          locationButtonEnable: location != null,
        ),
        onMapReady: (controller) async {
          final markers = markerHospitals
              .map((hospital) => NMarker(
                    id: hospital.id,
                    position: NLatLng(hospital.lat!, hospital.lng!),
                    caption: NOverlayCaption(text: hospital.name),
                    iconTintColor: _markerColor(hospital),
                  )..setOnTapListener((_) => _showHospitalSheet(hospital)))
              .toSet();
          await controller.addOverlayAll(markers);
        },
      ),
    );
  }
}

class _MapStub extends StatelessWidget {
  const _MapStub();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주변 병원')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 48, color: AppColors.neutral),
              const SizedBox(height: 16),
              Text(
                '주변 병원 지도 준비 중입니다.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '네이버 지도 연동이 완료되면 이 화면에서 주변 동물병원을 확인할 수 있어요. '
                '지금은 검색으로 병원을 찾아보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.neutral),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
