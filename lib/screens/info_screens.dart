import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../notifications/notification_service.dart';
import '../providers/bundle_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _sendTestNotification(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await NotificationService.instance.sendTestNotification();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '1분 뒤 테스트 알림이 울립니다. 안 오면 알림 권한·배터리 최적화 설정을 확인해주세요.'
              : '테스트 알림을 예약하지 못했습니다. 알림 권한을 확인해주세요.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '예약 알림 테스트',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '진료 예약에 등록한 알림이 실제로 울리는지 확인하고 싶다면, 아래 버튼으로 1분 뒤 '
                    '테스트 알림을 받아보세요. 알림 권한과 정확한 시각 알림 권한을 이 시점에 함께 확인·'
                    '요청합니다.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _sendTestNotification(context),
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('1분 뒤 테스트 알림 보내기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Center(child: Text('그 외 설정 항목은 준비 중입니다.')),
        ],
      ),
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
