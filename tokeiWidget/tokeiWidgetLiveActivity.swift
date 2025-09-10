//
//  tokeiWidgetLiveActivity.swift
//  tokeiWidget
//
//  Created by P on 9/9/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct tokeiWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct tokeiWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: tokeiWidgetAttributes.self) { context in
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

extension tokeiWidgetAttributes {
    fileprivate static var preview: tokeiWidgetAttributes {
        tokeiWidgetAttributes(name: "World")
    }
}

extension tokeiWidgetAttributes.ContentState {
    fileprivate static var smiley: tokeiWidgetAttributes.ContentState {
        tokeiWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: tokeiWidgetAttributes.ContentState {
         tokeiWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: tokeiWidgetAttributes.preview) {
   tokeiWidgetLiveActivity()
} contentStates: {
    tokeiWidgetAttributes.ContentState.smiley
    tokeiWidgetAttributes.ContentState.starEyes
}
