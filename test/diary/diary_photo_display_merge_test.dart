import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/diary/diary_photo_display_merge.dart';
import 'package:petcliniccheck/diary/diary_photo_upload_queue.dart';
import 'package:petcliniccheck/diary/models/diary.dart';

DiaryPhotoQueueItem _queueItem(String id, {required int order, int attempts = 0}) => DiaryPhotoQueueItem(
      id: id,
      uid: 'u1',
      diaryId: 'd1',
      order: order,
      mainFilePath: '/tmp/${id}_main.jpg',
      thumbFilePath: '/tmp/${id}_thumb.jpg',
      width: 100,
      height: 100,
      attempts: attempts,
    );

void main() {
  group('mergeDiaryPhotosForDisplay — 서버·대기열·자리표시를 순서대로 합친다("일기 재수정" 지시서 2-3, 2-7)', () {
    test('전부 서버에 올라가 있으면(대기 없음) order 순서대로 그대로 나온다', () {
      final uploaded = [
        const DiaryPhoto(path: 'b', width: 1, height: 1, order: 1),
        const DiaryPhoto(path: 'a', width: 1, height: 1, order: 0),
      ];
      final result = mergeDiaryPhotosForDisplay(uploaded: uploaded, localPending: const [], pendingPhotoCount: 0);

      expect(result.map((p) => p.networkPath), ['a', 'b']);
      expect(result.every((p) => p.kind == DiaryDisplayPhotoKind.uploaded), isTrue);
    });

    test('서버 사진과 이 기기 대기열 사진이 섞이면 order 기준으로 합쳐진다', () {
      final uploaded = [const DiaryPhoto(path: 'a', width: 1, height: 1, order: 0)];
      final pending = [_queueItem('p1', order: 1)];

      final result = mergeDiaryPhotosForDisplay(uploaded: uploaded, localPending: pending, pendingPhotoCount: 1);

      expect(result, hasLength(2));
      expect(result[0].kind, DiaryDisplayPhotoKind.uploaded);
      expect(result[0].networkPath, 'a');
      expect(result[1].kind, DiaryDisplayPhotoKind.localPending);
      expect(result[1].localFilePath, '/tmp/p1_main.jpg');
    });

    test('이 기기엔 로컬 파일이 없고 pendingPhotoCount만 있으면(다른 기기 등) 자리표시로 채운다', () {
      final result = mergeDiaryPhotosForDisplay(uploaded: const [], localPending: const [], pendingPhotoCount: 2);

      expect(result, hasLength(2));
      expect(result.every((p) => p.kind == DiaryDisplayPhotoKind.remotePendingPlaceholder), isTrue);
    });

    test('이 기기 대기열 일부 + 다른 기기 pending 일부가 섞이면 그만큼만 자리표시다', () {
      final pending = [_queueItem('p1', order: 0)];
      final result = mergeDiaryPhotosForDisplay(uploaded: const [], localPending: pending, pendingPhotoCount: 3);

      final kinds = result.map((p) => p.kind).toList();
      expect(kinds.where((k) => k == DiaryDisplayPhotoKind.localPending), hasLength(1));
      expect(kinds.where((k) => k == DiaryDisplayPhotoKind.remotePendingPlaceholder), hasLength(2));
    });

    test('아무것도 없으면 빈 목록이다', () {
      expect(mergeDiaryPhotosForDisplay(uploaded: const [], localPending: const [], pendingPhotoCount: 0), isEmpty);
    });

    test('최대 재시도를 채운 대기열 항목은 givenUp이 true다', () {
      final pending = [_queueItem('p1', order: 0, attempts: kDiaryPhotoUploadMaxAttempts)];
      final result = mergeDiaryPhotosForDisplay(uploaded: const [], localPending: pending, pendingPhotoCount: 1);

      expect(result.single.givenUp, isTrue);
    });
  });
}
