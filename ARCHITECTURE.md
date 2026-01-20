# System Architecture Diagram

## 📐 Cross-Device Notification Sync Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         DEVICE A (Phone)                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐      ┌─────────────────────────────┐    │
│  │   Cue App UI     │◄─────┤  NotificationService        │    │
│  │  - Home Screen   │      │  - FCM Token Management     │    │
│  │  - Create Screen │      │  - Local Notifications      │    │
│  │  - Action Buttons│      │  - Schedule/Cancel          │    │
│  └────────┬─────────┘      └──────────┬──────────────────┘    │
│           │                           │                         │
│           │ User Action               │ Notification Trigger   │
│           ▼                           ▼                         │
│  ┌────────────────────────────────────────────────────────┐    │
│  │           ReminderService (Data Layer)                 │    │
│  │  - addReminder()      - markAsCompleted()             │    │
│  │  - deleteReminder()   - snoozeReminder()              │    │
│  │  - getRemindersStream() ◄── Real-time Listener        │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
└───────────────────┼─────────────────────────────────────────────┘
                    │
                    │ Firestore API
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FIREBASE CLOUD (Backend)                     │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         Cloud Firestore (Real-time Database)             │  │
│  │                                                            │  │
│  │  Collection: reminders/                                   │  │
│  │  ├── {reminderId1}                                        │  │
│  │  │   ├── name: "Buy groceries"                           │  │
│  │  │   ├── time: Timestamp                                 │  │
│  │  │   ├── isCompleted: false → true (on Done)            │  │
│  │  │   ├── userId: "demo_user"                             │  │
│  │  │   └── deviceToken: "FCM_TOKEN_DEVICE_A"              │  │
│  │  │                                                         │  │
│  │  └── {reminderId2}...                                     │  │
│  │                                                            │  │
│  │  [Auto-sync to all connected clients]                    │  │
│  └────────────────────────┬─────────────────────────────────┘  │
│                            │                                    │
│  ┌─────────────────────────▼────────────────────────────────┐  │
│  │     Firebase Cloud Messaging (FCM)                       │  │
│  │  - Device Token Management                               │  │
│  │  - Topic Subscriptions (user_demo_user)                 │  │
│  │  - Background Message Delivery                           │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                    │
                    │ Firestore Stream Updates
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DEVICE B (Tablet)                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────┐  │
│  │           ReminderService (Data Layer)                   │  │
│  │  getRemindersStream() ──► Receives Update               │  │
│  │       ▼                                                   │  │
│  │  isCompleted: true detected                             │  │
│  └────────────────┬─────────────────────────────────────────┘  │
│                   │                                             │
│                   │ Update UI                                   │
│                   ▼                                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │   Cue App UI - Removes Reminder from List                │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │   NotificationService - Cancels Notification             │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 🔄 Sequence: Creating a Reminder

```
User (Device A)
     │
     │ 1. Taps "+"
     ▼
Create Reminder Screen
     │
     │ 2. Enters name & time
     │ 3. Taps "Save"
     ▼
ReminderService.addReminder()
     │
     │ 4. Creates Firestore document
     ▼
Cloud Firestore
     │
     │ 5. Real-time sync
     ├──────────────┬──────────────┐
     ▼              ▼              ▼
Device A       Device B       Device C
     │              │              │
     │ 6. Stream    │ 6. Stream    │ 6. Stream
     │    update    │    update    │    update
     ▼              ▼              ▼
Update UI      Update UI      Update UI
     │              │              │
     │ 7. Schedule  │ 7. Schedule  │ 7. Schedule
     │    local     │    local     │    local
     │    notif     │    notif     │    notif
     ▼              ▼              ▼
All devices show the new reminder ✅
```

## ✅ Sequence: Marking as Done

```
Device A                           Cloud Firestore                    Device B
   │                                      │                              │
   │ 1. User taps "Done"                 │                              │
   │    (on notification)                │                              │
   ▼                                      │                              │
NotificationService                      │                              │
.onNotificationAction()                  │                              │
   │                                      │                              │
   │ 2. Call markAsCompleted()           │                              │
   ▼                                      │                              │
ReminderService                          │                              │
.markAsCompleted(reminderId)            │                              │
   │                                      │                              │
   │ 3. Update Firestore                 │                              │
   │────────────────────────────────────►│                              │
   │    isCompleted: true                │                              │
   │                                      │                              │
   │ 4. Cancel local notification        │ 5. Real-time sync           │
   │    (on Device A)                    │────────────────────────────►│
   ▼                                      │                              ▼
Notification                             │                       getRemindersStream()
disappears                               │                       detects change
on Device A ✅                            │                              │
   │                                      │                              │ 6. UI updates
   │                                      │                              │    (removes from list)
   │                                      │                              ▼
   │                                      │                       Notification
   │                                      │                       cancelled
   │                                      │                       on Device B ✅
   │◄─────────────────────────────────────┴──────────────────────────────│
                    All devices synchronized in real-time!
```

