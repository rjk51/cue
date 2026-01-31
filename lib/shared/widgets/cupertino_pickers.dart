import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Shows a Cupertino-style date picker in a modal bottom sheet.
/// Returns the selected [DateTime] or null if cancelled.
Future<DateTime?> showCupertinoDatePickerModal({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  DateTime selected = initialDate;
  final DateTime min = firstDate ?? DateTime(2020);
  final DateTime max = lastDate ?? DateTime(2100);

  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (context) => Container(
      height: 280,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              CupertinoButton(
                child: const Text('Done'),
                onPressed: () => Navigator.of(context).pop(selected),
              ),
            ],
          ),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: initialDate.isBefore(min)
                  ? min
                  : (initialDate.isAfter(max) ? max : initialDate),
              minimumDate: min,
              maximumDate: max,
              onDateTimeChanged: (v) => selected = v,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shows a Cupertino-style time picker in a modal bottom sheet.
/// Returns the selected [TimeOfDay] or null if cancelled.
Future<TimeOfDay?> showCupertinoTimePickerModal({
  required BuildContext context,
  required TimeOfDay initialTime,
}) async {
  DateTime selected = DateTime(
    2000,
    1,
    1,
    initialTime.hour,
    initialTime.minute,
  );

  return showCupertinoModalPopup<TimeOfDay>(
    context: context,
    builder: (context) => Container(
      height: 280,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              CupertinoButton(
                child: const Text('Done'),
                onPressed: () => Navigator.of(context).pop(
                  TimeOfDay(hour: selected.hour, minute: selected.minute),
                ),
              ),
            ],
          ),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: selected,
              onDateTimeChanged: (v) => selected = v,
            ),
          ),
        ],
      ),
    ),
  );
}
