import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/pulse_models.dart';

/// Displays AI-generated productivity insights in swipeable cards.
class InsightsSection extends StatelessWidget {
  final List<AiInsight> insights;
  final Color accentColor;
  final bool isDarkMode;
  final Color cardColor;
  final Color textColor;
  final Color subtitleColor;

  const InsightsSection({
    super.key,
    required this.insights,
    required this.accentColor,
    required this.isDarkMode,
    required this.cardColor,
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome,
              color: accentColor,
              size: 18.sp,
            ),
            SizedBox(width: 6.w),
            Text(
              'SMART INSIGHTS',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: subtitleColor,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 140.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: insights.length,
            separatorBuilder: (_, __) => SizedBox(width: 12.w),
            itemBuilder: (context, index) {
              final insight = insights[index];
              return _InsightCard(
                insight: insight,
                accentColor: accentColor,
                isDarkMode: isDarkMode,
                cardColor: cardColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final AiInsight insight;
  final Color accentColor;
  final bool isDarkMode;
  final Color cardColor;
  final Color textColor;
  final Color subtitleColor;

  const _InsightCard({
    required this.insight,
    required this.accentColor,
    required this.isDarkMode,
    required this.cardColor,
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260.w,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: accentColor.withOpacity(0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                insight.emoji,
                style: TextStyle(fontSize: 22.sp),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  insight.title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Expanded(
            child: Text(
              insight.body,
              style: TextStyle(
                fontSize: 12.sp,
                color: subtitleColor,
                height: 1.5,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
