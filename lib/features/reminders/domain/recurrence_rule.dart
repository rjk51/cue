import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum RecurrenceFrequency { daily, weekly, monthly, yearly }

/// Captures recurrence selections from the UI and converts them
/// into the backend-friendly payload plus helper calculations.
class RecurrenceRule {
  RecurrenceRule({
    required this.frequency,
    required this.selectedWeekDays,
    required this.timeOfDay,
    required this.startDate,
    this.endDate,
  });

  final RecurrenceFrequency frequency;
  final Set<int> selectedWeekDays; // Monday = 1, Sunday = 7
  final TimeOfDay timeOfDay;
  final DateTime startDate;
  final DateTime? endDate;

  Map<String, dynamic> toBackendConfig() {
    final startBoundary = _combine(startDate);
    final endBoundary = endDate != null
        ? DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59, 999)
        : null;

    final timeString = _formatTime(timeOfDay);

    switch (frequency) {
      case RecurrenceFrequency.daily:
        return {
          'type': 'interval',
          'frequency': 'daily',
          'every': 1,
          'unit': 'days',
          'anchor': 'scheduled',
          'time': timeString,
          'startDate': Timestamp.fromDate(startBoundary),
          if (endBoundary != null) 'endDate': Timestamp.fromDate(endBoundary),
        };
      case RecurrenceFrequency.weekly:
        final days = _normalizeWeekDays();
        return {
          'type': 'weekly',
          'frequency': 'weekly',
          'days': days,
          'time': timeString,
          'startDate': Timestamp.fromDate(startBoundary),
          if (endBoundary != null) 'endDate': Timestamp.fromDate(endBoundary),
        };
      case RecurrenceFrequency.monthly:
        return {
          'type': 'monthly',
          'frequency': 'monthly',
          'pattern': 'dayOfMonth',
          'value': startBoundary.day,
          'time': timeString,
          'startDate': Timestamp.fromDate(startBoundary),
          if (endBoundary != null) 'endDate': Timestamp.fromDate(endBoundary),
        };
      case RecurrenceFrequency.yearly:
        return {
          'type': 'yearly',
          'frequency': 'yearly',
          'month': startBoundary.month,
          'day': startBoundary.day,
          'time': timeString,
          'startDate': Timestamp.fromDate(startBoundary),
          if (endBoundary != null) 'endDate': Timestamp.fromDate(endBoundary),
        };
    }
  }

  DateTime? nextOccurrence({DateTime? from}) {
    final baseline = _baselineDate(from);
    if (baseline == null) return null;

    final endBoundary = endDate != null
        ? DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59, 999)
        : null;

    DateTime candidate;
    switch (frequency) {
      case RecurrenceFrequency.daily:
        candidate = _combine(DateTime(baseline.year, baseline.month, baseline.day));
        if (candidate.isBefore(baseline)) {
          candidate = candidate.add(const Duration(days: 1));
        }
        break;
      case RecurrenceFrequency.weekly:
        final days = _normalizeWeekDays();
        candidate = _nextWeeklyDate(days, baseline);
        break;
      case RecurrenceFrequency.monthly:
        candidate = _clampDayOfMonth(
          DateTime(baseline.year, baseline.month, 1, timeOfDay.hour, timeOfDay.minute),
          startDate.day,
        );
        if (candidate.isBefore(baseline)) {
          candidate = _clampDayOfMonth(
            DateTime(baseline.year, baseline.month + 1, 1, timeOfDay.hour, timeOfDay.minute),
            startDate.day,
          );
        }
        break;
      case RecurrenceFrequency.yearly:
        candidate = DateTime(
          baseline.year,
          startDate.month,
          startDate.day,
          timeOfDay.hour,
          timeOfDay.minute,
        );
        if (candidate.isBefore(baseline)) {
          candidate = DateTime(
            baseline.year + 1,
            startDate.month,
            startDate.day,
            timeOfDay.hour,
            timeOfDay.minute,
          );
        }
        break;
    }

    if (endBoundary != null && candidate.isAfter(endBoundary)) {
      return null;
    }
    return candidate;
  }

  String summary() {
    final buffer = StringBuffer('Repeats ');
    switch (frequency) {
      case RecurrenceFrequency.daily:
        buffer.write('daily');
        break;
      case RecurrenceFrequency.weekly:
        buffer.write('weekly on ${_normalizeWeekDays().join(', ')}');
        break;
      case RecurrenceFrequency.monthly:
        buffer.write('monthly on day ${startDate.day}');
        break;
      case RecurrenceFrequency.yearly:
        buffer.write('yearly on ${startDate.month}/${startDate.day}');
        break;
    }
    buffer.write(' at ${_formatTime(timeOfDay)}');
    if (endDate != null) {
      buffer.write(' until ${endDate!.toLocal().toIso8601String().split('T').first}');
    }
    return buffer.toString();
  }

  DateTime? _baselineDate(DateTime? from) {
    final origin = from ?? DateTime.now();
    final startBoundary = _combine(startDate);

    if (endDate != null && startBoundary.isAfter(endDate!)) {
      return null;
    }

    return origin.isAfter(startBoundary) ? origin : startBoundary;
  }

  List<String> _normalizeWeekDays() {
    const dayLookup = {
      1: 'mon',
      2: 'tue',
      3: 'wed',
      4: 'thu',
      5: 'fri',
      6: 'sat',
      7: 'sun',
    };
    final days = selectedWeekDays.isEmpty ? {startDate.weekday} : selectedWeekDays;
    final sorted = days.toList()..sort();
    return sorted.map((d) => dayLookup[d] ?? 'mon').toList();
  }

  DateTime _combine(DateTime date) {
    return DateTime(date.year, date.month, date.day, timeOfDay.hour, timeOfDay.minute);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  DateTime _nextWeeklyDate(List<String> days, DateTime baseline) {
    const dayLookup = {
      'sun': DateTime.sunday,
      'mon': DateTime.monday,
      'tue': DateTime.tuesday,
      'wed': DateTime.wednesday,
      'thu': DateTime.thursday,
      'fri': DateTime.friday,
      'sat': DateTime.saturday,
    };

    final targetDays = days
        .map((d) => dayLookup[d])
        .whereType<int>()
        .toList()
      ..sort();

    if (targetDays.isEmpty) {
      return _combine(baseline);
    }

    final todayWeekday = baseline.weekday;
    for (final targetDay in targetDays) {
      if (targetDay == todayWeekday) {
        final candidate = _combine(baseline);
        if (!candidate.isBefore(baseline)) {
          return candidate;
        }
      }
      if (targetDay > todayWeekday) {
        final date = baseline.add(Duration(days: targetDay - todayWeekday));
        return _combine(date);
      }
    }

    final wrapDate = baseline.add(Duration(days: 7 - todayWeekday + targetDays.first));
    return _combine(wrapDate);
  }

  DateTime _clampDayOfMonth(DateTime base, int day) {
    final lastDay = DateTime(base.year, base.month + 1, 0).day;
    final clampedDay = day > lastDay ? lastDay : day;
    return DateTime(base.year, base.month, clampedDay, timeOfDay.hour, timeOfDay.minute);
  }
}
