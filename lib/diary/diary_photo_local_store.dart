import 'dart:io';

import 'package:flutter/foundation.dart';
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

/// iOS(출시 준비 L-7): 앱을 업데이트·재설치하면 iOS는 앱 폴더 경로
/// (`…/Application/<UUID>/Documents`)를 새로 정한다 — 파일은 새 폴더 아래
/// 같은 이름으로 옮겨져 있지만, 대기열(SharedPreferences)에 적어 둔 예전
/// 절대 경로는 더는 없다. 적힌 경로에 파일이 없고 지금 대기열 폴더
/// ([queueDirPath])에 같은 이름의 파일이 있으면 그 경로를 돌려준다. 그 밖에는
/// 적힌 경로 그대로 — 안드로이드처럼 경로가 바뀌지 않으면 항상 그대로다.
@visibleForTesting
String relocatedDiaryPhotoQueuePath(
  String storedPath,
  String queueDirPath, {
  required bool Function(String path) exists,
}) {
  if (exists(storedPath)) return storedPath;
  final name = storedPath.split('/').last;
  if (name.isEmpty) return storedPath;
  final candidate = '$queueDirPath/$name';
  return exists(candidate) ? candidate : storedPath;
}

/// [relocatedDiaryPhotoQueuePath]를 지금 기기의 대기열 폴더로 적용한다 —
/// iOS에서만 부른다. 폴더를 못 찾으면(드묾) 적힌 경로 그대로.
Future<String Function(String storedPath)> diaryPhotoQueuePathRelocator() async {
  try {
    final dir = await diaryPhotoQueueDirectory();
    return (String storedPath) => relocatedDiaryPhotoQueuePath(
      storedPath,
      dir.path,
      exists: (path) => File(path).existsSync(),
    );
  } catch (_) {
    return (String storedPath) => storedPath;
  }
}
