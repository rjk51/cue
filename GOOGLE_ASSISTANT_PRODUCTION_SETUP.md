# Google Assistant Production Setup Guide

## Why Google Assistant Uses Google Tasks

By default, Google Assistant uses Google's own services (Tasks/Keep) for reminders. To make Assistant use your Cue app, you need to follow these steps.

## Development/Testing Phase (Now)

### Method 1: Direct App Invocation (Recommended for Testing)

Tell Google Assistant to specifically use your app:

**Voice Commands:**
```
"Hey Google, open Cue and remind me to buy milk at 5 PM"
"Hey Google, use Cue to remind me to buy milk"
"Hey Google, in Cue, set a reminder for 3 PM"
```

### Method 2: Use Test Tool

#### Install Google Assistant Plugin in Android Studio

1. Open Android Studio
2. Go to **Settings/Preferences** → **Plugins**
3. Search for **"Google Assistant"**
4. Install and restart

#### Use the Test Tool

1. Go to **Tools** → **Google Assistant** → **App Actions Test Tool**
2. Select your app package: `com.cuehq.app`
3. Select action: `CREATE_REMINDER`
4. Fill in preview:
   - **text**: "Buy groceries"
   - **time**: "17:00"
   - **date**: "2026-02-10"
5. Click **"Run App Action"**

This simulates Google Assistant without needing actual voice commands.

### Method 3: ADB Testing (You're Already Doing This)

```bash
adb -s 192.168.0.102:43491 shell 'am start -W -a android.intent.action.VIEW -d "cue://reminder/create?text=Test%20reminder&time=17:00&date=2026-02-10" com.cuehq.app'
```

## Production Deployment (For Real Users)

To make Google Assistant automatically suggest or use Cue for all users:

### Step 1: Prepare Your App

✅ Your app already has:
- [x] `actions.xml` configured
- [x] Intent filters in `AndroidManifest.xml`
- [x] Deep link handling in `MainActivity.kt`
- [x] Flutter integration

### Step 2: Upload to Google Play Console

1. **Build release APK/AAB**:
   ```bash
   flutter build appbundle --release
   ```

2. **Upload to Google Play Console**:
   - Go to [Google Play Console](https://play.google.com/console)
   - Create or open your app
   - Upload the bundle

3. **Fill out store listing** (required before submission)

### Step 3: Submit App Actions for Review

1. In **Google Play Console**, go to:
   - **App content** → **App Actions**
   
2. Click **"Get started"** or **"Add action"**

3. **Configure your action**:
   - Action type: **Built-in Intent** → `actions.intent.CREATE_REMINDER`
   - Upload your `actions.xml` file (from `android/app/src/main/res/xml/actions.xml`)
   - Provide examples like:
     - "Remind me to buy milk at 5 PM"
     - "Set a reminder to call mom tomorrow"
     - "Create a reminder to workout at 7 AM"

4. **Test your action**:
   - Google provides a test tool in the console
   - Test with the provided examples

5. **Submit for review**:
   - Fill in all required information
   - Submit your app for review
   - Wait 1-3 business days for approval

### Step 4: After Approval

Once approved by Google:
- ✅ Google Assistant will recognize your app for reminders
- ✅ Users can say "Remind me..." and see Cue as an option
- ✅ Users can set Cue as default reminder app (on supported devices)

## Alternative: Voice Match Training

Even without Play Store approval, users can train Assistant:

### User Instructions

1. **Try multiple times**: Keep opening Cue manually when Assistant offers options
2. **Assistant learns**: After a few times, it will remember your preference
3. **Be specific**: Say "Open Cue" first, then give reminder details

## Custom Voice Shortcuts (Workaround)

Create a custom phrase that always opens Cue:

### Steps:

1. Open **Google Assistant**
2. Say: "Hey Google, open Assistant settings"
3. Go to **"Routines"**
4. Tap **"+"** to create new routine
5. Configure:
   - **When you say**: "add to cue" or "cue reminder"
   - **Assistant will**: 
     - Open app → Select **Cue**
     - (Optional) Send text → Type a variable

### Example Usage:

Instead of: "Hey Google, remind me to buy milk"  
Say: "Hey Google, cue reminder" → Then add details in the app

## URL Scheme Alternative

You can also share a special link that users can tap:

```
cue://reminder/create?text=Your%20reminder&time=17:00&date=2026-02-10
```

Users can:
- Save this as a home screen shortcut
- Use NFC tags
- Use QR codes
- Share via other apps

## Testing Checklist

Before production submission:

- [ ] ADB commands work correctly
- [ ] Deep links parse all parameters (text, time, date)
- [ ] App opens on various Android versions
- [ ] Handles missing parameters gracefully
- [ ] Test with Android Studio plugin
- [ ] Test on multiple devices
- [ ] Verify crash-free operation
- [ ] Check logs for errors

## Marketing Your Assistant Integration

Once live, promote it:

### In-App Tutorial
Show users how to use voice commands:
- "Hey Google, open Cue and remind me..."
- Show example commands
- Offer to set up a routine

### Store Listing
Mention in your Play Store description:
> "Works with Google Assistant! Just say 'Hey Google, open Cue and remind me...'"

### User Education
Create help documentation showing:
- Voice command examples
- How to set up routines
- How to train Assistant

## Troubleshooting Production Issues

### App doesn't appear in Assistant after approval
1. Wait 24-48 hours for full rollout
2. Clear Google app cache
3. Update Google app to latest version
4. Restart device

### Users report it doesn't work
1. Check if they have latest app version
2. Verify they say "open Cue" before reminder details
3. Confirm Google Play Services is updated
4. Check device compatibility (Android 6.0+)

## Current Status

**✅ Development Ready:**
- Your app can handle Assistant intents
- Deep links work correctly
- Parameters are parsed properly
- Integration is complete

**⏳ Production Pending:**
- Need to publish to Play Store
- Need to submit App Actions for review
- After approval, will work for all users

## Recommended Next Steps

**For Now (Testing):**
1. Use: "Hey Google, **open Cue** and remind me..."
2. Or use ADB commands for testing
3. Or use Android Studio plugin

**For Production:**
1. Complete your app (all features ready)
2. Build release version
3. Upload to Play Store
4. Submit App Actions for review
5. Wait for Google approval
6. Market the voice integration feature

## Summary

Your app is **technically ready** for Google Assistant integration. The reason it opens Google Tasks instead is because:

1. **Google defaults to its own services** (by design)
2. **You need Play Store approval** for automatic integration
3. **Users need to train Assistant** or use specific phrases

**Workaround for now:** Say "Hey Google, **open Cue** and remind me..."

This will open Cue directly, and your integration will handle the rest! 🎤

---

## Quick Commands Reference

```bash
# Test on device
adb -s 192.168.0.102:43491 shell 'am start -W -a android.intent.action.VIEW \
  -d "cue://reminder/create?text=Test&time=17:00&date=2026-02-10" \
  com.cuehq.app'

# Voice command template
"Hey Google, open Cue and remind me to [task] at [time]"

# Check logs
adb -s 192.168.0.102:43491 logcat -d -s MainActivity:D | tail -20
```

Need help with Play Store submission? Let me know! 🚀
