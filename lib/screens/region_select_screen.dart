import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/bundle_provider.dart';
import '../models/region_filter.dart';

/// 시/도 목록 -> 시군구 목록. Region values are read from
/// [HospitalRepository.sidoList]/[sigunguListFor], which are extracted from
/// the actual data at load time — nothing here is hardcoded
/// (스프린트 2 지시서 2: "하드코딩 금지").
class RegionSelectScreen extends ConsumerWidget {
  const RegionSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final sidoList = repo.sidoList;

    return Scaffold(
      appBar: AppBar(title: const Text('지역 선택')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('전체'),
            subtitle: const Text('지역을 좁히지 않고 전국에서 검색합니다'),
            onTap: () => Navigator.of(context).pop(const RegionFilter.all()),
          ),
          const Divider(height: 1),
          for (final sido in sidoList)
            ListTile(
              title: Text(sido),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await Navigator.of(context).push<RegionFilter>(
                  MaterialPageRoute(
                    builder: (_) => _SigunguSelectScreen(
                      sido: sido,
                      sigunguList: repo.sigunguListFor(sido),
                    ),
                  ),
                );
                if (result != null && context.mounted) {
                  Navigator.of(context).pop(result);
                }
              },
            ),
        ],
      ),
    );
  }
}

class _SigunguSelectScreen extends StatelessWidget {
  final String sido;
  final List<String> sigunguList;

  const _SigunguSelectScreen({required this.sido, required this.sigunguList});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(sido)),
      body: ListView(
        children: [
          ListTile(
            title: Text('$sido 전체'),
            onTap: () => Navigator.of(context).pop(RegionFilter(sido: sido)),
          ),
          const Divider(height: 1),
          for (final sigungu in sigunguList)
            ListTile(
              title: Text(sigungu),
              onTap: () => Navigator.of(context)
                  .pop(RegionFilter(sido: sido, sigungu: sigungu)),
            ),
        ],
      ),
    );
  }
}
