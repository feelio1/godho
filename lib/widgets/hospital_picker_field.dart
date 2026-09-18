import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hospital.dart';
import '../providers/bundle_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// 병원 이름 입력 필드 — 우리 DB에서 검색해 고르거나 이름을 직접 입력할 수
/// 있다. 진료기록·예약 두 폼이 함께 쓴다(스프린트 8에서 진료기록 폼에
/// 처음 만들었던 검색 로직을 스프린트 9에서 공용 위젯으로 뺐다 — "필드
/// 라벨 명확히" 지시를 두 폼에 동시에 반영하기 위함).
///
/// 상태(입력 텍스트, 선택된 병원 id)는 부모 화면이 들고 있고, 이 위젯은
/// 그 상태를 받아 그리기만 한다.
class HospitalPickerField extends ConsumerWidget {
  final TextEditingController controller;
  final String? selectedHospitalId;
  final bool showSuggestions;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<Hospital> onHospitalSelected;
  final VoidCallback onSelectionCleared;
  final VoidCallback onFieldTapped;

  const HospitalPickerField({
    super.key,
    required this.controller,
    required this.selectedHospitalId,
    required this.showSuggestions,
    required this.onTextChanged,
    required this.onHospitalSelected,
    required this.onSelectionCleared,
    required this.onFieldTapped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final query = controller.text.trim();
    final suggestions =
        showSuggestions && query.isNotEmpty ? repo.search(query).take(6).toList() : const <Hospital>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '병원 검색 또는 이름 직접 입력',
            prefixIcon: const Icon(Icons.storefront_outlined, size: 20, color: AppColors.textPlaceholder),
            suffixIcon: selectedHospitalId != null
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: '선택 해제하고 직접 입력',
                    onPressed: onSelectionCleared,
                  )
                : const Icon(Icons.expand_more, size: 18, color: AppColors.textPlaceholder),
          ),
          onChanged: onTextChanged,
          onTap: onFieldTapped,
        ),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              border: Border.all(color: AppColors.borderCard),
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: suggestions
                  .map((h) => ListTile(
                        dense: true,
                        title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          h.roadAddr,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        onTap: () => onHospitalSelected(h),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
