
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
    console.log("🔔 [triggerReminderNotification] Function called");
    console.log("📥 Request data:", JSON.stringify(data));
    try {
      const {reminderId} = data;

      if (!reminderId) {
        console.error("❌ [triggerReminderNotification] Missing reminderId");
        throw new functions.https.HttpsError(
          "invalid-argument",
          "reminderId is required"
        );
      }

      console.log(`🔔 [triggerReminderNotification] Processing reminder: ${reminderId}`);

      console.log("📖 Fetching reminder from Firestore...");
      const reminderDoc = await db.collection("reminders").doc(reminderId).get();

      if (!reminderDoc.exists) {
        console.error(`❌ [triggerReminderNotification] Reminder not found: ${reminderId}`);
        throw new functions.https.HttpsError(
          "not-found",
          "Reminder not found"
        );
      }

      const reminder = reminderDoc.data();
      console.log(`✅ Reminder data retrieved: ${reminder?.name || "Unnamed"}`);

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
        const deviceId = deviceDoc.id;
        const fcmToken = deviceDoc.data().fcmToken;
        const platform = deviceDoc.data().platform || "unknown";

        if (!fcmToken) {
          console.log(`⏭️  Skipping device [${deviceId}] - no FCM token`);
          return;
        }

        console.log(
          `📱 Preparing notification for [${platform.toUpperCase()}] device [${deviceId}]`
        );

        // Platform-specific message structure
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const message: any = {
          token: fcmToken,
        };

        if (platform === "android") {
          // Android: notification + data format (system handles display)
          message.notification = {
            title: reminder.name || "Reminder",
            body: reminder.description || "Your reminder is due!",
          };
          message.data = {
            reminderId: reminderId,
            title: reminder.name || "Reminder",
            body: reminder.description || "Your reminder is due!",
            type: "reminder_notification",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          };
          message.android = {
            priority: "high" as const,
          };
        } else {
          // iOS: Silent push with content-available (Flutter controls display)
          // Use obscure key names to prevent Firebase SDK from auto-displaying
          message.apns = {
            headers: {
              "apns-priority": "10",
            },
            payload: {
              aps: {
                "content-available": 1,
              },
              // Use non-standard keys to avoid auto-display
              reminder_id: reminderId,
              reminder_title: reminder.name || "Reminder",
              reminder_body: reminder.description || "Your reminder is due!",
              msg_type: "reminder_notification",
            },
          };
        }

        try {
          await messaging.send(message);
          console.log(`✅ [${platform.toUpperCase()}] Notification sent successfully!`);
          console.log(
            `   └─ Device: ${deviceId} | Token: ${fcmToken.substring(0, 20)}...`
          );
          console.log(`   └─ Reminder: ${reminder.name}`);
        } catch (error) {
          console.error(`❌ [${platform.toUpperCase()}] Failed to send notification`);
          console.error(`   └─ Device: ${deviceId} | Token: ${fcmToken.substring(0, 20)}...`);
          console.error("   └─ Error:", error);
        }
      });

      await Promise.all(sendPromises);
      console.log(`✅ All notification promises completed for ${devicesSnapshot.size} devices`);

      console.log("💾 Updating reminder with notifiedAt timestamp...");
      await reminderDoc.ref.update({
        notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`✅ Reminder ${reminderId} marked as notified`);

      console.log("✅ [triggerReminderNotification] Function completed successfully");
      return {success: true, notificationSent: true};
    } catch (error) {
      console.error("❌ [triggerReminderNotification] Error occurred:", error);
      console.error("❌ Error details:", JSON.stringify(error, null, 2));
      throw new functions.https.HttpsError(
        "internal",
        "Failed to send notification"
      );
    }
  }
);

