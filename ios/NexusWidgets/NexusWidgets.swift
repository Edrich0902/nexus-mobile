import SwiftUI
import WidgetKit

/// Must match `AppConfig.appGroupId` in lib/core/config/app_config.dart.
let nexusAppGroup = "group.app.nexus.nexusMobile"

private let store = UserDefaults(suiteName: nexusAppGroup)

private func value(_ key: String, _ fallback: String = "") -> String {
  let raw = store?.string(forKey: key) ?? ""
  return raw.trimmingCharacters(in: .whitespaces).isEmpty ? fallback : raw
}

private func link(_ path: String) -> URL {
  let safe = path.hasPrefix("/") && !path.hasPrefix("//") && !path.contains("..") ? path : "/home"
  return URL(string: "nexus://open\(safe)") ?? URL(string: "nexus://open/home")!
}

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255
    )
  }
}

/// Section "field" colours from tool/tokens.json.
enum FieldTone {
  case listening, f1, cellar, home

  var bg: Color {
    switch self {
    case .listening: Color(hex: 0x1ED760)
    case .f1: Color(hex: 0xD42218)
    case .cellar: Color(hex: 0x6B1A2B)
    case .home: Color(hex: 0x1A090D)
    }
  }

  var ink: Color {
    switch self {
    case .listening: Color(hex: 0x06150B)
    case .f1: Color(hex: 0xFFF4EF)
    case .cellar: Color(hex: 0xFFD9DE)
    case .home: Color(hex: 0xF6E8EA)
    }
  }
}

struct FieldEntry: TimelineEntry {
  let date: Date
  let eyebrow: String
  let title: String
  let sub: String
  let footer: String
  let path: String
}

/// Data is pushed by the app (home_widgets.dart); the timeline never polls.
struct FieldProvider: TimelineProvider {
  let read: () -> FieldEntry
  let sample: FieldEntry

  func placeholder(in context: Context) -> FieldEntry { sample }

  func getSnapshot(in context: Context, completion: @escaping (FieldEntry) -> Void) {
    completion(context.isPreview ? sample : read())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<FieldEntry>) -> Void) {
    completion(Timeline(entries: [read()], policy: .never))
  }
}

struct FieldView: View {
  let entry: FieldEntry
  let tone: FieldTone

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(entry.eyebrow.uppercased())
        .font(.system(size: 11, weight: .semibold))
        .tracking(0.9)
        .opacity(0.8)
        .lineLimit(1)
      Spacer(minLength: 0)
      Text(entry.title)
        .font(.system(size: 24, design: .serif))
        .lineLimit(2)
        .minimumScaleFactor(0.7)
      if !entry.sub.isEmpty {
        Text(entry.sub).font(.system(size: 13)).opacity(0.85).lineLimit(1)
      }
      if !entry.footer.isEmpty {
        Text(entry.footer).font(.system(size: 12, weight: .medium)).lineLimit(1)
      }
    }
    .foregroundStyle(tone.ink)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .widgetURL(link(entry.path))
    .nexusBackground(tone.bg)
  }
}

extension View {
  @ViewBuilder
  func nexusBackground(_ color: Color) -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(color, for: .widget)
    } else {
      padding().background(color)
    }
  }
}

// MARK: - Widgets (kinds must match homeWidgetKinds in home_widgets.dart)

struct ListeningWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: "NexusListening",
      provider: FieldProvider(
        read: {
          FieldEntry(
            date: .now,
            eyebrow: value("listening_state", "Listening"),
            title: value("listening_title", "Nothing playing"),
            sub: value("listening_artist"),
            footer: "",
            path: "/spotify"
          )
        },
        sample: FieldEntry(date: .now, eyebrow: "Playing", title: "Maria También", sub: "Khruangbin", footer: "", path: "/spotify")
      )
    ) { FieldView(entry: $0, tone: .listening) }
      .configurationDisplayName("Listening")
      .description("What is playing on Spotify right now.")
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct NextRaceWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: "NexusNextRace",
      provider: FieldProvider(
        read: {
          FieldEntry(
            date: .now,
            eyebrow: value("race_label", "Formula 1"),
            title: value("race_title", "Open Nexus to load the calendar"),
            sub: value("race_sub"),
            footer: value("race_when"),
            path: value("race_route", "/f1")
          )
        },
        sample: FieldEntry(
          date: .now, eyebrow: "Next race", title: "Singapore Grand Prix", sub: "Marina Bay · Singapore",
          footer: "Sun 4 Oct · 14:00", path: "/f1"
        )
      )
    ) { FieldView(entry: $0, tone: .f1) }
      .configurationDisplayName("Next race")
      .description("The next Formula 1 weekend, or the session that is live.")
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct TonightWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: "NexusTonight",
      provider: FieldProvider(
        read: {
          FieldEntry(
            date: .now,
            eyebrow: "Tonight",
            title: value("tonight_title", "Pick a bottle"),
            sub: value("tonight_sub"),
            footer: "",
            path: value("tonight_route", "/cellar")
          )
        },
        sample: FieldEntry(date: .now, eyebrow: "Tonight", title: "2019 Chryseia", sub: "Douro · Portugal", footer: "", path: "/cellar")
      )
    ) { FieldView(entry: $0, tone: .cellar) }
      .configurationDisplayName("Tonight")
      .description("A bottle from your cellar for this evening.")
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct QuickLogWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "NexusQuickLog", provider: QuickLogProvider()) { _ in
      VStack(alignment: .leading, spacing: 10) {
        Text("QUICK LOG").font(.system(size: 11, weight: .semibold)).tracking(0.9).opacity(0.8)
        Text("What are you having?").font(.system(size: 20, design: .serif))
        Spacer(minLength: 0)
        HStack(spacing: 6) {
          QuickLogPill(label: "Wine", path: "/capture?kind=wine")
          QuickLogPill(label: "Beer", path: "/capture?kind=beer")
          QuickLogPill(label: "Book", path: "/capture?kind=book&mode=barcode")
        }
      }
      .foregroundStyle(FieldTone.home.ink)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .nexusBackground(FieldTone.home.bg)
    }
    .configurationDisplayName("Quick log")
    .description("Jump straight into capture for a wine, beer or book.")
    .supportedFamilies([.systemMedium])
  }
}

private struct QuickLogPill: View {
  let label: String
  let path: String

  var body: some View {
    Link(destination: link(path)) {
      Text(label)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Color(hex: 0x0B2416))
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(Capsule().fill(Color(hex: 0x5ECF8A)))
    }
  }
}

private struct QuickLogProvider: TimelineProvider {
  struct Entry: TimelineEntry { let date: Date }
  func placeholder(in context: Context) -> Entry { Entry(date: .now) }
  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: .now)) }
  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    completion(Timeline(entries: [Entry(date: .now)], policy: .never))
  }
}

@main
struct NexusWidgetBundle: WidgetBundle {
  var body: some Widget {
    ListeningWidget()
    NextRaceWidget()
    TonightWidget()
    QuickLogWidget()
    F1LiveActivityWidget()
  }
}
