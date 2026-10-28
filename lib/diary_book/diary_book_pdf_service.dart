import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import 'book_layout.dart';
import 'book_spec.dart';
import 'diary_book_source.dart' show kBookLocalPhotoPrefix;
import 'render/book_pdf_renderer.dart';

/// 생성 단계 — 사진 준비(다운로드·캐시 확인) → 쪽 그리기.
enum DiaryBookPhase { photos, pages }

class DiaryBookProgress {
  final DiaryBookPhase phase;
  final int done;
  final int total;

  const DiaryBookProgress(this.phase, this.done, this.total);

  String get message => switch (phase) {
        DiaryBookPhase.photos => '사진 준비 중 ($done/$total장)',
        DiaryBookPhase.pages => '그림일기 만드는 중 ($done/$total쪽)',
      };
}

class DiaryBookPdf {
  final String path;
  final Uint8List bytes;

  const DiaryBookPdf({required this.path, required this.bytes});
}

abstract class DiaryBookPdfGenerator {
  Future<DiaryBookPdf> generate(
    BookLayout layout, {
    required BookSpec spec,
    required String cacheKey,
    void Function(DiaryBookProgress progress)? onProgress,
  });

  /// 임시 PDF를 전부 지운다(로그아웃·회원 탈퇴).
  Future<void> clearCache();
}

final diaryBookPdfGeneratorProvider = Provider<DiaryBookPdfGenerator>((ref) => DiaryBookPdfService());

/// PDF 한 쪽 → PNG. 미리보기 화면이 쓴다(테스트에서 바꿔 끼운다).
typedef DiaryBookRasterizer = Future<Uint8List> Function(Uint8List pdf, int pageIndex, double dpi);

final diaryBookRasterizerProvider = Provider<DiaryBookRasterizer>((ref) => rasterizeDiaryBookPage);

Future<Uint8List> rasterizeDiaryBookPage(Uint8List pdf, int pageIndex, double dpi) async {
  await for (final page in Printing.raster(pdf, pages: [pageIndex], dpi: dpi)) {
    return page.toPng();
  }
  throw StateError('page $pageIndex not rendered');
}

const _cacheFolder = 'diary_book_preview';

Future<Directory> diaryBookCacheDirectory() async {
  final base = await getApplicationCacheDirectory();
  return Directory('${base.path}/$_cacheFolder');
}

/// 미리보기 PDF 생성 — 앱 캐시 폴더에 임시 저장하고, 같은 조건(같은 캐시
/// 키)이면 다시 만들지 않는다. 새로 만들면 이전 파일은 지운다(늘 최신 한
/// 권만 남긴다). 실제 그리기는 메인 isolate 밖에서 한다.
class DiaryBookPdfService implements DiaryBookPdfGenerator {
  static const handwritingFontAsset = 'assets/fonts/nanum_pen_script/NanumPenScript-Regular.ttf';
  static const labelFontAsset = 'assets/fonts/IBMPlexSansKR-Regular.ttf';

  @override
  Future<DiaryBookPdf> generate(
    BookLayout layout, {
    required BookSpec spec,
    required String cacheKey,
    void Function(DiaryBookProgress progress)? onProgress,
  }) async {
    final dir = await diaryBookCacheDirectory();
    await dir.create(recursive: true);
    final file = File('${dir.path}/$cacheKey.pdf');
    if (await file.exists() && await file.length() > 0) {
      return DiaryBookPdf(path: file.path, bytes: await file.readAsBytes());
    }

    final photoPaths = await _resolvePhotoFiles(layout, onProgress);
    final fonts = BookRenderFonts(
      handwriting: (await rootBundle.load(handwritingFontAsset)).buffer.asUint8List(),
      label: (await rootBundle.load(labelFontAsset)).buffer.asUint8List(),
    );
    await renderDiaryBookInIsolate(
      DiaryBookRenderJob(layout: layout, spec: spec, fonts: fonts, photoPaths: photoPaths, outPath: file.path),
      onProgress,
    );
    await _deleteOthers(dir, keep: file.path);
    return DiaryBookPdf(path: file.path, bytes: await file.readAsBytes());
  }

  @override
  Future<void> clearCache() async {
    try {
      final dir = await diaryBookCacheDirectory();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('[DiaryBookPdfService] 캐시 삭제 실패(무시): $e');
    }
  }

