import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/pet.dart';
import '../../providers/auth_provider.dart';
import '../../providers/effective_pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/date_picker_sheet.dart';
import '../../widgets/inline_error_message.dart';
import '../book_input.dart';
import '../book_layout.dart';
import '../book_layout_engine.dart';
import '../book_spec.dart';
import '../diary_book_source.dart';
import '../providers/diary_book_providers.dart';
import 'diary_book_preview_screen.dart';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// 기본 기간 — 오늘까지 최근 3개월.
({DateTime start, DateTime end}) defaultDiaryBookPeriod([DateTime? today]) {
  final end = today ?? _today();
  return (start: DateTime(end.year, end.month - 3, end.day + 1), end: end);
}

/// 그림일기 만들기 설정 — 반려동물 → 기간 → (일기 수·예상 쪽 수) → 제목 →
/// 표지 사진 → [미리보기 만들기]. 진입점은 스위치가 켜졌을 때만 보인다.
class DiaryBookSetupScreen extends ConsumerStatefulWidget {
  /// 처음 선택할 반려동물(없으면 첫 번째).
  final String? initialPetId;
  final BookSpec spec;

  const DiaryBookSetupScreen({super.key, this.initialPetId, this.spec = BookSpec.a5});

  @override
  ConsumerState<DiaryBookSetupScreen> createState() => _DiaryBookSetupScreenState();
}

class _DiaryBookSetupScreenState extends ConsumerState<DiaryBookSetupScreen> {
  final _titleController = TextEditingController();
  String? _petId;
  late DateTime _start;
  late DateTime _end;
  String? _coverPhotoId;

  /// 제목을 사용자가 직접 고쳤는가 — 안 고쳤으면 반려동물을 바꿀 때 기본
  /// 제목도 따라 바뀐다.
  bool _titleEdited = false;

  @override
  void initState() {
    super.initState();
    final period = defaultDiaryBookPeriod();
    _start = period.start;
    _end = period.end;
    _petId = widget.initialPetId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Pet? _selectedPet(List<Pet> pets) {
    if (pets.isEmpty) return null;
    return pets.firstWhere((p) => p.id == _petId, orElse: () => pets.first);
  }

  /// 안 고친 제목 칸에 기본 제목을 채운다 — 빌드 중에 컨트롤러를 바꾸지
  /// 않도록 프레임 뒤로 미룬다(실제 책 제목은 [_title]이 바로 정한다).
  void _syncDefaultTitle(Pet pet) {
    if (_titleEdited) return;
    final title = defaultBookTitle(pet.name);
    if (_titleController.text == title) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_titleEdited) _titleController.text = title;
    });
  }

  String _title(Pet pet) => _titleEdited ? _titleController.text : defaultBookTitle(pet.name);

  Future<void> _pickDate({required bool start}) async {
    final today = _today();
    final picked = await showAppDatePickerSheet(
      context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked;
        if (_start.isAfter(_end)) _start = _end;
      }
      _coverPhotoId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final petsAsync = ref.watch(effectivePetsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('그림일기 만들기')),
      body: uid == null
          ? const _CenterMessage('로그인하면 그림일기를 만들 수 있어요')
          : petsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => InlineErrorMessage(error: error, onRetry: () => ref.invalidate(effectivePetsProvider)),
              data: (pets) {
                final pet = _selectedPet(pets);
                if (pet == null) return const _CenterMessage('반려동물을 먼저 등록해 주세요');
                _syncDefaultTitle(pet);
                return _buildForm(context, uid, pets, pet);
              },
            ),
    );
  }

  Widget _buildForm(BuildContext context, String uid, List<Pet> pets, Pet pet) {
    final query = DiaryBookQuery(uid: uid, petId: pet.id, petName: pet.name, start: _start, end: _end);
    final sourceAsync = ref.watch(diaryBookSourceProvider(query));
    final dateFormat = DateFormat('yyyy.MM.dd');

    final source = sourceAsync.value;
    final input = source?.input.copyWith(title: _title(pet), coverPhotoId: _coverPhotoId);
    final result = input == null ? null : layoutBook(input, spec: widget.spec);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              const _Label('반려동물'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in pets)
                    ChoiceChip(
                      label: Text(p.name),
                      selected: p.id == pet.id,
                      onSelected: (_) => setState(() {
                        _petId = p.id;
                        _coverPhotoId = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.section),
              const _Label('기간'),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('diaryBookStart'),
                      onPressed: () => _pickDate(start: true),
                      child: Text(dateFormat.format(_start)),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('~')),
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('diaryBookEnd'),
                      onPressed: () => _pickDate(start: false),
                      child: Text(dateFormat.format(_end)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              sourceAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => InlineErrorMessage(
                  error: error,
                  onRetry: () => ref.invalidate(diaryBookSourceProvider(query)),
                ),
                data: (_) => _SummaryLine(result: result!, diaryCount: input!.entries.length),
              ),
              const SizedBox(height: AppSpacing.section),
              const _Label('제목'),
              TextField(
                controller: _titleController,
                maxLength: 30,
                decoration: const InputDecoration(hintText: '○○의 그림일기'),
                onChanged: (_) => setState(() => _titleEdited = true),
              ),
              const SizedBox(height: 8),
              const _Label('표지 사진'),
              if (source != null) _CoverPicker(source: source, result: result, onSelected: _selectCover),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: result is BookLayoutOk ? () => _openPreview(input!) : null,
                child: const Text('미리보기 만들기'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _selectCover(String id) => setState(() => _coverPhotoId = id);

  void _openPreview(BookInput input) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DiaryBookPreviewScreen(input: input, spec: widget.spec)),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textLabel)),
      );
}