export const checkPendingReminders = functions.https.onCall(
  async (data) => {
    console.log("⏰ [checkPendingReminders] Function called");
    console.log("📥 Request data:", JSON.stringify(data));
    try {
      const {userId} = data;

      if (!userId) {
        console.error("❌ [checkPendingReminders] Missing userId");
        throw new functions.https.HttpsError(
          "invalid-argument",
          "userId is required"
        );
      }

      console.log(`🔍 Checking pending reminders for user: ${userId}`);

      const now = admin.firestore.Timestamp.now();
      const snapshot = await db
        .collection("reminders")
        .where("userId", "==", userId)
        .where("scheduledTime", "<=", now)
        .where("isCompleted", "==", false)
        .get();

      console.log(`📊 Found ${snapshot.size} pending reminder(s)`);
      const results = [];
      for (const doc of snapshot.docs) {
        const reminder = doc.data();
        console.log(`📝 Processing reminder [${doc.id}]: ${reminder.name || "Unnamed"}`);

        if (reminder.notifiedAt) {
          console.log(`⏭️  Skipping [${doc.id}] - already notified`);
          continue;
        }

        console.log("👤 Fetching user FCM token...");
        const userDoc = await db.collection("users").doc(userId).get();
        const fcmToken = userDoc.data()?.fcmToken;
        if (!fcmToken) {
          console.warn(`⚠️  No FCM token found for user: ${userId}`);
          continue;
        }
        console.log(`✅ FCM token found: ${fcmToken.substring(0, 20)}...`);

        try {
          console.log(`📤 Sending notification for reminder [${doc.id}]...`);
          await messaging.send({
            token: fcmToken,
            notification: {
              title: reminder.name || "Reminder",
              body: reminder.description || "Your reminder is due!",
            },
            data: {reminderId: doc.id, click_action: "FLUTTER_NOTIFICATION_CLICK"},
          });
          console.log(`✅ Notification sent for reminder [${doc.id}]`);

          console.log(`💾 Marking reminder [${doc.id}] as notified...`);
          await doc.ref.update({
            notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          results.push({reminderId: doc.id, status: "sent"});
          console.log(`✅ Reminder [${doc.id}] processed successfully`);
        } catch (error) {
          console.error(`❌ Failed to send notification for reminder [${doc.id}]:`, error);
          results.push({reminderId: doc.id, status: "failed"});
        }
      }

      console.log(`✅ [checkPendingReminders] Completed - Processed ${results.length} reminder(s)`);
      console.log("📊 Results:", JSON.stringify(results));
      return {success: true, processed: results.length, results};
    } catch (error) {
      console.error("❌ [checkPendingReminders] Error occurred:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to check pending reminders"
      );
    }
  }
);

/**
 * Firestore trigger: When a reminder is created, schedule it for notification
 * and handle recurrence logic
 */
export const scheduleReminderOnCreate = functions.firestore
  .document("reminders/{reminderId}")
  .onCreate(async (snap, context) => {
    console.log("🆕 [scheduleReminderOnCreate] Trigger fired");
    const reminderId = context.params.reminderId;
    const reminderData = snap.data();

    console.log(`📝 New reminder created [${reminderId}]`);
    console.log("📄 Reminder data:", JSON.stringify(reminderData, null, 2));

    // Handle recurrence logic
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
    }

    // Skip notification scheduling if already completed or no time set
    if (reminderData.isCompleted || !reminderData.time) {
      console.log(
        `⏭️  [scheduleReminderOnCreate] Skipping notification scheduling for ${reminderId}`
      );
      console.log(
        `   Reason: ${reminderData.isCompleted ? "Already completed" : "No time set"}`
      );
      return null;
    }

    const reminderTime = reminderData.time.toDate();
    const now = new Date();
    console.log(`⏰ Reminder time: ${reminderTime.toISOString()}`);
    console.log(`⏰ Current time: ${now.toISOString()}`);

    // Skip if time is in the past
    if (reminderTime <= now) {
      console.log(
        "⏭️  [scheduleReminderOnCreate] Time is in the past, skipping notification"
      );
      console.log(`   Time difference: ${now.getTime() - reminderTime.getTime()}ms`);
      return null;
    }
    console.log(
      "✅ Reminder time is in the future - will schedule notification"
    );

    // Create a document in pending_notifications collection
    await db.collection("pending_notifications").doc(reminderId).set({
      reminderId: reminderId,
      scheduledTime: reminderData.time,
      reminderName: reminderData.name || "Reminder",
      reminderDescription: reminderData.description || "Your reminder is due!",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Scheduled notification for reminder ${reminderId} at ${reminderTime}`);
    return null;
  });

export const onReminderUpdated = functions.firestore
  .document("reminders/{reminderId}")
  .onUpdate(async (change, context) => {
    console.log("═══════════════════════════════════════════════════════════");
    console.log("📝 [onReminderUpdated] TRIGGER FIRED");
    console.log("═══════════════════════════════════════════════════════════");
    console.log("🕐 Timestamp:", new Date().toISOString());
    console.log("📋 Context:", JSON.stringify(context));

    const before = change.before.data();
    const after = change.after.data();
    const reminderId = context.params.reminderId;

    console.log("───────────────────────────────────────────────────────────");
    console.log(`📝 Reminder ID: ${reminderId}`);
    console.log("───────────────────────────────────────────────────────────");
    console.log("📊 BEFORE data:");
    console.log(`   - isCompleted: ${before.isCompleted} (type: ${typeof before.isCompleted})`);
    console.log(`   - completedAt: ${before.completedAt}`);
    console.log(`   - name: ${before.name || before.title}`);
    console.log("───────────────────────────────────────────────────────────");
    console.log("📊 AFTER data:");
    console.log(`   - isCompleted: ${after.isCompleted} (type: ${typeof after.isCompleted})`);
    console.log(`   - completedAt: ${after.completedAt}`);
    console.log(`   - name: ${after.name || after.title}`);
    console.log("───────────────────────────────────────────────────────────");

    // Check condition with detailed logging
    const wasNotCompleted = !before.isCompleted;
    const isNowCompleted = after.isCompleted === true;
    console.log("🔍 COMPLETION CHECK:");
    console.log(`   - Was NOT completed before: ${wasNotCompleted}`);
    console.log(`   - Is NOW completed: ${isNowCompleted}`);
    console.log(`   - Should send dismiss: ${wasNotCompleted && isNowCompleted}`);

    // If reminder was just marked as completed, notify all devices to dismiss notification
    if (wasNotCompleted && isNowCompleted) {
      console.log(`✅ [onReminderUpdated] Reminder marked as completed: ${reminderId}`);
      console.log("📤 Initiating dismiss notification to all devices...");

      try {
        // Get all active devices
        const devicesSnapshot = await db
          .collection("devices")
          .where("active", "==", true)
          .get();

        if (devicesSnapshot.empty) {
          console.log("No active devices found");
          return null;
        }

        console.log(`📤 Sending dismiss notification to ${devicesSnapshot.size} devices`);

        // Send data-only message to dismiss notification on all devices
        const sendPromises = devicesSnapshot.docs.map(async (deviceDoc) => {
          const deviceId = deviceDoc.id;
          const fcmToken = deviceDoc.data().fcmToken;
          const platform = deviceDoc.data().platform || "unknown";

          if (!fcmToken) {
            console.log(`⏭️  Skipping device [${deviceId}] - no FCM token`);
            return;
          }

          console.log(`📱 Sending dismiss to [${platform.toUpperCase()}] device [${deviceId}]`);

          try {
            // Calculate notification ID (same as Flutter's hashCode)
            const notificationId = Math.abs(reminderId.split("").reduce((hash, char) => {
              return ((hash << 5) - hash) + char.charCodeAt(0);
            }, 0));

            console.log(
              `🔢 Calculated notification ID: ${notificationId} for reminder: ${reminderId}`
            );

            // Send silent data message to dismiss notification
            const message = {
              token: fcmToken,
              data: {
                type: "dismiss_notification",
                reminderId: reminderId,
                notificationId: String(notificationId),
                action: "completed",
              },
            } as admin.messaging.Message;

            // Platform-specific configuration
            if (platform.toLowerCase() === "ios") {
              // iOS: Use apns-collapse-id to REPLACE the original notification
              // with an empty one that effectively removes it from notification center.
              // Background-only pushes are unreliable (don't work on simulator,
              // may not wake terminated apps).
              message.apns = {
                headers: {
                  "apns-priority": "10",
                  "apns-push-type": "alert", // Use alert type for reliability
                  // CRITICAL: Same collapse-id as original to REPLACE it
                  "apns-collapse-id": reminderId,
                },
                payload: {
                  aps: {
                    // Minimal alert with zero-width space character
                    // This makes iOS deliver it as a real notification (triggers native handler)
                    // but appears invisible to the user. The apns-collapse-id will replace
                    // the original notification, effectively removing it.
                    "alert": "\u200B", // Zero-width space - invisible but not empty
                    "badge": 0, // Clear badge
                    "content-available": 1,
                    "mutable-content": 1,
                    "thread-id": reminderId,
                  },
                  // Custom data for Flutter/native handler
                  type: "dismiss_notification",
                  reminderId: reminderId,
                  notificationId: String(notificationId),
                  action: "completed",
                },
              };
              console.log(`📱 [IOS] Configured REPLACEMENT notification for ${deviceId}`);
              console.log(`   └─ Using apns-collapse-id: ${reminderId} to replace original`);
            } else {
              // Android: High priority for immediate delivery
              message.android = {
                priority: "high" as const,
              };
              console.log(`🤖 [ANDROID] Configured high-priority message for ${deviceId}`);
            }

            await messaging.send(message);
            console.log(`✅ [${platform.toUpperCase()}] Dismiss notification sent!`);
            console.log(
              `   └─ Device: ${deviceId} | Token: ${fcmToken.substring(0, 20)}...`
            );
            console.log(`   └─ Reminder: ${reminderId}`);
          } catch (error: unknown) {
            console.error(`❌ [${platform.toUpperCase()}] Failed to send dismiss notification`);
            console.error(`   └─ Device: ${deviceId} | Token: ${fcmToken.substring(0, 20)}...`);
            console.error("   └─ Error:", error);

            // Clean up stale tokens
            if (error && typeof error === "object" && "errorInfo" in error) {
              const firebaseError = error as { errorInfo?: { code?: string } };
              if (firebaseError.errorInfo?.code === "messaging/registration-token-not-registered") {
                console.log(`🧹 Removing stale token for device: ${deviceId}`);
                try {
                  await db.collection("devices").doc(deviceId).update({
                    active: false,
                    deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    deactivationReason: "Token not registered",
                  });
                  console.log(`✅ Deactivated stale device: ${deviceId}`);
                } catch (cleanupError) {
                  console.error(`❌ Failed to cleanup device ${deviceId}:`, cleanupError);
                }
              }
            }
          }
        });

        await Promise.all(sendPromises);
        const msg = "✅ Dismiss notifications sent to all devices for " +
          `reminder ${reminderId}`;
        console.log(msg);
        console.log("✅ [onReminderUpdated] Dismiss operation completed");
      } catch (error) {
        console.error("❌ [onReminderUpdated] Error sending dismiss notifications:", error);
        console.error("❌ Error details:", JSON.stringify(error, null, 2));
      }
    } else {
      console.log("───────────────────────────────────────────────────────────");
      console.log(`ℹ️  [onReminderUpdated] No dismiss action needed for ${reminderId}`);
      console.log("   Reason: Completion status did not change from false→true");
      // Log what fields actually changed
      const changedFields: string[] = [];
      Object.keys(after).forEach((key) => {
        const beforeVal = JSON.stringify(before[key]);
        const afterVal = JSON.stringify(after[key]);
        if (beforeVal !== afterVal) {
          changedFields.push(`${key}: ${beforeVal} → ${afterVal}`);
        }
      });
      const changedFieldsStr = changedFields.length > 0 ?
        changedFields.join(", ") : "none";
      console.log("   Changed fields:", changedFieldsStr);
      console.log("───────────────────────────────────────────────────────────");
    }

    console.log("═══════════════════════════════════════════════════════════");
    console.log("✅ [onReminderUpdated] Function completed");
    console.log("═══════════════════════════════════════════════════════════");
    return null;
  });

export const sendTestNotification = functions.https.onRequest(
  async (req, res) => {
    console.log("🧪 [sendTestNotification] Function called");
    console.log("📥 Request body:", JSON.stringify(req.body));
    console.log("📥 Request method:", req.method);
    try {
      const {reminderId} = req.body;

      if (!reminderId) {
        console.error("❌ [sendTestNotification] Missing reminderId");
        res.status(400).send({error: "reminderId required"});
        return;
      }

      console.log(`🧪 Testing notification for reminder: ${reminderId}`);

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

      console.log("📤 Sending test notification...");
      const testMessage = {
        token: fcmToken,
        notification: {
          title: reminder?.title || "Test Reminder",
          body: reminder?.description || "This is a test notification",
        },
        data: {reminderId, testMode: "true"},
      };
      console.log("📄 Test message:", JSON.stringify(testMessage));

      await messaging.send(testMessage);
      console.log("✅ [sendTestNotification] Test notification sent successfully");

      res.status(200).send({
        success: true,
        message: "Test notification sent successfully",
      });
    } catch (error) {
      console.error("❌ [sendTestNotification] Error occurred:", error);
      console.error("❌ Error details:", JSON.stringify(error, null, 2));
      res.status(500).send({error: "Failed to send notification"});
    }
  }
);


/**
 * Scheduled function - runs every minute but only reads pending notifications
 * Much more efficient: only reads documents that need processing
 */
export const processPendingNotifications = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async () => {
    console.log("⏰ [processPendingNotifications] Scheduled function triggered");
    console.log("🔍 Processing pending notifications...");

    const now = admin.firestore.Timestamp.now();
    console.log(`⏰ Current time: ${now.toDate().toISOString()}`);
    try {
      // Query ONLY pending notifications that are due
      // This is much cheaper than querying all reminders
      const snapshot = await db
        .collection("pending_notifications")
        .where("scheduledTime", "<=", now)
        .limit(50) // Process max 50 per run to avoid timeouts
        .get();

      if (snapshot.empty) {
        console.log("No pending notifications");
        return {success: true, processed: 0};
      }

      console.log(`📬 Found ${snapshot.size} pending notification(s) ready to process`);

      for (const doc of snapshot.docs) {
        const notification = doc.data();
        const reminderId = notification.reminderId;

        try {
          // Delete the pending notification FIRST to ensure only one process handles it
          await doc.ref.delete();
          console.log(`🔒 Processing reminder [${reminderId}]: "${notification.reminderName}"`);

          // Check if reminder still exists and isn't completed
          const reminderDoc = await db.collection("reminders").doc(reminderId).get();

          if (!reminderDoc.exists || reminderDoc.data()?.isCompleted) {
            console.log(`Reminder ${reminderId} completed or deleted, skipping`);
            continue;
          }

          // Check if already notified
          if (reminderDoc.data()?.notifiedAt) {
            console.log(`Reminder ${reminderId} already notified, skipping`);
            continue;
          }

          // Mark reminder as notified FIRST to prevent duplicate processing
          await reminderDoc.ref.update({
            notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Get active devices
          console.log("📱 Querying for active devices...");
          const devicesSnapshot = await db
            .collection("devices")
            .where("active", "==", true)
            .get();

          if (devicesSnapshot.empty) {
            console.log(`⚠️  No active devices found, skipping ${reminderId}`);
            continue;
          }
          console.log(`✅ Found ${devicesSnapshot.size} active device(s)`);

          // Send notifications
          const sendPromises = devicesSnapshot.docs.map(async (deviceDoc) => {
            const deviceId = deviceDoc.id;
            const fcmToken = deviceDoc.data().fcmToken;
            const platform = deviceDoc.data().platform || "unknown";

            if (!fcmToken) {
              console.log(`⏭️  Skipping device [${deviceId}] - no FCM token`);
              return;
            }

            console.log(`📱 Sending to [${platform.toUpperCase()}] device [${deviceId}]`);

            const message = {
              token: fcmToken,
              notification: {
                title: notification.reminderName,
                body: notification.reminderDescription,
              },
              data: {
                reminderId: reminderId,
                title: notification.reminderName,
                body: notification.reminderDescription,
                type: "reminder_notification",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
              android: {
                priority: "high" as const,
                // Use collapse_key for Android to enable notification replacement
                collapseKey: reminderId,
              },
              apns: {
                headers: {
                  // CRITICAL: This sets the notification identifier in iOS
                  // so we can remove it later using this same ID
                  "apns-collapse-id": reminderId,
                },
                payload: {
                  aps: {
                    "alert": {
                      title: notification.reminderName,
                      body: notification.reminderDescription,
                    },
                    "sound": "default",
                    "badge": 1,
                    "content-available": 1,
                    "mutable-content": 1,
                    "category": "reminder_category",
                    // Thread ID helps group notifications
                    "thread-id": reminderId,
                  },
                  // Include reminderId in payload for access in handlers
                  reminderId: reminderId,
                  type: "reminder_notification",
                },
              },
            };

            await messaging.send(message);
            console.log(`✅ [${platform.toUpperCase()}] Notification delivered!`);
            console.log(
              `   └─ Device: ${deviceId} | Token: ${fcmToken.substring(0, 20)}...`
            );
            console.log(`   └─ Reminder: ${notification.reminderName}`);
          });

          await Promise.all(sendPromises);

          console.log(`✅ Processed notification for ${reminderId}`);
        } catch (error) {
          console.error(`❌ Error processing ${reminderId}:`, error);
          console.error("❌ Error details:", JSON.stringify(error, null, 2));
        }
      }

      console.log(
        "✅ [processPendingNotifications] Batch completed - " +
        `Processed ${snapshot.size} notification(s)`
      );

      return {success: true, processed: snapshot.size};
    } catch (error) {
      console.error(
        "❌ [processPendingNotifications] Critical error occurred:", error
      );
      console.error("❌ Error details:", JSON.stringify(error, null, 2));
      return {success: false, error};
    }
  });
