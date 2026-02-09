/// Models for the Pulse productivity insights feature.

class StreakData {
  final int currentStreak;
  final int bestStreak;
  final DateTime? streakStartDate;
  final bool isActiveToday;

  const StreakData({
    required this.currentStreak,
    required this.bestStreak,
    this.streakStartDate,
    this.isActiveToday = false,
  });
}

class ProductivityStats {
  final int totalCompleted;
  final int totalMissed;
  final double completionRate; // 0.0 - 1.0
  final int activeReminders;
  final String? mostProductiveHour; // e.g., "9 AM"
  final String? mostConsistentReminder;
  final double thisWeekRate; // 0.0 - 1.0
  final double lastWeekRate; // 0.0 - 1.0
  final int completedToday;
  final int totalToday;

  const ProductivityStats({
    required this.totalCompleted,
    required this.totalMissed,
    required this.completionRate,
    required this.activeReminders,
    this.mostProductiveHour,
    this.mostConsistentReminder,
    required this.thisWeekRate,
    required this.lastWeekRate,
    required this.completedToday,
    required this.totalToday,
  });

  double get weekOverWeekChange => thisWeekRate - lastWeekRate;
  bool get isImproving => weekOverWeekChange > 0;
}

enum AchievementType {
  firstComplete,
  streak3,
  streak7,
  streak14,
  streak30,
  perfectDay,
  perfectWeek,
  earlyBird,
  nightOwl,
  centurion,
  consistent,
  comeback,
}

class Achievement {
  final AchievementType type;
  final String title;
  final String description;
  final String emoji;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.type,
    required this.title,
    required this.description,
    required this.emoji,
    required this.isUnlocked,
    this.unlockedAt,
  });

  static List<Achievement> allAchievements({
    required int currentStreak,
    required int bestStreak,
    required int totalCompleted,
    required double completionRate,
    required bool hasEarlyMorning,
    required bool hasLateNight,
    required bool hasPerfectDay,
    required bool hasPerfectWeek,
    required bool hasComeback,
    required double consistencyRate,
  }) {
    return [
      Achievement(
        type: AchievementType.firstComplete,
        title: 'First Step',
        description: 'Complete your first reminder',
        emoji: '🎯',
        isUnlocked: totalCompleted >= 1,
      ),
      Achievement(
        type: AchievementType.streak3,
        title: 'On a Roll',
        description: '3-day completion streak',
        emoji: '🔥',
        isUnlocked: bestStreak >= 3,
      ),
      Achievement(
        type: AchievementType.streak7,
        title: 'Week Warrior',
        description: '7-day completion streak',
        emoji: '⚡',
        isUnlocked: bestStreak >= 7,
      ),
      Achievement(
        type: AchievementType.streak14,
        title: 'Unstoppable',
        description: '14-day completion streak',
        emoji: '🚀',
        isUnlocked: bestStreak >= 14,
      ),
      Achievement(
        type: AchievementType.streak30,
        title: 'Legendary',
        description: '30-day completion streak',
        emoji: '👑',
        isUnlocked: bestStreak >= 30,
      ),
      Achievement(
        type: AchievementType.perfectDay,
        title: 'Perfect Day',
        description: 'Complete all reminders in a day',
        emoji: '✨',
        isUnlocked: hasPerfectDay,
      ),
      Achievement(
        type: AchievementType.perfectWeek,
        title: 'Perfect Week',
        description: 'Complete all reminders for 7 days straight',
        emoji: '💎',
        isUnlocked: hasPerfectWeek,
      ),
      Achievement(
        type: AchievementType.earlyBird,
        title: 'Early Bird',
        description: 'Complete a reminder before 7 AM',
        emoji: '🌅',
        isUnlocked: hasEarlyMorning,
      ),
      Achievement(
        type: AchievementType.nightOwl,
        title: 'Night Owl',
        description: 'Complete a reminder after 11 PM',
        emoji: '🦉',
        isUnlocked: hasLateNight,
      ),
      Achievement(
        type: AchievementType.centurion,
        title: 'Centurion',
        description: 'Complete 100 reminders',
        emoji: '💯',
        isUnlocked: totalCompleted >= 100,
      ),
      Achievement(
        type: AchievementType.consistent,
        title: 'Consistency King',
        description: 'Maintain 90%+ completion rate',
        emoji: '🏆',
        isUnlocked: consistencyRate >= 0.9 && totalCompleted >= 10,
      ),
      Achievement(
        type: AchievementType.comeback,
        title: 'Comeback Kid',
        description: 'Improve your weekly rate by 30%+',
        emoji: '💪',
        isUnlocked: hasComeback,
      ),
    ];
  }
}

/// Represents a single day's activity for the heatmap.
class DayActivity {
  final DateTime date;
  final int completedCount;
  final int totalCount;

  const DayActivity({
    required this.date,
    required this.completedCount,
    required this.totalCount,
  });

  double get rate =>
      totalCount > 0 ? completedCount / totalCount : 0.0;

  /// 0 = no activity, 1-4 = activity levels (like GitHub)
  int get level {
    if (totalCount == 0) return 0;
    final r = rate;
    if (r == 0) return 0;
    if (r < 0.25) return 1;
    if (r < 0.5) return 2;
    if (r < 0.75) return 3;
    return 4;
  }
}

class AiInsight {
  final String title;
  final String body;
  final String emoji;

  const AiInsight({
    required this.title,
    required this.body,
    required this.emoji,
  });
}
