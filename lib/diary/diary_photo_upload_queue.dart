import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'diary_photo_processor.dart' show ProcessedDiaryPhoto;

/// 압축된 사진 하나를 대기열에 넣기 전, 이 일기에서 몇 번째로 보여줄지
/// ([order])까지 함께 들고 있는 값("일기 재수정" 지시서 2) — 작성 화면이
/// 사용자가 배치한(드래그로 바꿀 수 있는) 최종 순서를 알고 있으므로
/// 여기서 함께 넘긴다. 업로드가 완료되는 순서(동시 업로드·재시도로 원래
/// 순서와 달라질 수 있음)와는 무관하게, 이 값이 항상 표시 순서다.
class QueuedDiaryPhoto {
  final ProcessedDiaryPhoto processed;
  final int order;

  const QueuedDiaryPhoto({required this.processed, required this.order});
}

/// 업로드 대기열 항목 — SharedPreferences에 JSON으로 저장된다("일기
/// 재수정" 지시서 2-2). 압축된 바이트 자체는 여기 없고 로컬 파일 경로만
/// 들고 있다(`diary_photo_local_store.dart`). [id]는 Storage 경로의
/// photoId로도 그대로 쓰여, 같은 항목을 재시도해도 항상 같은 경로에
/// 덮어쓰기만 해 고아 파일이 남지 않는다.
class DiaryPhotoQueueItem {
  final String id;
  final String uid;
  final String diaryId;
  final int order;
  final String mainFilePath;
  final String thumbFilePath;
  final int width;
  final int height;
  final int attempts;
  final DateTime? nextAttemptAt;

  const DiaryPhotoQueueItem({
    required this.id,
    required this.uid,
    required this.diaryId,
    required this.order,
    required this.mainFilePath,
    required this.thumbFilePath,
    required this.width,
    required this.height,
    this.attempts = 0,
    this.nextAttemptAt,
  });

  DiaryPhotoQueueItem copyWith({int? attempts, DateTime? nextAttemptAt}) => DiaryPhotoQueueItem(
        id: id,
        uid: uid,
        diaryId: diaryId,
        order: order,
        mainFilePath: mainFilePath,
        thumbFilePath: thumbFilePath,
        width: width,
        height: height,
        attempts: attempts ?? this.attempts,
        nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'diaryId': diaryId,
        'order': order,
        'mainFilePath': mainFilePath,
        'thumbFilePath': thumbFilePath,
        'width': width,
        'height': height,
        'attempts': attempts,
        'nextAttemptAt': nextAttemptAt?.toIso8601String(),
      };

  factory DiaryPhotoQueueItem.fromJson(Map<String, dynamic> json) => DiaryPhotoQueueItem(
        id: json['id'] as String,
        uid: json['uid'] as String,
        diaryId: json['diaryId'] as String,
        order: json['order'] as int,
        mainFilePath: json['mainFilePath'] as String,
        thumbFilePath: json['thumbFilePath'] as String,
        width: json['width'] as int,
        height: json['height'] as int,
        attempts: json['attempts'] as int? ?? 0,
        nextAttemptAt:
            json['nextAttemptAt'] == null ? null : DateTime.tryParse(json['nextAttemptAt'] as String),
      );
}

/// 대기열 영속 저장소 — 기기 로컬(SharedPreferences, 계정·서버 무관)에
/// JSON 배열로 둔다. 앱이 꺼졌다 켜져도([DiaryPhotoUploadQueueService]가
/// 다시 읽어) 이어서 처리할 수 있다("일기 재수정" 지시서 2-4).
class DiaryPhotoUploadQueueStore {
  const DiaryPhotoUploadQueueStore();

  static const _key = 'diary_photo_upload_queue_v1';

  Future<List<DiaryPhotoQueueItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => DiaryPhotoQueueItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _save(List<DiaryPhotoQueueItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> addAll(List<DiaryPhotoQueueItem> newItems) async {
    if (newItems.isEmpty) return;
    final items = await load();
    await _save([...items, ...newItems]);
  }

  /// [id]가 일치하는 항목을 [item]으로 교체한다 — 없으면 아무 일도
  /// 하지 않는다(이미 다른 경로로 지워졌을 수 있음).
  Future<void> update(DiaryPhotoQueueItem item) async {
    final items = await load();
    await _save([for (final i in items) if (i.id == item.id) item else i]);
  }

  Future<void> remove(String id) async {
    final items = await load();
    await _save(items.where((i) => i.id != id).toList());
  }

  Future<void> removeForDiary(String diaryId) async {
    final items = await load();
    await _save(items.where((i) => i.diaryId != diaryId).toList());
  }

  Future<void> removeForUid(String uid) async {
    final items = await load();
    await _save(items.where((i) => i.uid != uid).toList());
  }

  Future<List<DiaryPhotoQueueItem>> loadForDiary(String diaryId) async {
    final items = await load();
    return items.where((i) => i.diaryId == diaryId).toList();
  }
}

/// 이 횟수를 채우면 자동 재시도를 멈춘다("일기 재수정" 지시서 2-4) —
/// 이후로는 사용자가 "다시 시도"를 눌러야 한다.
const int kDiaryPhotoUploadMaxAttempts = 6;

/// [attempts]번째 실패 뒤 다음 시도까지 기다리는 시간 — 5초부터 시작해
/// 두 배씩 늘리고(지수 백오프) 5분으로 상한을 둔다.
Duration diaryPhotoUploadBackoff(int attempts) {
  final exponent = (attempts - 1).clamp(0, 10);
  final seconds = 5 * (1 << exponent);
  return Duration(seconds: seconds > 300 ? 300 : seconds);
}

bool diaryPhotoUploadGivenUp(int attempts) => attempts >= kDiaryPhotoUploadMaxAttempts;

/// 지금 바로 다시 보내도 되는지 — 포기한 항목은 자동으로는 보내지 않고
/// (수동 재시도만), 아직 백오프 대기 중인 항목도 보내지 않는다.
bool diaryPhotoUploadReadyToAttempt(DiaryPhotoQueueItem item, DateTime now) {
  if (diaryPhotoUploadGivenUp(item.attempts)) return false;
  final next = item.nextAttemptAt;
  return next == null || !next.isAfter(now);
}
