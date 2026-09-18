import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hospital_repository.dart';
import '../models/hospital.dart';
import '../models/hospital_status.dart';
import '../providers/bundle_provider.dart';
import '../providers/location_provider.dart';
import '../providers/saved_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../widgets/hospital_card.dart';
import '../widgets/mascot_image.dart';
import '../widgets/mascot_message.dart';
import 'detail_screen.dart';

enum _SavedFilter { all, open, closed }

/// 저장 화면(스프린트 14, Petcli 시안 07): 저장 목록은 그대로 두고,
/// 전체/영업중/폐업으로 화면에서만 걸러 보는 세그먼트를 얹었다 — 이미
/// 불러온 저장 목록을 상태값으로 나누는 순수 화면 표시 로직이라, 저장
/// 기능 자체(`savedHospitalsProvider`)는 전혀 건드리지 않는다.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  _SavedFilter _filter = _SavedFilter.all;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final bundle = ref.watch(bundleProvider).value;
    final savedAsync = ref.watch(savedHospitalsProvider);
    final location = ref.watch(locationProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('저장')),
      body: savedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('불러오지 못했습니다: $error')),
        data: (savedIds) {
          final hospitals = savedIds.map(repo.byId).whereType<Hospital>().toList();
          if (hospitals.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: MascotMessage(
                  title: '저장한 병원이 없습니다',
                  subtitle: '관심 있는 병원을 저장하면 여기서 바로 확인할 수 있어요',
                  assetPath: MascotImage.emptyRecordAssetPath,
                  overlayIcon: Icons.bookmark_outline,
                ),
              ),
            );
          }

          final filtered = hospitals.where((h) {
            switch (_filter) {
              case _SavedFilter.all:
                return true;
              case _SavedFilter.open:
                return h.status != HospitalStatus.closed;
              case _SavedFilter.closed:
                return h.status == HospitalStatus.closed;
            }
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: _SavedFilterSegment(
                  selected: _filter,
                  onChanged: (value) => setState(() => _filter = value),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          '조건에 맞는 저장한 병원이 없습니다',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final hospital = filtered[index];
                          final distance = HospitalRepository.distanceKm(
                            location?.latitude,
                            location?.longitude,
                            hospital.lat,
                            hospital.lng,
                          );
                          return HospitalCard(
                            hospital: hospital,
                            sameAddressRecordCount: bundle?.sameAddressRecordCount(hospital) ?? 1,
                            distanceKm: distance,
                            hasUserLocation: location != null,
                            trailingIcon: Icons.bookmark,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => DetailScreen(hospitalId: hospital.id)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SavedFilterSegment extends StatelessWidget {
  final _SavedFilter selected;
  final ValueChanged<_SavedFilter> onChanged;

  const _SavedFilterSegment({required this.selected, required this.onChanged});

  static const _labels = {
    _SavedFilter.all: '전체',
    _SavedFilter.open: '영업중',
    _SavedFilter.closed: '폐업',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: _SavedFilter.values.map((f) {
          final isSelected = f == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surfaceLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected ? AppShadows.segment : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  _labels[f]!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppColors.primaryTextTone : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
