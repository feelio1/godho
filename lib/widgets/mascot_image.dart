import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 마스코트 "장구름" (흰 비숑) 자리.
///
/// 실제 아트워크가 아직 없어 지금은 가벼운 원형 아이콘 placeholder를 그린다.
/// 나중에 실제 이미지를 `assets/mascot/janggureum.png`에 추가하고
/// pubspec.yaml의 assets 목록에 등록하면, 이 위젯은 코드 변경 없이 자동으로
/// 그 이미지를 사용하게 된다 (asset이 없으면 [errorBuilder]가 지금의
/// placeholder로 조용히 대체함).
///
/// 사용처는 홈 인사 영역·빈 상태·로딩 화면처럼 "친근함"을 담당하는 자리로
/// 제한한다. 병원 데이터 카드·타임라인·진료비 등 신뢰가 중요한 영역에는
/// 넣지 않는다 (스프린트 3 지시서).
class MascotImage extends StatelessWidget {
  static const _assetPath = 'assets/mascot/janggureum.png';

  final double size;
  final String semanticLabel;

  const MascotImage({super.key, this.size = 56, this.semanticLabel = '장구름'});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          _assetPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _MascotPlaceholder(size: size),
        ),
      ),
    );
  }
}

class _MascotPlaceholder extends StatelessWidget {
  final double size;

  const _MascotPlaceholder({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.pets,
        size: size * 0.52,
        color: AppColors.primaryDark,
      ),
    );
  }
}
