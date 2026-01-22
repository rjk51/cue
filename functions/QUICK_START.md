# Quick Start Guide - Recurrence System

## 🚀 For Hackathon Demo

This guide shows you how to use the recurrence system in 5 minutes.

## Setup

1. **Deploy the functions:**
   ```bash
   cd functions
   npm run build
   firebase deploy --only functions
   ```

2. **Functions available:**
   - `completeReminder` - Mark reminder as done, calculate next occurrence
   - `updateReminderRecurrence` - Change recurrence rules
   - `onReminderCompleted` - Auto-triggered log (Firestore trigger)

## Usage Examples

### 1. Creating a Reminder with Recurrence

In Firestore, create a document at `users/{userId}/reminders/{reminderId}`:

```json
{
  "id": "workout-reminder",
  "title": "Go to the gym",
  "status": "active",
  "nextDueAt": "2026-01-22T09:00:00Z",
  "recurrence": {
    "type": "weekly",
    "days": ["mon", "wed", "fri"],
    "time": "09:00"
  },
  "version": 1,
  "updatedAt": "2026-01-21T10:00:00Z"
}
```

### 2. Completing a Reminder (Client-Side)

```dart
// Flutter/Dart example
final callable = FirebaseFunctions.instance.httpsCallable('completeReminder');

try {
  final result = await callable.call({
    'reminderId': 'workout-reminder',
    'currentVersion': 1,  // For idempotency
  });

  if (result.data['success']) {
    if (result.data['duplicate']) {
      print('Already marked as complete');
    } else {
      print('✅ Completed!');
      print('Next workout: ${result.data['nextDueAt']}');
      // Output: Next workout: 2026-01-24T09:00:00.000Z
    }
  }
} catch (e) {
  print('Error: $e');
}
```

```javascript
// JavaScript example
const completeReminder = firebase.functions().httpsCallable('completeReminder');

completeReminder({
  reminderId: 'workout-reminder',
  currentVersion: 1
})
.then((result) => {
  console.log('Next due:', result.data.nextDueAt);
})
.catch((error) => {
  console.error('Error:', error);
});
```

### 3. Changing Recurrence Rules

```dart
final callable = FirebaseFunctions.instance.httpsCallable('updateReminderRecurrence');

await callable.call({
  'reminderId': 'workout-reminder',
  'recurrence': {
    'type': 'interval',
    'every': 2,
    'unit': 'days',
    'anchor': 'completion'
  }
});

// Now the reminder repeats every 2 days after completion
```

## Common Recurrence Patterns

### Daily Tasks
```json
{
  "type": "interval",
  "every": 1,
  "unit": "days",
  "anchor": "scheduled"
}
```

### Work Schedule (Mon-Fri at 9 AM)
```json
{
  "type": "weekly",
  "days": ["mon", "tue", "wed", "thu", "fri"],
  "time": "09:00"
}
```

### Medicine (Every 8 hours after taking)
```json
{
  "type": "interval",
  "every": 8,
  "unit": "hours",
  "anchor": "completion"
}
```

### Monthly Bill (15th of every month)
```json
{
  "type": "monthly",
  "pattern": "dayOfMonth",
  "value": 15,
  "time": "09:00"
}
```

### Water Plants (Every 3 days)
```json
{
  "type": "interval",
  "every": 3,
  "unit": "days",
  "anchor": "scheduled"
}
```

## What Happens When You Complete a Reminder?

```
User completes reminder
         ↓
completeReminder function called
         ↓
Validate user & reminder
         ↓
Check version (idempotency)
         ↓
calculateNextDueAt(reminder)
    ↓           ↓           ↓
 Interval    Weekly    Monthly
         ↓
Return next Date
         ↓
Update Firestore:
  - lastCompletedAt: NOW
  - nextDueAt: [calculated]
  - version: +1
         ↓
Return result to client
```

## Testing Locally

```bash
cd functions
npm run serve
```

Then use the Firebase Emulator Suite to test:

```javascript
// Connect to emulator
firebase.functions().useEmulator('localhost', 5001);

// Test completion
completeReminder({ reminderId: 'test-123' });
```

## Demo Script for Hackathon

1. **Show Firestore Console**
   - Display a reminder document with recurrence config
   - Point out: Only stores the NEXT occurrence, not future ones

2. **Complete the reminder**
   - Call `completeReminder` from client
   - Show Firestore update in real-time
   - Highlight the `nextDueAt` field automatically updated

3. **Show the code**
   - Open `recurrenceFunctions.ts`
   - Explain `calculateNextDueAt` function
   - Emphasize: Pure function, no database writes

4. **Explain scalability**
   - No cron jobs needed
   - No background processing
   - Works for millions of users
   - Each user's reminders are independent

5. **Show edge cases**
   - February 31st → Feb 28th
   - Overdue intervals skip to next future date
   - Idempotency prevents double-processing

## Key Points for Judges

✅ **Scalable:** No cron jobs, no background tasks  
✅ **Efficient:** Only calculates on explicit events  
✅ **Reliable:** Idempotent, handles edge cases  
✅ **Testable:** Pure functions, easy to unit test  
✅ **Production-ready:** Transaction-safe, handles race conditions  

## Troubleshooting

**Problem:** "Reminder not found"
- Check the document path: `users/{userId}/reminders/{reminderId}`
- Ensure the user is authenticated

**Problem:** "Duplicate completion"
- This is expected! The version check prevents double-processing
- It means the system is working correctly

**Problem:** Next due date seems wrong
- Check the recurrence configuration
- Verify timezone (system uses UTC internally)
- Use the test file to validate the calculation

## File Structure

```
functions/
├── src/
│   ├── index.ts                    # Exports all functions
│   └── recurrenceFunctions.ts      # Core recurrence logic ⭐
├── test/
│   └── recurrence.test.ts          # Unit tests
├── RECURRENCE_SYSTEM.md            # Full documentation
└── QUICK_START.md                  # This file
```

## Next Steps

1. ✅ Deploy functions to Firebase
2. ✅ Create a reminder with recurrence in Firestore
3. ✅ Test completing the reminder from your app
4. ✅ Watch the `nextDueAt` field update automatically
5. 🎉 Demo to judges!

## Support

For detailed documentation, see [RECURRENCE_SYSTEM.md](./RECURRENCE_SYSTEM.md)

For code examples, see [test/recurrence.test.ts](./test/recurrence.test.ts)

---

**Built for hackathon demo - simple, scalable, production-ready!** 🚀
