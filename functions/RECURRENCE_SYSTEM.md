# Reminder Recurrence System Documentation

## Overview

This is a **backend-only** recurrence system for a Firebase-based reminders app. It follows the principle of **storing recurrence rules, not repeated documents**, and only calculates the next occurrence when an explicit event happens (e.g., reminder completion).

## Core Principles

1. ✅ **Store recurrence RULES, not repeated documents**
2. ✅ **Only compute the NEXT due time on explicit events**
3. ✅ **Backend is the source of truth**
4. ❌ **NO pre-generation of future instances**
5. ❌ **NO cron jobs or scheduled functions**
6. ❌ **NO polling or timers**

## Data Model

Each reminder is stored at: `users/{userId}/reminders/{reminderId}`

```typescript
{
  id: string,
  title: string,
  status: "active" | "paused",
  nextDueAt: Timestamp,           // Only the NEXT occurrence
  recurrence: {
    type: "interval" | "weekly" | "monthly",
    
    // For interval-based (e.g., "Every 3 days")
    every?: number,               // 1, 2, 3, etc.
    unit?: "minutes" | "hours" | "days",
    anchor?: "completion" | "scheduled",  // When to calculate from
    
    // For weekly (e.g., "Every Monday and Wednesday at 9am")
    days?: string[],              // ["mon", "wed", "fri"]
    time?: string,                // "HH:mm" format
    
    // For monthly (e.g., "15th of every month")
    pattern?: "dayOfMonth" | "nthWeekday",
    value?: number                // Day number or nth occurrence
  },
  lastCompletedAt?: Timestamp,
  updatedAt: Timestamp,
  version: number                 // For idempotency
}
```

## Recurrence Types

### 1. Interval Recurrence

Repeat every X time units from a reference point.

**Examples:**
- Every 3 days
- Every 2 hours
- Every 30 minutes

**Configuration:**
```json
{
  "type": "interval",
  "every": 3,
  "unit": "days",
  "anchor": "completion"
}
```

**Anchor Modes:**
- `"completion"`: Next due = last completion + interval
  - Use for: "3 days after I complete it"
  - Example: Take medicine 8 hours after the last dose
  
- `"scheduled"`: Next due = last scheduled + interval
  - Use for: "Every 3 days regardless of when I complete it"
  - Example: Water plants every 7 days

### 2. Weekly Recurrence

Repeat on specific days of the week at a specific time.

**Examples:**
- Every Monday at 9:00 AM
- Every Mon/Wed/Fri at 14:30

**Configuration:**
```json
{
  "type": "weekly",
  "days": ["mon", "wed", "fri"],
  "time": "09:00"
}
```

**Day Names:** `sun`, `mon`, `tue`, `wed`, `thu`, `fri`, `sat`

### 3. Monthly Recurrence

Repeat on a specific day of each month.

**Pattern: Day of Month**
```json
{
  "type": "monthly",
  "pattern": "dayOfMonth",
  "value": 15,
  "time": "09:00"
}
```
- Repeats on the 15th of every month
- Handles months with fewer days (e.g., Feb 31 → Feb 28/29)

**Pattern: Nth Weekday**
```json
{
  "type": "monthly",
  "pattern": "nthWeekday",
  "value": 2,
  "time": "09:00"
}
```
- Repeats on the 2nd occurrence of the current weekday
- `value: -1` means the last occurrence

## Cloud Functions

### 1. `completeReminder`

**Type:** HTTPS Callable Function

**Purpose:** Mark a reminder as completed and calculate the next occurrence.

**Request:**
```typescript
{
  reminderId: string,
  completedAt?: number,      // Optional: timestamp in ms
  currentVersion?: number    // Optional: for idempotency
}
```

**Response:**
```typescript
{
  success: boolean,
  duplicate: boolean,        // True if already processed
  nextDueAt: string | null,  // ISO 8601 date string
  hasRecurrence: boolean
}
```

**Example Usage:**
```javascript
const result = await firebase.functions().httpsCallable('completeReminder')({
  reminderId: 'abc123',
  currentVersion: 5
});

console.log(result.data.nextDueAt);
// "2026-01-24T09:00:00.000Z"
```

**What It Does:**
1. Validates user authentication
2. Fetches the reminder document
3. Checks for duplicate completions (idempotency)
4. Updates `lastCompletedAt` timestamp
5. Calculates `nextDueAt` using the recurrence rule
6. Increments `version` number
7. Updates the Firestore document atomically

**Idempotency:**
The function uses the `version` field to prevent processing the same completion twice. If you provide `currentVersion` and it's less than the stored version, the function returns `duplicate: true` without making changes.

### 2. `updateReminderRecurrence`

**Type:** HTTPS Callable Function

**Purpose:** Update the recurrence rule of an existing reminder.

**Request:**
```typescript
{
  reminderId: string,
  recurrence: RecurrenceConfig
}
```

**Response:**
```typescript
{
  success: boolean,
  nextDueAt: string | null
}
```

**Example Usage:**
```javascript
const result = await firebase.functions().httpsCallable('updateReminderRecurrence')({
  reminderId: 'abc123',
  recurrence: {
    type: 'weekly',
    days: ['mon', 'wed', 'fri'],
    time: '09:00'
  }
});
```

### 3. `onReminderCompleted`

**Type:** Firestore Trigger

**Purpose:** Logs reminder completions for analytics and debugging.

**Trigger Path:** `users/{userId}/reminders/{reminderId}`

**What It Does:**
- Detects when a reminder is completed
- Logs completion details to console
- Can be extended for analytics, streak tracking, etc.

## Core Algorithm: `calculateNextDueAt`

This is the **pure function** at the heart of the system.

**Signature:**
```typescript
function calculateNextDueAt(reminder: Reminder): Date | null
```

