import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/medical_record.dart';
import 'package:petcliniccheck/utils/medical_record_calendar.dart';

MedicalRecord _record(String id, DateTime date, {String petId = 'p1'}) => MedicalRecord(
      id: id,
      petId: petId,
      date: date,
      hospitalName: '병원',
    );

void main() {
  group('groupRecordsByDate — 캘린더 월 뷰 마커·날짜별 목록의 기반(진료기록 쪽)', () {
    test('같은 날 여러 건은 한 키에 원래 순서 그대로 모인다', () {
      final morning = _record('r1', DateTime(2026, 9, 28, 9, 0));
      final afternoon = _record('r2', DateTime(2026, 9, 28, 15, 0));
      final grouped = groupRecordsByDate([morning, afternoon]);

      expect(grouped[DateTime(2026, 9, 28)]?.map((r) => r.id).toList(), ['r1', 'r2']);
    });

    test('날짜가 다르면 각각 다른 키로 나뉜다', () {
      final today = _record('r1', DateTime(2026, 9, 28));
      final yesterday = _record('r2', DateTime(2026, 9, 27));
      final grouped = groupRecordsByDate([today, yesterday]);

      expect(grouped.keys, hasLength(2));
      expect(grouped[DateTime(2026, 9, 28)]?.single.id, 'r1');
      expect(grouped[DateTime(2026, 9, 27)]?.single.id, 'r2');
    });

    test('빈 목록이면 빈 맵을 돌려준다(기록 없는 반려동물의 캘린더가 마커 없이 안전하게 뜸)', () {
      expect(groupRecordsByDate(const []), isEmpty);
    });
  });
}
