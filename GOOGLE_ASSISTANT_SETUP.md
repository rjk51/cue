# Google Assistant Integration for Cue App

## Overview
Your Cue app now supports Google Assistant integration! Users can ask Google Assistant to create reminders, and the app will automatically open with pre-filled data.

## How It Works
1. User says: **"Hey Google, remind me to buy groceries at 5 PM"**
2. Google Assistant captures the reminder text and time
3. The app launches with the Create Reminder screen pre-filled
4. User can review and save the reminder

## Setup Instructions

### 1. Prerequisites
- Android device or emulator with Google Play Services
- Google account signed into the device
- Your app installed on the device

### 2. Build and Install the App
```bash
# Clean build
flutter clean
flutter pub get

# Build and install on connected device
flutter run --release
# Or for debug mode
flutter run
```

### 3. Enable Google Assistant App Actions (Development)

#### Option A: Using Android Studio Plugin (Recommended)
1. Open Android Studio
2. Install "Google Assistant" plugin:
   - Go to: `Settings/Preferences` → `Plugins`
   - Search for "Google Assistant"
   - Install and restart Android Studio

3. Open the plugin:
   - `Tools` → `Google Assistant` → `App Actions Test Tool`

4. Configure the test:
   - Select your app from the dropdown
   - Choose "CREATE_REMINDER" action
   - Enter test parameters:
     - **text**: "Buy groceries"
     - **time**: "17:00"
     - **date**: "2024-12-30"
   - Click "Run App Action"

#### Option B: Using ADB Commands
```bash
# Test with text only
adb shell am start -a actions.intent.CREATE_REMINDER \
  -d "cue://reminder/create?text=Buy%20groceries"

# Test with text and time
adb shell am start -a actions.intent.CREATE_REMINDER \
  -d "cue://reminder/create?text=Buy%20groceries&time=17:00&date=2024-12-30"

# Test with different reminder
adb shell am start -a actions.intent.CREATE_REMINDER \
  -d "cue://reminder/create?text=Meeting%20with%20John&time=14:30&date=2024-12-31"
```

#### Option C: Using Deep Links (Alternative Testing)
```bash
# Test deep link directly
adb shell am start -W -a android.intent.action.VIEW \
  -d "cue://reminder/create?text=Test%20reminder&time=15:00&date=2024-12-30" \
  com.cuehq.app
```

### 4. Test with Google Assistant (Device Testing)

Once your app is installed, you can test with real Google Assistant:

1. **Enable Assistant on your device**
   - Long press the home button or say "Hey Google"

2. **Test various reminder commands**:
   - "Hey Google, remind me to call mom at 3 PM"
   - "Hey Google, set a reminder to workout tomorrow at 7 AM"
   - "Hey Google, remind me to take medicine at 9 PM today"
   - "Hey Google, create a reminder to buy groceries"

3. **Expected behavior**:
   - Google Assistant will show a list of apps that can handle reminders
   - Select "Cue" from the list
   - Your app should open with the Create Reminder screen
   - The reminder text and time should be pre-filled
   - Review and tap "Save" to create the reminder

### 5. Set Cue as Default Reminder App (Optional)

To make Google Assistant always use Cue for reminders:

1. Go to Android Settings
2. Navigate to: `Apps` → `Default apps` → `Digital assistant app`
3. Look for "Reminder" or "Tasks" option
4. Select "Cue" from the list

**Note**: This option may vary by device manufacturer and Android version.

## Testing Checklist

### ✅ Basic Testing
- [ ] Install app on device
- [ ] Test ADB command with text only
- [ ] Test ADB command with text and time
- [ ] Test ADB command with different dates
- [ ] Verify reminder screen opens
- [ ] Verify text is pre-filled correctly
- [ ] Verify time is pre-filled correctly
- [ ] Verify date is pre-filled correctly

### ✅ Google Assistant Testing
- [ ] Trigger Assistant with voice command
- [ ] Say "Remind me to [task] at [time]"
- [ ] Select Cue from app list
- [ ] Verify app opens with pre-filled data
- [ ] Save reminder and verify it appears in list
- [ ] Test with different time formats (3 PM, 15:00, etc.)
- [ ] Test with different date formats (today, tomorrow, specific date)

### ✅ Edge Cases
- [ ] Test with no time specified
- [ ] Test with no text (empty reminder)
- [ ] Test with special characters in text
- [ ] Test with very long reminder text
- [ ] Test when app is already running
- [ ] Test when app is in background
- [ ] Test when app is completely closed

## Troubleshooting

