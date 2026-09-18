import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// 바텀시트 피커 공용 뼈대(스프린트 14, Petcli 시안): 상단 그랩바 + 제목 +
/// X 닫기 버튼, 그 아래 각 피커의 실제 내용([child]). 지역/정렬/날짜/시간/
/// 품종/리마인더 6종 피커가 이 뼈대를 함께 쓴다 — 선택 로직은 각 피커가
/// 그대로 갖고, 이 위젯은 겉모습만 통일한다.
class PickerSheetChrome extends StatelessWidget {
  final String title;
  final Widget child;

  /// 화면 높이 대비 시트 높이 비율. 목록형 피커는 넉넉히, 짧은 피커는
  /// 작게 줄 수 있다.
  final double heightFactor;

  const PickerSheetChrome({
    super.key,
    required this.title,
    required this.child,
    this.heightFactor = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * heightFactor,
        decoration: const BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderInput,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
