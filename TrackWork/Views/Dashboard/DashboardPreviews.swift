import SwiftData
import SwiftUI

#Preview("Plan confidence") {
    DashboardView(referenceDate: PreviewData.planConfidenceReferenceDate)
        .modelContainer(PreviewData.planConfidenceModelContainer())
}

#Preview("Plan confidence largest text") {
    DashboardView(referenceDate: PreviewData.planConfidenceReferenceDate)
        .modelContainer(PreviewData.planConfidenceModelContainer())
        .environment(\.dynamicTypeSize, .accessibility5)
}

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
