
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/utils/concurrency.dart';

/// 사진 병렬 업로드가 쓰는 동시성 제한 작업 풀("일기 수정" 지시서 1-4) —
/// 순서 보존, 동시 개수 제한, 실패 시 중단을 검증한다.
void main() {
  test('결과는 입력 순서를 그대로 보존한다(완료 순서와 무관)', () async {
    final delays = [30, 10, 20, 5];
    final results = await mapWithConcurrency(delays, 4, (ms, index) async {
      await Future<void>.delayed(Duration(milliseconds: ms));
      return index;
    });
    expect(results, [0, 1, 2, 3]);
  });

  test('동시에 concurrency개까지만 돈다', () async {
    var current = 0;
    var maxConcurrent = 0;
    final items = List.generate(9, (i) => i);

    await mapWithConcurrency(items, 3, (item, index) async {
      current++;
      maxConcurrent = current > maxConcurrent ? current : maxConcurrent;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      current--;
      return item;
    });

    expect(maxConcurrent, 3);
  });

  test('빈 목록이면 빈 목록을 바로 돌려준다', () async {
    final results = await mapWithConcurrency<int, int>(const [], 3, (item, index) async => item);
    expect(results, isEmpty);
  });

  test('하나가 실패하면 시작된 작업은 끝까지 기다리고, 첫 에러를 다시 던진다', () async {
    final started = <int>[];
    Object? caught;
    try {
      await mapWithConcurrency(List.generate(6, (i) => i), 2, (item, index) async {
        started.add(item);
        if (item == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          throw Exception('item 1 failed');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return item;
      });
    } catch (e) {
      caught = e;
    }

    expect(caught, isNotNull);
    expect(caught.toString(), contains('item 1 failed'));
    // 2개씩 동시에 돌므로(0,1) 시작한 뒤 1이 실패하면, 아직 시작하지
    // 않았던 4, 5는 시작되지 않아야 한다 — 0은 이미 시작됐으니 끝까지
    // 간다.
    expect(started, isNot(contains(5)));
  });
}
