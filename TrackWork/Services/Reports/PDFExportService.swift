import Foundation
import UIKit

struct PDFExportService {
    func makePDF(from snapshot: ReportSnapshot) -> Data {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Work Track Monthly Report",
            kCGPDFContextCreator as String: "Work Track"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: format)
        return renderer.pdfData { pdfContext in
            var context = PDFLayoutContext(pdfContext: pdfContext, pageBounds: pageBounds)
            context.beginPage()
            drawReport(snapshot, in: &context)
        }
    }

    func writePDF(
        from snapshot: ReportSnapshot,
        directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let fileURL = directory.appendingPathComponent(fileName(for: snapshot))
        try makePDF(from: snapshot).write(to: fileURL, options: .atomic)
        return fileURL
    }

    func fileName(for snapshot: ReportSnapshot) -> String {
        let monthIdentifier: String
        if let firstISODate = snapshot.dailyRecords.first?.isoDate {
            monthIdentifier = String(firstISODate.prefix(7))
        } else {
            monthIdentifier = monthFormatter.string(from: snapshot.summary.periodStart)
        }

        return "Work Track \(monthIdentifier) Monthly Report.pdf"
    }

    private func drawReport(_ snapshot: ReportSnapshot, in context: inout PDFLayoutContext) {
        let summary = snapshot.summary
        let rule = snapshot.ruleSummary

        context.drawTitle("Work Track Monthly Report")
        context.drawKeyValueRows([
            ("Period", "\(dateFormatter.string(from: summary.periodStart)) to \(dateFormatter.string(from: summary.periodEnd))"),
            ("Jurisdiction", "\(rule.countryCode) / \(rule.jurisdictionId)"),
            ("Generated", timestampFormatter.string(from: summary.generatedAt))
        ])

        context.drawSectionTitle("Compliance Result")
        context.drawMetricGrid([
            ("Completed office days", summary.completedOfficeDays.formatted()),
            ("Adjusted required office days", summary.adjustedRequiredOfficeDays.formatted()),
            ("Adjusted eligible days", summary.adjustedEligibleDays.formatted()),
            ("Review required days", summary.reviewRequiredDays.formatted())
        ])

        context.drawSectionTitle("Compliance Rule Summary")
        context.drawKeyValueRows([
            ("Rule", rule.ruleName),
            ("Requirement", requirementSummary(rule)),
            ("Minimum office minutes", rule.minimumOfficeMinutes.formatted()),
            ("Selected ISO weekdays", rule.selectedISOWeekdays.map(String.init).joined(separator: ", ")),
            ("Prorate fixed target for leave", yesNo(rule.prorateFixedTargetForLeave))
        ])

        context.drawSectionTitle("Business Day Calculation")
        context.drawKeyValueRows([
            ("Base eligible days", summary.baseEligibleDays.formatted()),
            ("Adjusted eligible days", summary.adjustedEligibleDays.formatted()),
            ("Adjusted required office days", summary.adjustedRequiredOfficeDays.formatted()),
            ("Public holiday exclusions", snapshot.publicHolidayRows.count.formatted()),
            ("Leave days reducing eligibility", summary.leaveSummary.totalLeaveDays.formatted())
        ])

        context.drawSectionTitle("Leave Summary")
        context.drawKeyValueRows([
            ("Annual leave days", summary.leaveSummary.annualLeaveDays.formatted()),
            ("Sick leave days", summary.leaveSummary.sickLeaveDays.formatted()),
            ("Total leave days", summary.leaveSummary.totalLeaveDays.formatted())
        ])
        context.drawTable(
            columns: ["Date", "Type", "Duration", "Reduces eligible days", "Note"],
            rows: snapshot.leaveRows.map { row in
                [
                    row.isoDate,
                    row.type.displayName,
                    row.duration.displayName,
                    yesNo(row.countsAgainstEligibleDay),
                    note(row.note, in: snapshot)
                ]
            },
            columnWidths: [0.15, 0.18, 0.18, 0.22, 0.27]
        )

        context.drawSectionTitle("Day-by-Day Table")
        context.drawTable(
            columns: ["Date", "Detected", "Final", "Treatment", "Office min", "Home min", "Workday", "Holiday", "Leave", "Note"],
            rows: snapshot.dailyRecords.map { row in
                [
                    row.isoDate,
                    row.detectedStatus.displayName,
                    row.finalStatus.displayName,
                    row.complianceTreatment.displayName,
                    row.officeMinutes.formatted(),
                    row.homeMinutes.formatted(),
                    yesNo(row.isSelectedWorkday),
                    yesNo(row.isPublicHoliday),
                    yesNo(row.hasLeave),
                    note(row.note, in: snapshot)
                ]
            },
            columnWidths: [0.11, 0.10, 0.11, 0.17, 0.08, 0.08, 0.08, 0.08, 0.07, 0.12]
        )

        context.drawSectionTitle("Manual Notes and Overrides")
        context.drawTable(
            columns: ["Date", "Record type", "Adjusted classification", "Reason", "Note source", "Note"],
            rows: manualRows(from: snapshot),
            columnWidths: [0.14, 0.16, 0.20, 0.18, 0.15, 0.17]
        )

        context.drawSectionTitle("Public Holiday Source Summary")
        context.drawTable(
            columns: ["Date", "Name", "Country", "Jurisdiction", "Regional", "Source", "Source URL"],
            rows: snapshot.publicHolidayRows.map { row in
                [
                    row.isoDate,
                    row.name,
                    row.countryCode,
                    row.jurisdictionId,
                    yesNo(row.isRegional),
                    row.sourceName,
                    row.sourceURL ?? ""
                ]
            },
            columnWidths: [0.13, 0.22, 0.09, 0.14, 0.10, 0.16, 0.16]
        )

        context.drawSectionTitle("Privacy Defaults")
        context.drawKeyValueRows([
            ("Notes included", yesNo(snapshot.options.includeNotes)),
            ("Raw location events included", "No"),
            ("GPS coordinates included", "No")
        ])
    }

    private func manualRows(from snapshot: ReportSnapshot) -> [[String]] {
        var rows = snapshot.manualAdjustmentRows.map { row in
            [
                row.isoDate,
                "Manual override",
                row.adjustedClassification.displayName,
                row.reason.displayName,
                "Manual adjustment",
                note(row.note, in: snapshot)
            ]
        }

        guard snapshot.options.includeNotes else {
            return rows
        }

        rows += snapshot.noteRows.map { row in
            [
                row.isoDate,
                "Note",
                "",
                "",
                row.source.displayName,
                row.text
            ]
        }

        return rows.sorted { lhs, rhs in
            lhs.first ?? "" < rhs.first ?? ""
        }
    }

    private func note(_ text: String?, in snapshot: ReportSnapshot) -> String {
        guard snapshot.options.includeNotes else {
            return ""
        }

        return text ?? ""
    }

    private func requirementSummary(_ rule: ReportSnapshot.RuleSummary) -> String {
        switch rule.requirementType {
        case .fixedMonthlyDays:
            let days = rule.fixedRequiredDays?.formatted() ?? "Not set"
            return "Fixed monthly days: \(days)"
        case .percentageOfEligibleDays:
            let percentage = rule.requiredPercentage?.formatted(.percent.precision(.fractionLength(0...2))) ?? "Not set"
            return "Percentage of eligible days: \(percentage)"
        }
    }

    private func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }

    private var timestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        return formatter
    }
}

