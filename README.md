# 🚀 Cue — Human-Centered, Voice-First Reminders

**Version:** `1.0.0+14`  
**Last Updated:** `February 12, 2026`

Cue is a smart, voice-first reminder app designed to reduce friction in capturing tasks and bring a human, social layer back into remembering. Instead of cold system alerts, Cue introduces *Buddy Nudges* — reminders that feel personal, timely, and motivating.

---

## 🧠 Inspiration

We’ve all been there: you think of something important while walking or driving, but by the time you unlock your phone and navigate to a to-do app, the thought is gone.

Most reminder apps feel **mechanical** — just databases of text that fade into the background noise of notifications.

Cue was built to solve two problems:

- **Friction** — capturing a task should be as fast as speaking  
- **Isolation** — remembering shouldn’t feel like a lonely chore  

What if reminders felt more *human*?  
What if a friend could give you a gentle **nudge** instead of a sterile system alert?

Cue turns remembering into a **seamless, sometimes social experience**.

---

## 🚀 What it does

Cue helps you get tasks out of your head — and actually get them done.

### 🎙️ Voice-to-Task  
Create reminders by speaking. Speech is transcribed and converted into scheduled tasks instantly.

### 🔔 Actionable Background Notifications  
Take action directly from notifications:
- ✅ Mark as Done  
- ⏰ Snooze (quick presets)  
- ✍️ Custom Snooze  
No app opening required.

### 🤝 Buddy Nudges  
Friends, partners, or accountability peers can send **Nudges** — distinct alerts that cut through notification fatigue.

### 🔄 Reliable Sync  
Everything syncs across devices using Firebase.

---

## 🛠️ How we built it

- **Frontend:** Flutter (Android + iOS)  
- **Backend:** Firebase Auth, Firestore  
- **Notifications:** flutter_local_notifications + FCM  
- **Background Execution:** Dedicated FCM background isolate  
- **Monetization:** RevenueCat subscriptions  

---

## 🧩 Challenges we solved

### Android Background Execution  
Notifications failed silently due to missing channels.  
✔ Fixed by guaranteeing channel creation before posting notifications.

### Flutter Isolates  
Background handlers run in a separate isolate.  
✔ Implemented defensive service initialization to avoid crashes.

---

## 🏆 Accomplishments

- Rock-solid background notifications  
- Real-time Buddy Nudges  
- Near-instant voice-based task capture  

---

## 📚 What we learned

- Deep Android lifecycle + notification behavior  
- Defensive programming for background execution  
- Cross-platform notification consistency is *hard*  

---

## 🔮 What’s next

- 📴 Offline-first voice transcription  
- 🧠 Smart NLP for time detection  
- 👥 Team nudges for families & workgroups  

---

# 🧱 Tech Stack Overview

### Frontend
- Flutter (Dart)  
- Provider + ChangeNotifiers  
- Material + Cupertino  
- Responsive UI: `flutter_screenutil`

### Backend
- Firebase Auth  
- Firestore  
- Cloud Functions (Node.js)  
- Firebase Cloud Messaging  

### Key Dependencies

```yaml
firebase_core: ^2.24.2
firebase_auth: ^4.16.0
cloud_firestore: ^4.14.0
firebase_messaging: ^14.7.10
flutter_local_notifications: ^16.3.0
purchases_flutter: ^9.10.8
flutter_sound:
http:
```


# 🏗 System Architecture
```
Flutter App (Android / iOS)
   │
   ├── Presentation Layer
   ├── Business Logic Layer
   └── Data Layer
           │
           ▼
     Firebase Services
   ┌──────────┬────────────┬───────────┐
   │  Auth    │ Firestore  │    FCM    │
   └──────────┴────────────┴───────────┘
           │
           ▼
     Cloud Functions
   - Reminder processing
   - Buddy nudges
```
# 🔥 Firebase Integration
```
Firestore Schema
users/{userId}
reminders/{reminderId}
devices/{deviceId}
nudges/{nudgeId}
```

## 🚢 Deployment

### Android
```bash
flutter build appbundle --release
# or
flutter build aab --release

iOS
# Build IPA for App Store
flutter build ipa --export-method app-store
```
