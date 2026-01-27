# Consistency Tracking for Recurring Reminders

## Overview
The consistency tracking system evaluates recurring reminders on a **per-scheduled-day** basis. It accurately tracks completed and missed occurrences without double-counting or false positives.

## Core Rules

### 1. **Per-Day Evaluation**
- Each scheduled day is evaluated **exactly once**
- Evaluation happens when the reminder is completed OR when moving to the next occurrence
- Once evaluated, a day cannot be re-evaluated

### 2. **Completion Rules**
- If user presses "Done" on the **same calendar day** as scheduled: **COMPLETED**
- If user presses "Done" late (after the scheduled day): Previous day is marked **MISSED**, current day is **NOT COMPLETED**
- Snooze actions **DO NOT** affect consistency tracking

### 3. **Missed Detection**
- When calculating next recurrence, check if the previous scheduled day was missed
- A day is missed if: `current_date > scheduled_day AND user_did_not_complete AND day_not_already_evaluated`

## Data Model

```typescript
consistency: {
  completedCount: number,    // Total days completed on time
  missedCount: number,       // Total days missed
  lastEvaluatedDate: string  // YYYY-MM-DD (last day evaluated)
}
```

**Percentage Calculation:**
```
consistency% = (completedCount / (completedCount + missedCount)) × 100
```

## Implementation Flow

### When User Completes a Reminder

```typescript
1. Get scheduled day from nextDueAt (e.g., "2026-01-27")
2. Get completion day from timestamp (e.g., "2026-01-27")

3. IF scheduled_day < today:
   - Check if scheduled_day already evaluated
   - If NOT evaluated: Mark as MISSED
   - Update lastEvaluatedDate = scheduled_day

4. IF completion_day == scheduled_day:
   - Check if scheduled_day already evaluated
   - If NOT evaluated: Mark as COMPLETED
   - Update lastEvaluatedDate = scheduled_day

5. Calculate next recurrence
6. Save updates to Firestore
```

### Example Scenarios

#### Scenario 1: Perfect On-Time Completion
```
Day 1 (Mon): Scheduled 9:00 AM, Completed 9:30 AM
  → completedCount: 1, missedCount: 0 (100%)

Day 2 (Tue): Scheduled 9:00 AM, Completed 10:00 AM
  → completedCount: 2, missedCount: 0 (100%)
```

#### Scenario 2: Late Completion (Same Day)
```
Day 1 (Mon): Scheduled 9:00 AM, Completed 11:50 PM
  → completedCount: 1, missedCount: 0 (100%)
  ✓ Still counts as completed (same calendar day)
```

#### Scenario 3: Missed Day
```
Day 1 (Mon): Scheduled 9:00 AM, Never completed

Day 2 (Tue): User completes reminder at 10:00 AM
  → System detects Monday was missed
  → completedCount: 0, missedCount: 1 (0%)
  → Tuesday's completion doesn't count (not scheduled for Tuesday)
```

#### Scenario 4: Recovering After Miss
```
Day 1: Missed (0/1 = 0%)
Day 2: Completed on time (1/2 = 50%)
Day 3: Completed on time (2/3 = 67%)
Day 4: Completed on time (3/4 = 75%)
```

## Backend Implementation (Firebase Functions)

### Helper Functions

```typescript
// Convert Date to YYYY-MM-DD
function formatDateToYYYYMMDD(date: Date): string

// Get scheduled day from Firestore Timestamp
function getScheduledDay(timestamp: Timestamp): string

// Check if day already evaluated
function isDayAlreadyEvaluated(
  consistency: ConsistencyData,
  scheduledDay: string
): boolean

// Mark day as completed
function markDayCompleted(
  consistency: ConsistencyData,
  scheduledDay: string
): ConsistencyData

// Mark day as missed
function markDayMissed(
  consistency: ConsistencyData,
  scheduledDay: string
): ConsistencyData

// Check if scheduled day should be marked missed
function shouldMarkAsMissed(reminder: Reminder): boolean
```

### Transaction Logic

```typescript
// In markReminderCompleted function:

1. Check if previous scheduled day should be marked as missed
   if (shouldMarkAsMissed(reminder)) {
     reminder.consistency = markDayMissed(...)
   }

2. Check if current completion is on scheduled day
   if (completionDay === scheduledDay && !isDayAlreadyEvaluated(...)) {
     reminder.consistency = markDayCompleted(...)
   }

3. Calculate next recurrence
4. Save updated consistency data
```

## Frontend Implementation (Flutter)

### Data Class

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

### Usage in Reminder Model

```dart
class Reminder {
  final ConsistencyData? consistency;
  
  double get consistencyPercentage {
    if (consistency == null) return 0.0;
    return consistency!.percentage;
  }
}
```

### UI Display

```dart
// In reminder list screen
if (reminder.recurrence != null && !reminder.isCompleted) {
  _buildConsistencyMeter(reminder)
}

Widget _buildConsistencyMeter(Reminder reminder) {
  final percentage = reminder.consistencyPercentage;
  
  return CircularProgressIndicator(
    value: percentage / 100,
    // Show percentage text
    child: Text('${percentage.toInt()}%'),
  );
}
```

## Key Advantages

### ✅ Accurate Tracking
- No double-counting
- No false positives
- Each day evaluated exactly once

### ✅ Fair to Users
- Same-day completion always counts (even if late)
- Snoozing doesn't penalize consistency
- Clear, predictable rules

### ✅ Efficient
- No unbounded arrays
- No completion history storage
- Minimal Firestore writes

### ✅ Idempotent
- Multiple completions for same day don't break tracking
- Safe to retry operations
- Consistent state guaranteed

## What This System Does NOT Do

❌ Does NOT store completion timestamps  
❌ Does NOT use cron jobs or background scans  
❌ Does NOT track "expected" count (uses completed + missed instead)  
❌ Does NOT penalize snoozing  
❌ Does NOT require client-side logic  

## Migration Notes

If upgrading from previous consistency tracking:

1. **Old fields** (remove these):
   - `totalCompletions`
   - `totalExpected`
   - `completionHistory`
   - `recurringGroupId`

2. **New field** (add this):
   - `consistency: { completedCount: 0, missedCount: 0, lastEvaluatedDate: '' }`

3. **Behavior changes**:
   - Percentage now based on `completed / (completed + missed)`
   - Late completions on same day count as completed
   - System automatically detects and marks missed days
