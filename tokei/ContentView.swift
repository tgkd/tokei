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
  @State private var showTimeZoneList = false
  @State private var timeOffsetMinutes: Double = 0
  @State private var cameraResetTrigger = false

  var timeOffsetText: String {
    let hours = abs(Int(timeOffsetMinutes)) / 60
    let minutes = abs(Int(timeOffsetMinutes)) % 60
    let sign = timeOffsetMinutes >= 0 ? "+" : "-"
    return String(format: "%@%02d:%02d", sign, hours, minutes)
  }

  var body: some View {
    GeometryReader { _ in
      ZStack {
        EarthGlobeView(timeZones: timeZones, cameraResetTrigger: $cameraResetTrigger)
          .ignoresSafeArea()

        VStack {
          HStack {
            Button {
              cameraResetTrigger.toggle()
            } label: {
              Image(systemName: "location.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
            }
            .glassEffect(.regular, in: .circle)

            Spacer()

            Button {
              showTimeZoneList = true
            } label: {
              Image(systemName: "clock")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
            }
            .glassEffect(.regular, in: .circle)
          }
          .padding(.horizontal, 20)
          .padding(.top, 10)

          Spacer()

          HStack(spacing: 12) {
            Text(timeOffsetText)
              .font(.system(size: 14, weight: .medium, design: .monospaced))
              .foregroundColor(.white)
              .frame(width: 60)

            Slider(value: $timeOffsetMinutes, in: -1440...1440, step: 15)
              .onChange(of: timeOffsetMinutes) {
                updateTimeOffset(minutes: Int(timeOffsetMinutes))
              }

            Button(action: {
              resetTimeOffset()
            }) {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.gray)
                .opacity(timeOffsetMinutes == 0 ? 0.5 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(timeOffsetMinutes == 0)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .glassEffect(.regular, in: .capsule)
          .padding(.horizontal, 20)
          .padding(.bottom, 10)
        }
      }
    }
    .onAppear {
      loadTimeZones()
      loadTimeOffset()
    }
    .preferredColorScheme(.dark)
    .sheet(isPresented: $showTimeZoneList) {
      NavigationView {
        TimeZoneListView(timeZones: $timeZones)
      }
    }
  }

  private func loadTimeOffset() {
    timeOffsetMinutes = Double(UserDefaults.shared.integer(forKey: "time_offset_minutes"))
  }

  private func updateTimeOffset(minutes: Int) {
    UserDefaults.shared.set(minutes, forKey: "time_offset_minutes")
    WidgetCenter.shared.reloadTimelines(ofKind: "TokeiWidget")
  }

  private func resetTimeOffset() {
    timeOffsetMinutes = 0
    updateTimeOffset(minutes: 0)
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
