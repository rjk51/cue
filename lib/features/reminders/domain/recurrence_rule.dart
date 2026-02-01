import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum RecurrenceFrequency { hourly, daily, weekly, monthly, yearly }

/// Captures recurrence selections from the UI and converts them
/// into the backend-friendly payload plus helper calculations.
class RecurrenceRule {
  RecurrenceRule({
    required this.frequency,
    required this.selectedWeekDays,
    required this.timeOfDay,
    required this.startDate,
    this.endDate,
    this.intervalHours = 1,
    this.intervalMinutes = 0,
  });

  final RecurrenceFrequency frequency;
  final Set<int> selectedWeekDays; // Monday = 1, Sunday = 7
  final TimeOfDay timeOfDay;
  final DateTime startDate;
  final DateTime? endDate;
  final int intervalHours; // For hourly frequency
  final int intervalMinutes; // For hourly frequency

  Map<String, dynamic> toBackendConfig() {
    final startBoundary = _combine(startDate);
    final endBoundary = endDate != null
        ? DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59, 999)
        : null;

    final timeString = _formatTime(timeOfDay);

    switch (frequency) {
      case RecurrenceFrequency.hourly:
        // Calculate total minutes
        final totalMinutes = (intervalHours * 60) + intervalMinutes;

        // Determine unit and value
        String unit;
        int every;
        if (totalMinutes % 60 == 0) {
          // Whole hours
          unit = 'hours';
          every = totalMinutes ~/ 60;
        } else {
          // Use minutes
          unit = 'minutes';
          every = totalMinutes;
        }

        return {
          'type': 'interval',
          'frequency': 'hourly',
          'every': every,
          'unit': unit,
          'anchor': 'scheduled',
          'time': timeString,
          'startDate': Timestamp.fromDate(startBoundary),
          if (endBoundary != null) 'endDate': Timestamp.fromDate(endBoundary),
        };
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
      case RecurrenceFrequency.hourly:
        // For hourly, the first occurrence should be at the start time
        final totalMinutes = (intervalHours * 60) + intervalMinutes;
        final startTime = _combine(startDate);

        // If start time is in the future, use it as the first occurrence
        if (startTime.isAfter(baseline)) {
          candidate = startTime;
        } else {
          // Calculate how many intervals have passed since start time
          final minutesSinceStart = baseline.difference(startTime).inMinutes;
          final intervalsPassed = (minutesSinceStart / totalMinutes).ceil();
          candidate = startTime.add(
            Duration(minutes: totalMinutes * intervalsPassed),
          );
        }
        break;
      case RecurrenceFrequency.daily:
        candidate = _combine(
          DateTime(baseline.year, baseline.month, baseline.day),
        );
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
          DateTime(
            baseline.year,
            baseline.month,
            1,
            timeOfDay.hour,
            timeOfDay.minute,
          ),
          startDate.day,
        );
        if (candidate.isBefore(baseline)) {
          candidate = _clampDayOfMonth(
            DateTime(
              baseline.year,
              baseline.month + 1,
              1,
              timeOfDay.hour,
              timeOfDay.minute,
            ),
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
      case RecurrenceFrequency.hourly:
        final totalMinutes = (intervalHours * 60) + intervalMinutes;
        if (totalMinutes == 60) {
          buffer.write('hourly');
        } else if (totalMinutes < 60) {
          buffer.write('every $totalMinutes minutes');
        } else if (totalMinutes % 60 == 0) {
          final hours = totalMinutes ~/ 60;
          buffer.write('every $hours hours');
        } else {
          final hours = totalMinutes ~/ 60;
          final minutes = totalMinutes % 60;
          buffer.write('every ${hours}h ${minutes}m');
        }
        break;
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
      buffer.write(
        ' until ${endDate!.toLocal().toIso8601String().split('T').first}',
      );
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

  /// Get all occurrences for hourly reminders within a specific day.
  /// Returns a list of DateTimes for each occurrence on [date].
  /// Only applicable for hourly frequency.
  List<DateTime> getHourlyOccurrencesForDay(DateTime date) {
    if (frequency != RecurrenceFrequency.hourly) {
      return [];
    }

    final occurrences = <DateTime>[];
    final totalMinutes = (intervalHours * 60) + intervalMinutes;

    if (totalMinutes == 0) return occurrences;

    // Start of the requested day
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

    // Get the start time combined with startDate
    final startTime = _combine(startDate);

    // If end date exists and the requested day is after it, return empty
    if (endDate != null && date.isAfter(endDate!)) {
      return occurrences;
    }

    // If requested day is before start date, return empty
    if (date.isBefore(
      DateTime(startTime.year, startTime.month, startTime.day),
    )) {
      return occurrences;
    }

    // Calculate first occurrence of the day
    DateTime current;

    if (date.year == startTime.year &&
        date.month == startTime.month &&
        date.day == startTime.day) {
      // On the start day, first occurrence is at start time
      current = startTime;
    } else {
      // On subsequent days, calculate how many intervals have passed since start
      final minutesSinceStart = dayStart.difference(startTime).inMinutes;
      final intervalsPassed = (minutesSinceStart / totalMinutes).floor();
      current = startTime.add(
        Duration(minutes: totalMinutes * intervalsPassed),
      );

      // Move to first occurrence on this day
      while (current.isBefore(dayStart)) {
        current = current.add(Duration(minutes: totalMinutes));
      }
    }

    // Collect all occurrences within the day
    while (current.isBefore(dayEnd) || current.isAtSameMomentAs(dayEnd)) {
      occurrences.add(current);
      current = current.add(Duration(minutes: totalMinutes));
    }

    return occurrences;
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
    final days = selectedWeekDays.isEmpty
        ? {startDate.weekday}
        : selectedWeekDays;
    final sorted = days.toList()..sort();
    return sorted.map((d) => dayLookup[d] ?? 'mon').toList();
  }

  DateTime _combine(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
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

    final targetDays = days.map((d) => dayLookup[d]).whereType<int>().toList()
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

    final wrapDate = baseline.add(
      Duration(days: 7 - todayWeekday + targetDays.first),
    );
    return _combine(wrapDate);
  }

  DateTime _clampDayOfMonth(DateTime base, int day) {
    final lastDay = DateTime(base.year, base.month + 1, 0).day;
    final clampedDay = day > lastDay ? lastDay : day;
    return DateTime(
      base.year,
      base.month,
      clampedDay,
      timeOfDay.hour,
      timeOfDay.minute,
    );
  }

  /// Parse a backend recurrence config back into a RecurrenceRule
  factory RecurrenceRule.fromBackendConfig(Map<String, dynamic> config) {
    final frequencyStr = config['frequency'] as String?;
    final startDateTimestamp = config['startDate'] as Timestamp?;
    final endDateTimestamp = config['endDate'] as Timestamp?;
    final timeStr = config['time'] as String? ?? '09:00';

    // Parse time string (HH:mm format)
    final timeParts = timeStr.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 9;
    final minute = int.tryParse(timeParts[1]) ?? 0;
    final timeOfDay = TimeOfDay(hour: hour, minute: minute);

    final startDate = startDateTimestamp?.toDate() ?? DateTime.now();
    final endDate = endDateTimestamp?.toDate();

    RecurrenceFrequency frequency;
    Set<int> selectedDays = {};
    int intervalHours = 1;
    int intervalMinutes = 0;

    if (frequencyStr == 'hourly') {
      frequency = RecurrenceFrequency.hourly;
      selectedDays = {startDate.weekday};

      // Parse interval from config
      final unit = config['unit'] as String?;
      final every = config['every'] as int? ?? 1;

      if (unit == 'hours') {
        intervalHours = every;
        intervalMinutes = 0;
      } else if (unit == 'minutes') {
        intervalHours = every ~/ 60;
        intervalMinutes = every % 60;
      }
    } else if (frequencyStr == 'daily') {
      frequency = RecurrenceFrequency.daily;
      selectedDays = {startDate.weekday};
    } else if (frequencyStr == 'weekly') {
      frequency = RecurrenceFrequency.weekly;
      final days = config['days'] as List<dynamic>?;
      if (days != null) {
        selectedDays = days.map((d) => d as int).toSet();
      } else {
        selectedDays = {startDate.weekday};
      }
    } else if (frequencyStr == 'monthly') {
      frequency = RecurrenceFrequency.monthly;
      selectedDays = {startDate.weekday};
    } else if (frequencyStr == 'yearly') {
      frequency = RecurrenceFrequency.yearly;
      selectedDays = {startDate.weekday};
    } else {
      // Default to daily if unknown
      frequency = RecurrenceFrequency.daily;
      selectedDays = {startDate.weekday};
    }

    return RecurrenceRule(
      frequency: frequency,
      selectedWeekDays: selectedDays,
      timeOfDay: timeOfDay,
      startDate: startDate,
      endDate: endDate,
      intervalHours: intervalHours,
      intervalMinutes: intervalMinutes,
    );
  }
}
