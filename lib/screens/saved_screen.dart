import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hospital.dart';
import '../providers/bundle_provider.dart';
import '../providers/saved_provider.dart';
import '../widgets/hospital_card.dart';
import 'detail_screen.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final bundle = ref.watch(bundleProvider).value;
    final savedAsync = ref.watch(savedHospitalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('저장')),
      body: savedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('불러오지 못했습니다: $error')),
        data: (savedIds) {
          final hospitals = savedIds.map(repo.byId).whereType<Hospital>().toList();
          if (hospitals.isEmpty) {
            return const Center(child: Text('저장한 병원이 없습니다.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: hospitals.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final hospital = hospitals[index];
              return HospitalCard(
                hospital: hospital,
                sameAddressRecordCount: bundle?.sameAddressRecordCount(hospital) ?? 1,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DetailScreen(hospitalId: hospital.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
