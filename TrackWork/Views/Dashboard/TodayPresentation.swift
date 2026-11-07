import Foundation

struct TodayDashboardPresentation {
    let date: Date
    let status: TodayStatusPresentation
    let weekDays: [TodayWeekdayPresentation]
    let completedOfficeDays: Int
    let requiredOfficeDays: Int
    let remainingOfficeDays: Int
    let reviewCount: Int
    let targetIsConfigured: Bool
    let monthlyAttendanceMix: AttendanceMix?

    var targetProgress: Double {
        guard requiredOfficeDays > 0 else {
            return 0
        }

        return min(1, max(0, Double(completedOfficeDays) / Double(requiredOfficeDays)))
    }

    var runwayTitle: String {
        guard targetIsConfigured else {
            return "Set your office target"
        }

        if remainingOfficeDays == 0 {
            return "Monthly target met"
        }

        return remainingOfficeDays == 1
            ? "1 office day to go"
            : "\(remainingOfficeDays) office days to go"
    }

    var progressDetail: String {
        guard targetIsConfigured else {
            return "Choose a target in Settings"
        }

        return "\(completedOfficeDays) of \(requiredOfficeDays) office days recorded"
    }

    var recordedWorkdayShare: String {
        monthlyAttendanceMix?.officeShare?.formatted(.percent.precision(.fractionLength(0))) ?? "—"
    }

    var recordedWorkdayDetail: String {
        guard let mix = monthlyAttendanceMix else {
            return "Monthly share unavailable"
        }
        guard mix.totalDays > 0 else {
            return "No recorded workdays yet"
        }
        return "of recorded workdays · \(mix.officeDays) of \(mix.totalDays)"
    }

    var correctionTitle: String {
        switch status.kind {
        case .notRecorded, .planned:
            "Record today"
        case .publicHoliday, .annualLeave, .sickLeave, .excluded, .notRequired:
            "Review today"
        case .office, .home, .mixed, .needsReview:
            "Correct today"
        }
    }
}

struct TodayStatusPresentation {
    let kind: TodayStatusKind
    let title: String
    let source: String
    let systemImage: String
}

enum TodayStatusKind: Equatable {
    case office
    case home
    case mixed
    case annualLeave
    case sickLeave
    case publicHoliday
    case excluded
    case planned
    case needsReview
    case notRequired
    case notRecorded
}

struct TodayWeekdayPresentation: Identifiable {
    let date: Date
    let weekday: String
    let dayNumber: String
    let statusLabel: String
    let systemImage: String?
    let colorRole: TodayStatusKind
    let isToday: Bool

    var id: Date { date }
}

struct TodayDaySelection: Identifiable {
    let date: Date

    var id: Date { date }
}

struct TodayPresentationBuilder {
    struct Input {
        let referenceDate: Date
        let calendar: Calendar
        let summary: ComplianceSummary
        let attendanceDays: [AttendanceDay]
        let leaveRecords: [LeaveRecord]
        let publicHolidays: [PublicHoliday]
        let customExcludedDays: [CustomExcludedDay]
        let plannedOfficeDays: [PlannedOfficeDay]
        let selectedISOWeekdays: Set<Int>
        let jurisdictionId: String
        let targetIsConfigured: Bool
        let monthlyAttendanceMix: AttendanceMix?
    }

    func makePresentation(_ input: Input) -> TodayDashboardPresentation {
        let date = input.calendar.startOfDay(for: input.referenceDate)
        let weekDates = datesInWeek(containing: date, calendar: input.calendar)
        let weekDays = weekDates.map { weekdayPresentation(for: $0, input: input) }
        let today = weekDays.first { input.calendar.isDate($0.date, inSameDayAs: date) }
            ?? weekdayPresentation(for: date, input: input)

        return TodayDashboardPresentation(
            date: date,
            status: TodayStatusPresentation(
                kind: today.colorRole,
                title: statusTitle(for: today.colorRole),
                source: statusSource(for: date, input: input),
                systemImage: today.systemImage ?? defaultSystemImage(for: today.colorRole)
            ),
            weekDays: weekDays,
            completedOfficeDays: input.summary.completedOfficeDays,
            requiredOfficeDays: input.summary.requiredOfficeDays,
            remainingOfficeDays: input.summary.officeDaysNeeded,
            reviewCount: input.summary.reviewRequiredDays,
            targetIsConfigured: input.targetIsConfigured,
            monthlyAttendanceMix: input.monthlyAttendanceMix
        )
    }
}

