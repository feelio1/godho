import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../ads/global_banner_ad.dart';
import '../data/hospital_repository.dart';
import '../models/hospital.dart';
import '../models/region_filter.dart';
import '../providers/bundle_provider.dart';
import '../providers/designated_provider.dart';
import '../providers/location_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/recent_provider.dart';
import '../providers/region_provider.dart';
import '../providers/saved_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../widgets/brand_mark.dart';
import '../widgets/designated_hospital_card.dart';
import '../widgets/fee_summary_card.dart';
import '../widgets/home_banner.dart';
import '../widgets/hospital_card.dart';
import '../widgets/search_set_card.dart';
import 'detail_screen.dart';
import 'info_screens.dart';
import 'region_select_screen.dart';
import 'search_result_screen.dart';

/// 오래 운영된 병원 섹션에 들어가는 최소 운영 연수 기준. 사실 기준일 뿐
/// "오래됨=좋음" 같은 서사를 담지 않는다(CLAUDE.md 원칙 2).
const int _longOperatingYearsThreshold = 20;

/// 홈 각 리스트 섹션에 보여줄 최대 개수. "내 주변 가까운 병원"은 5개 +
/// "전체 병원 보기"로 안내하고, 가로 스크롤 섹션들은 조금 더 넉넉히 둔다.
const int _nearbyMaxItems = 5;
const int _horizontalSectionMaxItems = 10;

/// Only ever mounted once [MainShell] has confirmed the bundle is loaded.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
      body: const _HomeBody(),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('설정'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.source_outlined),
              title: const Text('출처'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SourcesScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('이용안내'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GuideScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 홈 화면 본문(스프린트 13 지시서 2 — 병원 리스트 섹션을 세로로 채워
/// 스크롤감 있게 재구성, 스프린트 14 — Petcli 시안으로 브랜드 헤더·검색
/// 세트 카드 도입). 브랜드 헤더 → 검색 세트 카드 → 배너 → 지정 병원 →
/// 내 주변 가까운 병원 → 운영 20년 이상 병원 → 최근 개원한 병원 → 최근
/// 확인한 병원 → 저장한 병원 순. 각 섹션은 데이터가 없으면 조용히 숨는다
/// — "추천/베스트" 같은 평가 표현 없이 정렬 기준(가까운 순/오래 운영된
/// 순/최근 개원 순)만 사실로 표기한다.
class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  Future<void> _changeRegion(BuildContext context, WidgetRef ref) async {
    final result = await showRegionPickerSheet(context);
    if (result != null) {
      await ref.read(regionProvider.notifier).selectRegion(result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final savedIds = ref.watch(savedHospitalsProvider).value ?? const [];
    final designatedIds = ref.watch(designatedHospitalsProvider).value ?? const [];
    final recentIds = ref.watch(recentHospitalsProvider).value ?? const [];
    final region = ref.watch(regionProvider).value?.filter ?? const RegionFilter.all();
    final location = ref.watch(locationProvider).value;

    final savedHospitals = savedIds.map(repo.byId).whereType<Hospital>().toList();
    final designatedHospitals = designatedIds.map(repo.byId).whereType<Hospital>().toList();
    final recentHospitals = recentIds.map(repo.byId).whereType<Hospital>().toList();

    // 선택 지역(전체 포함) 안의 영업중 병원 — 아래 세 섹션이 공유하는
    // 기본 후보군. 폐업 병원은 검색 화면의 "폐업 병원도 보기"에서만 다룬다.
    final regionOpenHospitals = repo.filterByStatus(
      repo.filterByRegion(repo.all, region),
      includeClosed: false,
    );

    final nearbyHospitals = repo.sortHospitals(
      regionOpenHospitals,
      SortOption.distance,
      currentLat: location?.latitude,
      currentLng: location?.longitude,
    );

    final longOperatingHospitals = repo
        .sortHospitals(regionOpenHospitals, SortOption.operatingLength)
        .where((h) => (h.operatingYears ?? -1) >= _longOperatingYearsThreshold)
        .toList();

    final recentlyOpenedHospitals = repo.sortHospitals(regionOpenHospitals, SortOption.recentOpen);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 28),
      children: [
        const _BrandHeader(),
        const SizedBox(height: AppSpacing.section),
        SearchSetCard(
          hintText: '병원명 또는 주소로 검색',
          onFieldTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SearchResultScreen()),
          ),
          region: region,
          sidoOptions: repo.sidoList,
          onSelectRegion: (filter) => ref.read(regionProvider.notifier).selectRegion(filter),
          onOpenRegionPicker: () => _changeRegion(context, ref),
        ),
        const SizedBox(height: AppSpacing.section),
        const FeeSummaryCard(),
        const SizedBox(height: AppSpacing.section),
        const HomeBanner(),
        const SizedBox(height: AppSpacing.section),
        const GlobalBannerAd(inline: true),
        if (designatedHospitals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          _DesignatedHospitalsSection(hospitals: designatedHospitals),
        ],
        const SizedBox(height: AppSpacing.section),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // "내 주변 병원" 최초 사용 시 위치 권한을 요청한다
              // (CLAUDE.md: 앱 시작 시 강제 요청 금지).
              ref.read(locationProvider.notifier).requestAndFetch();
              ref.read(selectedTabProvider.notifier).state = 1;
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('지도에서 보기'),
          ),
        ),
        if (nearbyHospitals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          _NearbyHospitalsSection(hospitals: nearbyHospitals, location: location),
        ],
        if (longOperatingHospitals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          _HospitalSection(
            title: '운영 $_longOperatingYearsThreshold년 이상 병원',
            hospitals: longOperatingHospitals.take(_horizontalSectionMaxItems).toList(),
            location: location,
          ),
        ],
        if (recentlyOpenedHospitals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          _HospitalSection(
            title: '최근 개원한 병원',
            hospitals: recentlyOpenedHospitals.take(_horizontalSectionMaxItems).toList(),
            location: location,
          ),
        ],
        if (recentHospitals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          _HospitalSection(
            title: '최근 확인한 병원',
            hospitals: recentHospitals,
            location: location,
          ),
        ],
        if (savedHospitals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          _HospitalSection(
            title: '저장한 병원',
            hospitals: savedHospitals,
            location: location,
          ),
        ],
      ],
    );
  }
}

