import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'picker_sheet_chrome.dart';

/// 시간 선택 바텀시트(스프린트 14 시안 15_시간 피커) — 오전/오후·시·분
/// 3열 휠. `TimeOfDay`를 그대로 주고받아 호출부(반려동물/예약/진료기록
/// 폼) 로직은 바뀌지 않는다.
Future<TimeOfDay?> showAppTimePickerSheet(BuildContext context, {required TimeOfDay initialTime}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TimePickerSheet(initialTime: initialTime),
  );
}

const _minuteStep = 5;

class _TimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;

  const _TimePickerSheet({required this.initialTime});

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late bool _isPm;
  late int _hour12; // 1~12
  late int _minuteIndex; // 0~11 (5분 단위)

  late final FixedExtentScrollController _periodController;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _isPm = widget.initialTime.hour >= 12;
    final h = widget.initialTime.hour % 12;
    _hour12 = h == 0 ? 12 : h;
    _minuteIndex = (widget.initialTime.minute / _minuteStep).round() % (60 ~/ _minuteStep);

    _periodController = FixedExtentScrollController(initialItem: _isPm ? 1 : 0);
    _hourController = FixedExtentScrollController(initialItem: _hour12 - 1);
    _minuteController = FixedExtentScrollController(initialItem: _minuteIndex);
  }

  @override
  void dispose() {
    _periodController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  TimeOfDay get _result {
    var hour24 = _hour12 % 12;
    if (_isPm) hour24 += 12;
    return TimeOfDay(hour: hour24, minute: _minuteIndex * _minuteStep);
  }

  @override
  Widget build(BuildContext context) {
    return PickerSheetChrome(
      title: '시간 선택',
      heightFactor: 0.55,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
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
                          controller: _periodController,
                          itemCount: 2,
                          labelBuilder: (i) => i == 0 ? '오전' : '오후',
                          onChanged: (i) => setState(() => _isPm = i == 1),
                        ),
                      ),
                      Expanded(
                        child: _Wheel(
                          controller: _hourController,
                          itemCount: 12,
                          labelBuilder: (i) => '${i + 1}',
                          onChanged: (i) => setState(() => _hour12 = i + 1),
                        ),
                      ),
                      Expanded(
                        child: _Wheel(
                          controller: _minuteController,
                          itemCount: 60 ~/ _minuteStep,
                          labelBuilder: (i) => (i * _minuteStep).toString().padLeft(2, '0'),
                          onChanged: (i) => setState(() => _minuteIndex = i),
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
                onPressed: () => Navigator.of(context).pop(_result),
                child: Text('${_result.format(context)} 선택'),
              ),
            ),
          ],
        ),
      ),
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
