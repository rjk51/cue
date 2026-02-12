import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/pulse_models.dart';

/// Quick glanceable stat cards for the dashboard.
class StatsRow extends StatelessWidget {
  final ProductivityStats stats;
  final Color accentColor;
  final bool isDarkMode;
  final Color cardColor;
  final Color textColor;
  final Color subtitleColor;

  const StatsRow({
    super.key,
    required this.stats,
    required this.accentColor,
    required this.isDarkMode,
    required this.cardColor,
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Completion',
            value: '${(stats.completionRate * 100).toStringAsFixed(0)}%',
            icon: Icons.check_circle_outline,
            color: Colors.green,
            isDarkMode: isDarkMode,
            cardColor: cardColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _StatCard(
            label: 'This Week',
            value: stats.isImproving ? '↑' : (stats.weekOverWeekChange < 0 ? '↓' : '—'),
            valueColor: stats.isImproving ? Colors.green : (stats.weekOverWeekChange < 0 ? Colors.red.shade400 : subtitleColor),
            icon: Icons.trending_up,
            color: stats.isImproving ? Colors.green : Colors.orange,
            isDarkMode: isDarkMode,
            cardColor: cardColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
            subtitle: stats.weekOverWeekChange != 0
                ? '${stats.weekOverWeekChange > 0 ? '+' : ''}${(stats.weekOverWeekChange * 100).toStringAsFixed(0)}% vs last'
                : 'Same as last',
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _StatCard(
            label: 'Total Done',
            value: '${stats.totalCompleted}',
            icon: Icons.done_all,
            color: accentColor,
            isDarkMode: isDarkMode,
            cardColor: cardColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final Color cardColor;
  final Color textColor;
  final Color subtitleColor;
  final String? subtitle;

  const _StatCard({
    required this.label,
    required this.value,
    this.valueColor,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    required this.cardColor,
    required this.textColor,
    required this.subtitleColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120.h,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: valueColor ?? textColor,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: subtitleColor,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 2.h),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 9.sp,
                color: subtitleColor.withOpacity(0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
