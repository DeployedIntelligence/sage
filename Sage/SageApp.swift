import SwiftUI

@main
struct SageApp: App {

    init() {
        openDatabase()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    // MARK: - Private

    private func openDatabase() {
        do {
            try DatabaseService.shared.open()
        } catch {
            // In production this would surface a user-facing error.
            // For now we log and let the app degrade gracefully.
            print("[SageApp] Failed to open database: \(error.localizedDescription)")
        }
    }
}