private struct PDFLayoutContext {
    private let pdfContext: UIGraphicsPDFRendererContext
    private let pageBounds: CGRect
    private let contentInsets = UIEdgeInsets(top: 44, left: 42, bottom: 44, right: 42)
    private var y: CGFloat = 0

    init(pdfContext: UIGraphicsPDFRendererContext, pageBounds: CGRect) {
        self.pdfContext = pdfContext
        self.pageBounds = pageBounds
    }

    mutating func beginPage() {
        pdfContext.beginPage()
        y = contentInsets.top
    }

    mutating func drawTitle(_ text: String) {
        drawText(text, font: .boldSystemFont(ofSize: 24), color: .label, spacingAfter: 8)
    }

    mutating func drawSectionTitle(_ text: String) {
        ensureSpace(38)
        y += 10
        drawText(text, font: .boldSystemFont(ofSize: 15), color: .label, spacingAfter: 8)
    }

    mutating func drawKeyValueRows(_ rows: [(String, String)]) {
        for (key, value) in rows {
            let keyWidth = contentWidth * 0.34
            let valueWidth = contentWidth - keyWidth - 12
            let keyHeight = measuredHeight(key, font: .systemFont(ofSize: 9, weight: .semibold), width: keyWidth)
            let valueHeight = measuredHeight(value, font: .systemFont(ofSize: 10), width: valueWidth)
            let rowHeight = max(keyHeight, valueHeight) + 8
            ensureSpace(rowHeight)

            drawText(key, in: CGRect(x: contentInsets.left, y: y + 4, width: keyWidth, height: rowHeight), font: .systemFont(ofSize: 9, weight: .semibold), color: .secondaryLabel)
            drawText(value, in: CGRect(x: contentInsets.left + keyWidth + 12, y: y + 4, width: valueWidth, height: rowHeight), font: .systemFont(ofSize: 10), color: .label)
            y += rowHeight
        }

        y += 8
    }

