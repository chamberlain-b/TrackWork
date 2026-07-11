import SwiftData
import SwiftUI

struct ExportView: View {
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \ManualAdjustment.createdAt) private var manualAdjustments: [ManualAdjustment]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date) private var customExcludedDays: [CustomExcludedDay]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    @State private var selectedPeriod: CompliancePeriodPreset = .currentMonth
    @State private var customRangeStart = Date.now
    @State private var customRangeEnd = Date.now
    @State private var includeNotes = true
    @State private var generatedFileURL: URL?
    @State private var generatedExportKind: ExportKind?
    @State private var generationError: String?

    private let usesNavigationStack: Bool
    private let calendar = Calendar.exportCalendar
    private let snapshotBuilder = ReportSnapshotBuilder()
    private let csvExportService = CSVExportService()
    private let pdfExportService = PDFExportService()
    private let generatedExportStore = GeneratedExportStore()

    init(usesNavigationStack: Bool = true) {
        self.usesNavigationStack = usesNavigationStack
    }

    private var activeRule: ComplianceRule {
        complianceRules.first ?? ComplianceRule()
    }

    private var selectedRange: ComplianceDateRange {
        selectedPeriod.dateRange(
            calendar: calendar,
            now: .now,
            customStart: customRangeStart,
            customEnd: customRangeEnd
        )
    }

    private var selectedRangeTitle: String {
        let start = selectedRange.start.formatted(.dateTime.day().month(.abbreviated).year())
        let end = selectedRange.end.formatted(.dateTime.day().month(.abbreviated).year())
        return start == end ? start : "\(start) – \(end)"
    }

    private var generatedFileName: String? {
        generatedFileURL?.lastPathComponent
    }

    var body: some View {
        Group {
            if usesNavigationStack {
                NavigationStack {
                    screenContent
                }
            } else {
                screenContent
            }
        }
    }

    private var screenContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                DSInsightCallout(
                    icon: "doc.richtext",
                    message: "Exports include an inclusive period summary, daily records, leave, custom exclusions, "
                        + "manual overrides, active-jurisdiction public holidays, and settings without raw location "
                        + "events or GPS coordinates.",
                    highlightedText: selectedRangeTitle
                )

                DSCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Report options")
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(Color.ds.textPrimary)

                        CompliancePeriodControls(
                            selectedPreset: $selectedPeriod,
                            customStart: $customRangeStart,
                            customEnd: $customRangeEnd,
                            accessibilityPrefix: "export"
                        )

                        Label(selectedRangeTitle, systemImage: "calendar")
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.ds.textSecondary)
                            .accessibilityIdentifier("export.periodRange")

                        Label("Using \(activeRule.name)", systemImage: "checkmark.seal")
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.ds.textSecondary)
                            .accessibilityIdentifier("export.savedRule")

                        Toggle("Include notes in export", isOn: $includeNotes)
                            .tint(Color.ds.accentPrimary)
                            .accessibilityIdentifier("export.includeNotes")

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: AppSpacing.sm) {
                                generatePDFButton
                                generateCSVButton
                            }

                            VStack(spacing: AppSpacing.sm) {
                                generatePDFButton
                                generateCSVButton
                            }
                        }

                        Text(
                            "Generated report files are temporary and are removed when you leave this screen. "
                                + "Copies you share are controlled by the destination you choose."
                        )
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                    }
                }
                .accessibilityIdentifier("export.reportOptions")

                if let generatedFileURL, let generatedFileName, let generatedExportKind {
                    DSCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label(generatedFileName, systemImage: generatedExportKind.systemImage)
                                .font(AppTypography.headline)
                                .foregroundStyle(Color.ds.textPrimary)
                                .lineLimit(2)
                                .accessibilityIdentifier("export.generatedFile")

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
                            .accessibilityIdentifier("export.share")
                        }
                    }
                }

                if let generationError {
                    DSInsightCallout(
                        icon: "exclamationmark.triangle",
                        message: generationError,
                        highlightedText: "Export failed"
                    )
                    .accessibilityIdentifier("export.error")
                }
            }
            .padding(AppSpacing.lg)
        }
        .appScreenBackground()
        .navigationTitle("Export")
        .onAppear {
            try? generatedExportStore.removeAllFiles()
        }
        .onChange(of: selectedPeriod) { _, _ in
            clearGeneratedFile()
        }
        .onChange(of: customRangeStart) { _, _ in
            clearGeneratedFile()
        }
        .onChange(of: customRangeEnd) { _, _ in
            clearGeneratedFile()
        }
        .onChange(of: includeNotes) { _, _ in
            clearGeneratedFile()
        }
        .onDisappear {
            clearGeneratedFile()
        }
    }

    private var generatePDFButton: some View {
        DSButton(
            title: "Generate PDF",
            systemImage: "doc.badge.plus",
            action: generatePDF
        )
        .accessibilityIdentifier("export.generatePDF")
    }

    private var generateCSVButton: some View {
        DSButton(
            title: "Generate CSV",
            systemImage: "tablecells.badge.ellipsis",
            action: generateCSV
        )
        .accessibilityIdentifier("export.generateCSV")
    }

    private func generatePDF() {
        generateExport(kind: .pdf) { snapshot in
            try pdfExportService.writePDF(
                from: snapshot,
                generatedExportStore: generatedExportStore
            )
        }
    }

    private func generateCSV() {
        generateExport(kind: .csv) { snapshot in
            try csvExportService.writeCSV(
                from: snapshot,
                generatedExportStore: generatedExportStore
            )
        }
    }

    private func generateExport(kind: ExportKind, writeFile: (ReportSnapshot) throws -> URL) {
        clearGeneratedFile()

        do {
            let snapshot = try makeSnapshot()
            generatedFileURL = try writeFile(snapshot)
            generatedExportKind = kind
        } catch {
            generatedFileURL = nil
            generatedExportKind = nil
            generationError = "The \(kind.label) could not be generated for \(selectedRangeTitle)."
        }
    }

    private func makeSnapshot() throws -> ReportSnapshot {
        try snapshotBuilder.build(
            ReportSnapshotBuilder.Input(
                range: selectedRange,
                calendar: calendar,
                rule: activeRule,
                attendanceDays: attendanceDays,
                leaveRecords: leaveRecords,
                manualAdjustments: manualAdjustments,
                publicHolidays: publicHolidays,
                customExcludedDays: customExcludedDays,
                options: ReportSnapshot.Options(includeNotes: includeNotes),
                generatedAt: .now
            )
        )
    }

    private func clearGeneratedFile() {
        if let generatedFileURL {
            try? generatedExportStore.removeFile(at: generatedFileURL)
        }

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
}

#Preview {
    ExportView()
        .modelContainer(PreviewData.modelContainer())
}
