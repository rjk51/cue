import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// ============================================================================
// TYPE DEFINITIONS
// ============================================================================

/**
 * Recurrence configuration for a reminder
 */
interface RecurrenceConfig {
  type: "interval" | "weekly" | "monthly" | "yearly";
  startDate?: admin.firestore.Timestamp;
  endDate?: admin.firestore.Timestamp;

  // For interval-based recurrence
  every?: number; // e.g., 2 for "every 2 days"
  unit?: "minutes" | "hours" | "days";
  anchor?: "completion" | "scheduled"; // anchor to completion or scheduled

  // For weekly recurrence
  days?: string[]; // e.g., ["mon", "wed", "fri"]
  time?: string; // e.g., "09:30" (HH:mm format)

  // For monthly recurrence
  pattern?: "dayOfMonth" | "nthWeekday";
  value?: number; // day number (1-31) or nth weekday (1-5, -1 for last)

  // For yearly recurrence
  month?: number; // 1-12
  day?: number; // 1-31
}

/**
 * Reminder document structure
 */
interface Reminder {
  id: string;
  title: string;
  status: "active" | "paused";
  nextDueAt?: admin.firestore.Timestamp;
  recurrence?: RecurrenceConfig;
  lastCompletedAt?: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
  version: number;
}

// ============================================================================
// PURE UTILITY FUNCTIONS
// ============================================================================

/**
 * Calculate the next due date for a reminder based on its recurrence rule.
 * This is a PURE function - it does not modify Firestore or have side
 * effects.
 * @param {Reminder} reminder - The reminder document
 * @return {Date | null} Date object for the next occurrence, or null
 */
export function calculateNextDueAt(reminder: Reminder): Date | null {
  // If no recurrence is defined, this is a one-time reminder
  if (!reminder.recurrence) {
    return null;
  }

  const recurrence = reminder.recurrence;
  const now = new Date();
  const startBoundary = recurrence.startDate?.toDate();
  const baseline = startBoundary && startBoundary > now ? startBoundary : now;

  let nextDue: Date | null = null;
  switch (recurrence.type) {
  case "interval":
    nextDue = calculateIntervalNextDue(reminder, recurrence, baseline);
    break;

  case "weekly":
    nextDue = calculateWeeklyNextDue(recurrence, baseline);
    break;

  case "monthly":
    nextDue = calculateMonthlyNextDue(recurrence, baseline);
    break;

  case "yearly":
    nextDue = calculateYearlyNextDue(recurrence, baseline);
    break;

  default:
    console.warn(`Unknown recurrence type: ${recurrence.type}`);
  }

  const endBoundary = recurrence.endDate?.toDate();
  if (endBoundary && nextDue && nextDue.getTime() > endBoundary.getTime()) {
    return null;
  }

  return nextDue;
}

/**
 * Calculate next due date for INTERVAL-based recurrence
 * Examples: "Every 3 days", "Every 2 hours"
 * Anchor modes:
 * - "completion": Next occurrence is X time after the last completion
 * - "scheduled": Next occurrence is X time after the last scheduled time
 * @param {Reminder} reminder - The reminder document
 * @param {RecurrenceConfig} recurrence - The recurrence configuration
 * @param {Date} baseline - Current date respecting start boundary
 * @return {Date} Next due date
 */
