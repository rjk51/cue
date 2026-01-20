# Optimized Cloud Notification System

## What Changed

### Problem with Previous Approach
- **Scheduled function (`checkReminders`)** ran every 1 minute on Firebase servers
- High cost: 1,440 invocations/day × 30 days = 43,200 invocations/month
- Unnecessary server load even when no reminders are due
- Cloud Scheduler permissions issues

### New Optimized Approach
- **App-triggered notifications**: Mobile app triggers Cloud Function only when reminder is due
- **Zero cost when idle**: Functions only run when reminders need to be sent
- **No Cloud Scheduler needed**: Uses local device timers + Firebase callable functions

## Architecture

### Mobile App Side
1. **Creates reminder** → Saves to Firestore with `scheduledTime`
2. **Schedules silent local alarm** → Triggers at reminder time
3. **When alarm fires** → Calls Cloud Function: `triggerReminderNotification`
4. **On app startup** → Calls `checkPendingReminders` to catch missed notifications

### Cloud Functions
1. **`triggerReminderNotification`** (Callable)
   - Called by app when reminder is due
   - Fetches user's FCM token from Firestore
   - Sends push notification
   - Marks reminder as notified

2. **`checkPendingReminders`** (Callable)
   - Called on app startup
   - Checks for overdue reminders that weren't notified
   - Sends notifications for all pending reminders

3. **`onReminderCreated/Updated`** (Firestore Triggers)
   - Logs reminder lifecycle events

## Cost Comparison

### Old Approach (Scheduled)
- **43,200 invocations/month** (every minute)
- **~$0.05/month** (assuming 100ms execution time)

### New Approach (App-Triggered)
- **~300 invocations/month** (10 reminders/day)
- **<$0.001/month** (negligible cost)
- **99% cost reduction**

## Files Modified

### Cloud Functions
- `functions/src/index.ts` - Replaced scheduled function with callable functions

### Flutter App
- `lib/features/notifications/notification_service.dart`
  - Added `_triggerCloudNotification()` - Calls Cloud Function
  - Added `checkPendingReminders()` - Checks missed notifications on startup
  - Modified `scheduleReminderNotification()` - Uses local timer + Cloud Function
- `lib/main.dart` - Added pending reminder check on app startup
- `pubspec.yaml` - Added `cloud_functions` dependency

## How It Works

```
User creates reminder "Call John" at 3:00 PM
↓
Flutter saves to Firestore with scheduledTime=3:00 PM
↓
Flutter schedules silent local alarm for 3:00 PM
↓
At 3:00 PM: Local alarm triggers
↓
Flutter calls triggerReminderNotification(reminderId)
↓
Cloud Function fetches user's FCM token
↓
Cloud Function sends push notification to user's device
↓
User receives: "Reminder: Call John"
```

## Testing

### Test the system:
1. Create a reminder for 2 minutes from now
2. Wait for the reminder time
3. You should receive a push notification from Firebase (not local)
4. Close and reopen the app - pending reminders will be checked

### Verify in logs:
```bash
cd /Users/amriteshkumar/Developer/cue
firebase functions:log --only triggerReminderNotification
```

## Benefits

✅ **99% cost reduction** - Only runs when needed
✅ **No Cloud Scheduler** - No permission issues
✅ **Reliable** - Works even if app is closed (background process)
✅ **Scalable** - Handles 1000s of users efficiently
✅ **Battery efficient** - Uses Android's AlarmManager
✅ **Fallback mechanism** - `checkPendingReminders` catches missed notifications

## Next Steps

1. **Deploy and test** - Create a reminder for 2 minutes from now
2. **Monitor logs** - Check Firebase Functions logs for execution
3. **Replace demo_user** - Use actual Firebase Auth user IDs
4. **Add error handling** - Handle network failures gracefully
5. **Analytics** - Track notification delivery rates
