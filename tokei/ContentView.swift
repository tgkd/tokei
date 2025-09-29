//
//  ContentView.swift
//  tokei
//
//  Created by P on 9/9/25.
//

import SwiftUI
import WidgetKit

struct ContentView: View {
  @State private var timeZones: [TimeZoneInfo] = []
  @State private var currentTime = Date()

  let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    NavigationView {
      GeometryReader { _ in
        ZStack {
          Color(UIColor.systemBackground)
            .ignoresSafeArea()

          VStack(spacing: 0) {
            EarthGlobeView()
              .frame(maxWidth: .infinity)
              .frame(maxHeight: .infinity)

            VStack(spacing: 16) {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text("Current Time")
                    .font(.caption)
                    .foregroundColor(.secondary)

                  Text(currentTime, style: .time)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                  Text("Time Zones")
                    .font(.caption)
                    .foregroundColor(.secondary)

                  Text("\(timeZones.count)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.blue)
                }
              }
              .padding(.horizontal, 20)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
      }
      .onReceive(timer) { _ in
        currentTime = Date()
      }
      .onAppear {
        loadTimeZones()
      }
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          NavigationLink(destination: TimeZoneListView(timeZones: $timeZones)) {
            Image(systemName: "list.bullet")
              .font(.system(size: 18, weight: .medium))
          }
        }
      }
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }

  private func loadTimeZones() {
    guard let data = UserDefaults.shared.data(forKey: "saved_timezones"),
      let savedTimeZones = try? JSONDecoder().decode([TimeZoneInfo].self, from: data)
    else {
      timeZones = Array(TimeZoneInfo.defaultTimeZones.prefix(3))
      return
    }
    timeZones = savedTimeZones
  }
}

extension UserDefaults {
  static let shared = UserDefaults(suiteName: "group.tokei.widget")!
}

#Preview {
  ContentView()
}
