# Consistency Tracking System - Changelog

## Summary of Changes

The consistency tracking system has been completely rewritten to follow a **per-scheduled-day evaluation** model that is accurate, idempotent, and efficient.

## What Changed

### Backend (Firebase Functions)

#### ✅ Added Helper Functions (`recurrenceFunctions.ts`)

```typescript
// Date formatting and extraction
formatDateToYYYYMMDD(date: Date): string
getScheduledDay(timestamp: Timestamp): string

// Evaluation logic
isDayAlreadyEvaluated(consistency, scheduledDay): boolean
shouldMarkAsMissed(reminder): boolean

// State updates
markDayCompleted(consistency, scheduledDay): ConsistencyData
markDayMissed(consistency, scheduledDay): ConsistencyData
```

#### ✅ Updated `markReminderCompleted()` Function

**Before:**
- Incremented `totalCompletions` on every completion
- Incremented `totalExpected` when scheduling next recurrence
- No logic to detect missed days
- Used `completionHistory` array (unbounded growth)

**After:**
- Checks if previous scheduled day was missed BEFORE calculating next recurrence
- Marks day as completed ONLY if completed on scheduled day
- Uses `lastEvaluatedDate` to prevent double-counting
- No arrays, just three numbers: `completedCount`, `missedCount`, `lastEvaluatedDate`

#### ✅ Added New Interface

```typescript
interface ConsistencyData {
  completedCount: number;
  missedCount: number;
  lastEvaluatedDate: string; // YYYY-MM-DD
}
```

### Frontend (Flutter)

#### ✅ Created `ConsistencyData` Class (`reminder_model.dart`)

```dart
class ConsistencyData {
  final int completedCount;
  final int missedCount;
  final String lastEvaluatedDate;
  
  double get percentage {
    final total = completedCount + missedCount;
    if (total == 0) return 0.0;
    return (completedCount / total) * 100;
  }
}
```

#### ✅ Updated `Reminder` Model

**Removed:**
- `totalCompletions` field
- `totalExpected` field
- `completionHistory` field
- `recurringGroupId` field

**Added:**
- `consistency` field (type: `ConsistencyData?`)

**Updated:**
- `consistencyPercentage` getter now uses `consistency.percentage`

#### ✅ Simplified `ReminderService` (`reminder_service.dart`)

**Removed:**
- Complex batch updates across recurring groups
- `completionHistory` array management
- Client-side consistency increment logic

**New Behavior:**
- Just marks reminder as completed
- All consistency logic handled by Firebase Functions
- Simpler, cleaner code

## New Rules vs Old Rules

| Aspect | Old System | New System |
|--------|------------|------------|
| **Tracking Method** | Expected count increments | Per-day evaluation |
| **Late Completion** | Counted as completed regardless | Only if same calendar day |
| **Missed Detection** | Never detected automatically | Auto-detected before next recurrence |
| **Double Counting** | Possible if not careful | Prevented by `lastEvaluatedDate` |
| **Storage** | Arrays + counters | Three fields only |
| **Calculation** | `completions / expected` | `completed / (completed + missed)` |

## Example Behavior Comparison

### Scenario: Daily reminder, user completes late

**Day 1 (Mon):** Scheduled 9 AM  
**Day 2 (Tue):** User completes at 10 AM

#### Old System:
```
✗ Day 1: totalExpected = 1
✗ Day 2: totalExpected = 2, totalCompletions = 1
✗ Consistency: 1/2 = 50%
✗ Problem: User didn't miss Day 1, they completed it late!
```

#### New System:
```
✓ Day 1: Not completed by end of day
✓ Day 2: System detects Day 1 was missed
✓ missedCount = 1, completedCount = 0
✓ Consistency: 0/1 = 0%
✓ Day 2 completion doesn't count (not scheduled for Day 2)
```

### Scenario: User completes on time

**Day 1 (Mon):** Scheduled 9 AM, Completed 9:30 AM  
**Day 2 (Tue):** Scheduled 9 AM, Completed 11:50 PM

#### Old System:
```
Day 1: totalExpected = 1, totalCompletions = 1 (100%)
Day 2: totalExpected = 2, totalCompletions = 2 (100%)
```

#### New System:
```
Day 1: completedCount = 1, missedCount = 0 (100%)
Day 2: completedCount = 2, missedCount = 0 (100%)
✓ Same result, but more accurate tracking
```

## Migration Path

### For Existing Reminders

1. **Option A: Automatic Migration (Recommended)**
   - Keep old fields temporarily
   - Initialize `consistency` with defaults on next completion
   - Gradually phase out old fields

2. **Option B: One-Time Migration Script**
   ```typescript
   // For each reminder with recurrence:
   if (reminder.totalCompletions && !reminder.consistency) {
     reminder.consistency = {
       completedCount: reminder.totalCompletions || 0,
       missedCount: (reminder.totalExpected || 0) - (reminder.totalCompletions || 0),
       lastEvaluatedDate: formatDateToYYYYMMDD(new Date())
     };
   }
   ```

3. **Option C: Clean Slate**
   - Start fresh with `consistency` = `{ completedCount: 0, missedCount: 0, lastEvaluatedDate: '' }`
   - Most accurate for future tracking

### For New Reminders

- Automatically initialize with empty consistency data
- Already implemented in `addReminder()` function

## Testing Checklist

- [ ] Create daily recurring reminder
- [ ] Complete on same day → Check `completedCount` increments
- [ ] Skip a day → Check `missedCount` increments
- [ ] Complete late (next day) → Check previous day marked missed
- [ ] Complete multiple times same day → Check no double-counting
- [ ] Verify consistency percentage displays correctly
- [ ] Test across date boundaries (11:59 PM → 12:01 AM)
- [ ] Verify snooze doesn't affect consistency

## Files Modified

### Backend
- `functions/src/recurrenceFunctions.ts` - Core logic

### Frontend
- `lib/features/reminders/domain/reminder_model.dart` - Data model
- `lib/features/reminders/data/reminder_service.dart` - Service layer
- `lib/features/reminders/presentation/reminder_list_screen.dart` - UI (uses new model)

### Documentation
- `CONSISTENCY_TRACKING.md` - Complete system documentation
- `CONSISTENCY_TRACKING_CHANGELOG.md` - This file

## Benefits of New System

1. **Accuracy**: Each day evaluated exactly once
2. **Fairness**: Same-day completion always counts
3. **Efficiency**: No unbounded arrays or histories
4. **Simplicity**: Clear, predictable rules
5. **Idempotency**: Safe to retry operations
6. **Backend-Only**: No complex client-side logic

## Known Limitations

1. **Timezone Handling**: Uses local date (YYYY-MM-DD) - ensure consistent timezone usage
2. **No Historical Data**: Cannot retroactively calculate consistency for old reminders
3. **No Partial Credit**: Either completed or missed, no in-between
4. **Snooze Transparency**: Snoozing doesn't extend the deadline

These limitations are by design for simplicity and accuracy.
