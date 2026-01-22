# Recurrence System - Visual Architecture

## System Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER ACTION                              │
│                 (Completes a reminder)                          │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FLUTTER APP (Client)                          │
│                                                                  │
│  FirebaseFunctions.instance                                     │
│    .httpsCallable('completeReminder')                           │
│    .call({                                                      │
│      reminderId: 'abc123',                                      │
│      currentVersion: 5                                          │
│    })                                                           │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            │ HTTPS Request
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│               FIREBASE CLOUD FUNCTION                            │
│                 completeReminder()                              │
│                                                                  │
│  1. Validate authentication ✓                                   │
│  2. Start Firestore transaction                                 │
│  3. Read reminder document                                      │
│  4. Check version (idempotency)                                 │
│  5. Call calculateNextDueAt(reminder) ───────┐                  │
│  6. Update Firestore                         │                  │
│  7. Return result                            │                  │
└──────────────────────────────────────────────┼──────────────────┘
                            │                  │
                            │                  │
                            │    ┌─────────────▼──────────────┐
                            │    │  calculateNextDueAt()      │
                            │    │  (Pure Function)           │
                            │    │                            │
                            │    │  switch (recurrence.type)  │
                            │    │    ├─ interval             │
                            │    │    ├─ weekly               │
                            │    │    └─ monthly              │
                            │    │                            │
                            │    │  return Date               │
                            │    └────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                  FIRESTORE UPDATE                                │
│                                                                  │
│  users/{userId}/reminders/{reminderId}                          │
│  {                                                               │
│    lastCompletedAt: NOW ✓                                       │
│    nextDueAt: 2026-01-24T09:00:00Z ✓                           │
│    version: 6 ✓                                                 │
│    updatedAt: NOW ✓                                             │
│  }                                                               │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            │ Response
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FLUTTER APP (Client)                          │
│                                                                  │
│  result.data = {                                                │
│    success: true,                                               │
│    duplicate: false,                                            │
│    nextDueAt: "2026-01-24T09:00:00Z",                          │
│    hasRecurrence: true                                          │
│  }                                                               │
│                                                                  │
│  → Update UI                                                    │
│  → Show next occurrence to user                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow - Recurrence Types

```
┌─────────────────────────────────────────────────────────────────┐
│                    INTERVAL RECURRENCE                           │
│                  "Every 3 days"                                 │
└───────────────────────────┬─────────────────────────────────────┘
                            │
            ┌───────────────┴────────────────┐
            │                                │
            ▼                                ▼
    ┌──────────────┐               ┌──────────────┐
    │ Completion   │               │  Scheduled   │
    │   Anchor     │               │   Anchor     │
    └──────┬───────┘               └──────┬───────┘
           │                              │
           │ Last completed:              │ Last scheduled:
           │ Jan 21 10:30 AM              │ Jan 21 09:00 AM
           │                              │
           │ + 3 days                     │ + 3 days
           │                              │
           ▼                              ▼
    Jan 24 10:30 AM               Jan 24 09:00 AM
    (3 days after I              (3 days regardless
     completed it)                of when I did it)


┌─────────────────────────────────────────────────────────────────┐
│                    WEEKLY RECURRENCE                             │
│              "Every Mon/Wed/Fri at 9am"                         │
└───────────────────────────┬─────────────────────────────────────┘
                            │
            Current: Tuesday Jan 21, 10am
                            │
            ┌───────────────┴────────────────┐
            │                                │
     Mon passed                      Wed not passed yet
            │                                │
            ▼                                ▼
    Skip to next Mon           Use Wed (tomorrow)
         (Jan 27)                  (Jan 22)
            │                                │
            └───────────────┬────────────────┘
                            │
                            ▼
                   Wed, Jan 22 at 9am


┌─────────────────────────────────────────────────────────────────┐
│                   MONTHLY RECURRENCE                             │
│                "15th of every month"                            │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                  Current: Jan 21
                            │
            ┌───────────────┴────────────────┐
            │                                │
     15th passed                      15th not passed
        this month                       this month
            │                                │
            ▼                                ▼
     Next month 15th              This month 15th
      (Feb 15)                        (Jan 15)
            │                                │
            └───────────────┬────────────────┘
                            │
                            ▼
                 Edge case handling:
                 Feb 31 → Feb 28/29
```