### App doesn't open when using Google Assistant
1. **Check if app is installed**: Verify the app is installed and can launch normally
2. **Check AndroidManifest.xml**: Ensure intent filters are correctly added
3. **Rebuild the app**: Some changes require a full rebuild
   ```bash
   flutter clean
   flutter build apk
   flutter install
   ```
4. **Check Logcat**: Monitor Android logs for errors
   ```bash
   adb logcat | grep MainActivity
   ```

### Pre-filled data is not showing
1. **Check logs**: Look for "Handling intent" messages in logcat
   ```bash
   adb logcat | grep "🎯\|🎙️"
   ```
2. **Verify intent data**: Check if data is being received in MainActivity
3. **Test with ADB**: Use the ADB commands above to verify the deep link works

### Google Assistant doesn't recognize the app
1. **Wait for indexing**: Google may take time to index your app's capabilities
2. **Clear Google app cache**: 
   - Go to Settings → Apps → Google
   - Clear cache and restart device
3. **Re-install the app**: Sometimes a fresh install helps

### Time/Date parsing issues
The app supports multiple date/time formats:
- ISO 8601: `2024-12-30T17:00:00`
- Simple format: `date=2024-12-30&time=17:00`
- Timestamp: UNIX timestamp in milliseconds

If parsing fails, check the logs for error messages.

## Production Deployment

### For Google Play Store Release
Once you're ready to publish:

1. **Upload to Google Play Console**
2. **Submit for App Actions Review**:
   - Go to Google Play Console
   - Navigate to "App content" → "App Actions"
   - Submit your actions.xml for review
   - Google will verify your implementation

3. **Wait for approval** (usually 1-3 days)
4. **Test in production**: After approval, test with real users

### App Actions Definition (actions.xml)
The `actions.xml` file is already created at:
```
android/app/src/main/res/xml/actions.xml
```

This defines how Google Assistant interacts with your app.

## Supported Commands

Your app now supports these Google Assistant commands:

### Basic Reminders
- "Remind me to [task]"
- "Set a reminder for [task]"
- "Create a reminder to [task]"

### Time-based Reminders
- "Remind me to [task] at [time]"
- "Set a reminder to [task] at [time] today"
- "Remind me to [task] tomorrow at [time]"

### Examples
- ✅ "Remind me to call mom at 3 PM"
- ✅ "Set a reminder to workout at 7 AM tomorrow"
- ✅ "Create a reminder to take medicine today at 9 PM"
- ✅ "Remind me to buy groceries at 5 PM on Friday"

## Technical Details

### Files Modified
1. **AndroidManifest.xml**: Added intent filters for App Actions
2. **MainActivity.kt**: Added intent handling logic
3. **actions.xml**: Created App Actions definition
4. **main.dart**: Added assistant channel listener
5. **create_reminder_screen.dart**: Added support for pre-filled data

### Data Flow
```
Google Assistant
    ↓
Android Intent (with reminder data)
    ↓
MainActivity.kt (parses intent)
    ↓
Method Channel (assistant_channel)
    ↓
main.dart (receives data)
    ↓
NewReminderScreen (displays with pre-filled fields)
    ↓
User saves reminder
    ↓
Firebase (stored)
```

### Supported Parameters
- **text**: Reminder description/title
- **date**: Date in YYYY-MM-DD format
- **time**: Time in HH:mm format (24-hour)

## Logs to Monitor

When testing, watch for these log messages:

```bash
# Android logs
adb logcat | grep "MainActivity"

# Look for:
🎯 Handling intent: action=...
🎙️ Google Assistant intent received
📎 Deep link URI: ...
✅ Sending reminder data to Flutter: ...

# Flutter logs
flutter logs

# Look for:
🎙️ Received handleAssistantReminder from Google Assistant
Assistant data: ...
```

## Need Help?

If you encounter issues:

1. **Check logs first**: Most issues show up in logcat
2. **Test with ADB**: Verify deep links work before testing with Assistant
3. **Clean rebuild**: Sometimes a clean build fixes issues
4. **Check device compatibility**: Ensure Google Assistant is available on your device

## Next Steps

1. Test thoroughly using the checklist above
2. Try various voice commands with Google Assistant
3. Test on multiple devices if possible
4. Consider adding more App Actions for other features
5. Submit for Google Play review when ready

---

## Quick Test Command

Copy and paste this for quick testing:

```bash
# Test reminder creation
adb shell am start -a actions.intent.CREATE_REMINDER \
  -d "cue://reminder/create?text=Test%20from%20Assistant&time=15:00&date=2024-12-30" \
  com.cuehq.app
```

**Your Google Assistant integration is ready! 🎉**
