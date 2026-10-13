import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/network_error.dart';

/// Riverpod `AsyncValue.error` 분기에서 공통으로 쓰는 안내 — 원인이
/// 네트워크면 "인터넷 연결을 확인해주세요"로 수렴시키고, [onRetry]가
/// 있으면 다시 시도할 수 있게 한다("오프라인 안내" 지시서 E). 이전엔
/// 여러 화면이 각자 `Text('불러오지 못했습니다: $error')`로 원인 예외를
/// 그대로 사용자에게 보여주고 있었다.
class InlineErrorMessage extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const InlineErrorMessage({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = isNetworkError(error) ? '인터넷 연결을 확인해주세요.' : '불러오지 못했어요. 잠시 후 다시 시도해주세요.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ],
        ),
      ),
    );
  }
}
