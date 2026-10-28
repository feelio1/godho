import 'diary_photo_upload_queue.dart';
import 'models/diary.dart';

/// [DiaryDisplayPhoto] 하나가 어디서 왔는지 — 화면이 어떻게 그릴지
/// 결정하는 데 쓴다("일기 재수정" 지시서 2-3, 2-7).
enum DiaryDisplayPhotoKind {
  /// 이미 서버(Storage)에 올라가 있다 — 보통의 네트워크 이미지.
  uploaded,

  /// 이 기기의 업로드 대기열에 있다 — 로컬 파일로 바로 보여줄 수 있다.
  localPending,

  /// 아직 안 올라갔는데(pendingPhotoCount > 0) 이 기기엔 로컬 파일이
  /// 없다 — 다른 기기에서 작성됐거나, 이 기기에서도 로컬 파일이 이미
  /// 지워진 경우. 자리표시만 보여준다.
  remotePendingPlaceholder,
}

/// 서버에 올라간 사진([DiaryPhoto])과 아직 이 기기 대기열에 있는 사진
/// ([DiaryPhotoQueueItem])을 한 화면에 순서대로 보여주기 위한 공통
/// 모양("일기 재수정" 지시서 2) — [mergeDiaryPhotosForDisplay]가 만든다.
class DiaryDisplayPhoto {
  final int order;
  final DiaryDisplayPhotoKind kind;
  final String? networkPath;
  final String? networkThumbPath;
  final String? localFilePath;

  /// [kind]가 [DiaryDisplayPhotoKind.localPending]일 때만 의미가 있다 —
  /// 재시도 최대 횟수를 채워 자동 재시도를 멈춘 상태인지("사진을
  /// 올리지 못했어요 · 다시 시도" 표시 여부).
  final bool givenUp;

  const DiaryDisplayPhoto._({
    required this.order,
    required this.kind,
    this.networkPath,
    this.networkThumbPath,
    this.localFilePath,
    this.givenUp = false,
  });

  factory DiaryDisplayPhoto.uploaded(DiaryPhoto photo) => DiaryDisplayPhoto._(
        order: photo.order,
        kind: DiaryDisplayPhotoKind.uploaded,
        networkPath: photo.path,
        networkThumbPath: photo.thumbPath,
      );

  factory DiaryDisplayPhoto.localPending(DiaryPhotoQueueItem item) => DiaryDisplayPhoto._(
        order: item.order,
        kind: DiaryDisplayPhotoKind.localPending,
        localFilePath: item.mainFilePath,
        givenUp: diaryPhotoUploadGivenUp(item.attempts),
      );

  factory DiaryDisplayPhoto.remotePendingPlaceholder({required int order}) => DiaryDisplayPhoto._(
        order: order,
        kind: DiaryDisplayPhotoKind.remotePendingPlaceholder,
      );
}

/// 서버에 올라간 사진·이 기기 대기열의 사진·(다른 기기 등에서) 아직
/// 로컬 파일 없이 남은 pending 개수를 하나의, 보여줄 순서([DiaryPhoto.
/// order]/[DiaryPhotoQueueItem.order] 기준)로 합친다("일기 재수정"
/// 지시서 2-3, 2-7). [pendingPhotoCount]가 [localPending]의 개수보다
/// 많으면 그 차이만큼 자리표시를 끝에 더한다.
List<DiaryDisplayPhoto> mergeDiaryPhotosForDisplay({
  required List<DiaryPhoto> uploaded,
  required List<DiaryPhotoQueueItem> localPending,
  required int pendingPhotoCount,
}) {
  final uploadedItems = sortedDiaryPhotos(uploaded).map(DiaryDisplayPhoto.uploaded).toList();
  final localDisplayItems = localPending.map(DiaryDisplayPhoto.localPending).toList()
    ..sort((a, b) => a.order - b.order);
  final remotePendingCount = (pendingPhotoCount - localPending.length).clamp(0, pendingPhotoCount);
  final placeholders = List.generate(
    remotePendingCount,
    (i) => DiaryDisplayPhoto.remotePendingPlaceholder(
      order: uploadedItems.length + localDisplayItems.length + i,
    ),
  );
  final merged = [...uploadedItems, ...localDisplayItems, ...placeholders];
  merged.sort((a, b) => a.order - b.order);
  return merged;
}