## 🔔 Notification Action Flow

```
┌─────────────────────────────────────────────────────────────┐
│             User Sees Notification                          │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  📱 Reminder: Buy groceries                        │    │
│  │  ⏰ Time to complete your task!                    │    │
│  │                                                     │    │
│  │  [✅ Done]  [⏰ Snooze 10 min]                     │    │
│  └────────────────────────────────────────────────────┘    │
└──────────────┬──────────────────────┬───────────────────────┘
               │                       │
      User taps "Done"        User taps "Snooze"
               │                       │
               ▼                       ▼
    ┌──────────────────┐    ┌──────────────────────┐
    │ Mark as Complete │    │ Add 10 minutes       │
    │ in Firestore     │    │ Update time          │
    │                  │    │ in Firestore         │
    │ isCompleted:true │    │ Reschedule notif     │
    └────────┬─────────┘    └─────────┬────────────┘
             │                         │
             │                         │
             └────────┬────────────────┘
                      │
                      ▼
           ┌───────────────────────┐
           │ Sync to All Devices   │
           │ via Firestore Stream  │
           └───────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
        ▼             ▼             ▼
   Device A      Device B      Device C
   Update UI     Update UI     Update UI
```

## 🏗️ Component Dependencies

```
┌────────────────────────────────────────────────────────────┐
│                         main.dart                          │
│  - Firebase initialization                                 │
│  - Notification action handler setup                       │
│  - Background message handler                              │
└────────────┬────────────────────────┬──────────────────────┘
             │                         │
             ▼                         ▼
┌──────────────────────┐    ┌──────────────────────┐
│  NotificationService │    │   ReminderService    │
├──────────────────────┤    ├──────────────────────┤
│ - FCM Setup          │    │ - Firestore CRUD     │
│ - Local Notifs       │    │ - Real-time Streams  │
│ - Scheduling         │    │ - Sync Logic         │
│ - Action Handlers    │    │ - Business Logic     │
└──────────┬───────────┘    └───────────┬──────────┘
           │                             │
           │  Uses                 Uses  │
           │   ▼                    ▼    │
           │ FCM             Firestore   │
           │  +                  +       │
           │ Local             Cloud     │
           │ Notifications   Database    │
           │                             │
           └──────────┬──────────────────┘
                      │
                      │ Both used by
                      ▼
           ┌──────────────────────┐
           │    UI Screens        │
           ├──────────────────────┤
           │ - HomeScreen         │
           │ - CreateReminderScreen│
           └──────────────────────┘
                      │
                      │ Displays
                      ▼
           ┌──────────────────────┐
           │   Reminder Model     │
           ├──────────────────────┤
           │ - id                 │
           │ - name               │
           │ - time               │
           │ - isCompleted        │
           │ - deviceToken        │
           └──────────────────────┘
```

## 📊 Data Flow

### Write Path (Create Reminder)
```
UI Input → Validation → Service Layer → Firestore Write → Stream Update → All Devices
```

### Read Path (Display Reminders)
```
Firestore Stream → Service Layer → Transform to Model → UI Update
```

### Notification Path
```
Scheduled Time → Local Notification → Action Tap → Service Call → Firestore Update → Sync
```

## 🔐 Security Layers

```
┌─────────────────────────────────────────┐
│          User Device                    │
│  ├─ App Permissions (Android)           │
│  ├─ FCM Token (unique per install)      │
│  └─ Local Storage (notifications)       │
└──────────────┬──────────────────────────┘
               │
               │ HTTPS/SSL
               ▼
┌─────────────────────────────────────────┐
│       Firebase Cloud                    │
│  ├─ Firestore Security Rules            │
│  ├─ FCM Authentication                  │
│  └─ API Key Restrictions                │
└─────────────────────────────────────────┘
```

## 💡 Key Design Decisions

1. **Firestore over Realtime DB**: Better querying, offline support
2. **Local Notifications**: Works without internet, battery efficient
3. **Topic Subscriptions**: Scalable multi-device messaging
4. **Stream Listeners**: Real-time sync without polling
5. **Action Buttons**: Native platform notifications for better UX

---

This architecture ensures:
- ⚡ Real-time synchronization
- 🔋 Battery efficiency
- 📴 Offline support
- 🔐 Security
- 📈 Scalability
