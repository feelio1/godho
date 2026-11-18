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
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../utils/external_links.dart';
import '../utils/phone_format.dart';
import '../widgets/compare_floating_bar.dart';
import '../widgets/fee_hospital_section.dart';
import '../widgets/guest_gate.dart';
import '../widgets/hospital_mini_map.dart';
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

  /// 병원 저장은 로그인 필요 기능이다("로그인 게이팅" 지시서 1) — 게스트가
  /// 누르면 먼저 로그인하도록 안내하고, 로그인에 성공하면 그 자리에서 바로
  /// 저장까지 이어간다.
  Future<void> _toggleSaved(String hospitalId) async {
    final ok = await requireLogin(context, ref, message: '로그인하면 관심 있는 병원을 저장해두고 언제든 다시 찾아볼 수 있어요.');
    if (!ok) return;
    ref.read(savedHospitalsProvider.notifier).toggle(hospitalId);
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
            onPressed: () => _toggleSaved(hospital.id),
          ),
          IconButton(
            tooltip: '공유',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () => ExternalLinks.shareHospital(hospital),
          ),
        ],
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [CompareFloatingBar(), GlobalBannerAd(inline: true)]),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 32),
          children: [
            _Header(hospital: hospital, isDesignated: isDesignated),
            const SizedBox(height: 18),
            _ActionRow(
              hospital: hospital,
              isInCompare: isInCompare,
              onCompareTap: () => _onCompareTap(context, hospital.id, isInCompare),
            ),
            const SizedBox(height: 32),
            _RecordSection(
              hospital: hospital,
              source: bundle?.source ?? '지방행정 인허가 데이터',
              generatedAt: bundle?.generatedAt,
            ),
            if (timeline != null) ...[
              const SizedBox(height: 32),
              TimelineView(timeline: timeline, recordCount: recordCount),
            ],
            // 폐업 병원은 지역 시세 자체를 달지 않는다(기존 규칙).
            if (hospital.status != HospitalStatus.closed) ...[
              const SizedBox(height: 32),
              FeeHospitalSection(hospital: hospital),
            ],
            const SizedBox(height: 28),
            _ExternalLinksSection(hospital: hospital),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비교는 최대 3곳까지 담을 수 있습니다.')));
    }
  }
}

/// 헤더("장구름의 수첩", 3차 업데이트 J-4) — 이름 26sp 굵게 / 주소 / 상태 한
/// 줄(영업 중 = 네이비 점 + "영업 중으로 등록돼 있어요", 폐업·확인 안 됨 =
/// 회색 칩) / 작은 지도(좌표 없으면 숨김) / 지정 병원 칩. 저장·공유는 앱바.
class _Header extends ConsumerWidget {
  final Hospital hospital;
  final bool isDesignated;

  const _Header({required this.hospital, required this.isDesignated});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hospital.name,
          style: const TextStyle(
            fontSize: 26,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(hospital.displayAddr, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        HospitalStatusMark(status: hospital.status, openLabel: '영업 중으로 등록돼 있어요', fontSize: 15),
        const SizedBox(height: 16),
        HospitalMiniMap(hospital: hospital),
        if (hospital.hasCoordinates) const SizedBox(height: 12),
        // "저장(bookmark)"과는 별개인 지정(단골) 병원 등록. 글자 라벨이 있는
        // 칩으로 확실히 눈에 띄게 하고 눌렀을 때 스낵바로 확인해준다.
        FilterChip(
          avatar: Icon(isDesignated ? Icons.push_pin : Icons.push_pin_outlined, size: 18, color: AppColors.primary),
          showCheckmark: false,
          label: Text(isDesignated ? '지정 병원' : '지정 병원으로 등록'),
          selected: isDesignated,
          onSelected: (_) => _toggleDesignated(context, ref),
        ),
      ],
    );
  }

  void _toggleDesignated(BuildContext context, WidgetRef ref) {
    ref.read(designatedHospitalsProvider.notifier).toggle(hospital.id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(isDesignated ? '지정 병원에서 해제했어요.' : '지정 병원으로 등록했어요. 진료기록·예약을 쓸 때 맨 위에 나와요.')));
  }
}

/// 행동 — [전화하기] 큰 주요 버튼(56dp) 한 줄 + 아래 흰 카드 버튼 3칸
/// [길찾기] [리뷰·영업시간] [비교 담기]. 전화번호가 없으면 큰 버튼이 "전화번호
/// 찾기"(네이버 지도 검색, 2차 업데이트 G). 예약·제휴 없음 고지는 이용안내.
class _ActionRow extends StatelessWidget {
  final Hospital hospital;
  final bool isInCompare;
  final VoidCallback onCompareTap;

