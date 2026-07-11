import SwiftData
import SwiftUI

#Preview("Populated") {
    DashboardView(referenceDate: PreviewData.dashboardReferenceDate)
        .modelContainer(PreviewData.modelContainer())
}

#Preview("Dark") {
    DashboardView(referenceDate: PreviewData.dashboardReferenceDate)
        .modelContainer(PreviewData.modelContainer())
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    DashboardView(referenceDate: PreviewData.dashboardReferenceDate)
        .modelContainer(PreviewData.modelContainer())
        .environment(\.dynamicTypeSize, .accessibility5)
}
