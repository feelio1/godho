import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'picker_sheet_chrome.dart';

const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

/// 날짜 선택 바텀시트(스프린트 14 시안 14_날짜 피커) — 그랩바+제목+X 뼈대
/// 위에 월 달력을 직접 그린다. Flutter 기본 `showDatePicker` 다이얼로그
/// 대신 쓴다는 점만 다르고, 반환값은 그대로 `DateTime?`이라 호출부
/// (반려동물 생일/예약 날짜/진료기록 날짜) 로직은 바뀌지 않는다.
Future<DateTime?> showAppDatePickerSheet(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DatePickerSheet(initialDate: initialDate, firstDate: firstDate, lastDate: lastDate),
  );
}

class _DatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _DatePickerSheet({required this.initialDate, required this.firstDate, required this.lastDate});

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime _selected;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _visibleMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  static int _monthIndex(DateTime d) => d.year * 12 + d.month;

  bool get _canGoPrev => _monthIndex(_visibleMonth) > _monthIndex(widget.firstDate);
  bool get _canGoNext => _monthIndex(_visibleMonth) < _monthIndex(widget.lastDate);

  void _changeMonth(int delta) {
    setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta));
  }

  bool _isSelectable(DateTime day) {
    final first = DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
    final last = DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
    return !day.isBefore(first) && !day.isAfter(last);
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday % 7; // 일=0
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;

    return PickerSheetChrome(
      title: '날짜 선택',
      heightFactor: 0.62,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _canGoPrev ? () => _changeMonth(-1) : null,
                ),
                SizedBox(
                  width: 140,
                  child: Text(
                    '${_visibleMonth.year}년 ${_visibleMonth.month}월',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _canGoNext ? () => _changeMonth(1) : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final label in _weekdayLabels)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: GridView.count(
                crossAxisCount: 7,
                children: [
                  for (var i = 0; i < firstWeekday; i++) const SizedBox.shrink(),
                  for (var day = 1; day <= daysInMonth; day++)
                    _DayCell(
                      date: DateTime(_visibleMonth.year, _visibleMonth.month, day),
                      selected: _selected.year == _visibleMonth.year &&
                          _selected.month == _visibleMonth.month &&
                          _selected.day == day,
                      enabled: _isSelectable(DateTime(_visibleMonth.year, _visibleMonth.month, day)),
                      onTap: (d) => setState(() => _selected = d),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                child: Text('${_selected.month}월 ${_selected.day}일 선택'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final bool enabled;
  final ValueChanged<DateTime> onTap;

  const _DayCell({required this.date, required this.selected, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: enabled ? () => onTap(date) : null,
        customBorder: const CircleBorder(),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : null,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: !enabled
                  ? AppColors.textPlaceholder.withValues(alpha: 0.5)
                  : selected
                      ? Colors.white
                      : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
