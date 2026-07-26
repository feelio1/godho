import 'package:flutter_test/flutter_test.dart';
import 'package:petcliniccheck/data/bundle_loader.dart';
import 'package:petcliniccheck/data/hospital_repository.dart';
import 'package:petcliniccheck/models/hospital_status.dart';
import 'package:petcliniccheck/models/region_filter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HospitalRepository repo;

  setUpAll(() async {
    final bundle = await const BundleLoader().load();
    repo = HospitalRepository(bundle);
  });

  test('sidoList is derived from the data, not hardcoded, and excludes blanks', () {
    expect(repo.sidoList, isNotEmpty);
    expect(repo.sidoList, contains('서울'));
    expect(repo.sidoList, contains('인천'));
    expect(repo.sidoList, isNot(contains('')));
    expect(repo.sidoList, orderedEquals(List.of(repo.sidoList)..sort()));
  });

  test('sigunguListFor only returns sigungu actually present under that sido', () {
    final list = repo.sigunguListFor('인천');
    expect(list, isNotEmpty);
    expect(list, contains('중구'));
    expect(repo.sigunguListFor('존재하지않는시도'), isEmpty);
  });

  test('filterByRegion narrows to sido, then sido+sigungu, and "전체" is a no-op', () {
    final all = repo.all;
    final nationwide = repo.filterByRegion(all, const RegionFilter.all());
    expect(nationwide.length, all.length);

    final seoulOnly = repo.filterByRegion(all, const RegionFilter(sido: '서울'));
    expect(seoulOnly, isNotEmpty);
    expect(seoulOnly.every((h) => h.sido == '서울'), isTrue);

    final jongno = repo.filterByRegion(
      all,
      const RegionFilter(sido: '서울', sigungu: '종로구'),
    );
    expect(jongno, isNotEmpty);
    expect(jongno.every((h) => h.sido == '서울' && h.sigungu == '종로구'), isTrue);
    expect(jongno.length, lessThan(seoulOnly.length));
  });

  test('filterByStatus defaults to hiding closed hospitals, toggle reveals them', () {
    final all = repo.all;
    final openOnly = repo.filterByStatus(all, includeClosed: false);
    expect(openOnly.every((h) => h.status != HospitalStatus.closed), isTrue);

    final withClosed = repo.filterByStatus(all, includeClosed: true);
    expect(withClosed.length, all.length);
    expect(withClosed.any((h) => h.status == HospitalStatus.closed), isTrue);
  });

  test('search matches nationwide, not just the previous single-region bundle', () {
    final seoulResults = repo.search('서울특별시');
    expect(seoulResults, isNotEmpty);
  });

  test('nearestRegion picks the region of the closest hospital with coordinates', () {
    final hospitalWithCoords = repo.all.firstWhere((h) => h.hasCoordinates);
    final region = repo.nearestRegion(hospitalWithCoords.lat!, hospitalWithCoords.lng!);
    expect(region, isNotNull);
    expect(region!.sido, hospitalWithCoords.sido);
  });

  test('coordinate-less hospitals are never dropped by filtering', () {
    final coordless = repo.all.where((h) => !h.hasCoordinates).toList();
    expect(coordless, isNotEmpty);
    final afterRegion = repo.filterByRegion(repo.all, const RegionFilter.all());
    final afterStatus = repo.filterByStatus(afterRegion, includeClosed: true);
    for (final h in coordless) {
      expect(afterStatus.map((e) => e.id), contains(h.id));
    }
  });
}