class _CenterMessage extends StatelessWidget {
  final String text;

  const _CenterMessage(this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
}

/// "포함 일기 N편 · 예상 M쪽" — 일기가 없거나 쪽수가 넘치면 그 이유.
class _SummaryLine extends StatelessWidget {
  final BookLayoutResult result;
  final int diaryCount;

  const _SummaryLine({required this.result, required this.diaryCount});

  @override
  Widget build(BuildContext context) {
    final text = switch (result) {
      BookLayoutEmpty() => '기간 안에 일기가 없어요',
      BookLayoutTooManyPages(:final pageCount, :final maxPages) =>
        '예상 $pageCount쪽 — 한 권은 최대 $maxPages쪽이에요. 기간을 줄여 주세요.',
      BookLayoutOk(:final layout) => '포함 일기 $diaryCount편 · 예상 ${layout.pageCount}쪽',
    };
    return Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary));
  }
}

class _CoverPicker extends StatelessWidget {
  final DiaryBookSource source;
  final BookLayoutResult? result;
  final ValueChanged<String> onSelected;

  const _CoverPicker({required this.source, required this.result, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final photos = source.allPhotos;
    if (photos.isEmpty) {
      return const Text('기간 안에 사진이 없어요 — 표지는 사진 없이 만들어져요',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary));
    }
    final current = switch (result) {
      BookLayoutOk(:final layout) => (layout.pages.first as CoverPage).photo?.photo.id,
      _ => null,
    };
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final photo = photos[index];
          final selected = photo.id == current;
          return GestureDetector(
            onTap: () => onSelected(photo.id),
            child: Container(
              width: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? AppColors.primary : AppColors.borderCard, width: selected ? 3 : 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: _Thumb(source.thumbnails[photo.id] ?? photo.id),
            ),
          );
        },
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String pathOrUrl;

  const _Thumb(this.pathOrUrl);

  @override
  Widget build(BuildContext context) {
    if (pathOrUrl.startsWith(kBookLocalPhotoPrefix)) {
      return Image.file(
        File(pathOrUrl.substring(kBookLocalPhotoPrefix.length)),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.surfaceMutedLight),
      );
    }
    return CachedNetworkImage(
      imageUrl: pathOrUrl,
      fit: BoxFit.cover,
      errorWidget: (_, _, _) => const ColoredBox(color: AppColors.surfaceMutedLight),
    );
  }
}