  const _ActionRow({required this.hospital, required this.isInCompare, required this.onCompareTap});

  @override
  Widget build(BuildContext context) {
    final hasPhone = ExternalLinks.sanitizedPhone(hospital.phone) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hasPhone
            ? FilledButton.icon(
                onPressed: () => ExternalLinks.call(context, hospital.phone),
                icon: const Icon(Icons.call_outlined),
                label: const Text('전화하기'),
              )
            : FilledButton.icon(
                onPressed: () => ExternalLinks.openNaverMapReviews(hospital),
                icon: const Icon(Icons.phone_in_talk_outlined),
                label: const Text('전화번호 찾기'),
              ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.navigation_outlined,
                label: '길찾기',
                onTap: () => ExternalLinks.openDirections(hospital),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: Icons.schedule_outlined,
                label: '리뷰·영업시간',
                onTap: () => ExternalLinks.openNaverMapReviews(hospital),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: isInCompare ? Icons.check_circle_outline : Icons.view_column_outlined,
                label: isInCompare ? '비교에 담음' : '비교 담기',
                active: isInCompare,
                onTap: onCompareTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          '리뷰와 영업시간은 네이버지도에서 열려요. 펫클은 병원을 평가하지 않아요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
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

  const _ActionButton({required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primarySoft : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: active
            ? const BorderSide(color: AppColors.primary, width: 2)
            : const BorderSide(color: AppColors.borderCard),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        child: SizedBox(
          height: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "이 병원의 기록" — 수첩 줄 모양: 왼쪽 항목명(회색) · 가운데 점선 · 오른쪽
/// 값(굵게). 문 연 날(개설신고일), 운영 기간, 등록 상태, 전화. 아래 출처·최종
/// 갱신일과 "운영 기간 ≠ 신뢰도" 안내.
class _RecordSection extends StatelessWidget {
  final Hospital hospital;
  final String source;
  final DateTime? generatedAt;

  const _RecordSection({required this.hospital, required this.source, this.generatedAt});

  static String _fmt(DateTime? d) => d != null ? DateFormat('yyyy.MM.dd').format(d) : '확인 불가';

  @override
  Widget build(BuildContext context) {
    final statusLabel = hospital.status == HospitalStatus.open ? '영업 중' : hospital.status.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('이 병원의 기록'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.cardLarge, 10, AppSpacing.cardLarge, AppSpacing.cardLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NotebookRow('문 연 날 (개설신고일)', _fmt(hospital.openDate)),
                _NotebookRow('운영 기간', hospitalOperatingLabel(hospital)),
                _NotebookRow('등록 상태', statusLabel),
                // 표시만 하이픈 형식으로 — 전화 걸기는 저장된 원래 값으로.
                if (hospital.phone != null) _NotebookRow('전화', formatPhoneNumber(hospital.phone!)),
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.borderMuted),
                const SizedBox(height: 12),
                Text(
                  '출처 $source · 최종 갱신 ${_fmt(generatedAt)}',
                  style: AppTextStyles.mono(size: 13, color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  '운영 기간은 공개된 인허가 기록상 계속 등록된 시점을 기준으로 계산한 값이며, '
                  '병원의 신뢰도나 진료 품질과는 관련이 없습니다.',
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    );
  }
}

/// 수첩 줄 한 칸 — 항목명 · 점선(notebookLine) · 값.
class _NotebookRow extends StatelessWidget {
  final String label;
  final String value;

  const _NotebookRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          const Expanded(child: _DottedLine()),
          const SizedBox(width: 8),
          Flexible(
            flex: 0,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.mono(size: 16, weight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedLine extends StatelessWidget {
  const _DottedLine();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(double.infinity, 2), painter: _DotsPainter());
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.notebookLine;
    const step = 4.0;
    for (var x = 1.0; x < size.width; x += step) {
      canvas.drawCircle(Offset(x, size.height / 2), 0.9, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 맨 아래 외부 지도 — 네이버지도·카카오맵 흰 알약 2개(리뷰는 외부에서만).
class _ExternalLinksSection extends StatelessWidget {
  final Hospital hospital;

  const _ExternalLinksSection({required this.hospital});

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 52),
      backgroundColor: AppColors.surfaceLight,
      foregroundColor: AppColors.textPrimary,
      side: const BorderSide(color: AppColors.borderCard),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: style,
                onPressed: () => ExternalLinks.openNaverMapReviews(hospital),
                child: const Text('네이버지도에서 보기'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                style: style,
                onPressed: () => ExternalLinks.openKakaoMapReviews(hospital),
                child: const Text('카카오맵에서 보기'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: ExternalLinks.openAnimalProtectionSystem,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('국가동물보호정보시스템'),
          ),
        ),
      ],
    );
  }
}
