import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/hospital.dart';
import '../providers/bundle_provider.dart';
import '../providers/compare_provider.dart';
import '../theme/app_colors.dart';
import '../utils/external_links.dart';
import '../widgets/mascot_message.dart';
import '../widgets/status_badge.dart';

const double _labelColumnWidth = 104;
const double _valueColumnWidth = 148;

class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compareIds = ref.watch(compareListProvider);
    final bundle = ref.watch(bundleProvider).value;

    final hospitals = compareIds
        .map((id) => ref.watch(hospitalByIdProvider(id)))
        .whereType<Hospital>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('비교'),
        actions: [
          if (hospitals.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(compareListProvider.notifier).clear(),
              child: const Text('전체 비우기'),
            ),
        ],
      ),
      body: hospitals.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: MascotMessage(
                  title: '비교할 병원을 먼저 담아주세요',
                  subtitle: '검색 결과나 병원 상세에서 "비교 추가"를 눌러 담을 수 있어요',
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderRow(hospitals: hospitals),
                    const Divider(height: 24),
                    _CompareRow(
                      label: '상태',
                      tooltip: '영업 여부는 공개된 인허가 데이터를 기준으로 표시됩니다.',
                      hospitals: hospitals,
                      valueBuilder: (h) => h.status.label,
                    ),
                    _CompareRow(
                      label: '운영기간',
                      tooltip: '계속 등록된 기간을 나타내는 값으로, 신뢰도나 진료 품질과는 관련이 없습니다.',
                      hospitals: hospitals,
                      valueBuilder: (h) => h.operatingPeriodLabel,
                    ),
                    _CompareRow(
                      label: '개설일',
                      tooltip: '최초 개설신고일입니다.',
                      hospitals: hospitals,
                      valueBuilder: (h) =>
                          h.openDate != null ? DateFormat('yyyy.MM.dd').format(h.openDate!) : '확인 불가',
                    ),
                    _CompareRow(
                      label: '동일주소기록',
                      tooltip: '동일 주소에서 확인된 인허가 기록 수입니다. 운영자가 동일하다는 의미는 아닙니다.',
                      hospitals: hospitals,
                      valueBuilder: (h) => '${bundle?.sameAddressRecordCount(h) ?? 1}건',
                    ),
                    _CompareRow(
                      label: '갱신일',
                      tooltip: '데이터가 마지막으로 갱신된 날짜입니다.',
                      hospitals: hospitals,
                      valueBuilder: (h) => bundle?.generatedAt != null
                          ? DateFormat('yyyy.MM.dd').format(bundle!.generatedAt!)
                          : '확인 불가',
                    ),
                    const SizedBox(height: 16),
                    _ActionsRow(hospitals: hospitals),
                  ],
                ),
              ),
            ),
    );
  }
}

class _HeaderRow extends ConsumerWidget {
  final List<Hospital> hospitals;

  const _HeaderRow({required this.hospitals});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: _labelColumnWidth),
        for (final h in hospitals)
          SizedBox(
            width: _valueColumnWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          h.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () =>
                            ref.read(compareListProvider.notifier).remove(h.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  StatusBadge(status: h.status),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final String tooltip;
  final List<Hospital> hospitals;
  final String Function(Hospital) valueBuilder;

  const _CompareRow({
    required this.label,
    required this.tooltip,
    required this.hospitals,
    required this.valueBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _labelColumnWidth,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 2),
                Tooltip(
                  message: tooltip,
                  triggerMode: TooltipTriggerMode.tap,
                  child: Icon(Icons.help_outline, size: 14, color: AppColors.neutral),
                ),
              ],
            ),
          ),
          for (final h in hospitals)
            SizedBox(
              width: _valueColumnWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(valueBuilder(h), style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  final List<Hospital> hospitals;

  const _ActionsRow({required this.hospitals});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: _labelColumnWidth),
        for (final h in hospitals)
          SizedBox(
            width: _valueColumnWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  OutlinedButton(
                    onPressed: () => ExternalLinks.call(context, h.phone),
                    child: const Text('전화'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ExternalLinks.openDirections(h),
                    child: const Text('길찾기'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