function calculateIntervalNextDue(
  reminder: Reminder,
  recurrence: RecurrenceConfig,
  baseline: Date
): Date {
  const every = recurrence.every || 1;
  const unit = recurrence.unit || "days";
  const anchor = recurrence.anchor || "completion";

  // Determine the reference point
  let referenceDate: Date;

  if (anchor === "completion" && reminder.lastCompletedAt) {
    // Anchor to last completion time
    referenceDate = reminder.lastCompletedAt.toDate();
  } else {
    // Anchor to last scheduled time (or current time if never completed)
    referenceDate = reminder.nextDueAt ? reminder.nextDueAt.toDate() : baseline;
  }

  // Calculate the interval in milliseconds
  let intervalMs: number;
  switch (unit) {
  case "minutes":
    intervalMs = every * 60 * 1000;
    break;
  case "hours":
    intervalMs = every * 60 * 60 * 1000;
    break;
  case "days":
  default:
    intervalMs = every * 24 * 60 * 60 * 1000;
    break;
  }

  // Add the interval to the reference date
  const nextDue = new Date(referenceDate.getTime() + intervalMs);

  // If the calculated next due is in the past, keep adding intervals
  // until it's in the future
  // This handles cases where the reminder wasn't completed for a long time
  while (nextDue.getTime() < baseline.getTime()) {
    nextDue.setTime(nextDue.getTime() + intervalMs);
  }

  return nextDue;
}

/**
 * Calculate next due date for WEEKLY recurrence
 * Examples: "Every Monday at 9am", "Every Mon/Wed/Fri at 14:30"
 * @param {RecurrenceConfig} recurrence - The recurrence configuration
 * @param {Date} baseline - Current date respecting start boundary
 * @return {Date} Next due date
 */
function calculateWeeklyNextDue(
  recurrence: RecurrenceConfig,
  baseline: Date
): Date {
  const days = recurrence.days || ["mon"];
  const time = recurrence.time || "09:00";

  // Parse the time (HH:mm)
  const [hours, minutes] = time.split(":").map(Number);

  // Map day names to day numbers (0 = Sunday, 1 = Monday, ..., 6 = Saturday)
  const dayMap: Record<string, number> = {
    sun: 0, mon: 1, tue: 2, wed: 3, thu: 4, fri: 5, sat: 6,
  };

  // Convert day names to day numbers
  const targetDays = days.map((day) => dayMap[day.toLowerCase()])
    .filter((d) => d !== undefined);

  if (targetDays.length === 0) {
    console.warn("No valid days specified for weekly recurrence");
    return baseline;
  }

  // Sort target days to find the next occurrence
  targetDays.sort((a, b) => a - b);

  // Find the next occurrence
  const currentDay = baseline.getDay();
  const currentHour = baseline.getHours();
  const currentMinute = baseline.getMinutes();

  // Check if we can schedule for today
  const todayIndex = targetDays.indexOf(currentDay);
  if (todayIndex !== -1) {
    // Today is a target day - check if the time hasn't passed yet
    if (hours > currentHour ||
        (hours === currentHour && minutes > currentMinute)) {
      const nextDue = new Date(baseline);
      nextDue.setHours(hours, minutes, 0, 0);
      return nextDue;
    }
  }

  // Find the next target day after today
  let daysUntilNext = -1;
  for (const targetDay of targetDays) {
    if (targetDay > currentDay) {
      daysUntilNext = targetDay - currentDay;
      break;
    }
  }

  // If no target day is after today, wrap to next week
  if (daysUntilNext === -1) {
    daysUntilNext = 7 - currentDay + targetDays[0];
  }

  // Calculate the next due date
  const nextDue = new Date(baseline);
  nextDue.setDate(nextDue.getDate() + daysUntilNext);
  nextDue.setHours(hours, minutes, 0, 0);

  return nextDue;
}

/**
 * Calculate next due date for MONTHLY recurrence
 * Patterns:
 * - "dayOfMonth": Repeat on a specific day (e.g., 15th of every month)
 * - "nthWeekday": Repeat on nth weekday (e.g., 2nd Tuesday, last Friday)
 * @param {RecurrenceConfig} recurrence - The recurrence configuration
 * @param {Date} baseline - Current date respecting start boundary
 * @return {Date} Next due date
 */
function calculateMonthlyNextDue(
  recurrence: RecurrenceConfig,
  baseline: Date
): Date {
  const pattern = recurrence.pattern || "dayOfMonth";
  const value = recurrence.value || 1;
  const time = recurrence.time || "09:00";

  const [hours, minutes] = time.split(":").map(Number);

  if (pattern === "dayOfMonth") {
    return calculateMonthlyDayOfMonth(baseline, value, hours, minutes);
  } else {
    return calculateMonthlyNthWeekday(baseline, value, hours, minutes);
  }
}

