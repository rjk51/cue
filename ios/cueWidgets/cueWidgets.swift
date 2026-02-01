//
//  cueWidgets.swift
//  cueWidgets
//
//  Created by Amritesh Kumar on 31/01/26.
//

import WidgetKit
import SwiftUI

// MARK: - 1. Theme Definition
// Using the specific colors you requested
struct AppTheme {
    static let primary = Color(hex: "FFAD87")        // Peach
    static let secondary = Color(hex: "C5A059")      // Gold
    static let surface = Color(hex: "2A262E")        // Dark Background
    static let surfaceHighlight = Color(hex: "352F3C") // Card Background
    static let onSurface = Color(hex: "FDFCF0")      // Text Color
}

struct ReminderData: Codable, Identifiable {
    let id: String
    let name: String
    let time: String
    let iconName: String
    let colorHex: String // We will ignore this for the theme consistency
    var priority: String?

    var isHighPriority: Bool {
        priority?.lowercased() == "high"
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
            return sampleReminders() // Fallback to sample if no data for testing
        }

        do {
            let reminders = try JSONDecoder().decode([ReminderData].self, from: data)
            return reminders
        } catch {
            return []
        }
    }

    func sampleReminders() -> [ReminderData] {
        return [
            ReminderData(id: "1", name: "Design Review", time: "10:00 AM", iconName: "paintbrush.fill", colorHex: "", priority: "high"),
            ReminderData(id: "2", name: "Team Sync", time: "11:30 AM", iconName: "person.2.fill", colorHex: "", priority: nil),
            ReminderData(id: "3", name: "Lunch", time: "1:00 PM", iconName: "fork.knife", colorHex: "", priority: nil),
            ReminderData(id: "4", name: "Client Call", time: "3:00 PM", iconName: "phone.fill", colorHex: "", priority: "high"),
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
        ZStack {
            // Main Background from Theme
            AppTheme.surface
            
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
        // This removes the default system padding/border in iOS 17+
        .containerBackground(AppTheme.surface, for: .widget)
    }
}

// MARK: - Small Widget
struct SmallWidgetView: View {
    let reminders: [ReminderData]

    var body: some View {
        VStack(alignment: .leading) {
            if let reminder = reminders.first {
                VStack(alignment: .leading, spacing: 0) {
                    // Header Icon
                    HStack {
                        Image(systemName: reminder.iconName)
                            .font(.system(size: 24))
                            .foregroundColor(reminder.isHighPriority ? AppTheme.primary : AppTheme.secondary)
                        Spacer()
                        
                        if reminder.isHighPriority {
                            Circle()
                                .fill(AppTheme.primary)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 12)

                    Spacer()

                    // Task Name
                    Text(reminder.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.onSurface)
                        .lineLimit(3)
                        .padding(.bottom, 4)

                    // Time
                    Text(reminder.time)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.onSurface.opacity(0.6))
                }
            } else {
                EmptyStateView()
            }
        }
        .padding()
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let reminders: [ReminderData]
    @State private var currentPage = 0
    
    private let itemsPerPage = 3
    private var totalPages: Int {
        max(1, Int(ceil(Double(reminders.count) / Double(itemsPerPage))))
    }
    
    private var currentPageReminders: [ReminderData] {
        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, reminders.count)
        guard startIndex < reminders.count else { return [] }
        return Array(reminders[startIndex..<endIndex])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Today")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text("\(reminders.count) Tasks")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.onSurface.opacity(0.5))
            }
            
            if reminders.isEmpty {
                EmptyStateView()
            } else {
                VStack(spacing: 8) {
                    ForEach(currentPageReminders) { reminder in
                        TaskRow(reminder: reminder)
                    }
                }
            }
            Spacer()
        }
        .padding()
        // Auto-cycle pages since we can't scroll
        .onAppear {
            if totalPages > 1 {
                Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
                    withAnimation {
                        currentPage = (currentPage + 1) % totalPages
                    }
                }
            }
        }
    }
}

// MARK: - Large Widget
struct LargeWidgetView: View {
    let reminders: [ReminderData]
    @State private var currentPage = 0
    
    private let itemsPerPage = 6 // Fits more on large
    private var totalPages: Int {
        max(1, Int(ceil(Double(reminders.count) / Double(itemsPerPage))))
    }
    
    private var currentPageReminders: [ReminderData] {
        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, reminders.count)
        guard startIndex < reminders.count else { return [] }
        return Array(reminders[startIndex..<endIndex])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date().formatted(.dateTime.weekday(.wide)))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.primary)
                        .textCase(.uppercase)
                    
                    Text(Date().formatted(.dateTime.day().month()))
                        .font(.system(size: 28, weight: .light, design: .rounded))
                        .foregroundColor(AppTheme.onSurface)
                }
                
                Spacer()
                
                // Page Dots
                if totalPages > 1 {
                    HStack(spacing: 4) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? AppTheme.primary : AppTheme.surfaceHighlight)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
            
            if reminders.isEmpty {
                EmptyStateView()
            } else {
                VStack(spacing: 8) {
                    ForEach(currentPageReminders) { reminder in
                        TaskRow(reminder: reminder)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .onAppear {
            if totalPages > 1 {
                Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
                    withAnimation {
                        currentPage = (currentPage + 1) % totalPages
                    }
                }
            }
        }
    }
}

// MARK: - Components

struct TaskRow: View {
    let reminder: ReminderData
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon Container
            ZStack {
                Circle()
                    .fill(AppTheme.surfaceHighlight.opacity(0.5)) // Slightly lighter than background
                    .frame(width: 32, height: 32)
                
                Image(systemName: reminder.iconName)
                    .font(.system(size: 14))
                    // Force the color to match theme, fixing the "green notification" issue
                    .foregroundColor(reminder.isHighPriority ? AppTheme.primary : AppTheme.secondary)
            }
            
            Text(reminder.name)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.onSurface)
                .lineLimit(1)
            
            Spacer()
            
            Text(reminder.time)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(AppTheme.onSurface.opacity(0.5))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.surfaceHighlight)
        )
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.secondary.opacity(0.5))
            
            Text("All Clear")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.onSurface.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Helpers
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
        }
        .configurationDisplayName("Cue Reminders")
        .description("View your upcoming reminders")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // This is crucial for removing the default system border
        .contentMarginsDisabled() 
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    cueWidgets()
} timeline: {
    SimpleEntry(date: .now, reminders: [
        ReminderData(id: "1", name: "Design Review", time: "10:00 AM", iconName: "paintbrush.fill", colorHex: "", priority: "high")
    ])
}

#Preview(as: .systemMedium) {
    cueWidgets()
} timeline: {
    SimpleEntry(date: .now, reminders: [
        ReminderData(id: "1", name: "Design Review", time: "10:00 AM", iconName: "paintbrush.fill", colorHex: "", priority: "high"),
        ReminderData(id: "2", name: "Team Sync", time: "11:30 AM", iconName: "person.3.fill", colorHex: "", priority: nil),
        ReminderData(id: "3", name: "Lunch", time: "1:00 PM", iconName: "fork.knife", colorHex: "", priority: nil),
    ])
}