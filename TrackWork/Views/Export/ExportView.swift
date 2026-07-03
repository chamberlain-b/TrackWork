import SwiftData
import SwiftUI

struct ExportView: View {
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \ManualAdjustment.createdAt) private var manualAdjustments: [ManualAdjustment]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    @State private var selectedMonth = Date.now
    @State private var includeNotes = true
    @State private var generatedFileURL: URL?
    @State private var generationError: String?

    private let calendar = Calendar.exportCalendar
    private let snapshotBuilder = ReportSnapshotBuilder()
    private let csvExportService = CSVExportService()

    private var activeRule: ComplianceRule {
        complianceRules.first ?? ComplianceRule()
    }

    private var selectedMonthStart: Date {
        calendar.monthStart(for: selectedMonth)
    }

    private var selectedMonthTitle: String {
        selectedMonthStart.formatted(.dateTime.month(.wide).year())
    }

    private var generatedFileName: String? {
        generatedFileURL?.lastPathComponent
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    DSInsightCallout(
                        icon: "tablecells",
                        message: "CSV exports include monthly summary, daily records, leave, manual overrides, public holidays, and settings.",
                        highlightedText: selectedMonthTitle
                    )

                    DSCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("Report options")
                                .font(AppTypography.cardTitle)
                                .foregroundStyle(Color.ds.textPrimary)

                            DatePicker(
                                "Selected month",
                                selection: $selectedMonth,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)

                            Toggle("Include notes", isOn: $includeNotes)
                                .tint(Color.ds.accentPrimary)

                            DSButton(
                                title: "Generate CSV",
                                systemImage: "doc.badge.plus",
                                action: generateCSV
                            )
                        }
                    }

                    if let generatedFileURL, let generatedFileName {
                        DSCard {
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                Label(generatedFileName, systemImage: "doc.text")
                                    .font(AppTypography.headline)
                                    .foregroundStyle(Color.ds.textPrimary)
                                    .lineLimit(2)

                                ShareLink(item: generatedFileURL) {
                                    Label("Share CSV", systemImage: "square.and.arrow.up")
                                        .font(AppTypography.headline)
                                        .foregroundStyle(Color.ds.textInverse)
                                        .frame(maxWidth: .infinity)
                                        .frame(minHeight: 50)
                                        .background(Color.ds.accentPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                                }
                            }
                        }
                    }

                    if let generationError {
                        DSInsightCallout(
                            icon: "exclamationmark.triangle",
                            message: generationError,
                            highlightedText: "Export failed"
                        )
                    }
                }
                .padding(AppSpacing.lg)
            }
            .appScreenBackground()
            .navigationTitle("Export")
            .onChange(of: selectedMonth) { _, _ in
                clearGeneratedFile()
            }
            .onChange(of: includeNotes) { _, _ in
                clearGeneratedFile()
            }
        }
    }

    private func generateCSV() {
        do {
            generationError = nil
            let snapshot = try snapshotBuilder.build(
                ReportSnapshotBuilder.Input(
                    month: selectedMonthStart,
                    calendar: calendar,
                    rule: activeRule,
                    attendanceDays: attendanceDays,
                    leaveRecords: leaveRecords,
                    manualAdjustments: manualAdjustments,
                    publicHolidays: publicHolidays.filter { $0.jurisdictionId == activeRule.jurisdictionId },
                    options: ReportSnapshot.Options(includeNotes: includeNotes),
                    generatedAt: .now
                )
            )
            generatedFileURL = try csvExportService.writeCSV(from: snapshot)
        } catch {
            generatedFileURL = nil
            generationError = "The CSV could not be generated for \(selectedMonthTitle)."
        }
    }

    private func clearGeneratedFile() {
        generatedFileURL = nil
        generationError = nil
    }
}

private extension Calendar {
    static var exportCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }

    func monthStart(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }
}

#Preview {
    ExportView()
        .modelContainer(PreviewData.modelContainer())
}
