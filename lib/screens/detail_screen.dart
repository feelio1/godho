import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../ads/global_banner_ad.dart';
import '../models/hospital.dart';
import '../providers/bundle_provider.dart';
import '../providers/compare_provider.dart';
import '../providers/recent_provider.dart';
import '../providers/saved_provider.dart';
import '../theme/app_colors.dart';
import '../utils/external_links.dart';
import '../widgets/compare_floating_bar.dart';
import '../widgets/fact_card.dart';
import '../widgets/fee_section.dart';
import '../widgets/source_footer.dart';
import '../widgets/status_badge.dart';
import '../widgets/timeline_view.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final String hospitalId;

  const DetailScreen({super.key, required this.hospitalId});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentHospitalsProvider.notifier).recordVisit(widget.hospitalId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hospital = ref.watch(hospitalByIdProvider(widget.hospitalId));
    final bundleAsync = ref.watch(bundleProvider);

    if (hospital == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('병원 정보를 찾을 수 없습니다.')),
      );
    }

    final bundle = bundleAsync.value;
    final timeline = bundle?.timelineFor(hospital);
    final recordCount = bundle?.sameAddressRecordCount(hospital) ?? 1;

    final savedIds = ref.watch(savedHospitalsProvider).value ?? const [];
    final isSaved = savedIds.contains(hospital.id);
    final compareIds = ref.watch(compareListProvider);
    final isInCompare = compareIds.contains(hospital.id);

    return Scaffold(
      appBar: AppBar(),
      bottomNavigationBar: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [CompareFloatingBar(), GlobalBannerAd()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            _Header(hospital: hospital, isSaved: isSaved, generatedAt: bundle?.generatedAt),
            const SizedBox(height: 20),
            _ActionRow(
              hospital: hospital,
              isInCompare: isInCompare,
              onCompareTap: () => _onCompareTap(context, hospital.id, isInCompare),
            ),
            const SizedBox(height: 10),
            const _ReservationButton(),
            const SizedBox(height: 24),
            _FactCardGrid(hospital: hospital, recordCount: recordCount),
            const SizedBox(height: 24),
            _OperatingInfoSection(
              hospital: hospital,
              source: bundle?.source ?? '지방행정 인허가 데이터',
              generatedAt: bundle?.generatedAt,
            ),
            if (timeline != null) ...[
              const SizedBox(height: 24),
              TimelineView(timeline: timeline),
            ],
            const SizedBox(height: 24),
            const FeeSection(),
            const SizedBox(height: 24),
            _ExternalLinksSection(hospital: hospital),
            SourceFooter(
              source: bundle?.source ?? '지방행정 인허가 데이터',
              lastUpdated: bundle?.generatedAt,
            ),
          ],
        ),
      ),
    );
  }

  void _onCompareTap(BuildContext context, String id, bool isInCompare) {
    final notifier = ref.read(compareListProvider.notifier);
    if (isInCompare) {
      notifier.remove(id);
      return;
    }
    final added = notifier.add(id);
    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비교는 최대 3곳까지 담을 수 있습니다.')),
      );
    }
  }
}

class _Header extends ConsumerWidget {
  final Hospital hospital;
  final bool isSaved;
  final DateTime? generatedAt;

