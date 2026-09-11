import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../config/kakao_map_config.dart';
import '../data/hospital_repository.dart';
import '../models/hospital.dart';
import '../models/hospital_status.dart';
import '../models/region_filter.dart';
import '../providers/bundle_provider.dart';
import '../providers/compare_provider.dart';
import '../providers/location_provider.dart';
import '../providers/region_provider.dart';
import '../theme/app_colors.dart';
import '../utils/map_clustering.dart';
import '../widgets/hospital_thumbnail.dart';
import '../widgets/mascot_message.dart';
import '../widgets/status_badge.dart';
import 'detail_screen.dart';

/// 마스코트 "장구름" 마커 자리. 실제 이미지가 아직 없어 지금은 중립
/// placeholder 아이콘을 쓴다 — `MascotImage`와 같은 방식으로, 나중에 이
/// 경로에 실제 파일을 추가하고 pubspec.yaml에 등록하면 코드 변경 없이 그
/// 이미지로 자동 교체된다(`_assetExists`가 성공하기 시작하므로).
const String _markerAssetPath = 'assets/mascot/marker.png';

/// 마스코트 "장구름"의 '내 위치' 전용 마커 자리. 병원 마커(`_markerAssetPath`)와
/// 경로를 분리해 두어, 이 이미지만 따로 준비되어도 코드 변경 없이 교체된다.
/// 내 위치는 지도에 하나뿐이고 의미(병원이 아니라 "나")가 다르므로, 실제
/// 이미지가 없는 동안에도 병원 마커와는 다른 후광(halo) placeholder를 쓴다
/// (스프린트 7 지시서 문제 1).
const String _myLocationAssetPath = 'assets/mascot/my_location.png';

/// 서울시청 — 위치 권한도, 선택 지역에 좌표 있는 병원도 없을 때의 최종 기본
/// 지도 중심.
const LatLng _defaultCenter = LatLng(37.5665, 126.9780);

/// 지도 위 마커 성능을 위한 상한. 필터·검색 결과 자체를 줄이는 것이 아니라
/// 지도 렌더링에만 적용되는 안전장치다.
const int _markerCap = 300;

const String _myLocationPoiId = '__my_location__';

/// 이 줌 레벨 이상에서만 개별 마커에 병원 이름 라벨을 보여준다(겹침 방지).
/// [_clusterDisabledZoom]과 같은 값으로 맞춰, 개별 마커가 보이기 시작하는
/// 순간 이름도 함께 보이도록 한다(스프린트 7 지시서 문제 3).
const int _labelZoomThreshold = 14;

/// 이 줌 레벨 이상에서는 클러스터링 없이 모두 개별 마커로 표시한다. 기존
/// 값(17)이 지나치게 높아 "아주 많이 확대해야만" 개별 병원이 보였던 문제를
/// 고쳐, 기본 시작 줌(15)보다 낮춰 적당한 확대에서 개별 마커가 보이게
/// 한다(스프린트 7 지시서 문제 3).
const int _clusterDisabledZoom = 14;

class NearbyMapScreen extends ConsumerStatefulWidget {
  const NearbyMapScreen({super.key});

