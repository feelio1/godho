import 'package:flutter/material.dart';

import '../models/fee.dart';
import '../theme/app_colors.dart';
import 'picker_sheet_chrome.dart';

/// 체중 기준 선택 시트(화면 24) — 지역/정렬 시트와 같은 단일 리스트
/// 패턴. 체중 무관 항목(백신·검사·예방)을 보고 있을 때도 칩은 계속
/// 보여주되, 선택해도 그 항목들의 값에는 영향이 없다(FeeBundle.lookup이
/// weightBased가 아닌 항목은 이 값을 무시한다).
Future<FeeWeightBucket?> showFeeWeightPickerSheet(
  BuildContext context, {
  required FeeWeightBucket selected,
}) {
  return showModalBottomSheet<FeeWeightBucket>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PickerSheetChrome(
      title: '체중 기준',
      heightFactor: 0.4,
      child: ListView(
        children: [
          for (final bucket in FeeWeightBucket.values)
            ListTile(
              title: Text(
                bucket.label,
                style: TextStyle(
                  fontWeight: bucket == selected ? FontWeight.w800 : FontWeight.w600,
                  color: bucket == selected ? AppColors.primaryTextTone : AppColors.textPrimary,
                ),
              ),
              trailing: bucket == selected ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () => Navigator.of(context).pop(bucket),
            ),
        ],
      ),
    ),
  );
}
