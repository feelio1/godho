import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../config/kakao_map_config.dart';
import '../data/hospital_repository.dart';
import '../models/hospital.dart';
import '../models/hospital_status.dart';
import '../models/operating_period.dart';
import '../models/region_filter.dart';
import '../providers/bundle_provider.dart';
import '../providers/compare_provider.dart';
import '../providers/location_provider.dart';
import '../providers/region_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/mascot_message.dart';
import '../widgets/status_badge.dart';
import 'detail_screen.dart';

/// 서울시청 — 위치 권한도, 선택 지역에 좌표 있는 병원도 없을 때의 최종 기본
/// 지도 중심.
const LatLng _defaultCenter = LatLng(37.5665, 126.9780);

/// 지도 위 마커 성능/가독성을 위한 상한. 필터·검색 결과 자체를 줄이는 것이
/// 아니라 지도 렌더링에만 적용되는 안전장치다(클러스터링은 다음 스프린트 예고).
const int _markerCap = 300;

class NearbyMapScreen extends ConsumerStatefulWidget {
  const NearbyMapScreen({super.key});

  @override
  ConsumerState<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends ConsumerState<NearbyMapScreen> {
  bool _mapFailed = false;

  @override
  void initState() {
    super.initState();
    // 위치 권한은 이 탭 최초 진입 시에만 요청합니다 (CLAUDE.md 하지 말 것 항목
    // 준수). 지도 SDK 키 유무와 무관하게 거리/가까운 순 정렬은 이 탭에서 계속
    // 동작해야 하므로, isKakaoMapConfigured 여부와 상관없이 요청한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationProvider.notifier).requestAndFetch();
    });
  }

  static Future<Uint8List> _dotIconBytes(Color color, double diameter) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final radius = diameter / 2;
    final center = Offset(radius, radius);
    canvas.drawCircle(center, radius - 1.5, Paint()..color = color);
    canvas.drawCircle(
      center,
      radius - 1.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(diameter.toInt(), diameter.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<PoiStyle> _dotStyle(Color color, {double diameter = 32}) async {
    final bytes = await _dotIconBytes(color, diameter);
    return PoiStyle(icon: KImage.fromData(bytes, diameter.toInt(), diameter.toInt()));
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

  static LatLng _centroidOrDefault(List<Hospital> hospitalsWithCoords) {
    if (hospitalsWithCoords.isEmpty) return _defaultCenter;
    var latSum = 0.0;
    var lngSum = 0.0;
    for (final h in hospitalsWithCoords) {
      latSum += h.lat!;
      lngSum += h.lng!;
    }
    return LatLng(latSum / hospitalsWithCoords.length, lngSum / hospitalsWithCoords.length);
  }

  @override
  Widget build(BuildContext context) {
    if (!isKakaoMapConfigured || _mapFailed) {
      return const _MapStub();
    }

    final repo = ref.watch(repositoryProvider);
    final location = ref.watch(locationProvider).value;
    final region = ref.watch(regionProvider).value?.filter ?? const RegionFilter.all();

    // 전국 규모(약 1만 곳)에서 지도에 표시할 후보를 선택된 지역으로 먼저
    // 좁힌다 — 검색 결과와 동일한 지역 필터를 공유한다.
    // 좌표 없는 병원(약 347곳)은 지도에서만 제외되고 검색·상세는 정상 제공된다.
    var markerHospitals = repo
        .filterByRegion(repo.all, region)
        .where((h) => h.hasCoordinates && h.status != HospitalStatus.closed)
        .toList();

    if (markerHospitals.length > _markerCap) {
      markerHospitals = repo.sortHospitals(
        markerHospitals,
        SortOption.distance,
        currentLat: location?.latitude,
        currentLng: location?.longitude,
      ).take(_markerCap).toList();
    }

    final initialTarget = location != null
        ? LatLng(location.latitude, location.longitude)
        : _centroidOrDefault(markerHospitals);

    return Scaffold(
      appBar: AppBar(title: const Text('주변 병원')),
      body: KakaoMap(
        option: KakaoMapOption(
          position: initialTarget,
          zoomLevel: location != null ? 15 : 12,
        ),
        onMapReady: (controller) async {
          final openStyle = await _dotStyle(AppColors.open);
          final newStyle = await _dotStyle(AppColors.neutral);
          final unknownStyle = await _dotStyle(AppColors.neutral.withValues(alpha: 0.45));

          await Future.wait(markerHospitals.map((hospital) {
            final style = hospital.status == HospitalStatus.unknown
                ? unknownStyle
                : hospital.operatingPeriodCategory == OperatingPeriodCategory.newHospital
                    ? newStyle
                    : openStyle;
            return controller.labelLayer.addPoi(
              LatLng(hospital.lat!, hospital.lng!),
              style: style,
              id: hospital.id,
              onClick: () => _showHospitalSheet(hospital),
            );
          }));
        },
        onMapError: (error) {
          if (mounted) setState(() => _mapFailed = true);
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
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: MascotMessage(
            title: '주변 병원 지도 준비 중입니다',
            subtitle: '카카오맵 연동이 완료되면 이 화면에서 주변 동물병원을 확인할 수 있어요. '
                '지금은 검색으로 병원을 찾아보세요.',
          ),
        ),
      ),
    );
  }
}
