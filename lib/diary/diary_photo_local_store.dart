import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 백그라운드 업로드 대기열이 압축된 원본·썸네일 바이트를 업로드 전까지
/// 파일로 들고 있는 폴더(앱 전용 문서 디렉터리 안) — "일기 재수정"
/// 지시서 2-2.
Future<Directory> diaryPhotoQueueDirectory() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/diary_photo_queue');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<String> writeDiaryPhotoQueueFile(String fileName, Uint8List bytes) async {
  final dir = await diaryPhotoQueueDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// 이미 없거나 지우다 실패해도(일시적 오류) 조용히 무시한다 — 업로드가
/// 끝난 뒤의 정리라 실패해도 기능에 영향이 없다.
Future<void> deleteDiaryPhotoQueueFile(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {}
}

/// 회원 탈퇴 시 전부 지운다("일기 재수정" 지시서 2-6) — 폴더 자체를
/// 지우면 그 안의 모든 로컬 파일이 함께 지워진다.
Future<void> deleteAllDiaryPhotoQueueFiles() async {
  try {
    final dir = await diaryPhotoQueueDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  } catch (_) {}
}
