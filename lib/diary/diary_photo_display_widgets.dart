import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'diary_photo_display_merge.dart';

/// 썸네일을 먼저 보여주고(목록에서 이미 캐시돼 있어 즉시 뜬다), 원본이
/// 준비되면 짧은 fade로 바꾼다("일기 수정" 지시서 2-1) — `thumbUrl`이
/// 없는(썸네일 없이 올려둔 기존 일기) 사진은 자리표시 없이 그냥 원본만
/// 기다린다. [memCacheWidth]를 주면 그 너비로만 디코딩해 메모리를
/// 아낀다(작은 영역에 큰 원본을 그대로 띄우지 않음).
class DiaryPhotoFadeImage extends StatelessWidget {
  final String mainUrl;
  final String? thumbUrl;
  final BoxFit fit;
  final double? width;
  final int? memCacheWidth;

  const DiaryPhotoFadeImage({
    super.key,
    required this.mainUrl,
    required this.thumbUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.memCacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = thumbUrl;
    return CachedNetworkImage(
      imageUrl: mainUrl,
      fit: fit,
      width: width,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: thumb == null
          ? null
          : (context, url) => CachedNetworkImage(imageUrl: thumb, fit: fit, width: width),
      errorWidget: (context, url, error) => Container(color: AppColors.surfaceMutedLight),
    );
  }
}

/// [DiaryDisplayPhoto]를 그 종류에 맞게 보여준다("일기 재수정" 지시서
/// 2-3, 2-7) — 서버에 올라간 사진은 [DiaryPhotoFadeImage](썸네일
/// 우선), 이 기기 업로드 대기열에 있는 사진은 로컬 파일을 바로, 로컬
/// 파일이 없는(다른 기기 등) pending은 자리표시만 보여준다. [showBadge]가
/// true면(기본) 대기열 사진 위에 "사진 올리는 중"/"올리지 못했어요"
/// 배지를 겹친다.
class DiaryDisplayImage extends StatelessWidget {
  final DiaryDisplayPhoto photo;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final bool showBadge;

  const DiaryDisplayImage({
    super.key,
    required this.photo,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    switch (photo.kind) {
      case DiaryDisplayPhotoKind.uploaded:
        return DiaryPhotoFadeImage(
          mainUrl: photo.networkPath!,
          thumbUrl: photo.networkThumbPath,
          fit: fit,
          width: width,
          memCacheWidth: memCacheWidth,
        );
      case DiaryDisplayPhotoKind.localPending:
        final image = Image.file(
          File(photo.localFilePath!),
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) =>
              Container(width: width, height: height, color: AppColors.surfaceMutedLight),
        );
        return showBadge ? _PendingPhotoOverlay(givenUp: photo.givenUp, child: image) : image;
      case DiaryDisplayPhotoKind.remotePendingPlaceholder:
        return Container(
          width: width,
          height: height,
          color: AppColors.surfaceLight,
          alignment: Alignment.center,
          child: const Icon(Icons.cloud_upload_outlined, size: 20, color: AppColors.textSecondary),
        );
    }
  }
}

/// 대기열 사진 위에 작게 겹치는 상태 배지 — 평소엔 "사진 올리는 중",
/// 최대 재시도 횟수를 채웠으면("일기 재수정" 지시서 2-4) "사진을 올리지
/// 못했어요"로 바뀐다(실제 "다시 시도" 버튼은 상세 화면에 따로 둔다).
class _PendingPhotoOverlay extends StatelessWidget {
  final bool givenUp;
  final Widget child;

  const _PendingPhotoOverlay({required this.givenUp, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            color: Colors.black.withValues(alpha: 0.55),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  givenUp ? Icons.error_outline : Icons.cloud_upload_outlined,
                  size: 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    givenUp ? '사진을 올리지 못했어요' : '사진 올리는 중',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
