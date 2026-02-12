# Buddy Nudge iOS → Android Fix

## Problem
Buddy nudges were not working when sent from iOS to Android devices. The notifications were not appearing on Android when an iOS user sent a nudge.

## Root Cause
The Cloud Functions code was sending buddy nudge notifications with **both** `data` and `notification` fields. However, the issue was more complex:

1. **Original Problem**: Both fields sent to all platforms, bypassing Flutter's custom handling on Android
2. **First Fix Attempt**: Removed `notification` field for Android (data-only)
   - ✅ Works in **foreground** (Flutter handles it)
   - ❌ Fails in **background/terminated** (no auto-display without `notification` field)
3. **Final Solution**: Keep both fields but handle properly:
   - **Background**: System auto-displays using `notification` field
   - **Foreground**: Flutter intercepts and displays with custom sound

## Solution

### 1. Updated Cloud Functions (`functions/src/index.ts`)
Changed buddy nudge to include **both** `data` and `notification` fields for Android:

**Key Changes:**
```typescript
if (platform === "android") {
  // Include BOTH fields:
  message.data = { type: "buddy_nudge", ... };      // For foreground handler
  message.notification = { title: ..., body: ... }; // For background auto-display
  message.android = {
    priority: "high",
    notification: { sound: "default" }
  };
}
```

**Why both fields?**
- **Foreground**: FCM doesn't auto-display notifications when app is open. Flutter's `onMessage` handler intercepts the data and displays with custom sound.
- **Background/Terminated**: System uses the `notification` field to auto-display. No Flutter code runs until user taps it.

### 2. Updated Flutter Notification Service (`lib/features/notifications/notification_service.dart`)
Added handling for `buddy_nudge` type messages:

- Detects buddy nudge messages in foreground handler
- Retrieves selected sound preference from LocalStorageService
- Displays notification with custom sound on Android
- Logs buddy nudge notifications for debugging

**Key Changes:**
```dart
// Added buddy_nudge type handling in _handleForegroundMessage
if (message.data['type'] == 'buddy_nudge') {
  final selectedSound = LocalStorageService.instance.getNudgeSound();
  _showBuddyNudgeNotification(
    title: title,
    body: body,
    sound: selectedSound,
  );
}
```

### 3. Updated LocalStorageService (`lib/services/local_storage_service.dart`)
Added methods to store/retrieve nudge sound preference:

- `getNudgeSound()` - Returns selected sound ID ('default', 'gentle', 'urgent', 'fun')
- `setNudgeSound(String soundId)` - Saves sound preference

### 4. Updated Buddy Screen (`lib/features/buddy/presentation/buddy_screen.dart`)
Modified to save settings to both SharedPreferences AND LocalStorageService:

- Ensures notification service can access sound preference
- Maintains backward compatibility with existing SharedPreferences

## Testing

### To Test the Fix:

1. **Deploy Cloud Functions:**
   ```bash
   cd functions
   npm run deploy
   # or
   firebase deploy --only functions
   ```

2. **Rebuild Flutter App:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

3. **Test Nudge Flow:**
   - Device A (iOS): Send nudge to Device B (Android)
   - Device B should receive notification with selected sound
   - Try all sound options (Default, Bell, Ding, Alert)

### Expected Behavior:
- ✅ iOS → Android nudges now work
- ✅ Android → iOS nudges still work (unchanged)
- ✅ Custom sound selection applies to notifications
- ✅ Notifications display properly on both platforms

## Deployment Steps

1. **Deploy Cloud Functions first:**
   ```bash
   cd functions
   npm install  # If needed
   npm run build
   firebase deploy --only functions:processPendingNotifications
   ```

2. **Rebuild and deploy Flutter app:**
   ```bash
   flutter clean
   flutter pub get
   flutter build ios
   flutter build android
   ```

3. **Verify:**
   - Test iOS → Android nudge
   - Test Android → iOS nudge
   - Check logs for "👋 Processing buddy nudge notification" in Cloud Functions
   - Check Flutter logs for "👋 Showing buddy nudge notification" on receiving device

## Notes

- The fix maintains backward compatibility - existing sound preferences will continue to work
- No database migrations needed
- Cloud Functions changes take effect immediately after deployment
- App needs to be rebuilt to pick up Flutter changes