  const _Header({required this.hospital, required this.isSaved, this.generatedAt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                hospital.name,
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              icon: Icon(
                isSaved ? Icons.favorite : Icons.favorite_border,
                color: isSaved ? Theme.of(context).colorScheme.primary : null,
              ),
              onPressed: () =>
                  ref.read(savedHospitalsProvider.notifier).toggle(hospital.id),
            ),
          ],
        ),
        Row(
          children: [
            StatusBadge(status: hospital.status),
            const SizedBox(width: 8),
            Expanded(
              child: Text(hospital.roadAddr, style: textTheme.bodyMedium),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '데이터 확인일: ${generatedAt != null ? DateFormat('yyyy.MM.dd').format(generatedAt!) : '확인 불가'}',
          style: textTheme.bodySmall?.copyWith(color: AppColors.neutral),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final Hospital hospital;
  final bool isInCompare;
  final VoidCallback onCompareTap;

  const _ActionRow({
    required this.hospital,
    required this.isInCompare,
    required this.onCompareTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.call_outlined,
            label: '전화',
            enabled: hospital.phone != null,
            onTap: () => ExternalLinks.call(hospital.phone!),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.directions_outlined,
            label: '길찾기',
            onTap: () => ExternalLinks.openDirections(hospital),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: isInCompare ? Icons.check_circle_outline : Icons.compare_arrows,
            label: '비교',
            active: isInCompare,
            onTap: onCompareTap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.ios_share_outlined,
            label: '공유',
            onTap: () => ExternalLinks.shareHospital(hospital),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool active;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Theme.of(context).colorScheme.primary : null;
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        foregroundColor: color,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// 예약 버튼 자리. 실제 예약 연동은 아직 없고, 눌러도 "준비 중" 안내만
/// 뜬다 — 지도 준비중 화면과 같은 패턴. 어떤 병원과도 제휴·거래 관계가
/// 없다는 점을 문구로 분명히 해 중립성을 지킨다 (스프린트 3 지시서).
class _ReservationButton extends StatelessWidget {
  const _ReservationButton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.secondary,
              foregroundColor: colorScheme.onSecondary,
            ),
            onPressed: () => _showReservationComingSoonSheet(context),
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('예약하기'),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '예약 연동 기능은 준비 중이에요',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _showReservationComingSoonSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '예약 기능 준비 중',
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '현재는 병원과의 예약 연동 기능을 제공하지 않습니다. 펫병원체크는 특정 병원과 '
                '제휴하거나 거래 관계를 맺지 않으며, 추후 전화·외부 예약 링크 연결 등의 기능을 '
                '검토하고 있습니다.',
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('확인'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactCardGrid extends StatelessWidget {
  final Hospital hospital;
  final int recordCount;

  const _FactCardGrid({required this.hospital, required this.recordCount});

  @override
  Widget build(BuildContext context) {
    final cards = [
      FactCard(
        label: '운영기간',
        value: hospital.operatingPeriodLabel,
        note: hospital.operatingPeriodCategory.neutralNote,
      ),
      FactCard(label: '영업상태', value: hospital.status.label),
      const FactCard(
        label: '진료비 정보',
        value: '준비 중',
        note: '지역 시세 데이터는 다음 업데이트에서 제공될 예정입니다.',
      ),
      FactCard(label: '동일 주소 기록', value: '$recordCount건'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: cards,
    );
  }
}

class _OperatingInfoSection extends StatelessWidget {
  final Hospital hospital;
  final String source;
  final DateTime? generatedAt;

  const _OperatingInfoSection({
    required this.hospital,
    required this.source,
    this.generatedAt,
  });

  static String _fmt(DateTime? d) => d != null ? DateFormat('yyyy.MM.dd').format(d) : '확인 불가';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('운영정보', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _InfoRow('개설신고일', _fmt(hospital.openDate)),
            _InfoRow('상태', hospital.status.label),
            _InfoRow('운영기간', hospital.operatingPeriodLabel),
            _InfoRow('출처', source),
            _InfoRow('최종갱신', _fmt(generatedAt)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.neutralBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '운영기간은 공개된 인허가 기록상 계속 등록된 시점(continuousSince)을 기준으로 계산한 값이며, '
                '병원의 신뢰도나 진료 품질과는 관련이 없습니다.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.neutral, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.neutral),
            ),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _ExternalLinksSection extends StatelessWidget {
  final Hospital hospital;

  const _ExternalLinksSection({required this.hospital});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('외부 링크', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            _LinkTile(
              label: '네이버지도에서 리뷰 보기',
              onTap: () => ExternalLinks.openNaverMapReviews(hospital),
            ),
            _LinkTile(
              label: '카카오맵에서 리뷰 보기',
              onTap: () => ExternalLinks.openKakaoMapReviews(hospital),
            ),
            _LinkTile(
              label: '국가동물보호정보시스템',
              onTap: ExternalLinks.openAnimalProtectionSystem,
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LinkTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: onTap,
    );
  }
}
