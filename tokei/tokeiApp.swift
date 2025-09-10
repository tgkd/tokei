//
//  tokeiApp.swift
//  tokei
//
//  Created by P on 9/9/25.
//

import SwiftUI
import WidgetKit

@main
struct tokeiApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }
    
    private func handleURL(_ url: URL) {
        guard url.scheme == "tokei" else { return }
        
        switch url.host {
        case "main":
            break
        case "timezones", "manage":
            break
        default:
            break
        }
        
        WidgetCenter.shared.reloadTimelines(ofKind: "TokeiWidget")
    }
}
