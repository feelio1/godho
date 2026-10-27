import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../data/app_settings.dart';
import '../../models/pet.dart';
import '../../notifications/notification_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/effective_pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../utils/appointment_calendar.dart' show dateOnly, isFutureDay;
import '../../utils/network_error.dart';
import '../../widgets/date_picker_sheet.dart';
import '../../widgets/form_field_label.dart';
import '../diary_daily_question.dart';
import '../diary_draft.dart';
import '../diary_photo_processor.dart';
import '../models/diary.dart';
import '../providers/diary_providers.dart';
import 'diary_weather_icons.dart';

/// 일기 사진 편집 중인 한 장 — 기존 사진(수정 중 그대로 두거나 뺄 수
/// 있음)과 새로 고른 파일(아직 올리지 않음)을 한 줄에서 함께 순서를
/// 바꿀 수 있게 하나의 타입으로 묻는다. 두 인스턴스를 비교할 일이 없어
/// `==`는 기본(식별자) 비교 그대로 쓴다 — [ReorderableListView]가 항목
/// 식별에 쓰는 키가 바로 이 동일성이다.
class _PhotoItem {
  final DiaryPhoto? existing;
  final File? newFile;

  const _PhotoItem.existing(DiaryPhoto photo)
      : existing = photo,
        newFile = null;

  const _PhotoItem.newFile(File file)
      : existing = null,
        newFile = file;
}

/// 일기 작성/수정 화면("방향 개편" 지시서 D). [existing]이 있으면 수정,
/// 없으면 새 작성 — [defaultPetIds]는 새 작성일 때만 쓰는 기본 선택
/// 반려동물(현재 "우리 아이" 탭에서 보고 있던 아이), [initialDate]는
/// 기본 날짜(생략하면 오늘 — 홈 "오늘의 일기 쓰기"에서 넘어올 때 쓴다,
/// "방향 개편" 지시서 F). [openGalleryOnStart]는 일기 세그먼트의 "+"
/// 버튼에서만 켠다 — 화면이 뜨자마자 갤러리 다중 선택을 바로 연다
/// ("일기 활성화" 지시서 D, 사진부터 시작). 임시저장(G)이 남아 있으면
/// 그 선택을 먼저 묻고, "새로 쓰기"를 골랐을 때만 갤러리를 연다.
class DiaryFormScreen extends ConsumerStatefulWidget {
  final Diary? existing;
  final List<String>? defaultPetIds;
  final DateTime? initialDate;
  final bool openGalleryOnStart;

  const DiaryFormScreen({
    super.key,
    this.existing,
    this.defaultPetIds,
    this.initialDate,
    this.openGalleryOnStart = false,
  });

  @override
  ConsumerState<DiaryFormScreen> createState() => _DiaryFormScreenState();
}

class _DiaryFormScreenState extends ConsumerState<DiaryFormScreen> {
  late DateTime _date;
  late final Set<String> _selectedPetIds;
  DiaryWeather? _weather;
  late final Set<DiaryActivity> _activities;
  late final TextEditingController _textController;
  late final List<_PhotoItem> _photoItems;
  bool _dirty = false;
  bool _saving = false;

  /// 사용자가 날짜를 직접 바꾼 뒤엔 사진 촬영일로 자동 바꾸지 않는다
  /// ("일기 활성화" 지시서 C). 수정 화면(기존 일기)은 이미 정해둔 날짜가
  /// 있으니 처음부터 자동 변경 대상에서 뺀다.
  bool get _dateAutoSuggestAllowed => widget.existing == null && !_dateManuallySet;
  bool _dateManuallySet = false;
  bool _showAutoDateNotice = false;

