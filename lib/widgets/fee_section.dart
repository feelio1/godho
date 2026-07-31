import 'package:flutter/material.dart';

/// Sprint 1 placeholder: regional fee-comparison data is not connected
/// yet (see 다음 스프린트 예고: 지역 시세 데이터 연동). Never fabricate a
/// number here — only the neutral placeholder and its disclaimer.
class FeeSection extends StatelessWidget {
  const FeeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '진료비 정보',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '지역 시세 준비 중',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '진료비는 병원과 진료 상황에 따라 달라질 수 있으며, 방문 전 병원에 직접 확인하는 것이 정확합니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
