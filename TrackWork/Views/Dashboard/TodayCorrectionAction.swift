import SwiftUI

struct TodayCorrectionAction: View {
    let presentation: TodayDashboardPresentation
    let onCorrectToday: () -> Void

    var body: some View {
        Button(action: onCorrectToday) {
            Label(presentation.correctionTitle, systemImage: "pencil")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ds.interactionPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(Color.ds.surfaceSecondary, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.ds.borderSubtle, lineWidth: 1)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(DSPressButtonStyle())
        .accessibilityHint("Opens today’s attendance editor")
        .accessibilityIdentifier("today.correct")
    }
}
