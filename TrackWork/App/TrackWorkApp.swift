import SwiftData
import SwiftUI

@main
struct TrackWorkApp: App {
    private let modelContainer = AppModelContainer.make()

    var body: some Scene {
        WindowGroup {
            AppRouter()
        }
        .modelContainer(modelContainer)
    }
}