## Database Schema Visualization

```
Firestore Structure:

users/
  └── {userId}/
       └── reminders/
            ├── reminder-1/
            │    ├── id: "reminder-1"
            │    ├── title: "Take medicine"
            │    ├── status: "active"
            │    ├── nextDueAt: Timestamp(2026-01-21T18:00:00Z)
            │    ├── recurrence: {
            │    │     type: "interval",
            │    │     every: 8,
            │    │     unit: "hours",
            │    │     anchor: "completion"
            │    │   }
            │    ├── lastCompletedAt: Timestamp(2026-01-21T10:00:00Z)
            │    ├── version: 5
            │    └── updatedAt: Timestamp(...)
            │
            ├── reminder-2/
            │    ├── id: "reminder-2"
            │    ├── title: "Team meeting"
            │    ├── status: "active"
            │    ├── nextDueAt: Timestamp(2026-01-22T14:00:00Z)
            │    ├── recurrence: {
            │    │     type: "weekly",
            │    │     days: ["mon", "wed"],
            │    │     time: "14:00"
            │    │   }
            │    ├── lastCompletedAt: Timestamp(2026-01-20T14:15:00Z)
            │    ├── version: 12
            │    └── updatedAt: Timestamp(...)
            │
            └── reminder-3/
                 ├── id: "reminder-3"
                 ├── title: "Pay rent"
                 ├── status: "active"
                 ├── nextDueAt: Timestamp(2026-02-01T09:00:00Z)
                 ├── recurrence: {
                 │     type: "monthly",
                 │     pattern: "dayOfMonth",
                 │     value: 1,
                 │     time: "09:00"
                 │   }
                 ├── lastCompletedAt: Timestamp(2026-01-01T09:05:00Z)
                 ├── version: 2
                 └── updatedAt: Timestamp(...)

Key Points:
✓ Each reminder = 1 document
✓ Only stores NEXT occurrence (nextDueAt)
✓ Recurrence = configuration object
✓ No pre-generated instances
✓ Version for idempotency
```

## Idempotency Mechanism

```
First Completion:
┌────────────────────────────────────────────────────────────────┐
│ Request: { reminderId: 'abc', currentVersion: 5 }              │
└────────────────┬───────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────┐
│ Firestore: { version: 5 }                                      │
│                                                                 │
│ Check: currentVersion (5) <= stored (5)  ✓ VALID              │
│                                                                 │
│ Action: Process completion                                     │
│         Update lastCompletedAt                                 │
│         Calculate nextDueAt                                    │
│         Increment version to 6                                 │
└────────────────┬───────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────┐
│ Result: { success: true, duplicate: false }                    │
└────────────────────────────────────────────────────────────────┘


Duplicate Completion (e.g., network retry):
┌────────────────────────────────────────────────────────────────┐
│ Request: { reminderId: 'abc', currentVersion: 5 }              │
└────────────────┬───────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────┐
│ Firestore: { version: 6 }                                      │
│                                                                 │
│ Check: currentVersion (5) < stored (6)  ✗ DUPLICATE           │
│                                                                 │
│ Action: Skip processing                                        │
│         Return duplicate flag                                  │
└────────────────┬───────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────┐
│ Result: { success: true, duplicate: true }                     │
└────────────────────────────────────────────────────────────────┘
```

## Scalability Comparison

