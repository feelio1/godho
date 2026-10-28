import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../diary/diary_photo_upload_queue.dart';
import '../../diary/providers/diary_providers.dart';
import '../diary_book_source.dart';

/// 설정 화면의 조건(반려동물·기간)으로 모은 일기 → 엔진 입력. 일기를
/// 읽기만 하고 원본은 바꾸지 않는다.
final diaryBookSourceProvider = FutureProvider.autoDispose.family<DiaryBookSource, DiaryBookQuery>((ref, query) async {
  final diaries = await fetchDiariesForBook(ref.watch(diaryRepositoryProvider), query);
  final queue = await const DiaryPhotoUploadQueueStore().load();
  final pendingByDiary = <String, List<DiaryPhotoQueueItem>>{};
  for (final item in queue) {
    if (item.uid != query.uid) continue;
    pendingByDiary.putIfAbsent(item.diaryId, () => []).add(item);
  }
  return buildDiaryBookSource(query: query, diaries: diaries, pendingByDiary: pendingByDiary);
});
