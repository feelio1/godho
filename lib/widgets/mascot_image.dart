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
  static const defaultAssetPath = 'assets/mascot/janggureum.png';

  /// 검색 결과가 없을 때(검색/주변 병원 등).
  static const emptySearchAssetPath = 'assets/mascot/empty_search.png';

  /// 진료기록·저장 목록이 비어 있을 때.
  static const emptyRecordAssetPath = 'assets/mascot/empty_record.png';

  final double size;
  final String semanticLabel;

  /// 기본은 장구름 얼굴(janggureum.png)이지만, 검색 결과 없음·빈 진료기록
  /// 처럼 상황에 맞는 다른 장구름 그림(예: empty_search.png)으로 바꿔 쓸 수
  /// 있다 — 실제 이미지가 없을 때의 폴백은 동일하게 유지된다.
  final String assetPath;

  const MascotImage({
    super.key,
    this.size = 56,
    this.semanticLabel = '장구름',
    this.assetPath = defaultAssetPath,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          assetPath,
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
