# Firebase Cloud Functions - Reminder Recurrence System

## 📋 Overview

This directory contains Firebase Cloud Functions for a scalable reminder recurrence system. The system stores recurrence **rules** instead of pre-generating instances, and calculates the next occurrence only when explicit events occur (like completing a reminder).

## 🚀 Quick Start

### Deploy Functions
```bash
npm run build
firebase deploy --only functions
```

### Test Locally
```bash
npm run serve
```

## 📁 File Structure

```
functions/
├── src/
│   ├── index.ts                          # Main entry point, exports all functions
│   ├── recurrenceFunctions.ts           # ⭐ Core recurrence logic (NEW)
│   ├── taskFunctions.js                  # Existing task functions
│   └── types.js                          # Existing types
│
├── lib/                                  # Compiled JavaScript output
│   ├── index.js
│   ├── recurrenceFunctions.js           # ⭐ Compiled recurrence functions
│   └── ...
│
├── test/
│   └── recurrence.test.ts               # Unit tests for recurrence system
│
├── Documentation/
│   ├── RECURRENCE_SYSTEM.md             # Complete technical documentation
│   ├── QUICK_START.md                   # 5-minute setup guide
│   ├── IMPLEMENTATION_SUMMARY.md        # What was implemented
│   ├── VISUAL_ARCHITECTURE.md           # Diagrams and visualizations
│   ├── FLUTTER_INTEGRATION_EXAMPLE.dart # Flutter client code example
│   └── README.md                        # This file
│
├── package.json                          # Dependencies and scripts
├── tsconfig.json                         # TypeScript configuration
└── .eslintrc.json                        # ESLint configuration
```

## 🎯 Cloud Functions

### New Recurrence Functions

#### 1. `completeReminder` (HTTPS Callable)
Marks a reminder as completed and calculates the next occurrence based on recurrence rules.

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

#### 2. `updateReminderRecurrence` (HTTPS Callable)
Updates the recurrence rule for an existing reminder and recalculates the next due date.

**Request:**
```typescript
{
  reminderId: string,
  recurrence: RecurrenceConfig
}
```

#### 3. `onReminderCompleted` (Firestore Trigger)
Automatically triggered when a reminder is completed. Logs completion events for analytics.

**Trigger Path:** `users/{userId}/reminders/{reminderId}`

### Existing Functions
- `triggerReminderNotification` - Sends FCM notifications
- `checkPendingReminders` - Checks for pending reminders
- `onReminderCreated` - Triggered when reminder is created
- `onReminderUpdated` - Triggered when reminder is updated
- `sendTestNotification` - Sends test notifications

## 🔧 Core Algorithm

### `calculateNextDueAt(reminder): Date | null`

Pure function that calculates the next occurrence date. Supports three recurrence types:

1. **Interval** - Repeat every X time units
   - `every: number` - How many units
   - `unit: "minutes" | "hours" | "days"`
   - `anchor: "completion" | "scheduled"` - When to calculate from

2. **Weekly** - Repeat on specific days
   - `days: string[]` - Day names (e.g., ["mon", "wed"])
   - `time: string` - Time in "HH:mm" format

3. **Monthly** - Repeat on specific day of month
   - `pattern: "dayOfMonth" | "nthWeekday"`
   - `value: number` - Day number or nth occurrence
   - `time: string` - Time in "HH:mm" format

## 📊 Data Model

Each reminder is stored at: `users/{userId}/reminders/{reminderId}`

```typescript
{
  id: string,
  title: string,
  status: "active" | "paused",
  nextDueAt: Timestamp,           // Only the NEXT occurrence ⭐
  recurrence?: {
    type: "interval" | "weekly" | "monthly",
    // Type-specific fields...
  },
  lastCompletedAt?: Timestamp,
  updatedAt: Timestamp,
  version: number                  // For idempotency
}
```

## 💡 Key Features

### ✅ Scalable
- No cron jobs or scheduled functions
- No background processing
- Event-driven architecture
- Scales horizontally

### ✅ Efficient
- Only calculates on explicit user actions
- Single document read/write per operation
- No batch processing needed

### ✅ Reliable
- Idempotent operations using version numbers
- Atomic updates with Firestore transactions
- Handles edge cases (Feb 31, overdue reminders, etc.)

### ✅ Testable
- Pure functions for core logic
- Comprehensive unit tests included
- Easy to mock and test

## 📚 Documentation

For detailed information, see:

- **[RECURRENCE_SYSTEM.md](./RECURRENCE_SYSTEM.md)** - Complete technical documentation
- **[QUICK_START.md](./QUICK_START.md)** - Setup and usage guide
- **[IMPLEMENTATION_SUMMARY.md](./IMPLEMENTATION_SUMMARY.md)** - Implementation details
- **[VISUAL_ARCHITECTURE.md](./VISUAL_ARCHITECTURE.md)** - System diagrams
- **[FLUTTER_INTEGRATION_EXAMPLE.dart](./FLUTTER_INTEGRATION_EXAMPLE.dart)** - Client code example

## 🧪 Testing

Unit tests are located in [test/recurrence.test.ts](./test/recurrence.test.ts).

To run tests (requires Jest setup):
```bash
npm install --save-dev jest @types/jest ts-jest
npm test
```

## 🔐 Security

Ensure your Firestore security rules allow authenticated users to access their own reminders:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/reminders/{reminderId} {
      allow read, write: if request.auth != null 
                         && request.auth.uid == userId;
    }
  }
}
```

## 🛠️ Development

### Build
```bash
npm run build
```

### Watch Mode
```bash
npm run build:watch
```

### Lint
```bash
npm run lint
```

### Deploy
```bash
npm run deploy
```

### View Logs
```bash
npm run logs
```

## 📦 Dependencies

### Production
- `firebase-admin@^12.0.0` - Firebase Admin SDK
- `firebase-functions@^5.0.0` - Cloud Functions SDK

### Development
- `typescript@^4.9.0` - TypeScript compiler
- `eslint` - Code linting
- `@typescript-eslint/*` - TypeScript ESLint plugins

## 🎓 How It Works

```
User Action (Complete Reminder)
        ↓
Cloud Function (completeReminder)
        ↓
Pure Function (calculateNextDueAt)
        ↓
Firestore Update (nextDueAt, version++)
        ↓
Return Result to Client
```

## 🚨 Important Notes

1. **No Pre-generation**: The system does NOT pre-generate future reminder instances
2. **No Cron Jobs**: The system does NOT use scheduled functions or cron jobs
3. **Event-Driven**: Calculations only happen on explicit user actions
4. **Pure Functions**: Core logic has no side effects and is easily testable
5. **Idempotent**: Safe to retry operations without side effects

## 🆘 Troubleshooting

### "Reminder not found"
- Verify the document path is correct
- Check user authentication
- Ensure the reminder exists in Firestore

### "Duplicate completion"
- This is expected behavior (idempotency working)
- Means the reminder was already completed with this version

### Next due date seems incorrect
- Check recurrence configuration
- Remember: System uses UTC internally
- Verify with unit tests

## 📧 Support

For issues or questions about the recurrence system, refer to the documentation files or examine the unit tests for examples.

## 📝 License

This code is part of a hackathon project and is provided as-is for educational and demonstration purposes.

---

**Built with ❤️ for scalable, production-ready reminder recurrence**
