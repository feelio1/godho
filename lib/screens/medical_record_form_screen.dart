import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/effective_record_actions.dart';
import '../models/medical_record.dart';
import '../models/pet.dart';
import '../providers/effective_pets_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../utils/appointment_calendar.dart';
import '../utils/network_error.dart';
import '../utils/record_appointment_flow.dart';
import '../widgets/date_picker_sheet.dart';
import '../widgets/form_field_label.dart';
import '../widgets/hospital_picker_field.dart';
import '../widgets/photo_attach_field.dart';
import '../widgets/picker_sheet_chrome.dart';
import 'appointment_form_screen.dart';

String _newLocalId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 31)}';

/// 방문 목적 분류 칩("펫클 앱 디자인" 캔버스 시안 RecordForm.dc.html) —
/// [MedicalRecord.category]는 여전히 자유 입력 문자열이라, 칩은 그 값을
/// 빠르게 채워주는 단축 입력일 뿐이다.
const _categoryChoices = ['진찰', '백신', '검사', '영상', '입원', '기타'];

/// 진료/방문 기록 추가·수정 폼(스프린트 8 지시서 2, 스프린트 9에서 필드
/// 라벨·사진 첨부 UI 개선). 병원은 우리 DB에서 검색해 고르거나 직접 입력할
/// 수 있다. 몸무게·진료비는 기록으로만 남기고 판정·평가 문구는 어디에도
/// 붙이지 않는다(건강·안전 원칙).
class MedicalRecordFormScreen extends ConsumerStatefulWidget {
  final String petId;
  final MedicalRecord? existing;

  /// 새 기록의 방문일 초기값(수정 시엔 무시) — 캘린더에서 과거 날짜를
  /// 골라 "그 날짜로 진료기록 추가"할 때 쓴다("캘린더 하단탭화 + 진료
  /// 연대기" 지시서 3). 생략하면 기존과 같이 오늘 날짜로 시작한다.
  final DateTime? initialDate;

  /// 예약 폼에서 세그먼트로 전환해 넘어올 때 함께 들고 오는 입력값
  /// (수정 시엔 무시) — "진료기록·예약 통합 입력" 지시서 3. [existing]이
  /// 있으면 이 값들은 쓰지 않는다.
  final String? initialHospitalId;
  final String? initialHospitalName;
  final String? initialMemo;
  final String? initialCategory;

  const MedicalRecordFormScreen({
    super.key,
    required this.petId,
    this.existing,
    this.initialDate,
    this.initialHospitalId,
    this.initialHospitalName,
    this.initialMemo,
    this.initialCategory,
  });

  @override
  ConsumerState<MedicalRecordFormScreen> createState() => _MedicalRecordFormScreenState();
}

class _MedicalRecordFormScreenState extends ConsumerState<MedicalRecordFormScreen> {
  late DateTime _date;
  late String _petId;
  late final TextEditingController _hospitalController;
  late final TextEditingController _memoController;
  late final TextEditingController _weightController;
  late final TextEditingController _costController;
  late final TextEditingController _categoryController;
  String? _selectedHospitalId;
  String? _selectedCategoryChip;
  String? _photoPath;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _date = existing?.date ?? widget.initialDate ?? DateTime.now();
    _petId = widget.petId;
    _hospitalController =
        TextEditingController(text: existing?.hospitalName ?? widget.initialHospitalName ?? '');
    _memoController = TextEditingController(text: existing?.memo ?? widget.initialMemo ?? '');
    _weightController = TextEditingController(text: existing?.weightKg?.toString() ?? '');
    _costController = TextEditingController(text: existing?.costWon?.toString() ?? '');
    _categoryController =
        TextEditingController(text: existing?.category ?? widget.initialCategory ?? '');
    _selectedHospitalId = existing?.hospitalId ?? widget.initialHospitalId;
    _photoPath = existing?.photoPath;

