//
//  cueWidgetsLiveActivity.swift
//  cueWidgets
//
//  Created by Amritesh Kumar on 31/01/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct cueWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct cueWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: cueWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension cueWidgetsAttributes {
    fileprivate static var preview: cueWidgetsAttributes {
        cueWidgetsAttributes(name: "World")
    }
}

extension cueWidgetsAttributes.ContentState {
    fileprivate static var smiley: cueWidgetsAttributes.ContentState {
        cueWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: cueWidgetsAttributes.ContentState {
         cueWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: cueWidgetsAttributes.preview) {
   cueWidgetsLiveActivity()
} contentStates: {
    cueWidgetsAttributes.ContentState.smiley
    cueWidgetsAttributes.ContentState.starEyes
}
