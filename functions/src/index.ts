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
 * Helper function to send dismissal notification to all devices
 * This tells all devices to cancel/dismiss the notification for a reminder
 * @param {string} reminderId - The ID of the reminder to dismiss
 */
async function sendDismissalNotificationToAllDevices(reminderId: string): Promise<void> {
  try {
    console.log(`Sending dismissal notification for reminder: ${reminderId}`);
    // Get all active devices
    const devicesSnapshot = await db
      .collection("devices")
      .where("active", "==", true)
      .get();

    if (devicesSnapshot.empty) {
      console.log("No active devices found for dismissal");
      return;
    }

    console.log(`Found ${devicesSnapshot.size} active devices for dismissal`);

    // Send dismissal message to all devices
    const sendPromises = devicesSnapshot.docs.map(async (deviceDoc) => {
      const fcmToken = deviceDoc.data().fcmToken;

      if (!fcmToken) {
        console.log(`Skipping device ${deviceDoc.id} - no token`);
        return;
      }

      // Send data-only message to dismiss notification
      const message = {
        token: fcmToken,
        data: {
          reminderId: reminderId,
          type: "dismiss_notification",
          action: "dismiss",
        },
        android: {
          priority: "high" as const,
        },
        apns: {
          payload: {
            aps: {
              "content-available": 1,
            },
          },
          headers: {
            "apns-priority": "5", // Normal priority for dismissal
          },
        },
      };

      try {
        await messaging.send(message);
        console.log(`✅ Dismissal sent to device: ${fcmToken.substring(0, 20)}...`);
      } catch (error) {
        console.error(`❌ Failed to send dismissal to device ${fcmToken.substring(0, 20)}:`, error);
      }
    });

    await Promise.all(sendPromises);
    console.log(`✅ Dismissal notifications sent to ${devicesSnapshot.size} devices`);
  } catch (error) {
    console.error("Error sending dismissal notifications:", error);
    // Don't throw - this is a best-effort operation
  }
}

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
        // Create a mock document for the fallback token
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const mockDoc: any = {
          id: "fallback",
          data: () => ({fcmToken: deviceToken}),
        };
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (devicesSnapshot.docs as any[]).push(mockDoc);
      }

      console.log(`Found ${devicesSnapshot.size} active devices`);

      // Send notification to all devices
      const sendPromises = devicesSnapshot.docs.map(async (deviceDoc) => {
        const deviceData = deviceDoc.data();
        const fcmToken = deviceData.fcmToken;
        const platform = deviceData.platform || "android"; // Default to android

        if (!fcmToken) {
          console.log(`Skipping device ${deviceDoc.id} - no token`);
          return;
        }

        const title = reminder.name || "Reminder";
        const body = reminder.description || "Your reminder is due!";

        // Build message based on platform
        // For iOS: Include notification payload so it shows in background with action buttons
        // For Android: Data-only message, Flutter will show with action buttons
        const message: admin.messaging.Message = {
          token: fcmToken,
          data: {
            reminderId: reminderId,
            title: title,
            body: body,
            type: "reminder_notification",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        };

        if (platform === "ios") {
          // For iOS: Include notification payload and APNS alert so it shows in background
          // iOS will automatically display the notification with action buttons from AppDelegate
          message.notification = {
            title: title,
            body: body,
          };
          message.apns = {
            payload: {
              aps: {
                "alert": {
                  "title": title,
                  "body": body,
                },
                "sound": "default",
                "badge": 1,
                "content-available": 1,
                "category": "reminder_category", // For iOS action buttons
              },
            },
            headers: {
              "apns-priority": "10", // High priority for immediate delivery
            },
          };
        } else {
          // For Android: Data-only message, Flutter will show with action buttons
          message.android = {
            priority: "high" as const,
          };
        }

        try {
          await messaging.send(message);
          const tokenPreview = fcmToken.substring(0, 20);
          console.log(`✅ Notification sent to ${platform} device: ${tokenPreview}...`);
        } catch (error) {
          const tokenPreview = fcmToken.substring(0, 20);
          const errorMsg = `❌ Failed to send to ${platform} device ${tokenPreview}:`;
          console.error(errorMsg, error);
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

    // Check if reminder was just completed
    if (!before.isCompleted && after.isCompleted) {
      const reminderId = context.params.reminderId;
      console.log(`Reminder completed: ${reminderId}`);

      // Send dismissal notification to all devices
      await sendDismissalNotificationToAllDevices(reminderId);
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