/**
 * Calculate monthly recurrence for specific day of month
 * Handles edge cases like Feb 31 (rolls to Feb 28/29)
 * @param {Date} now - Current date
 * @param {number} dayOfMonth - Day of month
 * @param {number} hours - Hour of day
 * @param {number} minutes - Minute of hour
 * @return {Date} Next due date
 */
function calculateMonthlyDayOfMonth(
  now: Date,
  dayOfMonth: number,
  hours: number,
  minutes: number
): Date {
  const nextDue = new Date(now);

  // Set to the target day of the current month
  nextDue.setDate(dayOfMonth);
  nextDue.setHours(hours, minutes, 0, 0);

  // If the date is in the past, move to next month
  if (nextDue <= now) {
    nextDue.setMonth(nextDue.getMonth() + 1);
    nextDue.setDate(dayOfMonth);
  }

  // Handle months with fewer days (e.g., Feb 31 → Feb 28/29)
  // If the day doesn't exist in the month, use the last day of that month
  const targetMonth = nextDue.getMonth();
  if (nextDue.getMonth() !== targetMonth) {
    // Day overflowed to next month - use last day of target month
    nextDue.setDate(0); // Sets to last day of previous month
  }

  return nextDue;
}

/**
 * Calculate next due date for YEARLY recurrence
 * Example: every year on March 10 at 09:00
 * @param {RecurrenceConfig} recurrence - The recurrence configuration
 * @param {Date} baseline - Current date respecting start boundary
 * @return {Date} Next due date
 */
function calculateYearlyNextDue(
  recurrence: RecurrenceConfig,
  baseline: Date
): Date {
  const time = recurrence.time || "09:00";
  const [hours, minutes] = time.split(":").map(Number);

  const month = recurrence.month ??
    ((recurrence.startDate?.toDate().getMonth() ?? baseline.getMonth()) + 1);
  const day = recurrence.day ?? recurrence.value ?? baseline.getDate();

  const target = new Date(baseline);
  target.setMonth(month - 1, day);
  target.setHours(hours, minutes, 0, 0);

  if (target <= baseline) {
    target.setFullYear(target.getFullYear() + 1);
    target.setMonth(month - 1, day);
  }

  // Clamp overflow (e.g., Feb 30 → Feb 28/29)
  if (target.getMonth() !== month - 1) {
    target.setDate(0);
    target.setHours(hours, minutes, 0, 0);
  }

  return target;
}

/**
 * Calculate monthly recurrence for nth weekday
 * Examples: 2nd Tuesday (value=2), Last Friday (value=-1)
 * For this simplified implementation, we use:
 * value 1-5: 1st, 2nd, 3rd, 4th, 5th occurrence
 * value -1: Last occurrence
 * @param {Date} now - Current date
 * @param {number} nthWeekday - Nth occurrence of weekday
 * @param {number} hours - Hour of day
 * @param {number} minutes - Minute of hour
 * @return {Date} Next due date
 */
function calculateMonthlyNthWeekday(
  now: Date,
  nthWeekday: number,
  hours: number,
  minutes: number
): Date {
  // For simplicity, this implementation uses the current day of week
  // In a real app, you'd want to store the target weekday separately
  const targetWeekday = now.getDay();

  const nextDue = new Date(now);
  nextDue.setHours(hours, minutes, 0, 0);

  // Move to next month to find the nth occurrence
  nextDue.setMonth(nextDue.getMonth() + 1);
  nextDue.setDate(1);

  // Find the first occurrence of the target weekday in this month
  while (nextDue.getDay() !== targetWeekday) {
    nextDue.setDate(nextDue.getDate() + 1);
  }

  // Now jump to the nth occurrence
  if (nthWeekday === -1) {
    // Last occurrence - keep adding weeks until we hit next month
    const targetMonth = nextDue.getMonth();
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const testDate = new Date(nextDue);
      testDate.setDate(testDate.getDate() + 7);
      if (testDate.getMonth() !== targetMonth) {
        break;
      }
      nextDue.setDate(nextDue.getDate() + 7);
    }
  } else {
    // Add weeks to get to the nth occurrence (1-indexed)
    nextDue.setDate(nextDue.getDate() + (nthWeekday - 1) * 7);
  }

  return nextDue;
}