  @override
  ConsumerState<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends ConsumerState<NearbyMapScreen> {
  bool _mapFailed = false;
  KakaoMapController? _controller;
  PoiStyle? _hospitalStyle;
  PoiStyle? _clusterStyle;
  PoiStyle? _myLocationStyle;
  List<Hospital> _markerCandidates = const [];
  List<Poi> _renderedPois = const [];
  Poi? _myLocationPoi;
  int _currentZoom = 15;
  RegionFilter? _lastRenderedRegion;

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

  // --- 아이콘 생성 (에셋이 없을 때만 쓰는 가벼운 placeholder) ---

  static Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Uint8List> _circleBytes(
    double diameter,
    Color fillColor, {
    IconData? glyph,
    Color glyphColor = Colors.white,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final radius = diameter / 2;
    final center = Offset(radius, radius);
    canvas.drawCircle(center, radius - 1.5, Paint()..color = fillColor);
    canvas.drawCircle(
      center,
      radius - 1.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    if (glyph != null) {
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(glyph.codePoint),
          style: TextStyle(
            fontSize: diameter * 0.5,
            fontFamily: glyph.fontFamily,
            package: glyph.fontPackage,
            color: glyphColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(radius - painter.width / 2, radius - painter.height / 2));
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(diameter.toInt(), diameter.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 병원 마커 스타일. 마스코트 asset이 있으면 그 이미지를, 없으면 중립
  /// placeholder 아이콘을 쓴다. 상태(영업/신규 등)와 무관하게 모든 병원이
  /// 동일한 외형이다 — 지도 위 색으로 상태를 구분하지 않는다(CLAUDE.md 평가
  /// 금지 원칙, 스프린트 6 지시서 2). 상태·운영기간 같은 사실은 마커 탭 시
  /// 하단 카드/상세에서 그대로 제공된다.
  Future<PoiStyle> _buildHospitalStyle() async {
    const size = 44.0;
    final hasAsset = await _assetExists(_markerAssetPath);
    final icon = hasAsset
        ? KImage.fromAsset(_markerAssetPath, size.toInt(), size.toInt())
        : KImage.fromData(
            await _circleBytes(size, AppColors.primarySoft, glyph: Icons.pets, glyphColor: AppColors.primaryDark),
            size.toInt(),
            size.toInt(),
          );
    final style = PoiStyle(icon: icon, textStyle: const []);
    // 일정 줌 레벨 이상으로 확대했을 때만 병원 이름 라벨을 노출한다(겹침 방지,
    // 스프린트 6 지시서 1). 라벨은 마커 이미지 아래쪽에 배치하고(textGravity
    // bottom) padding으로 아이콘과 텍스트 사이에 여백을 둬, 이름이 장구름
    // 마커 이미지 위에 겹쳐 보이던 문제를 해결한다(스프린트 11 지시서 2).
    style.addStyle(
      zoomLevel: _labelZoomThreshold,
      icon: icon,
      textGravity: const MapGravity(HorizontalAlign.center, VerticalAlign.bottom),
      padding: size * 0.28,
      textStyle: const [
        PoiTextStyle(size: 26, color: Colors.black, stroke: 4, strokeColor: Colors.white),
      ],
    );
    return style;
  }

  Future<PoiStyle> _buildClusterStyle() async {
    const size = 48.0;
    final bytes = await _circleBytes(size, AppColors.primary);
    return PoiStyle(
      icon: KImage.fromData(bytes, size.toInt(), size.toInt()),
      textStyle: const [PoiTextStyle(size: 26, color: Colors.white)],
    );
  }

  /// '내 위치' 마커 스타일. 표준 파란 점 대신 마스코트 자리를 쓴다 — 실제
  /// 장구름 이미지가 없는 동안에도 병원 마커와 헷갈리지 않도록 후광이 있는
  /// 전용 placeholder로 표시한다(스프린트 7 지시서 문제 1).
  Future<PoiStyle> _buildMyLocationStyle() async {
    const size = 56.0;
    final hasAsset = await _assetExists(_myLocationAssetPath);
    final icon = hasAsset
        ? KImage.fromAsset(_myLocationAssetPath, size.toInt(), size.toInt())
        : KImage.fromData(
            await _myLocationHaloBytes(size),
            size.toInt(),
            size.toInt(),
          );
    return PoiStyle(icon: icon);
  }

  /// 실제 마스코트 이미지가 없을 때만 쓰는 '내 위치' placeholder. 병원
  /// 마커(`_circleBytes`)와 달리 바깥에 반투명 후광을 둘러, 지도 위에 하나뿐인
  /// 내 위치 지점임을 병원 마커와 한눈에 구분할 수 있게 한다. 색은 상태·신뢰도
  /// 표현이 아니라 순수한 시각적 구분 용도다(CLAUDE.md 중립 원칙 유지).
  static Future<Uint8List> _myLocationHaloBytes(double diameter) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(diameter / 2, diameter / 2);
    canvas.drawCircle(center, diameter / 2, Paint()..color = AppColors.primary.withValues(alpha: 0.20));
    final innerRadius = diameter * 0.34;
    canvas.drawCircle(center, innerRadius, Paint()..color = AppColors.primary);
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.pets.codePoint),
        style: TextStyle(
          fontSize: innerRadius,
          fontFamily: Icons.pets.fontFamily,
          package: Icons.pets.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
    final picture = recorder.endRecording();
    final image = await picture.toImage(diameter.toInt(), diameter.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  bool _isRenderingMarkers = false;

  /// 렌더링 도중 새 요청(줌 변경 등)이 들어오면 무시하지 않고 기억해 뒀다가,
  /// 현재 렌더링이 끝난 직후 한 번 더 실행한다 — 빠른 핀치줌처럼 짧은
  /// 시간에 연속으로 요청이 들어와도 마지막 상태가 반드시 반영되게 하기
  /// 위함이다(스프린트 7 지시서 문제 2: 예전엔 겹치면 그냥 버려져 특정 줌
  /// 구간에서 마커가 갱신되지 않고 비어 보일 수 있었다).
  bool _renderPending = false;

  /// 클러스터 재계산 + 마커 다시 그리기. `onCameraMoveEnd`/지역 변경 등
  /// 여러 경로에서 겹쳐 호출될 수 있어 재진입 가드를 둔다(겹치면 add/remove
  /// 순서가 꼬여 중복 id 오류가 날 수 있음). 개별 POI 하나의 제거/추가가
  /// 실패해도(예: SDK 쪽에서 이미 사라진 POI) 나머지는 계속 그려, 하나의
  /// 오류로 지도 전체가 빈 채로 남지 않게 한다.
  Future<void> _renderMarkers() async {
    if (_isRenderingMarkers) {
      _renderPending = true;
      return;
    }
    _isRenderingMarkers = true;
    try {
      final controller = _controller;
      final hospitalStyle = _hospitalStyle;
      final clusterStyle = _clusterStyle;
      if (controller == null || hospitalStyle == null || clusterStyle == null) return;

      // 겹치는 id로 인한 등록 실패를 피하기 위해 기존 마커를 먼저 지운 뒤 다시
      // 그린다. 개별 제거 실패는 무시하고 계속 진행한다(하나 때문에 전체
      // 갱신이 중단되지 않도록).
      for (final poi in _renderedPois) {
        try {
          await controller.labelLayer.removePoi(poi);
        } catch (_) {
          // 이미 사라졌거나 일시적 오류 — 다음 마커 제거를 계속 진행한다.
        }
      }
      _renderedPois = const [];

      final groups = clusterHospitals(
        _markerCandidates,
        _currentZoom,
        clusterDisabledZoom: _clusterDisabledZoom,
      );
      final newPois = <Poi>[];
      for (final group in groups) {
        try {
          if (!group.isCluster) {
            final hospital = group.hospitals.first;
            newPois.add(await controller.labelLayer.addPoi(
              LatLng(hospital.lat!, hospital.lng!),
              style: hospitalStyle,
              id: hospital.id,
              text: hospital.name,
              onClick: () => _showHospitalSheet(hospital),
            ));
          } else {
            final center = group.position;
            final centroid = LatLng(center.lat, center.lng);
            newPois.add(await controller.labelLayer.addPoi(
              centroid,
              style: clusterStyle,
              text: '${group.hospitals.length}',
              onClick: () => _onClusterTap(centroid),
            ));
          }
        } catch (_) {
          // 이 그룹 하나만 건너뛰고 나머지 마커/클러스터는 계속 그린다.
        }
      }
      _renderedPois = newPois;
    } finally {
      _isRenderingMarkers = false;
      if (_renderPending) {
        _renderPending = false;
        unawaited(_renderMarkers());
      }
    }
  }

  Future<void> _onClusterTap(LatLng centroid) async {
    final nextZoom = (_currentZoom + 2).clamp(1, 20);
    await _controller?.moveCamera(
      CameraUpdate.newCenterPosition(centroid, zoomLevel: nextZoom),
      animation: const CameraAnimation(300),
    );
  }

  // --- 내 위치 ---

  Future<void> _updateMyLocationMarker(LatLng position) async {
    final controller = _controller;
    if (controller == null) return;
    _myLocationStyle ??= await _buildMyLocationStyle();
    if (_myLocationPoi != null) {
      await controller.labelLayer.removePoi(_myLocationPoi!);
      _myLocationPoi = null;
    }
    _myLocationPoi = await controller.labelLayer.addPoi(
      position,
      style: _myLocationStyle!,
      id: _myLocationPoiId,
    );
  }

  Future<void> _onMyLocationTap() async {
    var location = ref.read(locationProvider).value;
    if (location == null) {
      await ref.read(locationProvider.notifier).requestAndFetch();
      location = ref.read(locationProvider).value;
    }
    if (location == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치를 확인할 수 없습니다. 위치 권한을 확인해주세요.')),
        );
      }
      return;
    }
    final target = LatLng(location.latitude, location.longitude);
    await _updateMyLocationMarker(target);
    await _controller?.moveCamera(
      CameraUpdate.newCenterPosition(target, zoomLevel: 16),
      animation: const CameraAnimation(300),
    );
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HospitalThumbnail(width: 56, height: 56, borderRadius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
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
                        const SizedBox(height: 4),
                        Text(hospital.roadAddr),
                      ],
                    ),
                  ),
                ],
              ),
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

    // 위치가 나중에(맵이 이미 뜬 뒤) 확인되는 경우에도 내 위치 마커를 갱신한다.
    ref.listen<AsyncValue<Position?>>(locationProvider, (previous, next) {
      final position = next.value;
      if (position != null) {
        _updateMyLocationMarker(LatLng(position.latitude, position.longitude));
      }
    });

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

    _markerCandidates = markerHospitals;
    if (_controller != null && _lastRenderedRegion != null && _lastRenderedRegion != region) {
      // 지도가 이미 떠 있는 상태에서 지역이 바뀌면 마커를 다시 그린다.
      WidgetsBinding.instance.addPostFrameCallback((_) => _renderMarkers());
    }
    _lastRenderedRegion = region;

    final initialTarget = location != null
        ? LatLng(location.latitude, location.longitude)
        : _centroidOrDefault(markerHospitals);
    final initialZoom = location != null ? 15 : 12;

    return Scaffold(
      appBar: AppBar(title: const Text('주변 병원')),
      body: Stack(
        children: [
          KakaoMap(
            option: KakaoMapOption(position: initialTarget, zoomLevel: initialZoom),
            onMapReady: (controller) async {
              _controller = controller;
              _currentZoom = initialZoom;
              _hospitalStyle = await _buildHospitalStyle();
              _clusterStyle = await _buildClusterStyle();
              await _renderMarkers();
              if (location != null) {
                await _updateMyLocationMarker(LatLng(location.latitude, location.longitude));
              }
            },
            onCameraMoveEnd: (position, gestureType) {
              _currentZoom = position.zoomLevel;
              _renderMarkers();
            },
            onMapError: (error) {
              if (mounted) setState(() => _mapFailed = true);
            },
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'nearby_my_location_fab',
              onPressed: _onMyLocationTap,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
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
