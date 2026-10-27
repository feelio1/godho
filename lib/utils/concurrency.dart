/// 동시에 최대 [concurrency]개까지만 [task]를 돌리는 간단한 작업 풀 —
/// 사진 여러 장을 한꺼번에(끝없이) 올리지 않고 적당히 나눠 올리는 데
/// 쓴다("일기 수정" 지시서 1-4). 결과는 [items] 순서를 그대로 보존한다.
///
/// 하나라도 실패하면 이미 시작된 작업은 끝까지 기다리되(그래야 어디까지
/// 성공했는지 호출부가 정확히 알 수 있다), 아직 시작하지 않은 항목은
/// 더 시작하지 않고 멈춘다 — 그 뒤 첫 번째 에러를 그대로 다시 던진다.
Future<List<R>> mapWithConcurrency<T, R>(
  List<T> items,
  int concurrency,
  Future<R> Function(T item, int index) task,
) async {
  if (items.isEmpty) return const [];
  final results = List<R?>.filled(items.length, null);
  var nextIndex = 0;
  Object? firstError;
  StackTrace? firstStackTrace;

  Future<void> worker() async {
    while (true) {
      if (firstError != null) return;
      final i = nextIndex;
      if (i >= items.length) return;
      nextIndex = i + 1;
      try {
        results[i] = await task(items[i], i);
      } catch (e, st) {
        firstError ??= e;
        firstStackTrace ??= st;
        return;
      }
    }
  }

  final workerCount = concurrency < items.length ? concurrency : items.length;
  await Future.wait(List.generate(workerCount, (_) => worker()));

  final error = firstError;
  if (error != null) {
    Error.throwWithStackTrace(error, firstStackTrace!);
  }
  return results.cast<R>();
}
