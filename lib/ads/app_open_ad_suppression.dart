import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 진행 중인 흐름(일기 작성·기록 입력·로그인·결제·사진 선택 등) 동안 앱
/// 오프닝 광고를 막는 카운터. 흐름에 들어갈 때 [acquire], 나올 때
/// [release]를 짝지어 부르고, [AppOpenAdGate]는 복귀 시 [isSuppressed]가
/// true면 이번 복귀의 광고를 건너뛴다.
///
/// 상태를 구독해 다시 그릴 화면이 없으므로(복귀 순간에 한 번 읽을 뿐)
/// Riverpod 상태가 아니라 Provider가 들고 있는 평범한 객체다 — 그래서
/// 위젯 initState/dispose 안에서 바꿔도 "빌드 중 provider 수정" 오류가
/// 나지 않는다.
class AppOpenAdSuppression {
  int _count = 0;

  int get count => _count;
  bool get isSuppressed => _count > 0;

  void acquire() => _count++;

  /// 짝이 맞지 않는 release가 들어와도 음수로 내려가 영영 억제가 풀리는
  /// 일은 없게 0에서 멈춘다.
  void release() {
    if (_count > 0) _count--;
  }

  /// [action]이 도는 동안만 억제한다 — 예외로 끝나도 finally에서 반드시
  /// 내린다(사진 선택·카메라, 회원 탈퇴처럼 화면이 아닌 흐름용).
  Future<T> during<T>(Future<T> Function() action) async {
    acquire();
    try {
      return await action();
    } finally {
      release();
    }
  }
}

final adSuppressionProvider = Provider<AppOpenAdSuppression>((ref) => AppOpenAdSuppression());

/// 화면 단위 억제 — 마운트되어 있는 동안 [adSuppressionProvider]를 올려
/// 둔다. 어떤 경로로 화면이 사라지든(pop, popUntil, 예외 후 정리) dispose가
/// 불리므로 반드시 내려간다. 진입 시 카운터 객체를 잡아 두고 dispose에서는
/// ref 없이 그 객체만 쓴다.
class AppOpenAdSuppressor extends ConsumerStatefulWidget {
  final Widget child;

  const AppOpenAdSuppressor({super.key, required this.child});

  @override
  ConsumerState<AppOpenAdSuppressor> createState() => _AppOpenAdSuppressorState();
}

class _AppOpenAdSuppressorState extends ConsumerState<AppOpenAdSuppressor> {
  late final AppOpenAdSuppression _suppression;

  @override
  void initState() {
    super.initState();
    _suppression = ref.read(adSuppressionProvider)..acquire();
  }

  @override
  void dispose() {
    _suppression.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
