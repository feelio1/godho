import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'picker_sheet_chrome.dart';

const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

/// 날짜 선택 바텀시트(스프린트 14 시안 14_날짜 피커) — 그랩바+제목+X 뼈대
/// 위에 월 달력을 직접 그린다. Flutter 기본 `showDatePicker` 다이얼로그
/// 대신 쓴다는 점만 다르고, 반환값은 그대로 `DateTime?`이라 호출부
/// (반려동물 생일/예약 날짜/진료기록 날짜) 로직은 바뀌지 않는다.
///
/// 스프린트 15 지시서 4: 이전/다음 화살표만으로는 몇 년 전(반려동물
/// 생일, 과거 진료기록 등)으로 이동하기 힘들다는 문제 — 상단 "2026년
/// 9월" 헤더를 탭하면 연도·월을 바로 고르는 휠 선택 화면으로 전환된다
/// (기존 시간 피커의 휠 톤 재사용). 흰 배경·진한 블루·바텀시트 톤은
/// 그대로 유지한다.
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
  bool _pickingYearMonth = false;

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

  void _applyYearMonth(int year, int month) {
    setState(() {
      _visibleMonth = DateTime(year, month);
      _pickingYearMonth = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PickerSheetChrome(
      title: '날짜 선택',
      heightFactor: 0.62,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: _pickingYearMonth
            ? _YearMonthWheelPicker(
                initialYear: _visibleMonth.year,
                initialMonth: _visibleMonth.month,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                onCancel: () => setState(() => _pickingYearMonth = false),
                onConfirm: _applyYearMonth,
              )
            : _buildCalendar(context),
      ),
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final firstWeekday = DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday % 7; // 일=0
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _canGoPrev ? () => _changeMonth(-1) : null,
            ),
            InkWell(
              onTap: () => setState(() => _pickingYearMonth = true),
              borderRadius: BorderRadius.circular(AppRadius.field),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_visibleMonth.year}년 ${_visibleMonth.month}월',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.expand_more, size: 18, color: AppColors.textSecondary),
                  ],
                ),
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

/// 헤더 탭으로 여는 연도·월 휠 선택 화면 — 기존 시간 피커(3열 휠)와 같은
/// 톤. [firstDate]/[lastDate] 범위 밖의 연도·월은 애초에 휠에 나타나지
/// 않는다(달력의 `_isSelectable`과 동일한 제약을 여기서도 지킨다).
class _YearMonthWheelPicker extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  final DateTime firstDate;
  final DateTime lastDate;
  final VoidCallback onCancel;
  final void Function(int year, int month) onConfirm;

  const _YearMonthWheelPicker({
    required this.initialYear,
    required this.initialMonth,
    required this.firstDate,
    required this.lastDate,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  State<_YearMonthWheelPicker> createState() => _YearMonthWheelPickerState();
}

class _YearMonthWheelPickerState extends State<_YearMonthWheelPicker> {
  late final List<int> _years;
  late int _selectedYear;
  late int _selectedMonth;
  late final FixedExtentScrollController _yearController;
  late final FixedExtentScrollController _monthController;

  @override
  void initState() {
    super.initState();
    _years = [for (var y = widget.firstDate.year; y <= widget.lastDate.year; y++) y];
    _selectedYear = widget.initialYear;
    _selectedMonth = widget.initialMonth;
    _yearController = FixedExtentScrollController(initialItem: _years.indexOf(_selectedYear));
    _monthController = FixedExtentScrollController(initialItem: _selectedMonth - 1);
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  /// 연·월 휠은 12개월 전체를 항상 보여준다(연도별로 달 개수가 바뀌면
  /// 스크롤 컨트롤러를 다시 만들어야 해 복잡해진다) — 대신 확정 시점에
  /// [firstDate]/[lastDate] 범위 밖으로 나간 선택은 가장 가까운 허용
  /// 월로 당겨온다. 그 달 안의 구체적인 날짜 제약은 이후 달력의
  /// `_isSelectable`이 그대로 처리한다.
  void _confirm() {
    var result = DateTime(_selectedYear, _selectedMonth);
    final first = DateTime(widget.firstDate.year, widget.firstDate.month);
    final last = DateTime(widget.lastDate.year, widget.lastDate.month);
    if (result.isBefore(first)) {
      result = first;
    } else if (result.isAfter(last)) {
      result = last;
    }
    widget.onConfirm(result.year, result.month);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            TextButton(onPressed: widget.onCancel, child: const Text('취소')),
            Expanded(
              child: Text('연도·월 선택', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(width: 56),
          ],
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _Wheel(
                      controller: _yearController,
                      itemCount: _years.length,
                      labelBuilder: (i) => '${_years[i]}년',
                      onChanged: (i) => setState(() => _selectedYear = _years[i]),
                    ),
                  ),
                  Expanded(
                    child: _Wheel(
                      controller: _monthController,
                      itemCount: 12,
                      labelBuilder: (i) => '${i + 1}월',
                      onChanged: (i) => setState(() => _selectedMonth = i + 1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _confirm,
            child: Text('$_selectedYear년 $_selectedMonth월로 이동'),
          ),
        ),
      ],
    );
  }
}

class _Wheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int index) labelBuilder;
  final ValueChanged<int> onChanged;

  const _Wheel({
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 44,
      perspective: 0.003,
      diameterRatio: 1.4,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, index) => Center(
          child: Text(
            labelBuilder(index),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
