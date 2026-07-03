import Foundation

struct CSVExportService {
    func makeCSV(from snapshot: ReportSnapshot) -> String {
        var lines: [String] = []

        appendSection("Summary", rows: summaryRows(from: snapshot), to: &lines)
        appendSection("Daily Records", rows: dailyRecordRows(from: snapshot), to: &lines)
        appendSection("Leave", rows: leaveRows(from: snapshot), to: &lines)
        appendSection("Manual Overrides and Notes", rows: manualOverrideAndNoteRows(from: snapshot), to: &lines)
        appendSection("Public Holidays", rows: publicHolidayRows(from: snapshot), to: &lines)
        appendSection("Settings", rows: settingsRows(from: snapshot), to: &lines)

        return lines.joined(separator: "\r\n") + "\r\n"
    }

    func writeCSV(
        from snapshot: ReportSnapshot,
        directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let fileURL = directory.appendingPathComponent(fileName(for: snapshot))
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data(makeCSV(from: snapshot).utf8))
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func fileName(for snapshot: ReportSnapshot) -> String {
        let monthIdentifier: String
        if let firstISODate = snapshot.dailyRecords.first?.isoDate {
            monthIdentifier = String(firstISODate.prefix(7))
        } else {
            monthIdentifier = monthFormatter.string(from: snapshot.summary.periodStart)
        }

        return "WorkTrack_\(monthIdentifier).csv"
    }

    private func appendSection(_ title: String, rows: [[String]], to lines: inout [String]) {
        if !lines.isEmpty {
            lines.append("")
        }

        lines.append(csvLine([title]))
        lines.append(contentsOf: rows.map(csvLine))
    }

    private func summaryRows(from snapshot: ReportSnapshot) -> [[String]] {
        let summary = snapshot.summary
        let leaveSummary = summary.leaveSummary

        return [
            ["Metric", "Value"],
            ["Period start", isoDateFormatter.string(from: summary.periodStart)],
            ["Period end", isoDateFormatter.string(from: summary.periodEnd)],
            ["Generated at", timestampFormatter.string(from: summary.generatedAt)],
            ["Base eligible days", summary.baseEligibleDays.formatted()],
            ["Adjusted eligible days", summary.adjustedEligibleDays.formatted()],
            ["Adjusted required office days", summary.adjustedRequiredOfficeDays.formatted()],
            ["Completed office days", summary.completedOfficeDays.formatted()],
            ["Review required days", summary.reviewRequiredDays.formatted()],
            ["Annual leave days", leaveSummary.annualLeaveDays.formatted()],
            ["Sick leave days", leaveSummary.sickLeaveDays.formatted()],
            ["Total leave days", leaveSummary.totalLeaveDays.formatted()]
        ]
    }

    private func dailyRecordRows(from snapshot: ReportSnapshot) -> [[String]] {
        var rows = [[
            "Date",
            "Detected status",
            "Final status",
            "Compliance treatment",
            "Office minutes",
            "Home minutes",
            "Selected workday",
            "Public holiday",
            "Leave",
            "Note"
        ]]

        rows += snapshot.dailyRecords.map { row in
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
        }

        return rows
    }

    private func leaveRows(from snapshot: ReportSnapshot) -> [[String]] {
        var rows = [["Date", "Type", "Duration", "Reduces eligible days", "Note"]]

        rows += snapshot.leaveRows.map { row in
            [
                row.isoDate,
                row.type.displayName,
                row.duration.displayName,
                yesNo(row.countsAgainstEligibleDay),
                note(row.note, in: snapshot)
            ]
        }

        return rows
    }

    private func manualOverrideAndNoteRows(from snapshot: ReportSnapshot) -> [[String]] {
        var rows = [["Date", "Record type", "Adjusted classification", "Reason", "Note source", "Note"]]

        rows += snapshot.manualAdjustmentRows.map { row in
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

        return rows
    }

    private func publicHolidayRows(from snapshot: ReportSnapshot) -> [[String]] {
        var rows = [["Date", "Name", "Country", "Jurisdiction", "Regional", "Source", "Source URL"]]

        rows += snapshot.publicHolidayRows.map { row in
            [
                row.isoDate,
                row.name,
                row.countryCode,
                row.jurisdictionId,
                yesNo(row.isRegional),
                row.sourceName,
                row.sourceURL ?? ""
            ]
        }

        return rows
    }

    private func settingsRows(from snapshot: ReportSnapshot) -> [[String]] {
        let rule = snapshot.ruleSummary

        return [
            ["Setting", "Value"],
            ["Rule name", rule.ruleName],
            ["Country", rule.countryCode],
            ["Jurisdiction", rule.jurisdictionId],
            ["Requirement type", rule.requirementType.displayName],
            ["Fixed required days", rule.fixedRequiredDays?.formatted() ?? ""],
            ["Required percentage", formattedPercentage(rule.requiredPercentage)],
            ["Prorate fixed target for leave", yesNo(rule.prorateFixedTargetForLeave)],
            ["Minimum office minutes", rule.minimumOfficeMinutes.formatted()],
            ["Selected ISO weekdays", rule.selectedISOWeekdays.map(String.init).joined(separator: " ")],
            ["Notes included", yesNo(snapshot.options.includeNotes)],
            ["Raw location events included", "No"],
            ["GPS coordinates included", "No"]
        ]
    }

    private func note(_ text: String?, in snapshot: ReportSnapshot) -> String {
        guard snapshot.options.includeNotes else {
            return ""
        }

        return text ?? ""
    }

    private func csvLine(_ fields: [String]) -> String {
        fields.map(escapedField).joined(separator: ",")
    }

    private func escapedField(_ field: String) -> String {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    private func formattedPercentage(_ value: Double?) -> String {
        guard let value else {
            return ""
        }

        return value.formatted(.percent.precision(.fractionLength(0...2)))
    }

    private var isoDateFormatter: DateFormatter {
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
