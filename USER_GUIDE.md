# 📱 Visual User Guide

## How the App Works (User Perspective)

### 🏠 Home Screen

```
┌─────────────────────────────────────────┐
│  ← My Reminders                    ⓘ   │ ← Tap ⓘ to see FCM token
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ 🔔  Buy groceries                 │ │
│  │     Jan 20, 2026 - 02:00 PM      │ │
│  │                 ✅ Done  🗑️ Delete │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ 🔔  Team meeting                  │ │
│  │     Jan 20, 2026 - 03:30 PM      │ │
│  │                 ✅ Done  🗑️ Delete │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ ⚠️  Submit report (Overdue)       │ │ ← Shows overdue status
│  │     Jan 19, 2026 - 05:00 PM      │ │
│  │     Overdue                       │ │
│  │                 ✅ Done  🗑️ Delete │ │
│  └───────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
                    ⊕ ← Tap to add reminder
```

### ➕ Create Reminder Screen

```
┌─────────────────────────────────────────┐
│  ← Create Reminder                      │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ ✏️ Reminder Name                  │ │
│  │ Buy groceries____________         │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ 📅 Date                           │ │
│  │    20/1/2026                  →  │ │ ← Tap to select date
│  ├───────────────────────────────────┤ │
│  │ 🕐 Time                           │ │
│  │    14:00                      →  │ │ ← Tap to select time
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │      Save Reminder                │ │ ← Tap to save
│  └───────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

### 🔔 Notification Appears

```
╔═════════════════════════════════════════╗
║  📱 Cue                          2:00 PM ║
║─────────────────────────────────────────║
║  Reminder: Buy groceries                ║
║  Time to complete your task!            ║
║                                         ║
║  ┌──────────┐  ┌──────────────────┐   ║
║  │ ✅ Done  │  │ ⏰ Snooze 10 min │   ║ ← Action buttons
║  └──────────┘  └──────────────────┘   ║
╚═════════════════════════════════════════╝
```

## 🎬 User Flow Scenarios

### Scenario 1: Creating a Reminder

```
Step 1: Tap the ⊕ button
    ↓
Step 2: Enter reminder details
  • Name: "Buy groceries"
  • Date: Tomorrow
  • Time: 2:00 PM
    ↓
Step 3: Tap "Save Reminder"
    ↓
Step 4: See success message
  ✅ "Reminder created successfully!"
    ↓
Step 5: Back to home screen
  • New reminder appears in list
  • Notification scheduled for 2:00 PM tomorrow
```

### Scenario 2: Notification Arrives

```
Time: 2:00 PM Tomorrow
    ↓
📱 Phone vibrates/rings
    ↓
Notification appears on screen
┌─────────────────────────┐
│ Reminder: Buy groceries │
│ Time to complete!       │
│ [✅ Done] [⏰ Snooze]   │
└─────────────────────────┘
    ↓
User has 3 options:
  Option A: Tap notification → Opens app
  Option B: Tap "Done" → Marks complete
  Option C: Tap "Snooze" → Delays 10 min
```

### Scenario 3: Marking as Done (Cross-Device Magic!)

```
Device A (Phone)              Device B (Tablet)
─────────────────            ──────────────────
User taps "Done"             Showing reminder
on notification              in list
     │                            │
     │ ─────────────────────────► │
     │   Firestore Update         │
     │   isCompleted: true        │
     │                            │
Notification                 Real-time update!
disappears ✅                     │
                                 ▼
Reminder removed            Notification
from list ✅                disappears ✅
                                 │
                                 ▼
                            Reminder removed
                            from list ✅

⏱️ Sync time: < 1 second!
```

### Scenario 4: Snooze Feature

```
User taps "Snooze 10 min"
    ↓
Current time: 2:00 PM
New time set: 2:10 PM
    ↓
Notification disappears
    ↓
User continues working...
    ↓
⏰ 2:10 PM - New notification appears
┌─────────────────────────┐
│ Reminder: Buy groceries │
│ Time to complete!       │
│ [✅ Done] [⏰ Snooze]   │
└─────────────────────────┘
```

## 🎨 UI States

### Empty State
```
┌─────────────────────────────────────────┐
│  My Reminders                      ⓘ   │
├─────────────────────────────────────────┤
│                                         │
│             🔕                          │
│                                         │
│      No reminders yet.                  │
│      Tap + to add one!                  │
│                                         │
└─────────────────────────────────────────┘
                    ⊕
