import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcliniccheck/data/bundle_loader.dart';
import 'package:petcliniccheck/data/hospital_repository.dart';
import 'package:petcliniccheck/models/hospital.dart';
import 'package:petcliniccheck/models/hospital_status.dart';
import 'package:petcliniccheck/widgets/status_badge.dart';

Hospital _hospital({
  HospitalStatus status = HospitalStatus.open,
  DateTime? openDate,
  DateTime? continuousSince,
  String roadAddr = '서울특별시 종로구 진흥로 473',
  String jibunAddr = '서울특별시 종로구 신영동 249-6',
}) =>
    Hospital(
      id: 'h1',
      name: '월드펫동물병원',
      status: status,
      sido: '서울',
      sigungu: '종로구',
      roadAddr: roadAddr,
      jibunAddr: jibunAddr,
      lat: 37.6,
      lng: 126.96,
      openDate: openDate,
      continuousSince: continuousSince,
    );

/// 1차 업데이트(1.0.0+2) — 지시서 B·D·H·I.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('B. 영업 여부 확인 안 됨(unknown) 표기 — 운영 N년차로 계산하지 않는다', () {
    test('개설 기록이 있으면 연도만, 없으면 확인 안 됨만', () {
      final withDate = _hospital(
        status: HospitalStatus.unknown,
        openDate: DateTime(2010, 3, 2),
        continuousSince: DateTime(2010, 3, 2),
      );
      expect(hospitalOperatingLabel(withDate), '2010년 개설 기록 · 현재 영업 여부 확인 안 됨');
      expect(hospitalOperatingLabel(withDate), isNot(contains('년차')));
      expect(hospitalOperatingLabel(_hospital(status: HospitalStatus.unknown)), '현재 영업 여부 확인 안 됨');
    });

    test('영업중·폐업 표기는 그대로', () {
      final since = DateTime(DateTime.now().year - 5, 1, 1);
      expect(hospitalOperatingLabel(_hospital(continuousSince: since)), '운영 6년차');
      expect(HospitalStatus.unknown.label, '영업 여부 확인 안 됨');
      expect(HospitalStatus.closed.label, '폐업');
    });

    test('번들의 unknown 병원 전부(88곳)에 "운영 N년차"가 나오지 않는다', () async {
      final repo = HospitalRepository(await const BundleLoader().load());
      final unknown = repo.all.where((h) => h.status == HospitalStatus.unknown).toList();
      expect(unknown, isNotEmpty);
      for (final h in unknown) {
        final label = hospitalOperatingLabel(h);
        expect(label, contains('현재 영업 여부 확인 안 됨'), reason: h.name);
        expect(label, isNot(contains('년차')), reason: h.name);
      }
    });

    testWidgets('상태 칩은 회색 "영업 여부 확인 안 됨"', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HospitalStatusTag(hospital: _hospital(status: HospitalStatus.unknown, openDate: DateTime(2010))),
        ),
      ));
      expect(find.text('영업 여부 확인 안 됨'), findsOneWidget);
      expect(find.textContaining('년차'), findsNothing);
    });
  });

  group('D. 검색 — 모든 단어가 들어 있으면 포함', () {
    late HospitalRepository repo;
    setUpAll(() async => repo = HospitalRepository(await const BundleLoader().load()));

    test('"역삼동"(지번의 동 이름)으로 찾는다', () {
      final results = repo.search('역삼동');
      expect(results, isNotEmpty);
      expect(results.every((h) => '${h.name}${h.roadAddr}${h.jibunAddr}'.contains('역삼동')), isTrue);
    });

    test('"강남구 동물병원" — 일반어는 빼고 강남구 병원이 나온다', () {
      final results = repo.search('강남구 동물병원');
      expect(results, isNotEmpty);
      expect(results.any((h) => h.sigungu == '강남구'), isTrue);
      // 이름에 "동물병원"이 없어도 강남구면 나온다(그 단어는 거르지 않는다).
      expect(results.length, repo.search('강남구').length);
    });

    test('"종로 월드펫" — 지역 + 이름 일부', () {
      final results = repo.search('종로 월드펫');
      expect(results, isNotEmpty);
      expect(results.every((h) => h.name.contains('월드펫') && h.sigungu.contains('종로')), isTrue);
    });

    test('병원 이름 그대로 검색하면 그 병원이 나온다(띄어쓰기·대소문자 무관)', () {
      for (final h in repo.all.take(200)) {
        expect(repo.search(h.name).map((r) => r.id), contains(h.id), reason: h.name);
      }
      final spaced = repo.search('월드펫 동물병원');
      expect(spaced.map((h) => h.name), contains('월드펫동물병원'));
    });

    test('"동물병원"·"병원"만 치면 원래 검색어로 찾고, 빈 검색어는 결과 없음', () {
      expect(repo.search('동물병원'), isNotEmpty);
      expect(repo.search('동물병원').every((h) => '${h.name}${h.roadAddr}${h.jibunAddr}'.replaceAll(' ', '').contains('동물병원')), isTrue);
      expect(repo.search('   '), isEmpty);
      expect(repo.search('없는이름zzz 강남구'), isEmpty);
    });
  });

  testWidgets('H. 상태 칩은 부모 폭이 넓어도 글자 길이만큼만 차지한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 320, child: Wrap(children: [StatusBadge(status: HospitalStatus.closed)])),
        ),
      ),
    ));
    expect(tester.getSize(find.byType(StatusBadge)).width, lessThan(80));

    // Column(stretch가 아닌 기본 정렬) 안에서도 늘어나지 않는다.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [StatusBadge(status: HospitalStatus.unknown)],
          ),
        ),
      ),
    ));
    expect(tester.getSize(find.byType(StatusBadge)).width, lessThan(200));
  });

  test('I. displayAddr — 도로명이 비면 지번주소', () {
    expect(_hospital().displayAddr, '서울특별시 종로구 진흥로 473');
    expect(_hospital(roadAddr: '').displayAddr, '서울특별시 종로구 신영동 249-6');
    expect(_hospital(roadAddr: '  ').displayAddr, '서울특별시 종로구 신영동 249-6');
  });
}