  /// 새 일기 작성 중에만 자동 임시저장한다("일기 활성화" 지시서 G) —
  /// 수정 화면은 이미 저장된 내용이 있어 대상이 아니다.
  static const _draftStore = DiaryDraftStore();
  Timer? _draftSaveTimer;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _date = existing?.date ?? widget.initialDate ?? DateTime.now();
    _selectedPetIds = {...(existing?.petIds ?? widget.defaultPetIds ?? const [])};
    _weather = existing?.weather;
    _activities = {...(existing?.activities ?? const [])};
    _textController = TextEditingController(text: existing?.text ?? '');
    _photoItems = [for (final p in existing?.photos ?? const <DiaryPhoto>[]) _PhotoItem.existing(p)];
    if (existing == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkDraftOnStart());
    }
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
    _scheduleDraftSave();
  }

  /// 화면이 뜬 직후(새 작성일 때만) 임시저장된 일기가 있는지 본다 — 있으면
  /// "이어쓰기/새로 쓰기"를 먼저 묻고, 그 뒤(또는 임시본이 없을 때) 사진부터
  /// 시작 요청([DiaryFormScreen.openGalleryOnStart])을 처리한다.
  Future<void> _checkDraftOnStart() async {
    final draft = await _draftStore.load();
    if (!mounted) return;
    if (draft == null) {
      if (widget.openGalleryOnStart) await _pickFromGallery();
      return;
    }
    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('작성 중이던 일기가 있어요'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('새로 쓰기')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('이어쓰기')),
        ],
      ),
    );
    if (!mounted) return;
    if (resume == true) {
      _restoreDraft(draft);
    } else {
      await _draftStore.clear();
      if (widget.openGalleryOnStart) await _pickFromGallery();
    }
  }

  /// 로컬 파일이 사라졌으면(예: 임시 캐시 정리) 그 사진만 빼고 나머지를
  /// 복원한다("일기 활성화" 지시서 G).
  void _restoreDraft(DiaryDraft draft) {
    setState(() {
      _date = draft.date;
      _selectedPetIds
        ..clear()
        ..addAll(draft.petIds);
      _weather = draft.weather;
      _activities
        ..clear()
        ..addAll(draft.activities);
      _textController.text = draft.text;
      _photoItems.addAll(
        draft.photoPaths.where((p) => File(p).existsSync()).map((p) => _PhotoItem.newFile(File(p))),
      );
      _dirty = true;
      _dateManuallySet = true;
    });
  }

  void _scheduleDraftSave() {
    if (widget.existing != null) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 800), _saveDraftNow);
  }

  Future<void> _saveDraftNow() async {
    if (!mounted) return;
    await _draftStore.save(DiaryDraft(
      date: _date,
      petIds: _selectedPetIds.toList(),
      weather: _weather,
      activities: _activities.toList(),
      text: _textController.text,
      photoPaths: [for (final p in _photoItems) if (p.newFile != null) p.newFile!.path],
    ));
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePickerSheet(
      context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      _dateManuallySet = true;
      _showAutoDateNotice = false;
    });
    _markDirty();
  }

  Future<void> _pickFromGallery() async {
    if (_photoItems.length >= kDiaryMaxPhotos) {
      _showPhotoLimitNotice();
      return;
    }
    try {
      // 리사이즈 전 원본에서 촬영일(EXIF)을 읽어야 하므로, 여기서는
      // 줄이지 않고 원본 그대로 받는다 — 업로드용 압축은 저장 시점에
      // 저장소(FirestoreDiaryRepository)가 맡는다("일기 활성화" 지시서
      // A·C).
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isEmpty || !mounted) return;
      final allowed = capPhotoAdditions(_photoItems.length, picked);
      final overflow = allowed.length < picked.length;
      final files = allowed.map((x) => File(x.path)).toList();
      setState(() => _photoItems.addAll(files.map(_PhotoItem.newFile)));
      _markDirty();
      if (overflow) _showPhotoLimitNotice();
      await _applyExifDateSuggestion(files);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사진을 불러오지 못했습니다.')));
      }
    }
  }

  Future<void> _pickFromCamera() async {
    if (_photoItems.length >= kDiaryMaxPhotos) {
      _showPhotoLimitNotice();
      return;
    }
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera);
      if (picked == null || !mounted) return;
      final file = File(picked.path);
      setState(() => _photoItems.add(_PhotoItem.newFile(file)));
      _markDirty();
      await _applyExifDateSuggestion([file]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사진을 불러오지 못했습니다.')));
      }
    }
  }

  /// 방금 고른 사진들의 EXIF 촬영일 중 가장 이른 날을 일기 날짜로
  /// 제안한다 — 미래 날짜거나 정보가 없으면(둘 다 없으면) 바꾸지 않는다
  /// ("일기 활성화" 지시서 C). 사용자가 날짜를 직접 바꾼 뒤·수정 화면에선
  /// 아예 시도하지 않는다.
  Future<void> _applyExifDateSuggestion(List<File> files) async {
    if (!_dateAutoSuggestAllowed) return;
    final captureDates = <DateTime?>[];
    for (final file in files) {
      try {
        captureDates.add(readDiaryPhotoCaptureDate(await file.readAsBytes()));
      } catch (_) {
        captureDates.add(null);
      }
    }
    final suggested = suggestDiaryDateFromCaptureDates(captureDates);
    if (suggested == null || !mounted || !_dateAutoSuggestAllowed) return;
    if (dateOnly(suggested) == dateOnly(_date)) return;
    setState(() {
      _date = suggested;
      _showAutoDateNotice = true;
    });
  }

  void _showPhotoLimitNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('사진은 최대 $kDiaryMaxPhotos장까지 추가할 수 있어요.')),
    );
  }

  void _removePhoto(_PhotoItem item) {
    setState(() => _photoItems.remove(item));
    _markDirty();
  }

  void _reorderPhotos(int oldIndex, int newIndex) {
    setState(() {
      final item = _photoItems.removeAt(oldIndex);
      _photoItems.insert(newIndex, item);
    });
    _markDirty();
  }

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text('작성 중인 내용이 있어요. 나가시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('계속 쓰기')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('나가기')),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _save() async {
    if (_selectedPetIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('반려동물을 선택해주세요.')));
      return;
    }
    // 날짜 선택 시트가 이미 미래 날짜를 못 고르게 막지만("방향 개편"
    // 지시서 D), 저장 시점에도 한 번 더 막는다(방어적 검증 — 피커를
    // 거치지 않는 경로가 생기더라도 미래 날짜가 저장되지 않게).
    if (isFutureDay(_date)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('미래 날짜는 선택할 수 없어요.')));
      return;
    }
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    final now = DateTime.now();
    final existing = widget.existing;
    final keptExisting = [for (final p in _photoItems) if (p.existing != null) p.existing!];
    final newFiles = [for (final p in _photoItems) if (p.newFile != null) p.newFile!];
    final removedPhotos = [
      for (final old in existing?.photos ?? const <DiaryPhoto>[])
        if (!keptExisting.any((kept) => kept.path == old.path)) old,
    ];

    final diaryToSave = Diary(
      id: existing?.id ?? '',
      date: dateOnly(_date),
      petIds: _selectedPetIds.toList(),
      weather: _weather,
      activities: _activities.toList(),
      text: _textController.text.trim(),
      photos: existing == null ? const [] : keptExisting,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final repo = ref.read(diaryRepositoryProvider);
      if (existing == null) {
        await repo.createDiary(uid, diaryToSave, newFiles);
      } else {
        await repo.updateDiary(uid, diaryToSave, newPhotoFiles: newFiles, removedPhotos: removedPhotos);
      }
      ref.invalidate(diariesPageProvider);
      ref.invalidate(recentDiariesForTagOrderProvider);
      if (existing != null) ref.invalidate(diaryProvider(existing.id));
      await _draftStore.clear();
      if (existing == null) await _maybeShowDiaryReminderPrompt();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(actionFailureMessage(e, '일기 저장'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _questionPetName(List<Pet> pets) {
    for (final pet in pets) {
      if (_selectedPetIds.contains(pet.id)) return pet.name;
    }
    return pets.isNotEmpty ? pets.first.name : '반려동물';
  }

  /// 일기를 3번째 저장한 직후 한 번만 알림 동의를 묻는다("일기 활성화"
  /// 지시서 K) — 수락/거절 상관없이 한 번 묻고 나면 다시 묻지 않는다.
  /// 기본값은 꺼짐이라 아무것도 하지 않으면 알림은 울리지 않는다.
  Future<void> _maybeShowDiaryReminderPrompt() async {
    const settings = AppSettings();
    final count = await settings.incrementDiarySaveCount();
    if (count != 3 || await settings.diaryReminderPromptShown()) return;
    await settings.setDiaryReminderPromptShown();
    if (!mounted) return;

    final wantsToTurnOn = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('매일 이 시간에 일기 알림을 받을까요?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                '정한 시간에 오늘 하루를 일기로 남겨보도록 알려드려요. 언제든 내 정보 > 설정에서 끌 수 있어요.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: const Text('괜찮아요'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: const Text('시간 정하고 켜기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (wantsToTurnOn != true || !mounted) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(
        hour: AppSettings.diaryReminderDefaultHour,
        minute: AppSettings.diaryReminderDefaultMinute,
      ),
    );
    if (picked == null) return;
    await settings.setDiaryReminderEnabled(true);
    await settings.setDiaryReminderTime(hour: picked.hour, minute: picked.minute);
    await NotificationService.instance.scheduleDailyDiaryReminder(hour: picked.hour, minute: picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(effectivePetsProvider).value ?? const <Pet>[];
    final recentDiaries = ref.watch(recentDiariesForTagOrderProvider).value ?? const <Diary>[];
    final orderedActivities = sortActivitiesByRecentUsage(recentDiaries);
    final dailyQuestion = diaryDailyQuestionFor(_date, _questionPetName(pets));

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await _confirmDiscardIfDirty();
        if (!context.mounted) return;
        if (discard) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.existing == null ? '일기 쓰기' : '일기 수정')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  const Text('일기는 나만 볼 수 있어요', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: AppSpacing.formField),
              const FormFieldLabel('날짜'),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppRadius.field),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(AppRadius.field)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textPlaceholder),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('yyyy.MM.dd (E)', 'ko_KR').format(_date),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showAutoDateNotice) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_camera_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    const Text('사진 촬영일로 맞췄어요', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    TextButton(
                      onPressed: _pickDate,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('바꾸기', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.formField),
              const FormFieldLabel('반려동물'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pets
                    .map((pet) => FilterChip(
                          label: Text(pet.name),
                          selected: _selectedPetIds.contains(pet.id),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedPetIds.add(pet.id);
                              } else {
                                _selectedPetIds.remove(pet.id);
                              }
                            });
                            _markDirty();
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.formField),
              const FormFieldLabel('날씨 (선택)'),
              Row(
                children: DiaryWeather.values
                    .map((w) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _WeatherButton(
                            weather: w,
                            selected: _weather == w,
                            onTap: () {
                              setState(() => _weather = _weather == w ? null : w);
                              _markDirty();
                            },
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.formField),
              const FormFieldLabel('오늘 한 일 (선택)'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: orderedActivities
                    .map((a) => FilterChip(
                          label: Text(a.label, style: const TextStyle(fontSize: 14)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          selected: _activities.contains(a),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _activities.add(a);
                              } else {
                                _activities.remove(a);
                              }
                            });
                            _markDirty();
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.formField),
              FormFieldLabel('사진 (선택, 최대 $kDiaryMaxPhotos장)'),
              _PhotoEditor(
                items: _photoItems,
                onAddGallery: _pickFromGallery,
                onAddCamera: _pickFromCamera,
                onRemove: _removePhoto,
                onReorder: _reorderPhotos,
              ),
              const SizedBox(height: AppSpacing.formField),
              const FormFieldLabel('글'),
              TextField(
                controller: _textController,
                maxLines: 8,
                maxLength: kDiaryMaxTextLength,
                onChanged: (_) => _markDirty(),
                decoration: InputDecoration(hintText: dailyQuestion),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherButton extends StatelessWidget {
  final DiaryWeather weather;
  final bool selected;
  final VoidCallback onTap;

  const _WeatherButton({required this.weather, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.inputFill,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: AppColors.primary, width: 1.5) : null,
        ),
        alignment: Alignment.center,
        child: Icon(
          diaryWeatherIcon(weather),
          color: selected ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _PhotoEditor extends StatelessWidget {
  final List<_PhotoItem> items;
  final VoidCallback onAddGallery;
  final VoidCallback onAddCamera;
  final ValueChanged<_PhotoItem> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _PhotoEditor({
    required this.items,
    required this.onAddGallery,
    required this.onAddCamera,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isNotEmpty)
          SizedBox(
            height: 88,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorderItem: onReorder,
              itemBuilder: (context, index) {
                final item = items[index];
                return ReorderableDragStartListener(
                  key: ValueKey(item),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PhotoThumb(item: item, onRemove: () => onRemove(item)),
                  ),
                );
              },
            ),
          ),
        if (items.isNotEmpty) const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAddGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('갤러리'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAddCamera,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('카메라'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final _PhotoItem item;
  final VoidCallback onRemove;

  const _PhotoThumb({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final existing = item.existing;
    final newFile = item.newFile;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.field),
          child: existing != null
              ? CachedNetworkImage(
                  imageUrl: existing.displayThumbPath,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(width: 80, height: 80, color: AppColors.surfaceMutedLight),
                )
              : Image.file(newFile!, width: 80, height: 80, fit: BoxFit.cover),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
