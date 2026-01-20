# Cue - Smart Reminder App with Cross-Device Sync 🔔

A Flutter-based reminder application with **WhatsApp-style cross-device synchronization** powered by Firebase Cloud Messaging and Firestore.

## ✨ Features

- 📱 **Push Notifications** with action buttons (Done/Snooze)
- 🔄 **Real-time Cross-Device Sync** - Mark as done on one device, disappears on all devices
- 🔔 **Smart Scheduling** - Precise notification timing with timezone support
- 💾 **Cloud Sync** - All reminders stored in Firestore
- 🎯 **Action Buttons** - Complete or snooze directly from notifications
- ⚡ **Real-time Updates** - Changes sync instantly across all devices
- 🌐 **Offline Support** - Works offline, syncs when back online
- 🎨 **Clean UI** - Material Design 3 with intuitive interface

## 🚀 Quick Start

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run
```

## 📚 Documentation

Complete documentation is available:

- **[QUICKSTART.md](QUICKSTART.md)** - Get started in 5 minutes
- **[FCM_SETUP.md](FCM_SETUP.md)** - Detailed FCM & Firestore setup
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture & data flow
- **[USER_GUIDE.md](USER_GUIDE.md)** - Visual user guide
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Complete implementation overview
- **[CHECKLIST.md](CHECKLIST.md)** - Testing & deployment checklist

## 🎯 How It Works

### Creating a Reminder
1. Tap the + button
2. Enter reminder details (name, date, time)
3. Tap Save
4. Reminder syncs to all devices
5. Notification scheduled for the specified time

### Cross-Device Sync (The Magic! ✨)
```
Device A: Mark as "Done"
    ↓
Firestore: Update isCompleted = true
    ↓
Real-time Stream: Broadcast to all devices
    ↓
Device B, C, D: Auto-remove reminder & cancel notification
    ↓
Synchronized! (< 1 second)
```

## 🛠️ Tech Stack

- **Flutter** - Cross-platform mobile framework
- **Firebase Cloud Messaging** - Push notifications
- **Cloud Firestore** - Real-time NoSQL database
- **Flutter Local Notifications** - Native notification support
- **Timezone** - Accurate scheduling across timezones

## 📦 Key Dependencies

```yaml
firebase_core: ^3.15.0              # Firebase SDK
firebase_messaging: ^15.0.0         # FCM for push notifications
cloud_firestore: ^5.0.0             # Real-time database
flutter_local_notifications: ^17.0.0 # Local notifications
timezone: ^0.9.0                    # Timezone support
```

## 🏗️ Architecture

```
┌─────────────────┐
│   Flutter UI    │
└────────┬────────┘
         │
    ┌────┴────┐
    │ Service │ (NotificationService + ReminderService)
    └────┬────┘
         │
    ┌────┴────────────┐
    │                 │
    ▼                 ▼
┌─────────┐    ┌───────────┐
│   FCM   │    │ Firestore │
└─────────┘    └───────────┘
    │                 │
    └────────┬────────┘
             │
    Real-time Sync to All Devices
```

## 🧪 Testing

### Test Basic Features
```bash
flutter run
```
1. Create a reminder for 1 minute from now
2. Wait for notification
3. Tap "Done" button
4. Verify reminder is removed

### Test Cross-Device Sync
```bash
# Terminal 1
flutter run -d device1

# Terminal 2
flutter run -d device2
```
1. Create reminder on device1
2. See it appear on device2
3. Mark done on device1
4. Watch it disappear on device2

## 📱 Platform Support

- ✅ **Android** (Fully supported with all features)
- ✅ **iOS** (Supported, requires additional setup)
- ⚠️ **Web** (Limited - no local notifications)

## 🔐 Security

Currently configured for development with open Firestore rules. For production:

```javascript
// Update Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /reminders/{reminderId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == resource.data.userId;
    }
  }
}
```

## 📊 Project Structure

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase configuration
├── app/
│   └── app_theme.dart          # Theme configuration
└── features/
    ├── home/
    │   └── presentation/
    │       └── home_screen.dart         # Main screen
    ├── notifications/
    │   └── notification_service.dart    # FCM & local notifications
    └── reminders/
        ├── domain/
        │   └── reminder_model.dart      # Data model
        ├── data/
        │   └── reminder_service.dart    # Firestore operations
        └── presentation/
            └── create_reminder_screen.dart # Create reminder UI
```

## 🎓 Key Concepts

### Why Firestore?
- ⚡ Real-time synchronization
- 📴 Offline support built-in
- 🔄 Automatic conflict resolution
- 🎯 Simple queries with streams
- 📈 Scales automatically

### Why FCM?
- 📱 Native push notifications
- 🔋 Battery efficient
- 🌐 Works across platforms
- 🎯 Topic-based messaging
- 🔔 Background message handling

## 🚀 Roadmap

### Current Features ✅
- [x] Create/Delete reminders
- [x] Push notifications with actions
- [x] Cross-device synchronization
- [x] Real-time Firestore sync
- [x] Snooze functionality
- [x] Overdue indicators

### Planned Features 🎯
- [ ] User authentication (Firebase Auth)
- [ ] Recurring reminders
- [ ] Reminder categories/tags
- [ ] Voice input
- [ ] Reminder sharing
- [ ] Rich media attachments
- [ ] Location-based reminders
- [ ] Notification history

## 🤝 Contributing

This is a prototype project demonstrating FCM and Firestore integration. Feel free to:
- Report issues
- Suggest features
- Submit pull requests
- Use as reference for your projects

## 📄 License

This project is created for educational purposes.

## 🙏 Acknowledgments

- Firebase team for excellent documentation
- Flutter community for plugins and support
- Material Design for UI guidelines

## 📞 Firebase Project

- **Project ID**: cues-1ced9
- **Console**: https://console.firebase.google.com/project/cues-1ced9

## 💡 Getting Help

1. Check the [QUICKSTART.md](QUICKSTART.md) guide
2. Review [FCM_SETUP.md](FCM_SETUP.md) for technical details
3. Use [CHECKLIST.md](CHECKLIST.md) for troubleshooting
4. Check Flutter logs: `flutter logs`
5. Verify Firebase Console for data/errors

## 🎉 Success Stories

**What you can build with this:**
- Team collaboration apps
- Task management systems
- Event reminder apps
- Medication trackers
- Habit tracking apps
- Any app requiring cross-device notifications!

---

**Built with ❤️ using Flutter & Firebase**

Start building: `flutter run` 🚀
