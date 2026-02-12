import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../domain/pulse_models.dart';

/// A GitHub-style contribution heatmap showing activity over the last 91 days.
class ActivityHeatmap extends StatelessWidget {
  final List<DayActivity> data;
  final Color accentColor;
  final bool isDarkMode;

  const ActivityHeatmap({
    super.key,
    required this.data,
    required this.accentColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    // Arrange into weeks (columns) with days (rows, Mon=0, Sun=6)
    final weeks = <List<DayActivity?>>[];
    
    // Find the weekday of the first date (Monday = 1)
    if (data.isEmpty) return const SizedBox.shrink();
    
    // Create initial week with possible empty days before first date
    var currentWeek = List<DayActivity?>.filled(7, null);
    
    for (final day in data) {
      final weekday = day.date.weekday - 1; // 0 = Monday, 6 = Sunday
      
      if (weekday == 0 && currentWeek.any((d) => d != null)) {
        weeks.add(currentWeek);
        currentWeek = List<DayActivity?>.filled(7, null);
      }
      
      currentWeek[weekday] = day;
    }
    
    // Add the last week
    if (currentWeek.any((d) => d != null)) {
      weeks.add(currentWeek);
    }

    // Month labels
    final monthLabels = <MapEntry<int, String>>[];
    String? lastMonth;
    for (int col = 0; col < weeks.length; col++) {
      final firstDayInWeek = weeks[col].firstWhere((d) => d != null);
      if (firstDayInWeek != null) {
        final month = DateFormat('MMM').format(firstDayInWeek.date);
        if (month != lastMonth) {
          monthLabels.add(MapEntry(col, month));
          lastMonth = month;
        }
      }
    }

    final cellSize = 11.0.w;
    final cellSpacing = 3.0.w;
    final totalCellSize = cellSize + cellSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month labels row
        SizedBox(
          height: 16.h,
          child: Stack(
            children: [
              for (final entry in monthLabels)
                Positioned(
                  // Offset for day labels on the left
                  left: 24.w + (entry.key * totalCellSize),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.5)
                          : Colors.black.withOpacity(0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 4.h),
        // Heatmap grid
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day labels (Mon, Wed, Fri)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: cellSize * 0.5), // align with first row
                for (int i = 0; i < 7; i++)
                  SizedBox(
                    height: totalCellSize,
                    child: (i == 0 || i == 2 || i == 4)
                        ? Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: EdgeInsets.only(right: 6.w),
                              child: Text(
                                ['M', '', 'W', '', 'F', '', 'S'][i],
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.4)
                                      : Colors.black.withOpacity(0.35),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
            // Grid cells
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true, // Show most recent on the right
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final week in weeks)
                    Column(
                      children: [
                        for (int day = 0; day < 7; day++)
                          Padding(
                            padding: EdgeInsets.all(cellSpacing / 2),
                            child: _HeatmapCell(
                              activity: week[day],
                              size: cellSize,
                              accentColor: accentColor,
                              isDarkMode: isDarkMode,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              'Less',
              style: TextStyle(
                fontSize: 10.sp,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.4)
                    : Colors.black.withOpacity(0.35),
              ),
            ),
            SizedBox(width: 6.w),
            for (int level = 0; level <= 4; level++)
              Padding(
                padding: EdgeInsets.only(right: 3.w),
                child: Container(
                  width: cellSize * 0.8,
                  height: cellSize * 0.8,
                  decoration: BoxDecoration(
                    color: _getLevelColor(level),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
            SizedBox(width: 3.w),
            Text(
              'More',
              style: TextStyle(
                fontSize: 10.sp,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.4)
                    : Colors.black.withOpacity(0.35),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 0:
        return isDarkMode
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.05);
      case 1:
        return accentColor.withOpacity(0.2);
      case 2:
        return accentColor.withOpacity(0.4);
      case 3:
        return accentColor.withOpacity(0.7);
      case 4:
        return accentColor;
      default:
        return Colors.transparent;
    }
  }
}

class _HeatmapCell extends StatelessWidget {
  final DayActivity? activity;
  final double size;
  final Color accentColor;
  final bool isDarkMode;

  const _HeatmapCell({
    required this.activity,
    required this.size,
    required this.accentColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final level = activity?.level ?? -1;
    final color = level == -1
        ? Colors.transparent
        : level == 0
            ? (isDarkMode
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.05))
            : level == 1
                ? accentColor.withOpacity(0.2)
                : level == 2
                    ? accentColor.withOpacity(0.4)
                    : level == 3
                        ? accentColor.withOpacity(0.7)
                        : accentColor;

    return Tooltip(
      message: activity != null
          ? '${DateFormat('MMM d').format(activity!.date)}: ${activity!.completedCount} completed'
          : '',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2.5.r),
        ),
      ),
    );
  }
}
