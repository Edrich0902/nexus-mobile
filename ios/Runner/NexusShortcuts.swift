import AppIntents
import UIKit

/// Siri / Shortcuts / Spotlight actions. Each opens a `nexus://open/...`
/// link, which Flutter routes with the same paths as the web app.
@available(iOS 16.0, *)
private func openNexus(_ path: String) async {
  guard let url = URL(string: "nexus://open\(path)") else { return }
  await UIApplication.shared.open(url)
}

@available(iOS 16.0, *)
struct LogWineIntent: AppIntent {
  static var title: LocalizedStringResource = "Log a wine"
  static var description = IntentDescription("Open the Nexus camera ready to read a wine label.")
  static var openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    await openNexus("/capture?kind=wine")
    return .result()
  }
}

@available(iOS 16.0, *)
struct LogBeerIntent: AppIntent {
  static var title: LocalizedStringResource = "Log a beer"
  static var description = IntentDescription("Open the Nexus camera ready to read a beer label.")
  static var openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    await openNexus("/capture?kind=beer")
    return .result()
  }
}

@available(iOS 16.0, *)
struct ScanBookIntent: AppIntent {
  static var title: LocalizedStringResource = "Scan a book"
  static var description = IntentDescription("Scan a book barcode into your Nexus library.")
  static var openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    await openNexus("/capture?kind=book&mode=barcode")
    return .result()
  }
}

@available(iOS 16.0, *)
struct NexusShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: LogWineIntent(),
      phrases: ["Log a wine in \(.applicationName)", "Add a wine to \(.applicationName)"],
      shortTitle: "Log a wine",
      systemImageName: "wineglass"
    )
    AppShortcut(
      intent: LogBeerIntent(),
      phrases: ["Log a beer in \(.applicationName)"],
      shortTitle: "Log a beer",
      systemImageName: "mug"
    )
    AppShortcut(
      intent: ScanBookIntent(),
      phrases: ["Scan a book with \(.applicationName)"],
      shortTitle: "Scan a book",
      systemImageName: "barcode.viewfinder"
    )
  }
}
