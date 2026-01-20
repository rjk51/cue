# Firebase Cloud Functions Deployment Guide

## Overview
This guide will help you deploy Firebase Cloud Functions that send notifications when reminders are due.

## Prerequisites

1. **Firebase CLI** installed globally
   ```bash
   npm install -g firebase-tools
   ```

2. **Node.js 18** or higher
   ```bash
   node --version
   ```

3. **Firebase Blaze Plan** (Pay-as-you-go)
   - Cloud Functions require a billing account
   - Free tier includes: 2M invocations/month, 400K GB-seconds, 200K CPU-seconds
   - Visit: https://console.firebase.google.com/project/cues-1ced9/usage

## Step 1: Login to Firebase

```bash
cd /Users/amriteshkumar/Developer/cue
firebase login
```

## Step 2: Initialize Firebase Project

If not already initialized:

```bash
firebase init
```

Select:
- ✅ Functions: Configure Cloud Functions
- ✅ Use existing project: `cues-1ced9`
- ✅ Language: TypeScript
- ✅ ESLint: Yes
- ✅ Install dependencies: Yes

## Step 3: Install Dependencies

```bash
cd functions
npm install
```

## Step 4: Build the Functions

```bash
npm run build
```

## Step 5: Deploy to Firebase

### Deploy all functions:
```bash
firebase deploy --only functions
```

### Deploy specific function:
```bash
firebase deploy --only functions:checkReminders
```

### Deploy with debug logs:
```bash
firebase deploy --only functions --debug
```

## Step 6: Enable Billing

1. Go to: https://console.firebase.google.com/project/cues-1ced9/settings/billing
2. Upgrade to **Blaze Plan**
3. Set a budget alert (recommended: $10/month)

## Step 7: Configure Firestore Rules

Update Firestore security rules to allow Cloud Functions:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow Cloud Functions to read/write
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // Allow Cloud Functions service account
    match /users/{userId} {
      allow read, write: if request.auth != null || 
                           request.auth.token.firebase.sign_in_provider == "custom";
    }
    
    match /reminders/{reminderId} {
      allow read, write: if request.auth != null || 
                           request.auth.token.firebase.sign_in_provider == "custom";
    }
  }
}
```

## Step 8: Test the Functions

### View logs:
```bash
firebase functions:log
```

### Test locally (emulator):
```bash
cd functions
npm run serve
```

### Test the scheduled function manually:
You can trigger the function manually from Firebase Console:
1. Go to: https://console.firebase.google.com/project/cues-1ced9/functions
2. Find `checkReminders` function
3. Click "Test function"

### Test with HTTP function:
```bash
curl -X POST https://YOUR_REGION-cues-1ced9.cloudfunctions.net/sendTestNotification \
  -H "Content-Type: application/json" \
  -d '{"reminderId": "YOUR_REMINDER_ID"}'
```

## How It Works

### 1. **checkReminders** (Scheduled Function)
- Runs every 1 minute
- Queries Firestore for due reminders
- Sends FCM notifications to users
- Marks reminders as notified

### 2. **onReminderCreated** (Firestore Trigger)
- Triggered when a new reminder is created
- Logs creation for debugging

### 3. **onReminderUpdated** (Firestore Trigger)
- Triggered when a reminder is updated
- Detects completion events

### 4. **sendTestNotification** (HTTP Function)
- Test endpoint to send notifications manually
- Useful for debugging

## Expected Behavior

1. **User creates reminder in app**
   - Reminder saved to Firestore with `userId` and `scheduledTime`
   - FCM token saved to `users/{userId}` collection

2. **Every minute, Cloud Function runs**
   - Checks for reminders where `scheduledTime <= now`
   - Sends FCM notification to user's device
   - Updates reminder with `notifiedAt` timestamp

3. **User receives notification**
   - Even if app is closed/background
   - With action buttons (Done/Snooze)
   - Notification appears immediately

## Firestore Data Structure

### users/{userId}
```json
{
  "fcmToken": "dXXX...XXX",
  "lastUpdated": Timestamp,
  "platform": "android"
}
```

### reminders/{reminderId}
```json
{
  "name": "Buy groceries",
  "time": Timestamp,
  "isCompleted": false,
  "userId": "demo_user",
  "deviceToken": "dXXX...XXX",
  "notifiedAt": Timestamp (optional),
  "createdAt": Timestamp
}
```

## Monitoring

### View function invocations:
https://console.firebase.google.com/project/cues-1ced9/functions/logs

### View Firestore operations:
https://console.firebase.google.com/project/cues-1ced9/firestore/usage

### Set up alerts:
https://console.firebase.google.com/project/cues-1ced9/monitoring

## Troubleshooting

### Function fails to deploy:
```bash
firebase deploy --only functions --debug
```

### No notifications sent:
1. Check logs: `firebase functions:log`
2. Verify FCM token exists in Firestore users collection
3. Check reminder has correct userId and scheduledTime
4. Verify device token is valid

### Permission errors:
- Ensure Firestore rules allow Cloud Functions access
- Check Cloud Functions service account permissions

### Timezone issues:
- Function uses `timeZone: "Asia/Kolkata"` in schedule
- Adjust in `functions/src/index.ts` if needed

## Cost Estimation

### Free Tier (Blaze Plan):
- 2M invocations/month
- 400K GB-seconds
- 200K CPU-seconds

### Your Usage:
- `checkReminders`: 60 invocations/hour × 24 hours × 30 days = 43,200/month
- Well within free tier!

### Beyond Free Tier:
- $0.40 per million invocations
- $0.0000025 per GB-second
- $0.00001 per CPU-second

**Expected cost: $0/month** (within free tier)

## Next Steps

1. Deploy functions: `firebase deploy --only functions`
2. Run the Flutter app and create a reminder
3. Watch logs: `firebase functions:log --follow`
4. Wait 1 minute for notification
5. Check device for FCM notification

## Support

- Firebase Documentation: https://firebase.google.com/docs/functions
- Cloud Functions Samples: https://github.com/firebase/functions-samples
- Troubleshooting: https://firebase.google.com/docs/functions/troubleshooting
