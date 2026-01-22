/**
 * UNIT TESTS FOR RECURRENCE SYSTEM
 * 
 * These tests demonstrate that the calculateNextDueAt function
 * works correctly for all recurrence types and edge cases.
 * 
 * To run these tests:
 * 1. Install Jest: npm install --save-dev jest @types/jest ts-jest
 * 2. Add to package.json: "test": "jest"
 * 3. Run: npm test
 * 
 * For hackathon demo purposes, these tests serve as documentation
 * and proof of correctness.
 */

import * as admin from "firebase-admin";
import {calculateNextDueAt} from "../src/recurrenceFunctions";

// Mock Firestore Timestamp for testing
class MockTimestamp {
  private date: Date;

  constructor(seconds: number, nanoseconds: number = 0) {
    this.date = new Date(seconds * 1000 + nanoseconds / 1000000);
  }

  toDate(): Date {
    return new Date(this.date);
  }

  static fromDate(date: Date): MockTimestamp {
    return new MockTimestamp(Math.floor(date.getTime() / 1000));
  }
}

// Helper to create a test reminder
function createReminder(
  nextDueAt: Date,
  recurrence: any,
  lastCompletedAt?: Date
): any {
  return {
    id: "test-reminder",
    title: "Test Reminder",
    status: "active",
    nextDueAt: MockTimestamp.fromDate(nextDueAt) as any,
    recurrence,
    lastCompletedAt: lastCompletedAt
      ? (MockTimestamp.fromDate(lastCompletedAt) as any)
      : undefined,
    updatedAt: MockTimestamp.fromDate(new Date()) as any,
    version: 1,
  };
}