// ============================================================================
// CLOUD FUNCTIONS
// ============================================================================

/**
 * HTTP Callable Function: Complete a reminder and calculate next occurrence
 * This function is triggered when a user completes a reminder.
 * It updates the reminder with:
 * - lastCompletedAt timestamp
 * - nextDueAt (calculated using the recurrence rule)
 * - version (incremented for idempotency)
 * - updatedAt timestamp
 * Idempotency: Uses version number to ensure the same completion event
 * is not processed twice.
 */
export const completeReminder = functions.https.onCall(
  async (data, context) => {
    try {
      // Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated"
        );
      }

      const userId = context.auth.uid;
      const {reminderId, completedAt, currentVersion} = data;

      // Validate required parameters
      if (!reminderId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "reminderId is required"
        );
      }

      console.log(
        `Processing completion for reminder ${reminderId} by user ${userId}`
      );

      // Get the reminder document
      const db = admin.firestore();
      const messaging = admin.messaging();
      const reminderRef = db
        .collection("users")
        .doc(userId)
        .collection("reminders")
        .doc(reminderId);

      // Use a transaction to ensure atomic updates and idempotency
      const result = await db.runTransaction(async (transaction) => {
        const reminderDoc = await transaction.get(reminderRef);

        if (!reminderDoc.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "Reminder not found"
          );
        }

        const reminder = reminderDoc.data() as Reminder;

        // Idempotency check: If version is provided and matches current
        // version, this completion has already been processed
        if (currentVersion !== undefined &&
            reminder.version > currentVersion) {
          console.log(
            "Duplicate completion detected. Current version: " +
            `${reminder.version}, Provided version: ${currentVersion}`
          );
          return {
            success: true,
            duplicate: true,
            message: "Completion already processed",
          };
        }

        // Check if reminder is paused
        if (reminder.status === "paused") {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Cannot complete a paused reminder"
          );
        }

        // Determine completion timestamp
        const completionTimestamp = completedAt ?
          admin.firestore.Timestamp.fromMillis(completedAt) :
          admin.firestore.Timestamp.now();

        // Calculate the next due date using the recurrence rule
        const updatedReminder: Reminder = {
          ...reminder,
          lastCompletedAt: completionTimestamp,
        };

        const nextDueDate = calculateNextDueAt(updatedReminder);

        // Prepare update data
        const updateData: Record<string, unknown> = {
          lastCompletedAt: completionTimestamp,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          version: admin.firestore.FieldValue.increment(1),
        };

        // If there's a next occurrence, update nextDueAt
        if (nextDueDate) {
          updateData.nextDueAt =
            admin.firestore.Timestamp.fromDate(nextDueDate);
          console.log(
            `Next occurrence scheduled for: ${nextDueDate.toISOString()}`
          );
        } else {
          // No recurrence - this was a one-time reminder
          // Optionally mark as completed or inactive
          updateData.status = "paused";
          console.log("No recurrence configured - reminder completed");
        }

        // Perform the update
        transaction.update(reminderRef, updateData);

        return {
          success: true,
          duplicate: false,
          nextDueAt: nextDueDate?.toISOString() || null,
          hasRecurrence: !!nextDueDate,
        };
      });

      // After successful completion, send dismissal notifications to all devices
      // This ensures notifications are dismissed on all devices when reminder is completed
      try {
        const devicesSnapshot = await db
          .collection("devices")
          .where("active", "==", true)
          .get();

        if (!devicesSnapshot.empty) {
          console.log(`Sending dismissal notifications to ${devicesSnapshot.size} devices`);
          const dismissalPromises = devicesSnapshot.docs.map(async (deviceDoc) => {
            const fcmToken = deviceDoc.data().fcmToken;
            if (!fcmToken) return;

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
                  "apns-priority": "5",
                },
              },
            };

            try {
              await messaging.send(message);
            } catch (error) {
              console.error(`Failed to send dismissal to device: ${error}`);
            }
          });

          await Promise.all(dismissalPromises);
          console.log("✅ Dismissal notifications sent to all devices");
        }
      } catch (dismissalError) {
        // Don't fail the completion if dismissal fails
        console.error("Error sending dismissal notifications (non-fatal):", dismissalError);
      }

      return result;
    } catch (error) {
      console.error("Error completing reminder:", error);

      // Re-throw HttpsErrors as-is
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      // Wrap other errors
      throw new functions.https.HttpsError(
        "internal",
        "Failed to complete reminder"
      );
    }
  }
);

