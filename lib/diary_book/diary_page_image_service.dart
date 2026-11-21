import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diary/diary_photo_upload_queue.dart';
import '../diary/models/diary.dart';
import 'book_input.dart';
import 'book_layout.dart';
import 'book_layout_engine.dart';
import 'book_spec.dart';
import 'diary_book_pdf_service.dart';
import 'diary_book_source.dart';
import 'render/book_pdf_renderer.dart';

/// 화면 보기 래스터 상한(책 미리보기와 같은 110dpi).
const double kDiaryPageViewDpi = 110;

/// 공유 이미지 가로 픽셀.
const int kDiaryPageShareWidthPx = 1080;

/// 일기 한 편의 그림일기 장 이미지(쪽마다 PNG 파일 하나).
class DiaryPageImages {
  final List<File> files;

  /// 다른 기기에서 아직 올라가는 중이라 이 기기에 파일이 없어 빠진 사진 수.
  final int missingPhotoCount;

  const DiaryPageImages({required this.files, this.missingPhotoCount = 0});
}

/// 렌더 작업 실행기 — 기본은 별도 isolate(테스트는 같은 isolate로 바꿔 끼운다).
typedef DiaryPageRenderRunner = Future<void> Function(DiaryBookRenderJob job);

/// 사진 id → 로컬 파일 경로 준비기.
typedef DiaryPagePhotoResolver = Future<Map<String, String>> Function(List<String> ids);

/// 일기 한 장 보기·공유 이미지 생성(4차 업데이트 K-1) — 엔진의
/// [layoutSingleDiary]로 배치하고, 책과 같은 렌더러로 PDF를 그린 뒤(별도
/// isolate) `printing` 래스터로 PNG를 만든다. 화면 보기는 110dpi, 공유는 가로
/// 1080px + 하단 바깥 여백의 "펫클로 만든 그림일기". 결과는 앱 캐시 폴더
/// (`diary_page_preview/`)에 두고 같은 내용이면 다시 만들지 않는다.
class DiaryPageImageService {
  final Future<Directory> Function() cacheDirectory;
  final DiaryBookRasterizer rasterize;
  final DiaryPageRenderRunner render;
  final DiaryPagePhotoResolver resolvePhotos;
  final Future<BookRenderFonts> Function() loadFonts;

  DiaryPageImageService({
    Future<Directory> Function()? cacheDirectory,
    DiaryBookRasterizer? rasterize,
    DiaryPageRenderRunner? render,
    DiaryPagePhotoResolver? resolvePhotos,
    Future<BookRenderFonts> Function()? loadFonts,
  })  : cacheDirectory = cacheDirectory ?? diaryPageCacheDirectory,
        rasterize = rasterize ?? rasterizeDiaryBookPage,
        render = render ?? ((job) => renderDiaryBookInIsolate(job, null)),
        resolvePhotos = resolvePhotos ?? ((ids) => resolveBookPhotoFiles(ids, null)),
        loadFonts = loadFonts ?? _loadBundledFonts;

  static Future<BookRenderFonts> _loadBundledFonts() async => BookRenderFonts(
        handwriting: (await rootBundle.load(DiaryBookPdfService.handwritingFontAsset)).buffer.asUint8List(),
        label: (await rootBundle.load(DiaryBookPdfService.labelFontAsset)).buffer.asUint8List(),
      );

  /// 공유 이미지 래스터 dpi — 판형 가로가 [kDiaryPageShareWidthPx]가 되게.
  static double shareDpi(BookSpec spec) => kDiaryPageShareWidthPx / (spec.widthMm / 25.4);

  Future<List<File>> generate(BookDiaryEntry entry, {required bool share, BookSpec spec = BookSpec.a5}) async {
    final dir = await cacheDirectory();
    await dir.create(recursive: true);
    final mode = share ? 'share' : 'view';
    final key = diaryPageCacheKey(entry, spec, share: share);
    final prefix = '${_safe(entry.id)}_${mode}_';
    final cached = _collect(dir, '$prefix${key}_');
    if (cached.isNotEmpty) return cached;

    final pages = layoutSingleDiary(entry, spec: spec);
    final photoPaths = await resolvePhotos(bookLayoutPhotoIds(pages));
    final pdfPath = '${dir.path}/$prefix$key.pdf';
    await render(DiaryBookRenderJob(
      layout: BookLayout(pages),
      spec: spec,
      fonts: await loadFonts(),
      photoPaths: photoPaths,
      outPath: pdfPath,
      pageNumbers: false,
      shareFooter: share ? kShareFooterText : null,
    ));
    final pdfFile = File(pdfPath);
    final pdf = await pdfFile.readAsBytes();
    final dpi = share ? shareDpi(spec) : kDiaryPageViewDpi;
    final files = <File>[];
    try {
      for (var i = 0; i < pages.length; i++) {
        final png = await rasterize(pdf, i, dpi);
        final file = File('${dir.path}/$prefix${key}_$i.png');
        await file.writeAsBytes(png, flush: true);
        files.add(file);
      }
    } finally {
      try {
        await pdfFile.delete();
      } catch (_) {}
    }
    await _deleteStale(dir, prefix: prefix, keepKey: key);
    return files;
  }

  static String _safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  List<File> _collect(Directory dir, String stem) {
    final files = <File>[];
    for (var i = 0;; i++) {
      final f = File('${dir.path}/$stem$i.png');
      if (!f.existsSync() || f.lengthSync() == 0) break;
      files.add(f);
    }
    return files;
  }

  /// 같은 일기·같은 용도의 이전 이미지는 지운다(늘 최신 한 벌만).
  Future<void> _deleteStale(Directory dir, {required String prefix, required String keepKey}) async {
    try {
      await for (final entity in dir.list()) {
        final name = entity.uri.pathSegments.last;
        if (entity is File && name.startsWith(prefix) && !name.contains(keepKey)) await entity.delete();
      }
    } catch (e) {
      debugPrint('[DiaryPageImageService] 이전 이미지 정리 실패(무시): $e');
    }
  }
}

final diaryPageImageServiceProvider = Provider<DiaryPageImageService>((ref) => DiaryPageImageService());

/// 일기 + 이 기기 업로드 대기열 → 엔진 입력 한 편(사진이 아직 안 올라갔으면
/// 로컬 파일로).
Future<({BookDiaryEntry entry, int missingPhotoCount})> diaryPageEntryFor(Diary diary, String uid) async {
  final queue = await const DiaryPhotoUploadQueueStore().load();
  final pending = [for (final item in queue) if (item.uid == uid && item.diaryId == diary.id) item];
  return buildBookDiaryEntry(diary, pending);
}

/// 일기 한 편의 그림일기 장 — 화면 보기([share] false)·공유([share] true).
final diaryPageImagesProvider =
    FutureProvider.autoDispose.family<DiaryPageImages, ({Diary diary, String uid, bool share})>((ref, args) async {
  final built = await diaryPageEntryFor(args.diary, args.uid);
  final files = await ref.watch(diaryPageImageServiceProvider).generate(built.entry, share: args.share);
  return DiaryPageImages(files: files, missingPhotoCount: built.missingPhotoCount);
});

/// 바이트가 PNG인지(공유 파일이 원본 사진 파일이 아닌지 확인할 때).
bool isPngBytes(Uint8List bytes) =>
    bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
