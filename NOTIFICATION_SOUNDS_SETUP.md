# Notification Sounds Setup

## Required Sound Files

You need to add 3 additional notification sound files to enable the 4 sound options:

### Sound Files Needed:
1. ✅ `notification_ringtone.wav` (already exists - Default Tone)
2. ❌ `notification_bell.wav` (Bell Chime - needs to be added)
3. ❌ `notification_ding.wav` (Ding Sound - needs to be added)
4. ❌ `notification_alert.wav` (Alert Tone - needs to be added)

## Setup Instructions

### Android
1. Place the 3 new `.wav` files in: `android/app/src/main/res/raw/`
   - notification_bell.wav
   - notification_ding.wav
   - notification_alert.wav

### iOS
1. Place the 3 new `.wav` files in: `ios/Runner/`
2. Open Xcode project (`ios/Runner.xcodeproj`)
3. Add files to project:
   - Right-click on `Runner` folder → "Add Files to Runner"
   - Select the 3 new `.wav` files
   - Make sure "Copy items if needed" is checked
   - Make sure "Runner" target is selected
   - Click "Add"

## Sound File Specifications
- Format: WAV (recommended) or other iOS/Android compatible formats
- Duration: 1-3 seconds recommended
- Sample Rate: 44.1 kHz or 48 kHz
- Bit Depth: 16-bit

## Free Sound Resources
You can find free notification sounds at:
- [Freesound.org](https://freesound.org/)
- [Zapsplat.com](https://www.zapsplat.com/)
- [Notification Sounds](https://notificationsounds.com/)

## Testing
After adding the sounds:
1. Run the app
2. Go to Settings → Notifications
3. Select each sound option
4. Tap "Test Notification" to hear the selected sound
