# Firebase Cloud Functions for Notifications

## ✅ What's Been Set Up

### 1. Cloud Functions (`functions/src/index.ts`)
- ✅ **checkReminders** - Runs every minute, sends notifications for due reminders
- ✅ **onReminderCreated** - Logs when reminders are created
- ✅ **onReminderUpdated** - Tracks reminder completions
- ✅ **sendTestNotification** - HTTP endpoint for testing

### 2. Flutter App Updates
- ✅ **FCM Token Storage** - Tokens saved to Firestore `users/{userId}` collection
- ✅ **Reminder Model** - Added `userId` and `notifiedAt` fields
- ✅ **Firestore Integration** - Reminders include both `time` and `scheduledTime` fields

### 3. Data Structure

**users/{userId}:**
```json
{
  "fcmToken": "device_token",
  "lastUpdated": Timestamp,
  "platform": "android"
}
```

**reminders/{reminderId}:**
```json
{
  "name": "Reminder title",
  "time": Timestamp,
  "scheduledTime": Timestamp,
  "isCompleted": false,
  "userId": "demo_user",
  "deviceToken": "device_token",
  "notifiedAt": Timestamp,
  "createdAt": Timestamp
}
```

## 🚀 Quick Deploy

### Option 1: Using the deploy script
```bash
./deploy-functions.sh
```

### Option 2: Manual deployment
```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

## 📋 Prerequisites

1. **Firebase Blaze Plan** (required for Cloud Functions)
   - Go to: https://console.firebase.google.com/project/cues-1ced9/usage
   - Click "Modify plan" → "Select Blaze"
   - Set budget alert to $10/month

2. **Firebase CLI**
   ```bash
   npm install -g firebase-tools
   firebase login
   ```

3. **Node.js 18+**
   ```bash
   node --version  # Should be 18.x or higher
   ```

## 📖 How It Works

### Current Flow (Local Notifications):
```
User creates reminder → Saved to Firestore → Local notification scheduled → Triggers at time
```

### New Flow (Cloud Functions):
```
User creates reminder → Saved to Firestore → FCM token saved to users collection
                                           ↓
Cloud Function runs every minute → Checks for due reminders → Sends FCM notification → Updates notifiedAt
                                           ↓
User's device receives notification (even if app is closed)
```

## 🎯 Key Benefits

✅ **Works when app is closed** - FCM works in background  
✅ **Server-side scheduling** - No reliance on device  
✅ **Cross-device sync** - Notifications sent to all user's devices  
✅ **Centralized control** - Update notification logic without app update  

## 🔧 Testing

### 1. Deploy functions:
```bash
./deploy-functions.sh
```

### 2. Run the app:
```bash
flutter run
```

### 3. Create a reminder for 2 minutes from now

### 4. Watch Cloud Function logs:
```bash
firebase functions:log --follow
```

### 5. Wait for notification
- Function runs every minute
- Will send notification when `scheduledTime <= now`
- Check device for FCM notification

## 📊 Monitoring

### View function logs:
```bash
firebase functions:log
```

### View in Firebase Console:
- Functions: https://console.firebase.google.com/project/cues-1ced9/functions
- Firestore: https://console.firebase.google.com/project/cues-1ced9/firestore
- Usage: https://console.firebase.google.com/project/cues-1ced9/usage

## 💰 Cost Estimate

### Free Tier (Blaze Plan):
- 2M function invocations/month
- 400K GB-seconds compute
- 200K CPU-seconds

### Your Usage:
- `checkReminders`: 60 calls/hour × 24 hours × 30 days = **43,200 calls/month**
- Well within free tier!

**Expected monthly cost: $0** 🎉

## 🐛 Troubleshooting

### No notification received:
1. Check FCM token saved:
   ```bash
   firebase firestore:get users/demo_user
   ```

2. Check reminder format:
   ```bash
   firebase firestore:get reminders/{reminderId}
   ```

3. Check function logs:
   ```bash
   firebase functions:log
   ```

### Deployment fails:
```bash
# Try with debug mode
firebase deploy --only functions --debug

# Check Node.js version
node --version  # Must be 18+

# Rebuild
cd functions && npm run build && cd ..
```

### Permission errors:
- Enable Firestore API in Google Cloud Console
- Check IAM permissions for Cloud Functions service account

## 📝 Next Steps

1. **Deploy functions:**
   ```bash
   ./deploy-functions.sh
   ```

2. **Upgrade to Blaze plan** (if not already):
   - https://console.firebase.google.com/project/cues-1ced9/usage

3. **Test the system:**
   - Create a reminder for 2 minutes from now
   - Watch logs: `firebase functions:log --follow`
   - Wait for FCM notification

4. **Optional: Add authentication:**
   - Replace `'demo_user'` with actual Firebase Auth user ID
   - Update Firestore rules for proper security

## 📚 Documentation

- Full setup guide: [CLOUD_FUNCTIONS_SETUP.md](CLOUD_FUNCTIONS_SETUP.md)
- Firebase Functions docs: https://firebase.google.com/docs/functions
- FCM docs: https://firebase.google.com/docs/cloud-messaging

## ⚠️ Important Notes

1. **Remove local notifications** - Once Cloud Functions work, you can remove the local notification scheduling to rely entirely on FCM

2. **User authentication** - Currently using `'demo_user'` - replace with real auth in production

3. **Timezone** - Cloud Function uses `Asia/Kolkata` - adjust if needed in `functions/src/index.ts`

4. **Notification frequency** - Function runs every minute - adjust schedule in `functions/src/index.ts` if needed

---

**Ready to deploy?** Run: `./deploy-functions.sh`
