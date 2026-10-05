import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../ads/global_banner_ad.dart';
import '../models/hospital.dart';
import '../models/hospital_status.dart';
import '../providers/bundle_provider.dart';
import '../providers/compare_provider.dart';
import '../providers/designated_provider.dart';
import '../providers/recent_provider.dart';
import '../providers/saved_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/external_links.dart';
import '../widgets/compare_floating_bar.dart';
import '../widgets/fee_hospital_section.dart';
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
    final designatedIds = ref.watch(designatedHospitalsProvider).value ?? const [];
    final isDesignated = designatedIds.contains(hospital.id);
    final compareIds = ref.watch(compareListProvider);
    final isInCompare = compareIds.contains(hospital.id);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: isSaved ? '저장 해제' : '저장',
            icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
            color: isSaved ? AppColors.primary : AppColors.textPrimary,
            onPressed: () => ref.read(savedHospitalsProvider.notifier).toggle(hospital.id),
          ),
          IconButton(
            tooltip: '공유',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () => ExternalLinks.shareHospital(hospital),
          ),
        ],
      ),
      bottomNavigationBar: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [CompareFloatingBar(), GlobalBannerAd()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _Header(
              hospital: hospital,
              recordCount: recordCount,
              isDesignated: isDesignated,
              generatedAt: bundle?.generatedAt,
            ),
            const SizedBox(height: 20),
            _ActionRow(
              hospital: hospital,
              isInCompare: isInCompare,
              onCompareTap: () => _onCompareTap(context, hospital.id, isInCompare),
            ),
            // 액션 버튼(전화/길찾기/비교/예약) 바로 아래에 지역 시세를
            // 둔다(펫클 3단계 지시서 3 — 예전엔 타임라인 아래, 화면 한참
            // 밑에 있어 눈에 잘 안 띄었다). 폐업 병원은 시세 자체를 달지
            // 않는다(기존 FeeContextChip과 같은 규칙).
            if (hospital.status != HospitalStatus.closed) ...[
              const SizedBox(height: 24),
              FeeHospitalSection(hospital: hospital),
            ],
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

/// 헤더 — "펫클 앱 디자인" 캔버스 시안(Detail.dc.html) 그대로: 칩 한 줄
/// (운영기간/상태 + 같은 주소 기록 건수) → 병원명(큰 제목) → 주소 순.
/// "저장"은 앱바 아이콘으로 옮겨서 여기엔 없다.
class _Header extends ConsumerWidget {
  final Hospital hospital;
  final int recordCount;
  final bool isDesignated;
  final DateTime? generatedAt;

  const _Header({
    required this.hospital,
    required this.recordCount,
    required this.isDesignated,
    this.generatedAt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            HospitalStatusTag(hospital: hospital),
            if (recordCount > 1) Chip(label: Text('같은 주소 기록 $recordCount건')),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          hospital.name,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        const SizedBox(height: 4),
        Text(hospital.roadAddr, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        // "저장(bookmark)"과는 별개인 지정(단골) 병원 등록. 아이콘만으로는
        // 잘 안 보인다는 스프린트 9 피드백(지시서 2)에 따라, 글자 라벨이
        // 있는 칩으로 확실히 눈에 띄게 하고 눌렀을 때 스낵바로 확인해준다.
        FilterChip(
          avatar: Icon(
            isDesignated ? Icons.push_pin : Icons.push_pin_outlined,
            size: 18,
            color: isDesignated ? Theme.of(context).colorScheme.onPrimaryContainer : null,
          ),
          label: Text(isDesignated ? '지정 병원' : '지정 병원으로 등록'),
          selected: isDesignated,
          onSelected: (_) => _toggleDesignated(context, ref),
        ),
      ],
    );
  }

  void _toggleDesignated(BuildContext context, WidgetRef ref) {
    ref.read(designatedHospitalsProvider.notifier).toggle(hospital.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isDesignated ? '지정 병원에서 해제했습니다.' : '지정 병원으로 등록했습니다. 홈 상단에서 바로 볼 수 있어요.'),
      ),
    );
  }
}

/// 액션 4버튼 — "펫클 앱 디자인" 캔버스 시안(Detail.dc.html)의 2×2 아님,
/// 1행 4열 아이콘 그리드 그대로: 전화 · 길찾기 · 비교 담기 · 예약(준비
/// 중). "공유"는 시안처럼 앱바 아이콘으로 옮겼다.
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
            onTap: () => ExternalLinks.call(context, hospital.phone),
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
            label: '비교 담기',
            active: isInCompare,
            onTap: onCompareTap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.event_available_outlined,
            label: '예약 준비 중',
            muted: true,
            onTap: () => _showReservationComingSoonSheet(context),
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
  final bool active;

  /// 예약처럼 "아직 쓸 수 없음"을 알리는 톤 — 시안의 회색 비활성 타일.
  /// 완전히 막지는 않고 누르면 안내 시트가 뜬다(제휴 없음 고지가
  /// 중요해서 — 스프린트 3 지시서).
  final bool muted;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = muted
        ? AppColors.textPlaceholder
        : active
            ? AppColors.primary
            : AppColors.textPrimary;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10),
        foregroundColor: color,
        backgroundColor: muted ? AppColors.backgroundLight : null,
        side: BorderSide(color: muted ? AppColors.borderMuted : AppColors.borderCard),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }
}

/// 예약 준비중 안내 — 어떤 병원과도 제휴·거래 관계가 없다는 점을 문구로
/// 분명히 해 중립성을 지킨다(스프린트 3 지시서).
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
              style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '현재는 병원과의 예약 연동 기능을 제공하지 않습니다. Petcli는 특정 병원과 '
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
            Text('운영 정보', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            _InfoRow('개설신고일', _fmt(hospital.openDate), mono: true),
            _InfoRow('상태', hospital.status.label),
            _InfoRow('운영기간', hospitalOperatingLabel(hospital)),
            if (hospital.phone != null) _InfoRow('전화', hospital.phone!, mono: true),
            _InfoRow('출처', source),
            _InfoRow('최종갱신', _fmt(generatedAt), mono: true, last: true),
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

  /// 날짜·전화번호처럼 숫자가 섞인 값은 모노스페이스로("펫클 앱 디자인"
  /// 캔버스 시안의 `.mono`).
  final bool mono;

  /// 마지막 행은 하단 구분선을 긋지 않는다(시안 `.row:last-child`).
  final bool last;

  const _InfoRow(this.label, this.value, {this.mono = false, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: last
          ? null
          : const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderMuted))),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: mono
                ? AppTextStyles.mono(size: 14, color: AppColors.textPrimary)
                : const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
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
            Text('외부 링크', style: textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              '네이버·카카오 리뷰로 바로 이동합니다. Petcli는 평가·별점을 자체적으로 제공하지 않습니다.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
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