```

### Loading State
```
┌─────────────────────────────────────────┐
│  My Reminders                      ⓘ   │
├─────────────────────────────────────────┤
│                                         │
│                                         │
│              ⟳                          │
│         Loading...                      │
│                                         │
└─────────────────────────────────────────┘
```

### Error State
```
┌─────────────────────────────────────────┐
│  My Reminders                      ⓘ   │
├─────────────────────────────────────────┤
│                                         │
│              ⚠️                         │
│                                         │
│    Error: Connection failed             │
│                                         │
└─────────────────────────────────────────┘
```

### Success Feedback
```
┌─────────────────────────────────────────┐
│  My Reminders                      ⓘ   │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────┐   │
│  │ ✅ Reminder created!            │   │ ← Green snackbar
│  └─────────────────────────────────┘   │
│                                         │
│  [Reminder list...]                     │
└─────────────────────────────────────────┘
```

## 🎯 Button Guide

### Home Screen Actions

| Button | Icon | Action |
|--------|------|--------|
| Add | ⊕ | Create new reminder |
| Done | ✅ | Mark reminder complete |
| Delete | 🗑️ | Remove reminder |
| Info | ⓘ | Show FCM token |

### Notification Actions

| Button | Action | Result |
|--------|--------|--------|
| Done | Mark complete | Reminder disappears everywhere |
| Snooze | Delay 10 min | Gets new notification in 10 min |
| Tap body | Open app | View reminder details |

## 📊 Visual Indicators

### Reminder Status Colors

```
🔵 Blue Circle = Future reminder
    Example: Scheduled for tomorrow

🟢 Green Check = Completed
    Example: Task done

🟠 Orange Alert = Overdue
    Example: Past due date

🔔 Bell Icon = Active
    Example: Waiting for time

⚠️ Warning = Needs attention
    Example: Overdue reminder
```

## 🎓 Tips & Tricks

### Tip 1: View FCM Token
```
Tap ⓘ icon in top-right
    ↓
Dialog appears with your token
    ↓
Use this for testing FCM messages
```

### Tip 2: Quick Delete
```
Swipe left on reminder (planned)
    OR
Tap 🗑️ button
    ↓
Reminder deleted immediately
```

### Tip 3: Check Overdue
```
Orange reminders = Overdue
    ↓
Still receive notifications
    ↓
Complete them whenever ready
```

## 🔍 What You See vs What Happens

### When You Create a Reminder

**What You See:**
- Tap +
- Fill form
- Tap Save
- See green checkmark
- Back to home

**What Actually Happens:**
```
Your Device          Cloud              Other Devices
    │                  │                     │
    │ ─────────────────►│                    │
    │   Save to         │                    │
    │   Firestore       │                    │
    │                   │ ───────────────────►│
    │                   │   Real-time sync   │
    │                   │                     │
    │◄──────────────────┤                    │
    │   Confirmation    │                     │
    │                   │                     │
    │ Schedule local    │                     │
    │ notification      │                     │
    │                   │                     │
```

### When You Tap "Done"

**What You See:**
- Tap Done button
- Notification disappears
- Reminder removed from list

**What Actually Happens:**
```
1. Cancel local notification
2. Update Firestore (isCompleted: true)
3. Firestore broadcasts to all devices
4. Other devices receive update
5. Other devices cancel their notifications
6. Other devices remove from their lists
7. Everything synchronized!
```

## 📱 Multi-Device Experience

### Same User, Different Devices

```
Phone                Tablet              Laptop (Web)
  │                    │                      │
  │ Create reminder    │                      │
  │────────────────────┼──────────────────────►
  │                    │ ◄────────────────────┤
  │                    │   Sync (immediate)   │
  │                    │                      │
  │                    │ Mark as done         │
  │◄───────────────────┼──────────────────────┤
  │   Sync             │                      │
  │                    │                      │
All devices always in sync! ✅
```

## 🎉 Success Indicators

### Everything Working When:

✅ Reminders appear on all devices
✅ Notifications arrive at scheduled time
✅ Done button works from notification
✅ Changes sync in under 1 second
✅ App works offline (syncs when online)
✅ Green success messages appear
✅ No error messages

---

**Now you know exactly how to use your new notification system!** 🚀