  /// 쪽에 실제로 쓰이는 사진만, 하나씩 로컬 파일로 준비한다 — 올라간 사진은
  /// 이미지 디스크 캐시(`cached_network_image`와 같은 캐시)를 재사용하고
  /// 없을 때만 원본을 받는다. 업로드 대기 중 사진은 로컬 파일 그대로.
  /// 준비하지 못한 사진은 빼고(그 칸은 빈 칸으로 그린다) 계속한다.
  Future<Map<String, String>> _resolvePhotoFiles(
    BookLayout layout,
    void Function(DiaryBookProgress progress)? onProgress,
  ) async {
    final ids = <String>{
      for (final page in layout.pages)
        ...switch (page) {
          CoverPage(:final photo) => [if (photo != null) photo.photo.id],
          DiaryPage(:final photos) => [for (final p in photos) p.photo.id],
          _ => const <String>[],
        },
    }.toList();
    final paths = <String, String>{};
    for (final (i, id) in ids.indexed) {
      onProgress?.call(DiaryBookProgress(DiaryBookPhase.photos, i, ids.length));
      try {
        if (id.startsWith(kBookLocalPhotoPrefix)) {
          final path = id.substring(kBookLocalPhotoPrefix.length);
          if (await File(path).exists()) paths[id] = path;
        } else {
          paths[id] = (await DefaultCacheManager().getSingleFile(id)).path;
        }
      } catch (e) {
        debugPrint('[DiaryBookPdfService] 사진 준비 실패(빈 칸으로 그림): $e');
      }
    }
    onProgress?.call(DiaryBookProgress(DiaryBookPhase.photos, ids.length, ids.length));
    return paths;
  }

  Future<void> _deleteOthers(Directory dir, {required String keep}) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path != keep) await entity.delete();
      }
    } catch (e) {
      debugPrint('[DiaryBookPdfService] 이전 미리보기 정리 실패(무시): $e');
    }
  }
}

/// isolate로 넘기는 작업 — 결과 PDF는 [outPath]에 쓴다(큰 바이트를 다시
/// 메인 isolate로 복사하지 않게).
class DiaryBookRenderJob {
  final BookLayout layout;
  final BookSpec spec;
  final BookRenderFonts fonts;
  final Map<String, String> photoPaths;
  final String outPath;

  const DiaryBookRenderJob({
    required this.layout,
    required this.spec,
    required this.fonts,
    required this.photoPaths,
    required this.outPath,
  });
}

/// 그리기는 별도 isolate에서 — 진행·완료·오류·종료 알림을 모두 같은 포트로
/// 받아 순서가 섞이지 않게 한다(완료 메시지가 항상 종료 알림보다 먼저 온다).
Future<void> renderDiaryBookInIsolate(DiaryBookRenderJob job, void Function(DiaryBookProgress progress)? onProgress) async {
  final port = ReceivePort();
  try {
    await Isolate.spawn(_renderEntry, (job, port.sendPort), onError: port.sendPort, onExit: port.sendPort);
    await for (final message in port) {
      switch (message) {
        case ('progress', final int done, final int total):
          onProgress?.call(DiaryBookProgress(DiaryBookPhase.pages, done, total));
        case ('done', _, _):
          return;
        case ('error', final String error, _):
          throw StateError(error);
        case [final Object? error, _]:
          // 잡히지 않은 오류: [에러 문자열, 스택 문자열]
          throw StateError('$error');
        case null:
          throw StateError('render isolate exited without result');
      }
    }
  } finally {
    port.close();
  }
}

Future<void> _renderEntry((DiaryBookRenderJob, SendPort) args) async {
  final (job, send) = args;
  try {
    final bytes = await renderBookPdf(
      job.layout,
      spec: job.spec,
      fonts: job.fonts,
      loadPhoto: (id) {
        final path = job.photoPaths[id];
        if (path == null) return null;
        try {
          return File(path).readAsBytesSync();
        } catch (_) {
          return null;
        }
      },
      onProgress: (done, total) => send.send(('progress', done, total)),
    );
    final tmp = File('${job.outPath}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(job.outPath);
    send.send(('done', 0, 0));
  } catch (e) {
    send.send(('error', '$e', 0));
  }
}