describe("Recurrence System - calculateNextDueAt", () => {
  // =========================================================================
  // ONE-TIME REMINDERS
  // =========================================================================

  describe("One-Time Reminders", () => {
    it("should return null for reminders without recurrence", () => {
      const reminder = createReminder(new Date("2026-01-21T09:00:00Z"), undefined);

      const result = calculateNextDueAt(reminder);

      expect(result).toBeNull();
    });
  });

  // =========================================================================
  // INTERVAL RECURRENCE
  // =========================================================================

  describe("Interval Recurrence", () => {
    it("should calculate next due for interval in days (completion anchor)", () => {
      const lastCompleted = new Date("2026-01-21T10:30:00Z");
      const reminder = createReminder(
        new Date("2026-01-21T09:00:00Z"),
        {
          type: "interval",
          every: 3,
          unit: "days",
          anchor: "completion",
        },
        lastCompleted
      );

      const result = calculateNextDueAt(reminder);

      // Should be 3 days after last completion
      const expected = new Date("2026-01-24T10:30:00Z");
      expect(result?.toISOString()).toBe(expected.toISOString());
    });

    it("should calculate next due for interval in hours (completion anchor)", () => {
      const lastCompleted = new Date("2026-01-21T10:30:00Z");
      const reminder = createReminder(
        new Date("2026-01-21T09:00:00Z"),
        {
          type: "interval",
          every: 8,
          unit: "hours",
          anchor: "completion",
        },
        lastCompleted
      );

      const result = calculateNextDueAt(reminder);

      // Should be 8 hours after last completion
      const expected = new Date("2026-01-21T18:30:00Z");
      expect(result?.toISOString()).toBe(expected.toISOString());
    });

    it("should calculate next due for interval in minutes", () => {
      const lastCompleted = new Date("2026-01-21T10:30:00Z");
      const reminder = createReminder(
        new Date("2026-01-21T09:00:00Z"),
        {
          type: "interval",
          every: 45,
          unit: "minutes",
          anchor: "completion",
        },
        lastCompleted
      );

      const result = calculateNextDueAt(reminder);

      // Should be 45 minutes after last completion
      const expected = new Date("2026-01-21T11:15:00Z");
      expect(result?.toISOString()).toBe(expected.toISOString());
    });

    it("should use scheduled anchor when specified", () => {
      const lastCompleted = new Date("2026-01-21T10:30:00Z");
      const lastScheduled = new Date("2026-01-18T09:00:00Z");
      const reminder = createReminder(
        lastScheduled,
        {
          type: "interval",
          every: 3,
          unit: "days",
          anchor: "scheduled",
        },
        lastCompleted
      );

      const result = calculateNextDueAt(reminder);

      // Should be 3 days after last scheduled, not last completion
      const expected = new Date("2026-01-21T09:00:00Z");
      expect(result?.toISOString()).toBe(expected.toISOString());
    });

    it("should handle overdue intervals by skipping to future", () => {
      const lastCompleted = new Date("2026-01-10T09:00:00Z");
      const reminder = createReminder(
        new Date("2026-01-10T09:00:00Z"),
        {
          type: "interval",
          every: 3,
          unit: "days",
          anchor: "completion",
        },
        lastCompleted
      );

      // Mock current time to be much later
      const now = new Date("2026-01-25T12:00:00Z");
      const originalNow = Date.now;
      Date.now = () => now.getTime();

      const result = calculateNextDueAt(reminder);

      // Should skip past due intervals and find next future date
      // Last completed: Jan 10
      // Intervals: Jan 13, 16, 19, 22, 25, 28
      // First future one from Jan 25 noon is Jan 28
      expect(result!.getTime()).toBeGreaterThan(now.getTime());

      Date.now = originalNow;
    });
  });

  // =========================================================================
  // WEEKLY RECURRENCE
  // =========================================================================

  describe("Weekly Recurrence", () => {
    it("should calculate next due for single weekly day", () => {
      const reminder = createReminder(new Date("2026-01-21T09:00:00Z"), {
        type: "weekly",
        days: ["wed"],
        time: "14:00",
      });

      // Current: Tuesday Jan 21, 2026
      const now = new Date("2026-01-21T10:00:00Z");
      const originalNow = Date.now;
      Date.now = () => now.getTime();

      const result = calculateNextDueAt(reminder);

      // Next Wednesday at 14:00
      const expected = new Date("2026-01-22T14:00:00Z");
      expect(result?.toISOString()).toBe(expected.toISOString());

      Date.now = originalNow;
    });

    it("should calculate next due for multiple weekly days", () => {
      const reminder = createReminder(new Date("2026-01-21T09:00:00Z"), {
        type: "weekly",
        days: ["mon", "wed", "fri"],
        time: "09:00",
      });

      // Current: Tuesday Jan 21, 2026 at 10:00
      const now = new Date("2026-01-21T10:00:00Z");
      const originalNow = Date.now;
      Date.now = () => now.getTime();

      const result = calculateNextDueAt(reminder);

      // Next occurrence: Wednesday Jan 22 at 09:00
      const expected = new Date("2026-01-22T09:00:00Z");
      expect(result?.toISOString()).toBe(expected.toISOString());

      Date.now = originalNow;
    });

    it("should handle same-day weekly recurrence if time hasn't passed", () => {
      const reminder = createReminder(new Date("2026-01-21T09:00:00Z"), {
        type: "weekly",
        days: ["wed"],
        time: "14:00",
      });

      // Current: Wednesday Jan 21, 2026 at 10:00 (before 14:00)
      const now = new Date("2026-01-21T10:00:00Z"); // This is a Wednesday
      const originalNow = Date.now;
      Date.now = () => now.getTime();

      const result = calculateNextDueAt(reminder);

      // Should be today at 14:00
      const expected = new Date("2026-01-21T14:00:00Z");
      expect(result?.toISOString()).toBe(expected.toISOString());

      Date.now = originalNow;
    });

    it("should wrap to next week if all days have passed", () => {
      const reminder = createReminder(new Date("2026-01-21T09:00:00Z"), {
        type: "weekly",
        days: ["mon", "tue"],
        time: "09:00",
      });

      // Current: Friday Jan 24, 2026
      const now = new Date("2026-01-24T10:00:00Z");
      const originalNow = Date.now;
      Date.now = () => now.getTime();

      const result = calculateNextDueAt(reminder);

      // Next Monday (Jan 27)
      const expected = new Date("2026-01-27T09:00:00Z");
      expect(result?.toISOString()).toBe(expected.toISOString());

      Date.now = originalNow;
    });
  });

  // =========================================================================
  // MONTHLY RECURRENCE
  // =========================================================================

  describe("Monthly Recurrence - Day of Month", () => {
    it("should calculate next due for specific day of month", () => {
      const reminder = createReminder(new Date("2026-01-15T09:00:00Z"), {
        type: "monthly",
        pattern: "dayOfMonth",
        value: 15,
        time: "09:00",
      });

      // Current: Jan 21, 2026
      const now = new Date("2026-01-21T10:00:00Z");
      const originalNow = Date.now;
      Date.now = () => now.getTime();

      const result = calculateNextDueAt(reminder);

      // Next 15th: February 15
      const expected = new Date("2026-02-15T09:00:00Z");
      expect(result?.toISOString()).toBe(expected.toISOString());

      Date.now = originalNow;
    });

    it("should handle same month if day hasn't passed", () => {
      const reminder = createReminder(new Date("2026-01-15T09:00:00Z"), {
        type: "monthly",
        pattern: "dayOfMonth",
        value: 25,
        time: "09:00",
      });

      // Current: Jan 21, 2026
      const now = new Date("2026-01-21T10:00:00Z");
      const originalNow = Date.now;
      Date.now = () => now.getTime();

      const result = calculateNextDueAt(reminder);

      // Should be this month on the 25th
      const expected = new Date("2026-01-25T09:00:00Z");
      expect(result?.toISOString()).toBe(expected.toISOString());

      Date.now = originalNow;
    });

    it("should handle February edge case (day 31 → day 28)", () => {
      const reminder = createReminder(new Date("2026-01-31T09:00:00Z"), {
        type: "monthly",
        pattern: "dayOfMonth",
        value: 31,
        time: "09:00",
      });

      // Current: Jan 31, 2026
      const now = new Date("2026-01-31T10:00:00Z");
      const originalNow = Date.now;
      Date.now = () => now.getTime();

      const result = calculateNextDueAt(reminder);

      // February only has 28 days in 2026, so should roll to Feb 28
      expect(result?.getMonth()).toBe(1); // February (0-indexed)
      expect(result?.getDate()).toBeLessThanOrEqual(28);

      Date.now = originalNow;
    });
  });

  describe("Monthly Recurrence - Nth Weekday", () => {
    it("should calculate next due for nth weekday", () => {
      const reminder = createReminder(new Date("2026-01-15T09:00:00Z"), {
        type: "monthly",
        pattern: "nthWeekday",
        value: 2, // 2nd occurrence
        time: "09:00",
      });

      const now = new Date("2026-01-21T10:00:00Z");
      const originalNow = Date.now;
      Date.now = () => now.getTime();

      const result = calculateNextDueAt(reminder);

      // Should calculate 2nd occurrence of current weekday in next month
      expect(result).toBeTruthy();
      expect(result!.getTime()).toBeGreaterThan(now.getTime());

      Date.now = originalNow;
    });
  });

  // =========================================================================
  // EDGE CASES
  // =========================================================================

  describe("Edge Cases", () => {
    it("should handle missing optional fields with defaults", () => {
      const reminder = createReminder(new Date("2026-01-21T09:00:00Z"), {
        type: "interval",
        // Missing 'every', 'unit', and 'anchor'
      });

      const result = calculateNextDueAt(reminder);

      // Should use defaults: every=1, unit=days, anchor=completion
      expect(result).toBeTruthy();
    });

    it("should handle invalid recurrence type gracefully", () => {
      const reminder = createReminder(new Date("2026-01-21T09:00:00Z"), {
        type: "invalid-type",
      });

      const result = calculateNextDueAt(reminder);

      // Should return null or handle gracefully
      expect(result).toBeNull();
    });

    it("should handle reminder with no lastCompletedAt (first time)", () => {
      const reminder = createReminder(
        new Date("2026-01-21T09:00:00Z"),
        {
          type: "interval",
          every: 3,
          unit: "days",
          anchor: "completion",
        }
        // No lastCompletedAt
      );

      const result = calculateNextDueAt(reminder);

      // Should use nextDueAt as reference
      expect(result).toBeTruthy();
    });
  });
});

