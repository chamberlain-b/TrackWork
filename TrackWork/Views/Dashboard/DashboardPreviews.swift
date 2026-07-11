import SwiftData
import SwiftUI

#Preview("Populated") {
    DashboardView()
        .modelContainer(PreviewData.modelContainer())
}

#Preview("Large text") {
    DashboardView()
        .modelContainer(PreviewData.modelContainer())
        .environment(\.dynamicTypeSize, .accessibility2)
}
