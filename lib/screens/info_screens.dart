import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/bundle_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: const Center(child: Text('설정 항목은 준비 중입니다.')),
    );
  }
}

class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(bundleProvider).value;
    final generatedAt = bundle?.generatedAt;
    return Scaffold(
      appBar: AppBar(title: const Text('출처')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('데이터 출처', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(bundle?.source ?? '지방행정 인허가 데이터'),
            const SizedBox(height: 16),
            Text('대상 지역', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(bundle?.region ?? '확인 불가'),
            const SizedBox(height: 16),
            Text('최종 갱신일', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(generatedAt != null ? DateFormat('yyyy.MM.dd').format(generatedAt) : '확인 불가'),
          ],
        ),
      ),
    );
  }
}

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이용안내')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.asset(
                'assets/mascot/logo.png',
                height: 160,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '펫병원체크는 동물병원을 평가하거나 순위를 매기지 않습니다. '
              '공개된 행정·인허가 정보를 있는 그대로 보여드려, 방문 전 보호자가 스스로 판단할 수 있도록 돕는 팩트체크 앱입니다.',
            ),
            const SizedBox(height: 16),
            const Text(
              '운영기간이 길다고 해서 더 좋은 병원이라는 뜻은 아니며, 신규 병원이라고 해서 문제가 있다는 뜻도 아닙니다. '
              '데이터가 없는 항목은 추정하지 않고 "확인 불가"로 표시합니다.',
            ),
            const SizedBox(height: 16),
            const Text(
              '동일 주소에서 여러 인허가 기록이 확인되더라도, 각 기록의 운영자가 동일한 사람인지는 알 수 없습니다.',
            ),
          ],
        ),
      ),
    );
  }
}
