# iOS Notification Setup - Complete Guide

## ✅ What Was Fixed

### 1. AppDelegate.swift
- ✅ Added Firebase Messaging imports
- ✅ Added UNUserNotificationCenter delegate setup
- ✅ Implemented remote notification registration
- ✅ Added APNs token handling
- ✅ Implemented Firebase Messaging delegate

### 2. Info.plist
- ✅ Added `UIBackgroundModes` with `remote-notification`
- ✅ Added `FirebaseAppDelegateProxyEnabled` set to `false`

### 3. Podfile
- ✅ Enabled iOS 13.0 platform
- ✅ Reinstalled all pods

### 4. Runner.entitlements
- ✅ Already has `aps-environment` set to `development`

## 🔧 Manual Steps Required in Xcode

### Step 1: Open Xcode Project
```bash
cd /Users/amriteshkumar/Developer/cue/ios
open Runner.xcworkspace
```

### Step 2: Enable Push Notifications Capability
1. Select `Runner` project in the navigator
2. Select `Runner` target
3. Click on **"Signing & Capabilities"** tab
4. Click **"+ Capability"** button
5. Search for and add **"Push Notifications"**
6. Verify it shows ✓ Push Notifications

### Step 3: Enable Background Modes
1. In the same **"Signing & Capabilities"** tab
2. Check if **"Background Modes"** capability exists
3. If not, click **"+ Capability"** and add **"Background Modes"**
4. Check these boxes:
   - ☑️ Remote notifications
   - ☑️ Background fetch

### Step 4: Verify GoogleService-Info.plist
1. Make sure `GoogleService-Info.plist` exists in `ios/Runner/`
2. In Xcode project navigator, verify it's included in the Runner target

### Step 5: Check Bundle Identifier
1. In Xcode, verify the Bundle Identifier matches your Firebase iOS app
2. Go to: Runner target → General → Identity → Bundle Identifier
3. Should match the one in Firebase Console

## 📱 Testing Steps

### 1. Clean Build
```bash
cd /Users/amriteshkumar/Developer/cue
flutter clean
flutter pub get
cd ios
pod install
cd ..
```

### 2. Run on Device (Not Simulator!)
```bash
flutter run --release
```

**Important:** Push notifications DON'T work on iOS Simulator. You MUST test on a real device.

### 3. Check Console Logs
Look for these messages:
```
✅ APNS token retrieved
✅ Firebase registration token: [token]
✅ FCM Token: [token]
```

### 4. Test Notification Flow
1. Create a reminder in the app
2. Wait for the scheduled time
3. Check if notification appears
4. Try marking as done or snoozing from notification

## 🔍 Troubleshooting

### Issue: No APNS token
**Solution:**
- Make sure you're testing on a real device, not simulator
- Check that Push Notifications capability is enabled in Xcode
- Verify your Apple Developer account has proper certificates

### Issue: FCM token is null
**Solution:**
- Wait a few seconds - iOS needs time to get APNS token first
- Check Firebase Console has correct APNs keys
- Verify GoogleService-Info.plist is present

### Issue: Notifications not appearing
**Solution:**
1. Check device notification settings:
   - Settings → Notifications → Cue
   - Allow Notifications should be ON
2. Check Firebase Console:
   - Project Settings → Cloud Messaging
   - Verify APNs keys are uploaded
3. Check Firebase Functions logs:
   - Functions → Logs
   - Look for notification send attempts

### Issue: "APNS token has not been set yet" error
**Solution:**
- This is now handled with retry logic in the code
- The app will retry after 2 seconds
- The app won't crash - it continues even if FCM fails

## 📋 Verification Checklist

Before testing, verify:
- [ ] Xcode project has Push Notifications capability
- [ ] Background Modes enabled with Remote notifications
- [ ] GoogleService-Info.plist exists in ios/Runner/
- [ ] Runner.entitlements has aps-environment = development
- [ ] Testing on REAL iOS device (not simulator)
- [ ] Device allows notifications for the app
- [ ] Firebase Console has APNs keys configured
- [ ] Bundle ID matches Firebase iOS app

## 🎯 Expected Behavior

### On App Launch:
1. App requests notification permission
2. Gets APNS token from Apple
3. Gets FCM token from Firebase
4. Saves FCM token to Firestore

### When Reminder is Due:
1. Cloud Function triggers
2. Sends FCM message with reminder data
3. iOS receives remote notification
4. Flutter local notifications displays it
5. User can tap Done or Snooze

## 🔐 Production Setup

When ready for production:

1. Change `aps-environment` in Runner.entitlements:
   ```xml
   <key>aps-environment</key>
   <string>production</string>
   ```

2. Upload Production APNs key to Firebase:
   - Firebase Console → Project Settings → Cloud Messaging
   - Upload your production .p8 key

3. Build for release:
   ```bash
   flutter build ios --release
   ```

## ✨ Summary

Your iOS app is now configured to:
- ✅ Register for push notifications
- ✅ Receive APNs tokens
- ✅ Get FCM tokens
- ✅ Handle foreground notifications
- ✅ Handle background notifications
- ✅ Show notification actions (Done/Snooze)
- ✅ Handle graceful errors

The code changes are complete. Just need to enable capabilities in Xcode and test on a real device!
