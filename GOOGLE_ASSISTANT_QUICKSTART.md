# Quick Start: Test Google Assistant Integration

## Immediate Testing (5 minutes)

### 1. Build and Install
```bash
cd /Users/amriteshkumar/Developer/cue
flutter clean
flutter pub get
flutter run
```

### 2. Test with ADB (Simplest Method)

Open a new terminal and run:

```bash
# Test 1: Basic reminder with time
adb shell am start -a actions.intent.CREATE_REMINDER \
  -d "cue://reminder/create?text=Buy%20milk&time=17:00&date=2024-12-30"
```

**Expected Result**: 
- App opens
- Create Reminder screen appears
- "Buy milk" is pre-filled in the title
- Time is set to 5:00 PM
- Date is set to Dec 30, 2024

```bash
# Test 2: Different reminder
adb shell am start -a actions.intent.CREATE_REMINDER \
  -d "cue://reminder/create?text=Call%20dentist&time=14:30&date=2024-12-31"
```

**Expected Result**: 
- App opens
- "Call dentist" pre-filled
- Time set to 2:30 PM
- Date set to Dec 31, 2024

```bash
# Test 3: Just text, no time
adb shell am start -a actions.intent.CREATE_REMINDER \
  -d "cue://reminder/create?text=Remember%20to%20workout"
```

**Expected Result**: 
- App opens
- "Remember to workout" pre-filled
- Time defaults to current time

### 3. Test with Google Assistant

1. Say: **"Hey Google"** (or long-press home button)

2. Say: **"Remind me to buy groceries at 5 PM"**

3. When prompted, select **"Cue"** from the app list

4. App should open with:
   - Text: "buy groceries" 
   - Time: 5:00 PM

5. Tap Save to create the reminder

### 4. More Voice Commands to Try

- "Hey Google, remind me to call mom at 3 PM"
- "Hey Google, set a reminder to workout tomorrow at 7 AM"
- "Hey Google, remind me to take medicine at 9 PM today"

## Check Logs

If something doesn't work, check the logs:

```bash
# Android logs
adb logcat | grep -E "MainActivity|🎯|🎙️"

# Flutter logs
flutter logs
```

Look for:
- 🎯 Handling intent: ...
- 🎙️ Google Assistant intent received
- ✅ Sending reminder data to Flutter

## Troubleshooting

**App doesn't open?**
```bash
# Rebuild and reinstall
flutter clean
flutter pub get
flutter run --release
```

**Data not showing?**
- Check logcat for error messages
- Make sure URL encoding is correct (%20 for spaces)
- Try the simple ADB commands above first

**Google Assistant doesn't work?**
- ADB commands work but Assistant doesn't? This is normal for development builds
- Google needs time to index your app
- For production, you'll need to submit to Google Play Console

## Success Indicators

✅ ADB command opens the app  
✅ Reminder text is pre-filled  
✅ Time is set correctly  
✅ Date is set correctly  
✅ You can save the reminder  
✅ Reminder appears in your list  

## Next Steps

Once ADB testing works:
1. Test more complex scenarios
2. Try with Google Assistant
3. Test on different devices
4. Read full documentation: `GOOGLE_ASSISTANT_SETUP.md`

---

**Ready to test? Start with Step 1 above! 🚀**
