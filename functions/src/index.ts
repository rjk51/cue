import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ============================================================================
// RECURRENCE SYSTEM EXPORTS
// ============================================================================
// Export recurrence functions from separate module to keep code organized
export {
  completeReminder,
  updateReminderRecurrence,
  onReminderCompleted,
  calculateNextDueAt,
} from "./recurrenceFunctions";

/**
 * HTTP Callable Function triggered by the mobile app when a reminder is due
 * Sends FCM notification for a specific reminder
 */
export const triggerReminderNotification = functions.https.onCall(
  async (data) => {
    try {
      const {reminderId} = data;

      if (!reminderId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "reminderId is required"
        );
      }

      console.log(`Triggering notification for reminder: ${reminderId}`);

      const reminderDoc = await db.collection("reminders").doc(reminderId).get();

      if (!reminderDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Reminder not found"
        );
      }

      const reminder = reminderDoc.data();

      if (reminder?.notifiedAt) {
        console.log("Reminder already notified");
        return {success: true, alreadyNotified: true};
      }

      if (reminder?.isCompleted) {
        console.log("Reminder already completed");
        return {success: true, alreadyCompleted: true};
      }

      // Get all active devices to send notification to all of them
      console.log("Fetching all active devices...");
      const devicesSnapshot = await db
        .collection("devices")
        .where("active", "==", true)
        .get();

      if (devicesSnapshot.empty) {
        // Fallback to reminder's deviceToken if no devices found
        const deviceToken = reminder?.deviceToken;
        if (!deviceToken) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "No devices found and no deviceToken in reminder"
          );
        }
        console.log("No devices collection found, using reminder deviceToken");
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        devicesSnapshot.docs.push({
          data: () => ({fcmToken: deviceToken}),
        } as any);
      }

      console.log(`Found ${devicesSnapshot.size} active devices`);

      // Send notification to all devices
      const sendPromises = devicesSnapshot.docs.map(async (deviceDoc) => {
        const fcmToken = deviceDoc.data().fcmToken;

        if (!fcmToken) {
          console.log(`Skipping device ${deviceDoc.id} - no token`);
          return;
        }

        // Send data-only message so Flutter can show notification with action buttons
        const message = {
          token: fcmToken,
          data: {
            reminderId: reminderId,
            title: reminder.name || "Reminder",
            body: reminder.description || "Your reminder is due!",
            type: "reminder_notification",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high" as const,
          },
          apns: {
            payload: {
              aps: {
                "content-available": 1,
                "badge": 1,
              },
            },
          },
        };

        try {
          await messaging.send(message);
          console.log(`✅ Notification sent to device: ${fcmToken.substring(0, 20)}...`);
        } catch (error) {
          console.error(`❌ Failed to send to device ${fcmToken.substring(0, 20)}:`, error);
        }
      });

      await Promise.all(sendPromises);
      console.log(`✅ Notifications sent to ${devicesSnapshot.size} devices`);

      await reminderDoc.ref.update({
        notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {success: true, notificationSent: true};
    } catch (error) {
      console.error("Error triggering reminder notification:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to send notification"
      );
    }
  }
);

export const checkPendingReminders = functions.https.onCall(
  async (data) => {
    try {
      const {userId} = data;

      if (!userId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "userId is required"
        );
      }

      const now = admin.firestore.Timestamp.now();
      const snapshot = await db
        .collection("reminders")
        .where("userId", "==", userId)
        .where("scheduledTime", "<=", now)
        .where("isCompleted", "==", false)
        .get();

      const results = [];
      for (const doc of snapshot.docs) {
        const reminder = doc.data();
        if (reminder.notifiedAt) continue;

        const userDoc = await db.collection("users").doc(userId).get();
        const fcmToken = userDoc.data()?.fcmToken;
        if (!fcmToken) continue;

        try {
          await messaging.send({
            token: fcmToken,
            notification: {
              title: reminder.name || "Reminder",
              body: reminder.description || "Your reminder is due!",
            },
            data: {reminderId: doc.id, click_action: "FLUTTER_NOTIFICATION_CLICK"},
          });

          await doc.ref.update({
            notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          results.push({reminderId: doc.id, status: "sent"});
        } catch (error) {
          results.push({reminderId: doc.id, status: "failed"});
        }
      }

      return {success: true, processed: results.length, results};
    } catch (error) {
      throw new functions.https.HttpsError(
        "internal",
        "Failed to check pending reminders"
      );
    }
  }
);

export const onReminderCreated = functions.firestore
  .document("reminders/{reminderId}")
  .onCreate(async (snap, context) => {
    const reminderId = context.params.reminderId;
    const reminderData = snap.data();

    console.log(`New reminder created: ${reminderId}`, reminderData);

    // Check if the reminder has recurrence
    if (reminderData.recurrence) {
      console.log(`Processing recurring reminder: ${reminderId}`);
      console.log(`Recurrence type: ${reminderData.recurrence.type}`);

      try {
        // Save to suggestions collection for the user
        const suggestionData = {
          userId: reminderData.userId,
          reminderId: reminderId,
          title: reminderData.title,
          description: reminderData.description || "",
          status: reminderData.status || "active",
          recurrence: reminderData.recurrence,
          nextDueAt: reminderData.nextDueAt,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          version: reminderData.version || 1,
        };

        await db.collection("suggestions").add(suggestionData);
        const msg = "Recurring reminder saved to suggestions " +
          `collection for user: ${reminderData.userId}`;
        console.log(`✅ ${msg}`);
      } catch (error) {
        console.error("❌ Error saving to suggestions collection:", error);
      }
    } else {
      console.log("Non-recurring reminder, skipping suggestions collection");
    }

    return null;
  });

export const onReminderUpdated = functions.firestore
  .document("reminders/{reminderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (!before.isCompleted && after.isCompleted) {
      console.log(`Reminder completed: ${context.params.reminderId}`);
    }

    return null;
  });

export const sendTestNotification = functions.https.onRequest(
  async (req, res) => {
    try {
      const {reminderId} = req.body;

      if (!reminderId) {
        res.status(400).send({error: "reminderId required"});
        return;
      }

      const reminderDoc = await db.collection("reminders").doc(reminderId).get();
      if (!reminderDoc.exists) {
        res.status(404).send({error: "Reminder not found"});
        return;
      }

      const reminder = reminderDoc.data();
      const userDoc = await db.collection("users").doc(reminder?.userId).get();

      if (!userDoc.exists) {
        res.status(404).send({error: "User not found"});
        return;
      }

      const fcmToken = userDoc.data()?.fcmToken;

      if (!fcmToken) {
        res.status(400).send({error: "No FCM token found"});
        return;
      }

      await messaging.send({
        token: fcmToken,
        notification: {
          title: reminder?.title || "Test Reminder",
          body: reminder?.description || "This is a test notification",
        },
        data: {reminderId, testMode: "true"},
      });

      res.status(200).send({
        success: true,
        message: "Test notification sent successfully",
      });
    } catch (error) {
      console.error("Error sending test notification:", error);
      res.status(500).send({error: "Failed to send test notification"});
    }
  }
);
