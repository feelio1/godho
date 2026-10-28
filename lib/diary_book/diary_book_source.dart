import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../diary/data/diary_repository.dart';
import '../diary/diary_photo_upload_queue.dart';
import '../diary/models/diary.dart';
import 'book_input.dart';
import 'book_spec.dart';
import 'render/book_pdf_renderer.dart' show kBookRendererVersion;

/// 업로드 대기 중(이 기기 로컬 파일) 사진의 id 접두어 — 나머지 id는 다운로드
/// URL이다.
const String kBookLocalPhotoPrefix = 'file:';

/// 그림일기 만들기 설정 화면이 고른 조건.
class DiaryBookQuery {
  final String uid;
  final String petId;
  final String petName;
  final DateTime start;
  final DateTime end;

  const DiaryBookQuery({
    required this.uid,
    required this.petId,
    required this.petName,
    required this.start,
    required this.end,
  });

  @override
  bool operator ==(Object other) =>
      other is DiaryBookQuery &&
      other.uid == uid &&
      other.petId == petId &&
      other.petName == petName &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(uid, petId, petName, start, end);
}

/// 엔진 입력 + 설정 화면 표지 사진 고르기용 썸네일(사진 id → 썸네일 URL
/// 또는 로컬 파일 경로).
class DiaryBookSource {
  final BookInput input;
  final Map<String, String> thumbnails;

  /// 다른 기기에서 아직 올라가는 중이라 이 기기에 파일이 없어 빠진 사진 수.
  final int missingPhotoCount;

  const DiaryBookSource({required this.input, required this.thumbnails, this.missingPhotoCount = 0});

  List<BookPhoto> get allPhotos => [for (final e in input.entries) ...e.photos];
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 기간 안(양 끝 포함), 이 반려동물이 들어간 일기를 날짜순으로 — 기존 월
/// 단위 조회(`fetchDiariesForMonth`)를 달마다 불러 모은다(저장소·저장 로직은
/// 바꾸지 않는다).
Future<List<Diary>> fetchDiariesForBook(DiaryRepository repo, DiaryBookQuery query) async {
  final start = _dateOnly(query.start);
  final endExclusive = _dateOnly(query.end).add(const Duration(days: 1));
  final result = <Diary>[];
  var month = DateTime(start.year, start.month, 1);
  while (month.isBefore(endExclusive)) {
    final diaries = await repo.fetchDiariesForMonth(query.uid, month);
    for (final d in diaries) {
      if (!d.petIds.contains(query.petId)) continue;
      if (d.date.isBefore(start) || !d.date.isBefore(endExclusive)) continue;
      result.add(d);
    }
    month = DateTime(month.year, month.month + 1, 1);
  }
  result.sort((a, b) {
    final diff = a.date.compareTo(b.date);
    return diff != 0 ? diff : a.createdAt.compareTo(b.createdAt);
  });
  return result;
}

BookWeather? _weather(DiaryWeather? w) => switch (w) {
      null => null,
      DiaryWeather.sunny => BookWeather.sunny,
      DiaryWeather.partlyCloudy => BookWeather.partlyCloudy,
      DiaryWeather.cloudy => BookWeather.cloudy,
      DiaryWeather.rainy => BookWeather.rainy,
      DiaryWeather.snowy => BookWeather.snowy,
    };

/// 일기 → 엔진 입력. 사진은 올라간 것(다운로드 URL)과 이 기기 업로드 대기
/// 중인 것(로컬 파일)을 [DiaryPhoto.order] 순서로 합친다. 다른 기기에서
/// 아직 올리는 중인 사진은 이 기기에 파일이 없어 넣지 않는다.
DiaryBookSource buildDiaryBookSource({
  required DiaryBookQuery query,
  required List<Diary> diaries,
  required Map<String, List<DiaryPhotoQueueItem>> pendingByDiary,
}) {
  final thumbnails = <String, String>{};
  final entries = <BookDiaryEntry>[];
  var missing = 0;
  for (final diary in diaries) {
    final localPending = pendingByDiary[diary.id] ?? const <DiaryPhotoQueueItem>[];
    // 아직 올라가는 중인 사진 중 이 기기 대기열에도 없는 것 = 다른 기기의 사진.
    final remotePending = diary.pendingPhotoCount - localPending.length;
    if (remotePending > 0) missing += remotePending;
    final photos = <(int, BookPhoto)>[];
    for (final p in sortedDiaryPhotos(diary.photos)) {
      if (p.path.isEmpty) continue;
      photos.add((p.order, BookPhoto(id: p.path, widthPx: p.width, heightPx: p.height)));
      thumbnails[p.path] = p.displayThumbPath;
    }
    for (final item in localPending) {
      final id = '$kBookLocalPhotoPrefix${item.mainFilePath}';
      photos.add((item.order, BookPhoto(id: id, widthPx: item.width, heightPx: item.height)));
      thumbnails[id] = '$kBookLocalPhotoPrefix${item.thumbFilePath}';
    }
    final ordered = photos.indexed.toList()
      ..sort((a, b) {
        final diff = a.$2.$1 - b.$2.$1;
        return diff != 0 ? diff : a.$1 - b.$1;
      });
    entries.add(BookDiaryEntry(
      id: diary.id,
      date: diary.date,
      weather: _weather(diary.weather),
      activities: [for (final a in diary.activities) a.label],
      text: diary.text,
      photos: [for (final o in ordered) o.$2.$2],
    ));
  }
  return DiaryBookSource(
    input: BookInput(
      petName: query.petName,
      title: defaultBookTitle(query.petName),
      periodStart: query.start,
      periodEnd: query.end,
      entries: entries,
    ),
    thumbnails: thumbnails,
    missingPhotoCount: missing,
  );
}

/// 같은 조건이면 같은 키 — 일기 글·날씨·활동·사진·제목·표지·판형·렌더러
/// 버전 중 하나라도 바뀌면(일기 수정 포함) 키가 달라져 새로 만든다.
String diaryBookCacheKey(BookInput input, BookSpec spec) {
  final buffer = StringBuffer()
    ..writeln('v$kBookRendererVersion')
    ..writeln(spec.cacheKey)
    ..writeln(input.petName)
    ..writeln(input.title)
    ..writeln(input.coverPhotoId ?? '')
    ..writeln('${input.periodStart.toIso8601String()}~${input.periodEnd.toIso8601String()}');
  for (final e in input.entries) {
    buffer
      ..writeln(e.id)
      ..writeln(e.date.toIso8601String())
      ..writeln(e.weather?.name ?? '')
      ..writeln(e.activities.join(','))
      ..writeln(jsonEncode(e.text));
    for (final p in e.photos) {
      buffer.writeln('${p.id}|${p.widthPx}x${p.heightPx}');
    }
  }
  return sha1.convert(utf8.encode(buffer.toString())).toString();
}
