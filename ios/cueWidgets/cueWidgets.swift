//
//  cueWidgets.swift
//  cueWidgets
//
//  Created by Amritesh Kumar on 31/01/26.
//

import WidgetKit
import SwiftUI

struct ReminderData: Codable, Identifiable {
    let id: String
    let name: String
    let time: String
    let iconName: String
    let colorHex: String

    var color: Color {
        Color(hex: colorHex)
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), reminders: sampleReminders())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), reminders: loadReminders())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let reminders = loadReminders()
        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate, reminders: reminders)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    func loadReminders() -> [ReminderData] {
        guard let userDefaults = UserDefaults(suiteName: "group.com.cue.app"),
              let data = userDefaults.data(forKey: "todayReminders") else {
            print("⚠️ No data found in App Group")
            return []
        }

        do {
            let reminders = try JSONDecoder().decode([ReminderData].self, from: data)
            print("✅ Loaded \(reminders.count) reminders from App Group")
            return reminders
        } catch {
            print("❌ Failed to decode reminders: \(error)")
            return []
        }
    }

    func sampleReminders() -> [ReminderData] {
        return [
            ReminderData(id: "1", name: "Sample Reminder", time: "3:00 PM", iconName: "bell.fill", colorHex: "2D7A78")
        ]
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let reminders: [ReminderData]
}

struct cueWidgetsEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(reminders: entry.reminders)
        case .systemMedium:
            MediumWidgetView(reminders: entry.reminders)
        case .systemLarge:
            LargeWidgetView(reminders: entry.reminders)
        default:
            SmallWidgetView(reminders: entry.reminders)
        }
    }
}

struct SmallWidgetView: View {
    let reminders: [ReminderData]

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "4A4458"), Color(hex: "2D7A78")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                if let nextReminder = reminders.first {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: nextReminder.iconName)
                                .font(.system(size: 24))
                                .foregroundColor(nextReminder.color)
                            Spacer()
                        }

                        Text(nextReminder.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        Text(nextReminder.time)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                        Text("All caught up!")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding()
                }
            }
        }
    }
}

struct MediumWidgetView: View {
    let reminders: [ReminderData]

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "4A4458"), Color(hex: "2D7A78")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Today's Reminders")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text("\(reminders.count)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                if reminders.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.8))
                            Text("All caught up!")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                    }
                    Spacer()
                } else {
                    ForEach(reminders.prefix(3)) { reminder in
                        HStack(spacing: 12) {
                            Image(systemName: reminder.iconName)
                                .font(.system(size: 16))
                                .foregroundColor(reminder.color)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(reminder.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Text(reminder.time)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }

                Spacer()
            }
            .padding()
        }
    }
}

struct LargeWidgetView: View {
    let reminders: [ReminderData]

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "4A4458"), Color(hex: "2D7A78")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Today's Reminders")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(reminders.count)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                }

                if reminders.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.8))
                            Text("All caught up!")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Text("No reminders for today")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                    }
                    Spacer()
                } else {
                    ForEach(reminders.prefix(6)) { reminder in
                        HStack(spacing: 12) {
                            Image(systemName: reminder.iconName)
                                .font(.system(size: 18))
                                .foregroundColor(reminder.color)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(reminder.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Text(reminder.time)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                }

                Spacer()
            }
            .padding()
        }
    }
}

// Color extension to support hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct cueWidgets: Widget {
    let kind: String = "cueWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            cueWidgetsEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Cue Reminders")
        .description("View your upcoming reminders")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    cueWidgets()
} timeline: {
    SimpleEntry(date: .now, reminders: [
        ReminderData(id: "1", name: "Morning Workout", time: "8:00 AM", iconName: "figure.run", colorHex: "2D7A78")
    ])
    SimpleEntry(date: .now, reminders: [])
}