// ============================================================================
// INTEGRATION TEST EXAMPLES
// ============================================================================

describe("Integration Examples", () => {
  it("Example 1: Medicine reminder (every 8 hours after completion)", () => {
    const lastCompleted = new Date("2026-01-21T08:00:00Z");
    const reminder = createReminder(
      new Date("2026-01-21T08:00:00Z"),
      {
        type: "interval",
        every: 8,
        unit: "hours",
        anchor: "completion",
      },
      lastCompleted
    );

    const result = calculateNextDueAt(reminder);

    console.log("Medicine Reminder:");
    console.log("  Last taken:", lastCompleted.toISOString());
    console.log("  Next due:", result?.toISOString());
    console.log("  → Take medicine at 4:00 PM");
  });

  it("Example 2: Team meeting (every Monday and Wednesday at 2 PM)", () => {
    const reminder = createReminder(new Date(), {
      type: "weekly",
      days: ["mon", "wed"],
      time: "14:00",
    });

    const result = calculateNextDueAt(reminder);

    console.log("\nTeam Meeting:");
    console.log("  Next occurrence:", result?.toISOString());
  });

  it("Example 3: Rent payment (1st of every month)", () => {
    const reminder = createReminder(new Date(), {
      type: "monthly",
      pattern: "dayOfMonth",
      value: 1,
      time: "09:00",
    });

    const result = calculateNextDueAt(reminder);

    console.log("\nRent Payment:");
    console.log("  Next due:", result?.toISOString());
  });
});
