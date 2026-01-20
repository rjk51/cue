# FCM Notification System with Cross-Device Sync

## 🎯 Overview

This implementation provides a complete notification system with:
- **Action Buttons** (Done/Snooze) on notifications
- **Real-time Cross-Device Sync** (like WhatsApp notifications)
- **Firebase Cloud Messaging (FCM)** integration
- **Cloud Firestore** for data persistence
- **Local Notifications** with scheduling

## 🏗️ Architecture

### Components

1. **NotificationService** (`lib/features/notifications/notification_service.dart`)
   - Handles FCM token management
   - Manages local notifications with action buttons
   - Schedules reminder notifications
   - Handles background messages

2. **ReminderService** (`lib/features/reminders/data/reminder_service.dart`)
   - Manages Firestore CRUD operations
   - Provides real-time streams for reminders
   - Handles cross-device synchronization
   - Manages reminder completion/snooze logic

3. **Reminder Model** (`lib/features/reminders/domain/reminder_model.dart`)
   - Enhanced with Firestore support
   - Includes `isCompleted` flag for sync
   - Device token tracking

## 🚀 Features

### ✅ Notification Action Buttons
- **Done Button**: Marks reminder as completed and syncs across devices
- **Snooze Button**: Delays reminder by 10 minutes

### 🔄 Cross-Device Sync (WhatsApp-style)
When you mark a notification as "Done" on Device A:
1. The reminder is marked as `isCompleted: true` in Firestore
2. Firestore automatically syncs to all devices
3. Device B receives the update via Firestore stream
4. Device B automatically removes the notification
5. Real-time sync happens within milliseconds

### 📱 How It Works

```
Device A (Mark Done)
        ↓
   Firestore Update
   (isCompleted: true)
        ↓
   Real-time Stream
        ↓
   Device B (Auto Remove)
```

## 📦 Dependencies Added

```yaml
firebase_messaging: ^15.1.7      # FCM for push notifications
cloud_firestore: ^5.8.0          # Real-time database
flutter_local_notifications: ^18.0.1  # Local notifications with actions
timezone: ^0.9.4                 # Timezone support for scheduling
```

## 🔧 Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Firebase Configuration

Your Firebase is already configured! The following files are in place:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart`

### 3. Android Permissions

Already configured in `android/app/src/main/AndroidManifest.xml`:
- POST_NOTIFICATIONS (Android 13+)
- SCHEDULE_EXACT_ALARM (for precise notifications)
- INTERNET (for FCM)
- VIBRATE, WAKE_LOCK (for notification alerts)

### 4. iOS Permissions (if needed)

Add to `ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

## 🎮 Usage

### Creating a Reminder

1. Tap the **+** button
2. Enter reminder name and select date/time
3. Tap **Save Reminder**
4. Reminder is saved to Firestore
5. Local notification is scheduled
6. All devices receive the update in real-time

### Marking as Done

**Option 1: From Notification**
- Tap "Done" button on the notification
- Reminder is marked complete in Firestore
- Notification disappears on all devices

**Option 2: From App**
- Tap the green checkmark icon
- Same behavior as above

### Snooze Feature

- Tap "Snooze" on the notification
- Reminder time is extended by 10 minutes
- New notification is scheduled
- All devices see the updated time

## 🔐 Security Rules (Firestore)

Add these rules to your Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /reminders/{reminderId} {
      // For demo: allow all (replace with proper auth in production)
      allow read, write: if true;
      
      // Production rule (with Firebase Auth):
      // allow read, write: if request.auth != null 
      //   && request.auth.uid == resource.data.userId;
    }
  }
}
```

## 📊 Firestore Data Structure

```javascript
reminders/
  {reminderId}/
    ├── id: string
    ├── name: string
    ├── time: timestamp
    ├── isCompleted: boolean
    ├── deviceToken: string (optional)
    ├── userId: string
    ├── createdAt: timestamp
    ├── completedAt: timestamp (optional)
    └── updatedAt: timestamp (optional)
```

## 🧪 Testing Cross-Device Sync

### Method 1: Two Physical Devices
1. Install app on Device A and Device B
2. Create a reminder on Device A
3. See it appear on Device B in real-time
4. Mark as done on Device A
5. Watch it disappear on Device B instantly

### Method 2: Emulator + Physical Device
1. Run on Android emulator: `flutter run`
2. Run on physical device: `flutter run -d <device-id>`
3. Test the sync as above

### Method 3: Multiple Emulators
1. Start two emulators
2. Run on first: `flutter run -d emulator-5554`
3. Run on second: `flutter run -d emulator-5556`
4. Test sync between emulators

## 🐛 Debugging

### View FCM Token
Tap the info icon (ⓘ) in the app bar to see your FCM token.

### Check Logs
```bash
flutter logs
```

Look for:
- "FCM Token: ..."
- "Scheduled notification for: ..."
- "Reminder marked as completed: ..."
- "Notification action: ..."

### Common Issues

**Issue**: Notifications not showing
- **Fix**: Check Android 13+ notification permissions
- Run: Settings → Apps → Cue → Notifications → Enable

**Issue**: Action buttons not working
- **Fix**: Ensure app is targeting Android 12+ (API 31+)

**Issue**: Cross-device sync not working
- **Fix**: Check internet connection and Firestore rules

## 🚀 Next Steps (Production)

### 1. Add Firebase Authentication
```dart
// Replace 'demo_user' with real user ID
final String _userId = FirebaseAuth.instance.currentUser!.uid;
```

### 2. Implement Cloud Functions
Create a Cloud Function to send FCM messages when reminders are completed:

```javascript
exports.onReminderCompleted = functions.firestore
  .document('reminders/{reminderId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const previousData = change.before.data();
    
    if (newData.isCompleted && !previousData.isCompleted) {
      // Send FCM message to all user devices
      const payload = {
        data: {
          type: 'reminder_completed',
          reminderId: context.params.reminderId
        }
      };
      
      await admin.messaging().sendToTopic(
        `user_${newData.userId}`,
        payload
      );
    }
  });
```

### 3. Add Categories for iOS
Define notification categories in iOS for action buttons.

### 4. Add Analytics
Track notification interactions:
```dart
await FirebaseAnalytics.instance.logEvent(
  name: 'notification_action',
  parameters: {'action': 'mark_done', 'reminder_id': reminderId},
);
```

## 📸 Screenshots

The app now shows:
- ✅ Real-time reminder list with Firestore sync
- 📝 Action buttons (Done/Delete) on each reminder
- 🔔 Notifications with Done/Snooze action buttons
- 💚 Visual feedback with snackbars
- 📱 FCM token display for testing

## 🎯 Key Benefits

1. **WhatsApp-Style Sync**: Notifications disappear across all devices when marked done
2. **No Server Code Needed**: Firestore handles real-time sync automatically
3. **Offline Support**: Actions queue and sync when back online
4. **Battery Efficient**: Uses Firebase listeners instead of polling
5. **Scalable**: Ready for production with minimal changes

## 🔗 Resources

- [Firebase Cloud Messaging Docs](https://firebase.google.com/docs/cloud-messaging)
- [Firestore Real-time Updates](https://firebase.google.com/docs/firestore/query-data/listen)
- [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)

## 📝 Notes

- Currently using a demo user ID (`demo_user`)
- In production, integrate Firebase Authentication
- Add Cloud Functions for advanced FCM scenarios
- Consider adding notification sound/vibration customization
- Implement notification history/completed reminders view

---

**Built with ❤️ using Flutter & Firebase**