private extension TodayPresentationBuilder {
    func datesInWeek(containing date: Date, calendar: Calendar) -> [Date] {
        let normalizedDate = calendar.startOfDay(for: date)
        let mondayOffset = calendar.mondayBasedWeekdayIndex(for: normalizedDate)
        guard let weekStart = calendar.date(byAdding: .day, value: -mondayOffset, to: normalizedDate) else {
            return [normalizedDate]
        }

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    func weekdayPresentation(
        for date: Date,
        input: Input
    ) -> TodayWeekdayPresentation {
        let attendanceDay = first(on: date, in: input.attendanceDays, calendar: input.calendar)
        let leaveRecord = first(on: date, in: input.leaveRecords, calendar: input.calendar)
        let publicHoliday = ActiveJurisdictionHolidayResolver.holiday(
            on: date,
            from: input.publicHolidays,
            jurisdictionId: input.jurisdictionId,
            calendar: input.calendar
        )
        let customExcludedDay = first(
            on: date,
            in: input.customExcludedDays,
            calendar: input.calendar
        )
        let plannedOfficeDay = first(
            on: date,
            in: input.plannedOfficeDays,
            calendar: input.calendar
        )
        let calendarPresentation = CalendarDayPresentation(
            date: date,
            attendanceDay: attendanceDay,
            leaveRecord: leaveRecord,
            publicHoliday: publicHoliday,
            customExcludedDay: customExcludedDay,
            plannedOfficeDay: plannedOfficeDay,
            selectedISOWeekdays: input.selectedISOWeekdays,
            calendar: input.calendar,
            referenceDate: input.referenceDate
        )

        return TodayWeekdayPresentation(
            date: input.calendar.startOfDay(for: date),
            weekday: date.formatted(.dateTime.weekday(.abbreviated)),
            dayNumber: date.formatted(.dateTime.day()),
            statusLabel: calendarPresentation.label,
            systemImage: calendarPresentation.systemImage,
            colorRole: statusKind(for: calendarPresentation.kind),
            isToday: input.calendar.isDate(date, inSameDayAs: input.referenceDate)
        )
    }

    // Exhaustive UI mappings are intentionally flat and easier to audit as switches.
    // swiftlint:disable cyclomatic_complexity
    func statusKind(for kind: CalendarDayPresentation.Kind) -> TodayStatusKind {
        switch kind {
        case .office:
            .office
        case .home:
            .home
        case .mixed:
            .mixed
        case .annualLeave:
            .annualLeave
        case .sickLeave:
            .sickLeave
        case .publicHoliday:
            .publicHoliday
        case .excluded:
            .excluded
        case .planned:
            .planned
        case .review:
            .needsReview
        case .notRequired:
            .notRequired
        case .upcoming:
            .notRecorded
        }
    }

    func statusTitle(for kind: TodayStatusKind) -> String {
        switch kind {
        case .office:
            "Office"
        case .home:
            "Home"
        case .mixed:
            "Mixed"
        case .annualLeave:
            "Annual leave"
        case .sickLeave:
            "Sick leave"
        case .publicHoliday:
            "Public holiday"
        case .excluded:
            "Excluded"
        case .planned:
            "Office planned"
        case .needsReview:
            "Needs review"
        case .notRequired:
            "Not a workday"
        case .notRecorded:
            "Not recorded"
        }
    }

    func defaultSystemImage(for kind: TodayStatusKind) -> String {
        switch kind {
        case .office:
            "building.2.fill"
        case .home:
            "house.fill"
        case .mixed:
            "arrow.left.arrow.right"
        case .annualLeave:
            "sun.max.fill"
        case .sickLeave:
            "cross.case.fill"
        case .publicHoliday:
            "sparkles"
        case .excluded:
            "calendar.badge.minus"
        case .planned:
            "calendar.badge.clock"
        case .needsReview:
            "exclamationmark"
        case .notRequired:
            "calendar"
        case .notRecorded:
            "circle.dashed"
        }
    }
    // swiftlint:enable cyclomatic_complexity

    func statusSource(for date: Date, input: Input) -> String {
        if let publicHoliday = ActiveJurisdictionHolidayResolver.holiday(
            on: date,
            from: input.publicHolidays,
            jurisdictionId: input.jurisdictionId,
            calendar: input.calendar
        ) {
            return publicHoliday.name
        }

        if let leaveRecord = first(on: date, in: input.leaveRecords, calendar: input.calendar),
           let leaveType = leaveRecord.leaveType {
            return "Full-day \(leaveType.displayName.lowercased())"
        }

        if let excludedDay = first(
            on: date,
            in: input.customExcludedDays,
            calendar: input.calendar
        ) {
            let reason = excludedDay.reason?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return reason.isEmpty ? "Excluded from the office target" : reason
        }

        if let attendanceDay = first(on: date, in: input.attendanceDays, calendar: input.calendar) {
            if attendanceDay.manualClassification != nil {
                return "Manually corrected"
            }

            if attendanceDay.detectedClassification != .unknown {
                return "Detected from attendance evidence"
            }

            if attendanceDay.finalClassification != .unknown {
                return "Recorded for today"
            }
        }

        if first(on: date, in: input.plannedOfficeDays, calendar: input.calendar) != nil {
            return "Planned office day"
        }

        if input.selectedISOWeekdays.contains(input.calendar.isoWeekday(for: date)) {
            return "No attendance recorded yet"
        }

        return "Not in your work schedule"
    }

    func first(
        on date: Date,
        in records: [AttendanceDay],
        calendar: Calendar
    ) -> AttendanceDay? {
        records.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func first(
        on date: Date,
        in records: [LeaveRecord],
        calendar: Calendar
    ) -> LeaveRecord? {
        records.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func first(
        on date: Date,
        in records: [CustomExcludedDay],
        calendar: Calendar
    ) -> CustomExcludedDay? {
        records.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func first(
        on date: Date,
        in records: [PlannedOfficeDay],
        calendar: Calendar
    ) -> PlannedOfficeDay? {
        records.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
}
