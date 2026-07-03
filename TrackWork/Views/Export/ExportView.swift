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
    @State private var generatedExportKind: ExportKind?
    @State private var generationError: String?

    private let calendar = Calendar.exportCalendar
    private let snapshotBuilder = ReportSnapshotBuilder()
    private let csvExportService = CSVExportService()
    private let pdfExportService = PDFExportService()

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
                        icon: "doc.richtext",
                        message: "Exports include monthly summary, daily records, leave, manual overrides, public holidays, and settings without raw location events or GPS coordinates.",
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

                            Toggle("Include notes in export", isOn: $includeNotes)
                                .tint(Color.ds.accentPrimary)

                            HStack(spacing: AppSpacing.sm) {
                                DSButton(
                                    title: "Generate PDF",
                                    systemImage: "doc.badge.plus",
                                    action: generatePDF
                                )

                                DSButton(
                                    title: "Generate CSV",
                                    systemImage: "tablecells.badge.ellipsis",
                                    action: generateCSV
                                )
                            }
                        }
                    }

                    if let generatedFileURL, let generatedFileName, let generatedExportKind {
                        DSCard {
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                Label(generatedFileName, systemImage: generatedExportKind.systemImage)
                                    .font(AppTypography.headline)
                                    .foregroundStyle(Color.ds.textPrimary)
                                    .lineLimit(2)

                                ShareLink(item: generatedFileURL) {
                                    Label("Share \(generatedExportKind.label)", systemImage: "square.and.arrow.up")
                                        .font(AppTypography.headline)
                                        .foregroundStyle(Color.ds.textInverse)
                                        .frame(maxWidth: .infinity)
                                        .frame(minHeight: 50)
                                        .background(Color.ds.accentPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                                }
                                .accessibilityLabel("Share \(generatedExportKind.label) report named \(generatedFileName)")
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

    private func generatePDF() {
        generateExport(kind: .pdf) { snapshot in
            try pdfExportService.writePDF(from: snapshot)
        }
    }

    private func generateCSV() {
        generateExport(kind: .csv) { snapshot in
            try csvExportService.writeCSV(from: snapshot)
        }
    }

    private func generateExport(kind: ExportKind, writeFile: (ReportSnapshot) throws -> URL) {
        do {
            generationError = nil
            let snapshot = try makeSnapshot()
            generatedFileURL = try writeFile(snapshot)
            generatedExportKind = kind
        } catch {
            generatedFileURL = nil
            generatedExportKind = nil
            generationError = "The \(kind.label) could not be generated for \(selectedMonthTitle)."
        }
    }

    private func makeSnapshot() throws -> ReportSnapshot {
        try snapshotBuilder.build(
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
    }

    private func clearGeneratedFile() {
        generatedFileURL = nil
        generatedExportKind = nil
        generationError = nil
    }
}

private enum ExportKind {
    case pdf
    case csv

    var label: String {
        switch self {
        case .pdf:
            "PDF"
        case .csv:
            "CSV"
        }
    }

    var systemImage: String {
        switch self {
        case .pdf:
            "doc.richtext"
        case .csv:
            "tablecells"
        }
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
