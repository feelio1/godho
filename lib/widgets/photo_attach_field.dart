import 'dart:io';

import 'package:flutter/material.dart';

/// "사진 첨부" 입력 — 라벨/아이콘을 명확히 하고 선택한 사진을 바로
/// 썸네일로 보여준다. 스프린트 8에서는 사진 버튼이 눈에 잘 안 띈다는
/// 피드백이 있어(스프린트 9 지시서 2) 진료기록·예약 두 폼에서 함께 쓰는
/// 공용 위젯으로 뺐다.
class PhotoAttachField extends StatelessWidget {
  final String? photoPath;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final String label;

  const PhotoAttachField({
    super.key,
    required this.photoPath,
    required this.onPick,
    required this.onClear,
    this.label = '사진 첨부 (선택)',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            if (photoPath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(photoPath!), width: 72, height: 72, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(photoPath == null ? '갤러리에서 사진 선택' : '다른 사진으로 변경'),
              ),
            ),
            if (photoPath != null)
              IconButton(
                tooltip: '사진 삭제',
                icon: const Icon(Icons.delete_outline),
                onPressed: onClear,
              ),
          ],
        ),
      ],
    );
  }
}