    final initialCategory = existing?.category ?? widget.initialCategory ?? '';
    if (initialCategory.isEmpty) {
      _selectedCategoryChip = null;
    } else if (_categoryChoices.contains(initialCategory) && initialCategory != '기타') {
      _selectedCategoryChip = initialCategory;
    } else {
      _selectedCategoryChip = '기타';
    }
  }

  @override
  void dispose() {
    _hospitalController.dispose();
    _memoController.dispose();
    _weightController.dispose();
    _costController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  /// 수정 모드에서는 기존 기록 수정 의미를 유지해 범위를 과거~오늘로
  /// 두지만, 새 기록은 예약 폼과 같은 범위(5년 뒤까지)까지 고를 수 있다 —
  /// 미래 날짜를 고르면 저장 직전이 아니라 여기서 바로 예약 폼으로
  /// 넘어간다(미래 날짜 진료기록 저장 금지, "진료기록·예약 통합 입력"
  /// 지시서 1, 하지 말 것).
  Future<void> _pickDate() async {
    final isNew = widget.existing == null;
    final picked = await showAppDatePickerSheet(
      context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: isNew ? DateTime(_date.year + 5) : DateTime.now(),
    );
    if (picked == null) return;
    if (isNew && isFutureDay(picked)) {
      await _switchToAppointment(targetDate: picked, dateDriven: true);
      return;
    }
    setState(() => _date = picked);
  }

  /// 체중·비용·사진 중 하나라도 입력돼 있으면 예약으로 넘어갈 때
  /// 버려진다는 확인을 먼저 받는다("진료기록·예약 통합 입력" 지시서 3).
  bool get _hasRecordOnlyData =>
      _weightController.text.trim().isNotEmpty ||
      _costController.text.trim().isNotEmpty ||
      _photoPath != null;

  Future<void> _switchToAppointment({DateTime? targetDate, bool dateDriven = false}) async {
    if (_hasRecordOnlyData) {
      final confirmed =
          await confirmKindSwitch(context, '체중·비용·사진은 예약에 저장되지 않아요. 계속할까요?');
      if (!confirmed) return;
    }
    if (!mounted) return;
    // 날짜를 미래로 바꿔서 자동으로 넘어가는 경우만 왜 바뀌었는지 짧게
    // 안내한다 — 세그먼트를 직접 눌러 넘어갈 땐 의도한 전환이라 안내가
    // 필요 없다("진료기록·예약 통합 입력" 지시서 2).
    if (dateDriven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('미래 날짜라 예약으로 저장돼요')),
      );
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AppointmentFormScreen(
          petId: _petId,
          initialDate: targetDate ?? _date,
          initialHospitalId: _selectedHospitalId,
          initialHospitalName: _hospitalController.text.trim(),
          initialMemo: _memoController.text.trim(),
          initialReason: _categoryController.text.trim(),
        ),
      ),
    );
  }

  Future<void> _pickPet(List<Pet> pets) async {
    if (pets.length < 2) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PickerSheetChrome(
        title: '반려동물 선택',
        heightFactor: 0.4,
        child: ListView(
          children: [
            for (final pet in pets)
              ListTile(
                leading: const Icon(Icons.pets, color: AppColors.primary),
                title: Text(pet.name),
                trailing: pet.id == _petId ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.of(context).pop(pet.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _petId = picked);
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        setState(() => _photoPath = picked.path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진을 불러오지 못했습니다.')),
        );
      }
    }
  }

  Future<void> _save() async {
    final hospitalName = _hospitalController.text.trim();
    if (hospitalName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('병원 이름을 입력하거나 검색해서 선택해주세요.')),
      );
      return;
    }
    final weight = double.tryParse(_weightController.text.trim());
    final cost = int.tryParse(_costController.text.trim().replaceAll(',', ''));

    final record = MedicalRecord(
      id: widget.existing?.id ?? _newLocalId(),
      petId: _petId,
      date: _date,
      hospitalId: _selectedHospitalId,
      hospitalName: hospitalName,
      memo: _memoController.text.trim(),
      weightKg: weight,
      costWon: cost,
      category: _categoryController.text.trim(),
      photoPath: _photoPath,
    );
    try {
      // 반려동물이 계정(로그인) 것이면 Firestore, 게스트/로컬이면 기존
      // 로컬 저장소로 — 어느 쪽이든 이 한 줄로 갈린다("진료기록·예약
      // Firestore 저장" 지시서 B-2).
      await EffectiveRecordActions.upsert(ref, record, isNew: widget.existing == null);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(actionFailureMessage(e, '저장'))),
        );
      }
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    try {
      await EffectiveRecordActions.delete(ref, _petId, existing.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(actionFailureMessage(e, '삭제'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로그인 상태면 계정(Firestore) 반려동물, 게스트면 로컬 반려동물 —
    // 진료기록 화면과 같은 소스를 써서 선택되는 반려동물이 항상 일치한다
    // (펫클 3단계 지시서 2).
    final pets = ref.watch(effectivePetsProvider).value ?? const <Pet>[];
    final currentPet = pets.where((p) => p.id == _petId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '기록·예약 추가' : '진료 기록 수정'),
        actions: [
          if (widget.existing != null)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            // 수정 모드에서는 종류를 바꿀 수 없다(기존 기록/예약을 바꾸고
            // 싶으면 삭제 후 새로 추가) — 세그먼트 자체를 숨긴다
            // ("진료기록·예약 통합 입력" 지시서 4). 날짜가 과거면 "예약"
            // 옵션을 막는다 — 미래 날짜에서 "진료기록"을 막은 것과
            // 대칭으로, 과거 날짜 예약도 만들 수 없게 한다("판단 콜
            // 답변" 지시서).
            if (widget.existing == null) ...[
              SegmentedButton<RecordOrAppointmentKind>(
                segments: [
                  const ButtonSegment(value: RecordOrAppointmentKind.record, label: Text('진료기록')),
                  ButtonSegment(
                    value: RecordOrAppointmentKind.appointment,
                    label: const Text('예약'),
                    enabled: !isPastDay(_date),
                  ),
                ],
                selected: const {RecordOrAppointmentKind.record},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  if (selection.first == RecordOrAppointmentKind.appointment) {
                    _switchToAppointment();
                  }
                },
              ),
              const SizedBox(height: AppSpacing.formField),
            ],
            const FormFieldLabel('반려동물'),
            InkWell(
              onTap: () => _pickPet(pets),
              borderRadius: BorderRadius.circular(AppRadius.field),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pets, size: 18, color: AppColors.textPlaceholder),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        currentPet?.name ?? '반려동물 없음',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                    if (pets.length > 1)
                      const Icon(Icons.expand_more, size: 18, color: AppColors.textPlaceholder),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.formField),
            const FormFieldLabel('병원'),
            HospitalPickerField(
              controller: _hospitalController,
              selectedHospitalId: _selectedHospitalId,
              showSuggestions: _showSuggestions,
              onTextChanged: (_) => setState(() {
                _selectedHospitalId = null;
                _showSuggestions = true;
              }),
              onHospitalSelected: (h) => setState(() {
                _selectedHospitalId = h.id;
                _hospitalController.text = h.name;
                _showSuggestions = false;
              }),
              onSelectionCleared: () => setState(() => _selectedHospitalId = null),
              onFieldTapped: () => setState(() => _showSuggestions = true),
            ),
            const SizedBox(height: AppSpacing.formField),
            const FormFieldLabel('방문일'),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppRadius.field),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textPlaceholder),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('yyyy.MM.dd').format(_date),
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.formField),
            const FormFieldLabel('방문 목적'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categoryChoices
                  .map((choice) => ChoiceChip(
                        label: Text(choice),
                        selected: _selectedCategoryChip == choice,
                        onSelected: (_) => setState(() {
                          _selectedCategoryChip = choice;
                          if (choice == '기타') {
                            if (_categoryChoices.contains(_categoryController.text)) {
                              _categoryController.clear();
                            }
                          } else {
                            _categoryController.text = choice;
                          }
                        }),
                      ))
                  .toList(),
            ),
            if (_selectedCategoryChip == '기타') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _categoryController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: '방문 목적을 입력해주세요'),
              ),
            ],
            const SizedBox(height: AppSpacing.formField),
            const FormFieldLabel('진료 내용'),
            TextField(
              controller: _memoController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: '어떤 진료를 받았는지 남겨보세요'),
            ),
            const SizedBox(height: AppSpacing.formField),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FormFieldLabel('몸무게'),
                      TextField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: '0.0',
                          suffixText: 'kg',
                          suffixStyle: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FormFieldLabel('진료비'),
                      TextField(
                        controller: _costController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '0',
                          suffixText: '원',
                          suffixStyle: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.formField),
            PhotoAttachField(
              photoPath: _photoPath,
              onPick: _pickPhoto,
              onClear: () => setState(() => _photoPath = null),
            ),
            const SizedBox(height: 28),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: const Text('저장'))),
          ],
        ),
      ),
    );
  }
}
