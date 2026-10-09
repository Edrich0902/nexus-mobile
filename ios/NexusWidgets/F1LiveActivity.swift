import ActivityKit
import SwiftUI
import WidgetKit

/// Shape required by the `live_activities` Flutter plugin: the payload lives
/// in the shared app group under `<activity id>_<key>`.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  public struct ContentState: Codable, Hashable {}

  var id = UUID()
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String { "\(id)_\(key)" }
}

private let shared = UserDefaults(suiteName: nexusAppGroup)!

/// Payload written by lib/features/f1/f1_live_activity.dart.
private struct F1Session {
  let title: String
  let session: String
  let circuit: String
  let startsAt: Date
  let endsAt: Date
  let route: String

  init(_ attributes: LiveActivitiesAppAttributes) {
    func text(_ key: String) -> String { shared.string(forKey: attributes.prefixedKey(key)) ?? "" }
    title = text("title")
    session = text("session")
    circuit = text("circuit")
    route = text("route")
    startsAt = Date(timeIntervalSince1970: shared.double(forKey: attributes.prefixedKey("startsAt")))
    endsAt = Date(timeIntervalSince1970: shared.double(forKey: attributes.prefixedKey("endsAt")))
  }

  var live: Bool { Date() >= startsAt }

  var url: URL { URL(string: "nexus://open\(route.hasPrefix("/") ? route : "/f1")")! }
}

private let raceRed = Color(hex: 0xD42218)
private let raceInk = Color(hex: 0xFFF4EF)

/// Counts down to lights-out, then up while the session runs. Both are
/// rendered by the system, so no pushes are needed to keep it current.
private struct SessionClock: View {
  let s: F1Session

  var body: some View {
    if s.live {
      Text(s.startsAt, style: .timer)
    } else {
      Text(timerInterval: Date()...max(Date(), s.startsAt), countsDown: true)
    }
  }
}

struct F1LiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      let s = F1Session(context.attributes)
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(s.live ? "\(s.session.uppercased()) · LIVE" : s.session.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.9)
            .opacity(0.85)
          Text(s.title).font(.system(size: 22, design: .serif)).lineLimit(1)
          if !s.circuit.isEmpty {
            Text(s.circuit).font(.system(size: 13)).opacity(0.85).lineLimit(1)
          }
        }
        Spacer(minLength: 8)
        SessionClock(s: s)
          .font(.system(size: 26, weight: .semibold).monospacedDigit())
          .multilineTextAlignment(.trailing)
          .frame(maxWidth: 110, alignment: .trailing)
      }
      .padding(16)
      .foregroundStyle(raceInk)
      .activityBackgroundTint(raceRed)
      .activitySystemActionForegroundColor(raceInk)
      .widgetURL(s.url)
    } dynamicIsland: { context in
      let s = F1Session(context.attributes)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text("F1").font(.system(size: 16, weight: .heavy)).foregroundStyle(raceRed)
        }
        DynamicIslandExpandedRegion(.trailing) {
          SessionClock(s: s).font(.system(size: 16, weight: .semibold).monospacedDigit())
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 2) {
            Text(s.title).font(.system(size: 17, design: .serif)).lineLimit(1)
            Text([s.session, s.circuit].filter { !$0.isEmpty }.joined(separator: " · "))
              .font(.system(size: 12))
              .opacity(0.8)
              .lineLimit(1)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      } compactLeading: {
        Text("F1").font(.system(size: 13, weight: .heavy)).foregroundStyle(raceRed)
      } compactTrailing: {
        SessionClock(s: s)
          .font(.system(size: 13, weight: .semibold).monospacedDigit())
          .frame(maxWidth: 52)
      } minimal: {
        Text("F1").font(.system(size: 12, weight: .heavy)).foregroundStyle(raceRed)
      }
      .widgetURL(s.url)
      .keylineTint(raceRed)
    }
  }
}
