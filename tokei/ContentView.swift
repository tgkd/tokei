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
  @State private var showTimeZoneList = false

  let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    GeometryReader { _ in
      ZStack(alignment: .bottom) {
        EarthGlobeView(timeZones: timeZones)
          .ignoresSafeArea()

        VStack(spacing: 16) {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Current Time")
                .font(.caption)
                .foregroundColor(.gray)

              Text(currentTime, style: .time)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
              Text("Time Zones")
                .font(.caption)
                .foregroundColor(.gray)

              Text("\(timeZones.count)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            }
          }
          .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .glassEffect(.regular, in: .rect(cornerRadius: 28, style: .continuous))
        .onTapGesture {
          showTimeZoneList = true
        }
      }
    }
    .onReceive(timer) { _ in
      currentTime = Date()
    }
    .onAppear {
      loadTimeZones()
    }
    .preferredColorScheme(.dark)
    .sheet(isPresented: $showTimeZoneList) {
      NavigationView {
        TimeZoneListView(timeZones: $timeZones)
      }
    }
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