/// 브랜드 헤더 — "Petcli" 워드마크 + 한 줄 부제. 앱이 무엇인지(공개된
/// 사실을 확인하는 팩트체크 앱)만 담백하게 설명하고, 어떤 평가·추천
/// 표현도 쓰지 않는다(CLAUDE.md 원칙 1).
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BrandMark(fontSize: 25),
        SizedBox(height: 4),
        Text(
          '동물병원의 공개된 행정·가격 정보를 확인하세요',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// "내 주변 가까운 병원" — 세로 리스트 카드 [_nearbyMaxItems]개 + 전체
/// 보기(스프린트 13 지시서 2 신규 섹션). 위치가 없으면 선택 지역 기준
/// 목록을 그대로 보여준다(거리 정렬은 위치가 있을 때만 의미가 있음 —
/// `HospitalRepository.sortHospitals`가 이미 이 경우를 안전하게 처리한다).
class _NearbyHospitalsSection extends ConsumerWidget {
  final List<Hospital> hospitals;
  final Position? location;

  const _NearbyHospitalsSection({required this.hospitals, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(bundleProvider).value;
    final hasLocation = location != null;
    final visible = hospitals.take(_nearbyMaxItems).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('내 주변 가까운 병원', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        ...visible.map((hospital) {
          final distance = HospitalRepository.distanceKm(
            location?.latitude,
            location?.longitude,
            hospital.lat,
            hospital.lng,
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: HospitalCard(
              hospital: hospital,
              sameAddressRecordCount: bundle?.sameAddressRecordCount(hospital) ?? 1,
              distanceKm: distance,
              hasUserLocation: hasLocation,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DetailScreen(hospitalId: hospital.id)),
              ),
            ),
          );
        }),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchResultScreen()),
            ),
            child: const Text('전체 병원 보기'),
          ),
        ),
      ],
    );
  }
}

/// 홈 상단 "지정 병원" 섹션 — 사용자가 지정한 단골 병원을 카드로 보여주고
/// 카드에서 바로 전화·길찾기·상세로 이동할 수 있다(스프린트 8 지시서 1).
/// 영업시간·실시간 영업여부는 표시하지 않는다(데이터 없음, 추정 금지).
class _DesignatedHospitalsSection extends StatelessWidget {
  final List<Hospital> hospitals;

  const _DesignatedHospitalsSection({required this.hospitals});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('지정 병원', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        ...hospitals.map(
          (hospital) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DesignatedHospitalCard(
              hospital: hospital,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DetailScreen(hospitalId: hospital.id)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HospitalSection extends ConsumerWidget {
  final String title;
  final List<Hospital> hospitals;
  final Position? location;

  const _HospitalSection({
    required this.title,
    required this.hospitals,
    required this.location,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(bundleProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: hospitals.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final hospital = hospitals[index];
              final distance = HospitalRepository.distanceKm(
                location?.latitude,
                location?.longitude,
                hospital.lat,
                hospital.lng,
              );
              return SizedBox(
                width: 260,
                child: HospitalCard(
                  hospital: hospital,
                  sameAddressRecordCount: bundle?.sameAddressRecordCount(hospital) ?? 1,
                  distanceKm: distance,
                  hasUserLocation: location != null,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => DetailScreen(hospitalId: hospital.id)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
