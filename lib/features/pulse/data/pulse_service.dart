import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../reminders/domain/reminder_model.dart';
import '../domain/pulse_models.dart';

/// Service that computes all Pulse analytics from Firestore reminder data.
class PulseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  /// Fetch all reminders (both active and completed) for analytics.
  Future<List<Reminder>> _fetchAllReminders() async {
    final userId = _userId;
    if (userId == null) return [];

    final snapshot = await _firestore
        .collection('reminders')
        .where('userId', isEqualTo: userId)
        .get();

    return snapshot.docs
        .map((doc) => Reminder.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get all completed dates across all reminders (sorted).
  List<String> _getAllCompletedDates(List<Reminder> reminders) {
    final dates = <String>{};
    for (final r in reminders) {
      if (r.consistency != null) {
        dates.addAll(r.consistency!.completedDates);
      }
      // Also check completed non-recurring reminders
      if (r.isCompleted && r.recurrence == null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(r.time);
        dates.add(dateStr);
      }
    }
    final sorted = dates.toList()..sort();
    return sorted;
  }

  /// Calculate streak data from completed dates.
  StreakData computeStreaks(List<String> allCompletedDates) {
    if (allCompletedDates.isEmpty) {
      return const StreakData(
        currentStreak: 0,
        bestStreak: 0,
        isActiveToday: false,
      );
    }

    // Parse and deduplicate dates
    final uniqueDates = allCompletedDates.toSet().toList()..sort();
    final parsedDates =
        uniqueDates.map((d) => DateTime.parse(d)).toList()..sort();

    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final yesterdayStr = DateFormat('yyyy-MM-dd')
        .format(today.subtract(const Duration(days: 1)));

    final isActiveToday = uniqueDates.contains(todayStr);

    // Compute current streak (going backwards from today/yesterday)
    int currentStreak = 0;
    DateTime checkDate;
    if (isActiveToday) {
      checkDate = DateTime(today.year, today.month, today.day);
    } else if (uniqueDates.contains(yesterdayStr)) {
      checkDate = today.subtract(const Duration(days: 1));
      checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);
    } else {
      // No activity today or yesterday — streak is 0
      currentStreak = 0;
      checkDate = today; // won't enter loop
    }

    if (isActiveToday || uniqueDates.contains(yesterdayStr)) {
      while (true) {
        final checkStr = DateFormat('yyyy-MM-dd').format(checkDate);
        if (uniqueDates.contains(checkStr)) {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    // Compute best streak
    int bestStreak = 0;
    int tempStreak = 1;
    for (int i = 1; i < parsedDates.length; i++) {
      final diff = parsedDates[i].difference(parsedDates[i - 1]).inDays;
      if (diff == 1) {
        tempStreak++;
      } else if (diff > 1) {
        bestStreak = tempStreak > bestStreak ? tempStreak : bestStreak;
        tempStreak = 1;
      }
      // diff == 0 means same day, skip
    }
    bestStreak = tempStreak > bestStreak ? tempStreak : bestStreak;

    // Streak start date
    DateTime? streakStart;
    if (currentStreak > 0) {
      streakStart = (isActiveToday ? today : today.subtract(const Duration(days: 1)))
          .subtract(Duration(days: currentStreak - 1));
    }

    return StreakData(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      streakStartDate: streakStart,
      isActiveToday: isActiveToday,
    );
  }

  /// Generate heatmap data for the last N days.
  List<DayActivity> computeHeatmap(
    List<Reminder> reminders, {
    int days = 90,
  }) {
    final today = DateTime.now();
    final result = <DayActivity>[];

    // Collect all completed dates per date
    final completedPerDate = <String, int>{};
    final totalPerDate = <String, int>{};

    for (final r in reminders) {
      if (r.consistency != null) {
        for (final d in r.consistency!.completedDates) {
          completedPerDate[d] = (completedPerDate[d] ?? 0) + 1;
          totalPerDate[d] = (totalPerDate[d] ?? 0) + 1;
        }
        // Count missed days too (from consistency counts minus completed dates)
        // For simplicity, we use completedDates as the primary source
      }

      if (r.isCompleted && r.recurrence == null) {
        final d = DateFormat('yyyy-MM-dd').format(r.time);
        completedPerDate[d] = (completedPerDate[d] ?? 0) + 1;
        totalPerDate[d] = (totalPerDate[d] ?? 0) + 1;
      }
    }

    for (int i = days - 1; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      result.add(DayActivity(
        date: date,
        completedCount: completedPerDate[dateStr] ?? 0,
        totalCount: totalPerDate[dateStr] ?? 0,
      ));
    }

    return result;
  }

  /// Compute overall productivity stats.
  ProductivityStats computeStats(List<Reminder> reminders) {
    int totalCompleted = 0;
    int totalMissed = 0;
    int activeReminders = 0;
    String? mostConsistentReminder;
    double bestConsistency = 0;

    // Count completions per hour for "most productive hour"
    final hourCounts = <int, int>{};

    for (final r in reminders) {
      if (r.recurrence != null) {
        activeReminders++;
        if (r.consistency != null) {
          totalCompleted += r.consistency!.completedCount;
          totalMissed += r.consistency!.missedCount;
          if (r.consistency!.percentage > bestConsistency &&
              r.consistency!.completedCount > 0) {
            bestConsistency = r.consistency!.percentage;
            mostConsistentReminder = r.name;
          }

          // Track hours from completed dates (use reminder time as proxy)
          for (final _ in r.consistency!.completedDates) {
            final hour = r.time.hour;
            hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
          }
        }
      } else {
        if (r.isCompleted) {
          totalCompleted++;
          final hour = r.time.hour;
          hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
        } else {
          activeReminders++;
        }
      }
    }

    // Find most productive hour
    String? mostProductiveHour;
    if (hourCounts.isNotEmpty) {
      final topHour =
          hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      final period = topHour >= 12 ? 'PM' : 'AM';
      final displayHour = topHour == 0
          ? 12
          : topHour > 12
              ? topHour - 12
              : topHour;
      mostProductiveHour = '$displayHour $period';
    }

    // This week vs last week completion rate
    final now = DateTime.now();
    final thisWeekStart =
        now.subtract(Duration(days: now.weekday - 1)); // Monday
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    int thisWeekCompleted = 0;
    int thisWeekTotal = 0;
    int lastWeekCompleted = 0;
    int lastWeekTotal = 0;

    for (final r in reminders) {
      if (r.consistency != null) {
        for (final d in r.consistency!.completedDates) {
          final date = DateTime.tryParse(d);
          if (date == null) continue;
          if (!date.isBefore(thisWeekStart)) {
            thisWeekCompleted++;
            thisWeekTotal++;
          } else if (!date.isBefore(lastWeekStart) &&
              date.isBefore(thisWeekStart)) {
            lastWeekCompleted++;
            lastWeekTotal++;
          }
        }
      }
    }

    // Today's stats
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    int completedToday = 0;
    int totalToday = 0;

    for (final r in reminders) {
      if (r.recurrence != null) {
        // Check if the recurring reminder was completed today
        if (r.consistency != null &&
            r.consistency!.completedDates.contains(todayStr)) {
          completedToday++;
        }
        // Count recurring reminders that are due today
        final effectiveDate = r.effectiveNextDueAt;
        if (effectiveDate.year == now.year &&
            effectiveDate.month == now.month &&
            effectiveDate.day == now.day) {
          totalToday++;
        }
      } else {
        if (r.time.year == now.year &&
            r.time.month == now.month &&
            r.time.day == now.day) {
          totalToday++;
          if (r.isCompleted) completedToday++;
        }
      }
    }

    final total = totalCompleted + totalMissed;
    final completionRate = total > 0 ? totalCompleted / total : 0.0;
    final thisWeekRate =
        thisWeekTotal > 0 ? thisWeekCompleted / thisWeekTotal : 0.0;
    final lastWeekRate =
        lastWeekTotal > 0 ? lastWeekCompleted / lastWeekTotal : 0.0;

    return ProductivityStats(
      totalCompleted: totalCompleted,
      totalMissed: totalMissed,
      completionRate: completionRate,
      activeReminders: activeReminders,
      mostProductiveHour: mostProductiveHour,
      mostConsistentReminder: mostConsistentReminder,
      thisWeekRate: thisWeekRate,
      lastWeekRate: lastWeekRate,
      completedToday: completedToday,
      totalToday: totalToday,
    );
  }

  /// Generate AI-style insights from the data (no API call needed — rule-based).
  List<AiInsight> generateInsights(
    ProductivityStats stats,
    StreakData streaks,
    List<DayActivity> heatmap,
  ) {
    final insights = <AiInsight>[];

    // Streak insight
    if (streaks.currentStreak > 0) {
      if (streaks.currentStreak >= 7) {
        insights.add(AiInsight(
          title: 'Incredible streak!',
          body:
              'You\'ve been consistent for ${streaks.currentStreak} days straight. That\'s the kind of discipline that builds lasting habits.',
          emoji: '🔥',
        ));
      } else {
        insights.add(AiInsight(
          title: 'Building momentum',
          body:
              '${streaks.currentStreak}-day streak and counting! Keep going — habits typically solidify after 21 days.',
          emoji: '📈',
        ));
      }
    } else {
      insights.add(AiInsight(
        title: 'Fresh start',
        body:
            'Complete a reminder today to start a new streak. Every great journey begins with a single step!',
        emoji: '🌱',
      ));
    }

    // Completion rate insight
    if (stats.completionRate >= 0.9) {
      insights.add(AiInsight(
        title: 'Top performer',
        body:
            '${(stats.completionRate * 100).toStringAsFixed(0)}% completion rate — you\'re in the elite category. Most people average around 60%.',
        emoji: '🏆',
      ));
    } else if (stats.completionRate >= 0.7) {
      insights.add(AiInsight(
        title: 'Solid consistency',
        body:
            '${(stats.completionRate * 100).toStringAsFixed(0)}% completion rate. Try snoozing instead of missing — it keeps you accountable.',
        emoji: '💪',
      ));
    } else if (stats.totalCompleted > 0) {
      insights.add(AiInsight(
        title: 'Room to grow',
        body:
            '${(stats.completionRate * 100).toStringAsFixed(0)}% completion rate. Consider reducing the number of reminders to focus on what matters most.',
        emoji: '🎯',
      ));
    }

    // Week-over-week insight
    if (stats.thisWeekRate > stats.lastWeekRate && stats.lastWeekRate > 0) {
      final improvement =
          ((stats.thisWeekRate - stats.lastWeekRate) * 100).toStringAsFixed(0);
      insights.add(AiInsight(
        title: 'Trending up!',
        body:
            'You\'re $improvement% more productive this week compared to last week. The upward trend is real.',
        emoji: '🚀',
      ));
    } else if (stats.thisWeekRate < stats.lastWeekRate &&
        stats.lastWeekRate > 0) {
      insights.add(AiInsight(
        title: 'Slight dip',
        body:
            'This week is a bit slower than last. That\'s normal — focus on completing just one more reminder today.',
        emoji: '💡',
      ));
    }

    // Most productive hour
    if (stats.mostProductiveHour != null) {
      insights.add(AiInsight(
        title: 'Peak hour: ${stats.mostProductiveHour}',
        body:
            'You complete the most reminders around ${stats.mostProductiveHour}. Schedule important tasks here for best results.',
        emoji: '⏰',
      ));
    }

    // Most consistent reminder
    if (stats.mostConsistentReminder != null) {
      insights.add(AiInsight(
        title: 'Star reminder',
        body:
            '"${stats.mostConsistentReminder}" is your most consistently completed reminder. It\'s become a true habit!',
        emoji: '⭐',
      ));
    }

    // Activity pattern from heatmap
    final activeDays = heatmap.where((d) => d.completedCount > 0).length;
    if (activeDays > 0) {
      final percentage = ((activeDays / heatmap.length) * 100).toStringAsFixed(0);
      insights.add(AiInsight(
        title: 'Activity coverage',
        body:
            'You\'ve been active on $activeDays out of the last ${heatmap.length} days ($percentage%). Every day you show up counts.',
        emoji: '📊',
      ));
    }

    return insights;
  }

  /// Compute achievements based on all data.
  List<Achievement> computeAchievements(
    List<Reminder> reminders,
    StreakData streaks,
    ProductivityStats stats,
  ) {
    // Check for early bird / night owl
    bool hasEarlyMorning = false;
    bool hasLateNight = false;

    for (final r in reminders) {
      if (r.isCompleted || (r.consistency?.completedCount ?? 0) > 0) {
        if (r.time.hour < 7) hasEarlyMorning = true;
        if (r.time.hour >= 23) hasLateNight = true;
      }
    }

    // Check for perfect day (all reminders completed in a single day)
    bool hasPerfectDay = stats.completedToday > 0 &&
        stats.completedToday >= stats.totalToday &&
        stats.totalToday > 0;

    // Perfect week: 7+ day streak
    bool hasPerfectWeek = streaks.bestStreak >= 7;

    // Comeback: week-over-week improvement > 30%
    bool hasComeback =
        stats.weekOverWeekChange > 0.3 && stats.lastWeekRate > 0;

    return Achievement.allAchievements(
      currentStreak: streaks.currentStreak,
      bestStreak: streaks.bestStreak,
      totalCompleted: stats.totalCompleted,
      completionRate: stats.completionRate,
      hasEarlyMorning: hasEarlyMorning,
      hasLateNight: hasLateNight,
      hasPerfectDay: hasPerfectDay,
      hasPerfectWeek: hasPerfectWeek,
      hasComeback: hasComeback,
      consistencyRate: stats.completionRate,
    );
  }

  /// Main entry: fetch all data and compute everything.
  Future<PulseData> loadPulseData() async {
    final reminders = await _fetchAllReminders();
    final completedDates = _getAllCompletedDates(reminders);
    final streaks = computeStreaks(completedDates);
    final heatmap = computeHeatmap(reminders, days: 91); // 13 weeks
    final stats = computeStats(reminders);
    final insights = generateInsights(stats, streaks, heatmap);
    final achievements = computeAchievements(reminders, streaks, stats);

    return PulseData(
      streaks: streaks,
      heatmap: heatmap,
      stats: stats,
      insights: insights,
      achievements: achievements,
    );
  }
}

/// All Pulse data bundled together.
class PulseData {
  final StreakData streaks;
  final List<DayActivity> heatmap;
  final ProductivityStats stats;
  final List<AiInsight> insights;
  final List<Achievement> achievements;

  const PulseData({
    required this.streaks,
    required this.heatmap,
    required this.stats,
    required this.insights,
    required this.achievements,
  });
}