    mutating func drawMetricGrid(_ metrics: [(String, String)]) {
        let gap: CGFloat = 10
        let tileWidth = (contentWidth - gap) / 2
        let tileHeight: CGFloat = 58

        for index in stride(from: 0, to: metrics.count, by: 2) {
            ensureSpace(tileHeight + 8)
            for column in 0..<2 {
                let metricIndex = index + column
                guard metricIndex < metrics.count else {
                    continue
                }

                let metric = metrics[metricIndex]
                let x = contentInsets.left + CGFloat(column) * (tileWidth + gap)
                let rect = CGRect(x: x, y: y, width: tileWidth, height: tileHeight)
                UIColor.secondarySystemBackground.setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: 8).fill()
                drawText(metric.1, in: rect.insetBy(dx: 10, dy: 8), font: .boldSystemFont(ofSize: 18), color: .label)
                drawText(metric.0, in: CGRect(x: rect.minX + 10, y: rect.minY + 32, width: rect.width - 20, height: 18), font: .systemFont(ofSize: 9, weight: .semibold), color: .secondaryLabel)
            }
            y += tileHeight + 8
        }

        y += 6
    }

    mutating func drawTable(columns: [String], rows: [[String]], columnWidths: [CGFloat]) {
        guard columns.count == columnWidths.count else {
            return
        }

        if rows.isEmpty {
            drawText("No records", font: .systemFont(ofSize: 10), color: .secondaryLabel, spacingAfter: 10)
            return
        }

        drawTableHeader(columns: columns, columnWidths: columnWidths)
        for row in rows {
            drawTableRow(row, columns: columns, columnWidths: columnWidths)
        }

        y += 8
    }

    private mutating func drawTableHeader(columns: [String], columnWidths: [CGFloat]) {
        let rowHeight: CGFloat = 24
        ensureSpace(rowHeight)
        let rect = CGRect(x: contentInsets.left, y: y, width: contentWidth, height: rowHeight)
        UIColor.systemGray5.setFill()
        UIBezierPath(rect: rect).fill()
        drawCells(columns, columnWidths: columnWidths, rowHeight: rowHeight, font: .systemFont(ofSize: 7, weight: .semibold), color: .label)
        y += rowHeight
    }

    private mutating func drawTableRow(_ row: [String], columns: [String], columnWidths: [CGFloat]) {
        let values = Array(row.prefix(columns.count)) + Array(repeating: "", count: max(0, columns.count - row.count))
        let rowHeight = min(maxTableRowHeight, max(22, measuredRowHeight(values, columnWidths: columnWidths) + 8))

        if availableHeight < rowHeight {
            beginPage()
            drawTableHeader(columns: columns, columnWidths: columnWidths)
        }

        UIColor.systemBackground.setFill()
        UIRectFill(CGRect(x: contentInsets.left, y: y, width: contentWidth, height: rowHeight))
        UIColor.separator.setStroke()
        UIBezierPath(rect: CGRect(x: contentInsets.left, y: y, width: contentWidth, height: rowHeight)).stroke()
        drawCells(values, columnWidths: columnWidths, rowHeight: rowHeight, font: .systemFont(ofSize: 7), color: .label)
        y += rowHeight
    }

    private mutating func drawCells(_ values: [String], columnWidths: [CGFloat], rowHeight: CGFloat, font: UIFont, color: UIColor) {
        var x = contentInsets.left
        for (index, value) in values.enumerated() {
            let width = contentWidth * columnWidths[index]
            let rect = CGRect(x: x + 3, y: y + 4, width: width - 6, height: rowHeight - 8)
            drawText(value, in: rect, font: font, color: color)
            x += width
        }
    }

    private mutating func drawText(_ text: String, font: UIFont, color: UIColor, spacingAfter: CGFloat) {
        let height = measuredHeight(text, font: font, width: contentWidth)
        ensureSpace(height + spacingAfter)
        drawText(text, in: CGRect(x: contentInsets.left, y: y, width: contentWidth, height: height), font: font, color: color)
        y += height + spacingAfter
    }

    private func drawText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .left
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine], attributes: attributes, context: nil)
    }

    private func measuredRowHeight(_ values: [String], columnWidths: [CGFloat]) -> CGFloat {
        zip(values, columnWidths).map { value, ratio in
            measuredHeight(value, font: .systemFont(ofSize: 7), width: contentWidth * ratio - 6)
        }.max() ?? 0
    }

    private func measuredHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let rect = NSString(string: text).boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(rect.height)
    }

    private mutating func ensureSpace(_ height: CGFloat) {
        if availableHeight < height {
            beginPage()
        }
    }

    private var contentWidth: CGFloat {
        pageBounds.width - contentInsets.left - contentInsets.right
    }

    private var availableHeight: CGFloat {
        pageBounds.height - contentInsets.bottom - y
    }

    private var maxTableRowHeight: CGFloat {
        64
    }
}

private extension ReportSnapshot.NoteRow.Source {
    var displayName: String {
        switch self {
        case .attendanceDay:
            "Attendance day"
        case .leave:
            "Leave"
        case .manualAdjustment:
            "Manual adjustment"
        }
    }
}