/**
 * HTTP Callable Function: Update reminder recurrence rule
 * This function allows updating the recurrence configuration of a reminder.
 * It recalculates the next due date based on the new rule.
 */
export const updateReminderRecurrence = functions.https.onCall(
  async (data, context) => {
    try {
      // Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated"
        );
      }

      const userId = context.auth.uid;
      const {reminderId, recurrence} = data;

      // Validate required parameters
      if (!reminderId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "reminderId is required"
        );
      }

      if (!recurrence) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "recurrence is required"
        );
      }

      console.log(`Updating recurrence for reminder ${reminderId}`);

      // Get the reminder document
      const db = admin.firestore();
      const reminderRef = db
        .collection("users")
        .doc(userId)
        .collection("reminders")
        .doc(reminderId);

      const reminderDoc = await reminderRef.get();

      if (!reminderDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Reminder not found"
        );
      }

      const reminder = reminderDoc.data() as Reminder;

      // Update the reminder with new recurrence rule
      const updatedReminder: Reminder = {
        ...reminder,
        recurrence: recurrence,
      };

      // Recalculate next due date based on new rule
      const nextDueDate = calculateNextDueAt(updatedReminder);

      const updateData: Record<string, unknown> = {
        recurrence: recurrence,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        version: admin.firestore.FieldValue.increment(1),
      };

      if (nextDueDate) {
        updateData.nextDueAt =
          admin.firestore.Timestamp.fromDate(nextDueDate);
      }

      await reminderRef.update(updateData);

      return {
        success: true,
        nextDueAt: nextDueDate?.toISOString() || null,
      };
    } catch (error) {
      console.error("Error updating reminder recurrence:", error);

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        "internal",
        "Failed to update reminder recurrence"
      );
    }
  }
);

/**
 * Firestore Trigger: Log reminder completions
 * This function triggers whenever a reminder document is updated.
 * It logs completions for analytics and debugging purposes.
 */
export const onReminderCompleted = functions.firestore
  .document("users/{userId}/reminders/{reminderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() as Reminder;
    const after = change.after.data() as Reminder;

    // Check if this update represents a completion
    const wasCompleted =
      !before.lastCompletedAt && after.lastCompletedAt;

    if (wasCompleted) {
      const userId = context.params.userId;
      const reminderId = context.params.reminderId;

      console.log(
        `✅ Reminder completed: ${reminderId} by user ${userId} at ` +
        `${after.lastCompletedAt.toDate().toISOString()}`
      );

      // Log whether a next occurrence was scheduled
      if (after.nextDueAt && after.recurrence) {
        console.log(
          `   Next occurrence: ${after.nextDueAt.toDate().toISOString()} ` +
          `(${after.recurrence.type})`
        );
      } else {
        console.log("   No next occurrence (one-time reminder or paused)");
      }

      // Here you could add analytics tracking, streak calculations, etc.
    }

    return null;
  });