**Input:** A reminder document with recurrence configuration

**Output:** The next due date as a Date object, or `null` if no recurrence

**Key Features:**
- **Pure function:** No side effects, no Firestore writes
- **Testable:** Easy to unit test with various scenarios
- **Timezone-safe:** Works with UTC timestamps internally
- **Edge case handling:** Handles invalid dates, missing fields, etc.

**Algorithm Flow:**
```
1. Check if reminder has recurrence
   ├─ NO → Return null (one-time reminder)
   └─ YES → Continue

2. Switch on recurrence.type:
   ├─ "interval" → calculateIntervalNextDue()
   ├─ "weekly" → calculateWeeklyNextDue()
   └─ "monthly" → calculateMonthlyNextDue()

3. Return the calculated Date
```

## Edge Cases Handled

### 1. One-Time Reminders
If `recurrence` is not defined, `calculateNextDueAt` returns `null`, and the reminder is marked as `"paused"` after completion.

### 2. Interval Anchored to Completion vs Scheduled
- **Completion anchor:** Medicine taken 8 hours after the last dose
- **Scheduled anchor:** Water plants every 7 days, even if you forgot

### 3. Weekly Recurrence with Multiple Days
The function finds the next valid day and time, handling week wraparound.

### 4. Monthly Edge Cases
- **Day 31 in February:** Rolls to Feb 28/29 (last day of month)
- **Nth weekday that doesn't exist:** Uses the last occurrence

### 5. Past Due Times
If a reminder wasn't completed for a long time, the interval algorithm keeps adding intervals until the next due date is in the future.

### 6. Timezone Safety
All calculations use JavaScript Date objects and Firestore Timestamps, which handle timezone conversions automatically. The frontend should display times in the user's local timezone.

## Idempotency

The system ensures idempotency using the `version` field:

```typescript
// First completion
completeReminder({ reminderId: 'abc', currentVersion: 1 });
// Updates version to 2, calculates next due

// Duplicate completion (e.g., network retry)
completeReminder({ reminderId: 'abc', currentVersion: 1 });
// Detects version mismatch, returns duplicate: true
```

This prevents:
- Double-advancing the recurrence
- Processing the same completion event multiple times
- Race conditions from multiple devices

## Testing Examples

### Example 1: Interval Recurrence (Completion Anchor)

**Reminder:**
```json
{
  "id": "med-reminder",
  "title": "Take medication",
  "nextDueAt": "2026-01-21T09:00:00Z",
  "lastCompletedAt": "2026-01-21T10:30:00Z",
  "recurrence": {
    "type": "interval",
    "every": 8,
    "unit": "hours",
    "anchor": "completion"
  },
  "version": 3
}
```

**Result:**
```
Next due: 2026-01-21T18:30:00Z
(8 hours after 10:30 completion)
```

### Example 2: Weekly Recurrence

**Reminder:**
```json
{
  "title": "Team meeting",
  "recurrence": {
    "type": "weekly",
    "days": ["mon", "wed"],
    "time": "14:00"
  }
}
```

**Current time:** Tuesday, Jan 21, 2026 at 10:00

**Result:**
```
Next due: Wednesday, Jan 22, 2026 at 14:00
```

### Example 3: Monthly Recurrence

**Reminder:**
```json
{
  "title": "Pay rent",
  "recurrence": {
    "type": "monthly",
    "pattern": "dayOfMonth",
    "value": 1,
    "time": "09:00"
  }
}
```

**Current time:** Jan 21, 2026

**Result:**
```
Next due: February 1, 2026 at 09:00
```

## Integration Guide

### Client-Side (Flutter/Dart)

**Complete a reminder:**
```dart
final callable = FirebaseFunctions.instance.httpsCallable('completeReminder');
final result = await callable.call({
  'reminderId': reminderId,
  'currentVersion': reminder.version,
});

if (result.data['duplicate']) {
  print('Already processed');
} else {
  print('Next due: ${result.data['nextDueAt']}');
}
```

**Update recurrence:**
```dart
final callable = FirebaseFunctions.instance.httpsCallable('updateReminderRecurrence');
await callable.call({
  'reminderId': reminderId,
  'recurrence': {
    'type': 'weekly',
    'days': ['mon', 'wed', 'fri'],
    'time': '09:00',
  },
});
```

## Deployment

1. **Build the functions:**
   ```bash
   cd functions
   npm run build
   ```

2. **Deploy to Firebase:**
   ```bash
   npm run deploy
   ```

3. **Test locally:**
   ```bash
   npm run serve
   ```

## Limitations & Future Enhancements

**Current Limitations:**
- Monthly nth weekday uses current weekday (could be configurable)
- No support for complex patterns like "every other week"
- No support for exclusion dates (holidays, etc.)

**Potential Enhancements:**
- Add support for custom recurrence patterns
- Add support for multiple time zones per user
- Add undo functionality for accidental completions
- Add snooze functionality
- Track completion streaks and statistics

## Security Rules

Ensure your Firestore security rules allow authenticated users to update their own reminders:

```javascript
match /users/{userId}/reminders/{reminderId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

## Performance Considerations

- **No N+1 queries:** All operations use single document reads/writes
- **Atomic updates:** Transactions ensure consistency
- **No background jobs:** No overhead from cron scheduling
- **Scalable:** Each completion is independent, scales horizontally

## Conclusion

This recurrence system is:
- ✅ **Scalable:** No background jobs or batch operations
- ✅ **Efficient:** Only calculates next occurrence on demand
- ✅ **Maintainable:** Pure functions, clear separation of concerns
- ✅ **Idempotent:** Safe to retry without side effects
- ✅ **Testable:** Core logic is pure and isolated

Perfect for a hackathon demo! 🚀
