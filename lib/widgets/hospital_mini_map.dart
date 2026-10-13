import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../config/kakao_map_config.dart';
import '../models/hospital.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../utils/external_links.dart';

/// 병원 상세 헤더의 작은 지도("출시 전 마무리" 지시서 D) — 조작은
/// 막아두고(스크롤/줌 제스처가 상세 화면 스크롤과 충돌하지 않게) 탭하면
/// 길찾기로 이어간다("둘 중 구현 쉬운 쪽" — 캘린더 탭의 지도 포커스 같은
/// 별도 상태 공유 없이 바로 쓸 수 있는 경로). 좌표가 없는 병원(약 6%)이나
/// 카카오맵 키가 설정되지 않은 빌드에서는 영역 자체를 숨긴다(빈 지도
/// 표시 금지) — 주변 병원 탭의 지도 코드는 이 위젯과 무관하게 그대로
/// 둔다.
class HospitalMiniMap extends StatefulWidget {
  final Hospital hospital;

  const HospitalMiniMap({super.key, required this.hospital});

  @override
  State<HospitalMiniMap> createState() => _HospitalMiniMapState();
}

class _HospitalMiniMapState extends State<HospitalMiniMap> {
  bool _failed = false;

  static const double _height = 160;
  static const int _zoomLevel = 16;
  static const List<GestureType> _allGestures = [
    GestureType.oneFingerDoubleTap,
    GestureType.twoFingerSingleTap,
    GestureType.pan,
    GestureType.rotate,
    GestureType.zoom,
    GestureType.tilt,
    GestureType.longTapAndDrag,
    GestureType.rotateZoom,
    GestureType.oneFingerZoom,
  ];

  Future<void> _onMapReady(KakaoMapController controller) async {
    // 조작 비활성 — SDK 차원에서도 모든 제스처를 꺼서 혹시라도 터치가
    // 지도로 새더라도 패닝/줌으로 이어지지 않게 한다(아래 투명
    // GestureDetector가 1차로 터치를 가로채는 것과 별개의 방어선).
    for (final gesture in _allGestures) {
      try {
        await controller.setGesture(gesture, false);
      } catch (_) {
        // 일부 제스처는 플랫폼에 따라 지원하지 않을 수 있다 — 무시하고
        // 나머지를 계속 끈다.
      }
    }
    try {
      final style = await _buildMarkerStyle();
      await controller.labelLayer.addPoi(
        LatLng(widget.hospital.lat!, widget.hospital.lng!),
        style: style,
        id: widget.hospital.id,
      );
    } catch (_) {
      // 마커 하나 못 찍어도 지도 자체는 보여준다.
    }
  }

  Future<PoiStyle> _buildMarkerStyle() async {
    const size = 32.0;
    final bytes = await _dotBytes(size);
    return PoiStyle(icon: KImage.fromData(bytes, size.toInt(), size.toInt()));
  }

  static Future<Uint8List> _dotBytes(double diameter) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(diameter / 2, diameter / 2);
    canvas.drawCircle(center, diameter / 2 - 1.5, Paint()..color = AppColors.primary);
    canvas.drawCircle(
      center,
      diameter / 2 - 1.5,
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

  @override
  Widget build(BuildContext context) {
    final hospital = widget.hospital;
    if (!hospital.hasCoordinates || !isKakaoMapConfigured || !kakaoMapSdkInitialized || _failed) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        height: _height,
        child: Stack(
          children: [
            KakaoMap(
              option: KakaoMapOption(
                position: LatLng(hospital.lat!, hospital.lng!),
                zoomLevel: _zoomLevel,
              ),
              forceGesture: false,
              onMapReady: _onMapReady,
              onMapError: (error) {
                debugPrint('[HospitalMiniMap] onMapError: $error');
                if (mounted) setState(() => _failed = true);
              },
            ),
            // 지도가 터치를 직접 받으면(패닝/줌) 상세 화면 스크롤과
            // 충돌한다 — 이 투명 레이어가 모든 터치를 먼저 가로채
            // 탭만 길찾기로 보내고 나머지는 조용히 무시한다. 부모
            // ListView의 세로 드래그는 claim하지 않으므로(onTap만 등록)
            // 스크롤은 그대로 통과한다.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ExternalLinks.openDirections(hospital),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