```
❌ TRADITIONAL APPROACH (Don't do this):

┌─────────────────────────────────────────────────────────────────┐
│  Cron Job runs every minute                                     │
│  └── Check ALL reminders in database                           │
│       └── If due time passed                                    │
│            └── Send notification                                │
│                                                                  │
│  Problems:                                                      │
│  • Scans entire database                                        │
│  • Runs even when no reminders are due                          │
│  • Doesn't scale (millions of users = slow query)               │
│  • Costs money even when idle                                   │
└─────────────────────────────────────────────────────────────────┘


✅ OUR APPROACH (Event-driven):

┌─────────────────────────────────────────────────────────────────┐
│  User completes reminder                                        │
│  └── Cloud Function triggered                                   │
│       └── Process ONLY that reminder                            │
│            └── Calculate next due                               │
│                 └── Update Firestore                            │
│                                                                  │
│  Benefits:                                                      │
│  ✓ Only runs when needed                                        │
│  ✓ Processes one document at a time                             │
│  ✓ Scales to billions of users                                  │
│  ✓ No cost when idle                                            │
│  ✓ No background jobs to manage                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Code Organization

```
functions/
│
├── src/
│   ├── index.ts
│   │   └── Exports all functions
│   │       ├── completeReminder
│   │       ├── updateReminderRecurrence
│   │       ├── onReminderCompleted
│   │       └── calculateNextDueAt
│   │
│   └── recurrenceFunctions.ts ⭐ CORE LOGIC
│       │
│       ├── Type Definitions
│       │   ├── RecurrenceConfig
│       │   └── Reminder
│       │
│       ├── Pure Functions (No side effects)
│       │   ├── calculateNextDueAt() ← Main entry point
│       │   ├── calculateIntervalNextDue()
│       │   ├── calculateWeeklyNextDue()
│       │   └── calculateMonthlyNextDue()
│       │
│       └── Cloud Functions (Side effects here)
│           ├── completeReminder (Callable)
│           ├── updateReminderRecurrence (Callable)
│           └── onReminderCompleted (Trigger)
│
├── test/
│   └── recurrence.test.ts
│       ├── Unit tests for all recurrence types
│       ├── Edge case tests
│       └── Integration examples
│
└── Documentation
    ├── RECURRENCE_SYSTEM.md (Full docs)
    ├── QUICK_START.md (Setup guide)
    ├── IMPLEMENTATION_SUMMARY.md (What was built)
    ├── VISUAL_ARCHITECTURE.md (This file)
    └── FLUTTER_INTEGRATION_EXAMPLE.dart (Client code)
```

## Timeline Example

```
Interval Recurrence - "Every 3 days"

Day 1 (Jan 21):
  ┌─────────────────────────────────────┐
  │ User creates reminder                │
  │ nextDueAt: Jan 21 09:00             │
  └─────────────────────────────────────┘

Day 1 (Jan 21, 10:30am):
  ┌─────────────────────────────────────┐
  │ User completes reminder              │
  │ lastCompletedAt: Jan 21 10:30       │
  │ calculateNextDueAt() runs            │
  │ nextDueAt: Jan 24 10:30  ← +3 days  │
  └─────────────────────────────────────┘

Day 4 (Jan 24, 11:00am):
  ┌─────────────────────────────────────┐
  │ User completes reminder              │
  │ lastCompletedAt: Jan 24 11:00       │
  │ calculateNextDueAt() runs            │
  │ nextDueAt: Jan 27 11:00  ← +3 days  │
  └─────────────────────────────────────┘

Day 7 (Jan 27):
  ┌─────────────────────────────────────┐
  │ User forgets to complete             │
  │ nextDueAt still: Jan 27 11:00       │
  │ (No automatic update - waiting for  │
  │  explicit user action)               │
  └─────────────────────────────────────┘

Day 10 (Jan 30, 2:00pm):
  ┌─────────────────────────────────────┐
  │ User finally completes (3 days late) │
  │ lastCompletedAt: Jan 30 14:00       │
  │ calculateNextDueAt() runs            │
  │ nextDueAt: Feb 2 14:00   ← +3 days  │
  │ (Calculated from completion, not     │
  │  from the missed Jan 27 date)        │
  └─────────────────────────────────────┘
```

---

**This visual guide complements the technical documentation and helps
understand the system architecture at a glance.**
