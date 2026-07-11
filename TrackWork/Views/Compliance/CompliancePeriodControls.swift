import SwiftUI

struct CompliancePeriodControls: View {
    @Binding var selectedPreset: CompliancePeriodPreset
    @Binding var customStart: Date
    @Binding var customEnd: Date

    let accessibilityPrefix: String

    var body: some View {
        Picker("Period", selection: $selectedPreset) {
            ForEach(CompliancePeriodPreset.allCases) { preset in
                Text(preset.displayName)
                    .tag(preset)
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("\(accessibilityPrefix).periodPreset")

        if selectedPreset == .custom {
            DatePicker(
                "Start date",
                selection: $customStart,
                displayedComponents: .date
            )
            .accessibilityIdentifier("\(accessibilityPrefix).customStartDate")
            .onChange(of: customStart) { _, newStart in
                if newStart > customEnd {
                    customEnd = newStart
                }
            }

            DatePicker(
                "End date",
                selection: $customEnd,
                displayedComponents: .date
            )
            .accessibilityIdentifier("\(accessibilityPrefix).customEndDate")
            .onChange(of: customEnd) { _, newEnd in
                if newEnd < customStart {
                    customStart = newEnd
                }
            }
        }
    }
}
