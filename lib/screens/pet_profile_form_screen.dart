import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/pet.dart';
import '../providers/pet_provider.dart';
import '../theme/app_colors.dart';

String _newLocalId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 31)}';

/// 반려동물 프로필 등록/수정 폼. [existing]이 없으면 새로 등록.
class PetProfileFormScreen extends ConsumerStatefulWidget {
  final Pet? existing;

  const PetProfileFormScreen({super.key, this.existing});

  @override
  ConsumerState<PetProfileFormScreen> createState() => _PetProfileFormScreenState();
}

class _PetProfileFormScreenState extends ConsumerState<PetProfileFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _breedController;
  late PetSpecies _species;
  DateTime? _birthday;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _breedController = TextEditingController(text: existing?.breed ?? '');
    _species = existing?.species ?? PetSpecies.dog;
    _birthday = existing?.birthday;
    _photoPath = existing?.photoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
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

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 1, now.month, now.day),
      firstDate: DateTime(now.year - 40),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요.')),
      );
      return;
    }
    final pet = Pet(
      id: widget.existing?.id ?? _newLocalId(),
      name: name,
      species: _species,
      breed: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
      birthday: _birthday,
      photoPath: _photoPath,
    );
    ref.read(petsProvider.notifier).upsert(pet);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? '반려동물 등록' : '반려동물 정보 수정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primarySoft,
                  backgroundImage: _photoPath != null ? FileImage(File(_photoPath!)) : null,
                  child: _photoPath == null
                      ? const Icon(Icons.pets, size: 36, color: AppColors.primaryDark)
                      : null,
                ),
              ),
            ),
            Center(
              child: TextButton(onPressed: _pickPhoto, child: const Text('사진 선택')),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Text('종', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<PetSpecies>(
              segments: PetSpecies.values
                  .map((s) => ButtonSegment(value: s, label: Text(s.label)))
                  .toList(),
              selected: {_species},
              onSelectionChanged: (selection) => setState(() => _species = selection.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _breedController,
              decoration: const InputDecoration(
                labelText: '품종 (선택)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('생일 (선택)'),
              subtitle: Text(
                _birthday != null ? DateFormat('yyyy.MM.dd').format(_birthday!) : '설정 안 함',
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(icon: const Icon(Icons.calendar_today_outlined), onPressed: _pickBirthday),
                  if (_birthday != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _birthday = null),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}
