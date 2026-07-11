import Foundation

enum ReportSnapshotBuilderError: Error, Equatable {
    case invalidPeriod
    case invalidRequirement
}

struct ReportSnapshotBuilder {
    struct Input {
        let range: ComplianceDateRange
        let calendar: Calendar
        let rule: ComplianceRule
        let attendanceDays: [AttendanceDay]
        let leaveRecords: [LeaveRecord]
        let manualAdjustments: [ManualAdjustment]
        let publicHolidays: [PublicHoliday]
        let customExcludedDays: [CustomExcludedDay]
        let options: ReportSnapshot.Options
        let generatedAt: Date

        init(
            range: ComplianceDateRange,
            calendar: Calendar,
            rule: ComplianceRule,
            attendanceDays: [AttendanceDay],
            leaveRecords: [LeaveRecord],
            manualAdjustments: [ManualAdjustment],
            publicHolidays: [PublicHoliday],
            customExcludedDays: [CustomExcludedDay] = [],
            options: ReportSnapshot.Options = ReportSnapshot.Options(),
            generatedAt: Date = .now
        ) {
            self.range = range
            self.calendar = calendar
            self.rule = rule
            self.attendanceDays = attendanceDays
            self.leaveRecords = leaveRecords
            self.manualAdjustments = manualAdjustments
            self.publicHolidays = publicHolidays
            self.customExcludedDays = customExcludedDays
            self.options = options
            self.generatedAt = generatedAt
        }
    }

    private let periodEvaluator = CompliancePeriodEvaluator()
    private let businessDayCalculator = BusinessDayCalculator()

    func build(_ input: Input) throws -> ReportSnapshot {
        let periodStart = input.range.start
        let periodEnd = input.range.end
        let periodAttendanceDays = input.attendanceDays.filtered(
            to: input.range,
            calendar: input.calendar
        )
        let periodLeaveRecords = input.leaveRecords.filtered(
            to: input.range,
            calendar: input.calendar
        )
        let periodPublicHolidays = input.publicHolidays.filter { holiday in
            holiday.jurisdictionId == input.rule.jurisdictionId
                && input.range.contains(holiday.date, calendar: input.calendar)
        }
        let periodCustomExcludedDays = input.customExcludedDays.filtered(
            to: input.range,
            calendar: input.calendar
        )
        let publicHolidayDates = Set(
            periodPublicHolidays.map { input.calendar.startOfDay(for: $0.date) }
        )
        let customExcludedDates = Set(
            periodCustomExcludedDays.map { input.calendar.startOfDay(for: $0.date) }
        )
        let selectedWorkdays = Set(input.rule.selectedISOWeekdays)
        let baseEligibleDates = businessDayCalculator.eligibleDates(
            from: periodStart,
            through: periodEnd,
            calendar: input.calendar,
            selectedISOWeekdays: selectedWorkdays,
            publicHolidays: publicHolidayDates
        )
        let eligibleLeaveDates = eligibleLeaveDates(
            from: periodLeaveRecords,
            eligibleDates: baseEligibleDates,
            calendar: input.calendar
        )
        let effectiveCustomExcludedDates = customExcludedDates
            .intersection(baseEligibleDates)
            .subtracting(eligibleLeaveDates)
        let complianceSummary = periodEvaluator.evaluate(
            CompliancePeriodEvaluator.Input(
                range: input.range,
                calendar: input.calendar,
                rule: input.rule,
                attendanceDays: periodAttendanceDays,
                leaveRecords: periodLeaveRecords,
                publicHolidays: periodPublicHolidays,
                customExcludedDays: periodCustomExcludedDays,
                evaluationDate: input.generatedAt
            )
        )

        let attendanceByDate = Dictionary(grouping: periodAttendanceDays) { input.calendar.startOfDay(for: $0.date) }
        let leaveByDate = Dictionary(grouping: periodLeaveRecords) { input.calendar.startOfDay(for: $0.date) }
        let dailyRecords = makeDailyRecords(
            periodStart: periodStart,
            periodEnd: periodEnd,
            calendar: input.calendar,
            selectedISOWeekdays: selectedWorkdays,
            publicHolidayDates: publicHolidayDates,
            customExcludedDates: customExcludedDates,
            eligibleLeaveDates: eligibleLeaveDates,
            effectiveCustomExcludedDates: effectiveCustomExcludedDates,
            attendanceByDate: attendanceByDate,
            leaveByDate: leaveByDate,
            minimumOfficeMinutes: input.rule.minimumOfficeMinutes,
            includeNotes: input.options.includeNotes
        )
        let manualAdjustmentRows = makeManualAdjustmentRows(
            from: input.manualAdjustments,
            attendanceDays: periodAttendanceDays,
            periodStart: periodStart,
            periodEnd: periodEnd,
            calendar: input.calendar,
            includeNotes: input.options.includeNotes
        )
        let leaveRows = makeLeaveRows(
            from: periodLeaveRecords,
            eligibleLeaveDates: eligibleLeaveDates,
            calendar: input.calendar,
            includeNotes: input.options.includeNotes
        )
        let customExclusionRows = makeCustomExclusionRows(
            from: periodCustomExcludedDays,
            effectiveCustomExcludedDates: effectiveCustomExcludedDates,
            calendar: input.calendar,
            includeNotes: input.options.includeNotes
        )
        let publicHolidayRows = makePublicHolidayRows(from: periodPublicHolidays, calendar: input.calendar)
        let noteRows = input.options.includeNotes ? makeNoteRows(
            attendanceDays: periodAttendanceDays,
            leaveRecords: periodLeaveRecords,
            manualAdjustments: input.manualAdjustments,
            attendanceDateById: Dictionary(uniqueKeysWithValues: periodAttendanceDays.map { ($0.id, input.calendar.startOfDay(for: $0.date)) }),
            periodStart: periodStart,
            periodEnd: periodEnd,
            calendar: input.calendar
        ) : []

        return ReportSnapshot(
            summary: ReportSnapshot.Summary(
                periodStart: periodStart,
                periodEnd: periodEnd,
                generatedAt: input.generatedAt,
                baseEligibleDays: complianceSummary.baseEligibleDays,
                adjustedEligibleDays: complianceSummary.adjustedEligibleDays,
                adjustedRequiredOfficeDays: complianceSummary.requiredOfficeDays,
                completedOfficeDays: complianceSummary.completedOfficeDays,
                reviewRequiredDays: complianceSummary.reviewRequiredDays,
                customExcludedDays: complianceSummary.customExcludedDays,
                leaveSummary: leaveSummary(from: eligibleLeaveDates, leaveRecords: periodLeaveRecords, calendar: input.calendar)
            ),
            dailyRecords: dailyRecords,
            leaveRows: leaveRows,
            customExclusionRows: customExclusionRows,
            manualAdjustmentRows: manualAdjustmentRows,
            noteRows: noteRows,
            publicHolidayRows: publicHolidayRows,
            ruleSummary: ruleSummary(from: input.rule),
            options: input.options
        )
    }

    private func makeDailyRecords(
        periodStart: Date,
        periodEnd: Date,
        calendar: Calendar,
        selectedISOWeekdays: Set<Int>,
        publicHolidayDates: Set<Date>,
        customExcludedDates: Set<Date>,
        eligibleLeaveDates: Set<Date>,
        effectiveCustomExcludedDates: Set<Date>,
        attendanceByDate: [Date: [AttendanceDay]],
        leaveByDate: [Date: [LeaveRecord]],
        minimumOfficeMinutes: Int,
        includeNotes: Bool
    ) -> [ReportSnapshot.DailyRecordRow] {
        dates(from: periodStart, through: periodEnd, calendar: calendar).map { date in
            let attendanceDay = attendanceByDate[date]?.sorted { $0.updatedAt < $1.updatedAt }.last
            let isSelectedWorkday = selectedISOWeekdays.contains(isoWeekday(for: date, calendar: calendar))
            let isPublicHoliday = publicHolidayDates.contains(date)
            let isCustomExcluded = customExcludedDates.contains(date)
            let isExcludedFromRequirement = !isSelectedWorkday
                || isPublicHoliday
                || eligibleLeaveDates.contains(date)
                || effectiveCustomExcludedDates.contains(date)
            let detectedStatus = attendanceDay?.detectedClassification ?? .unknown
            let finalStatus = attendanceDay?.finalClassification ?? inferredFinalStatus(
                for: date,
                calendar: calendar,
                selectedISOWeekdays: selectedISOWeekdays,
                publicHolidayDates: publicHolidayDates,
                leaveRecords: leaveByDate[date] ?? []
            )

            return ReportSnapshot.DailyRecordRow(
                date: date,
                isoDate: isoDate(from: date, calendar: calendar),
                detectedStatus: detectedStatus,
                finalStatus: finalStatus,
                complianceTreatment: isExcludedFromRequirement
                    ? .excludedFromRequirement
                    : ComplianceTreatmentResolver.resolve(
                        classification: finalStatus,
                        officeMinutes: attendanceDay?.officeMinutes ?? 0,
                        minimumOfficeMinutes: minimumOfficeMinutes
                    ),
                officeMinutes: attendanceDay?.officeMinutes ?? 0,
                homeMinutes: attendanceDay?.homeMinutes ?? 0,
                isSelectedWorkday: isSelectedWorkday,
                isPublicHoliday: isPublicHoliday,
                hasLeave: leaveByDate[date]?.isEmpty == false,
                isCustomExcluded: isCustomExcluded,
                note: includeNotes ? attendanceDay?.note : nil
            )
        }
    }

    private func makeLeaveRows(
        from leaveRecords: [LeaveRecord],
        eligibleLeaveDates: Set<Date>,
        calendar: Calendar,
        includeNotes: Bool
    ) -> [ReportSnapshot.LeaveRow] {
        leaveRecords.compactMap { leaveRecord in
            guard let leaveType = leaveRecord.leaveType,
                  let duration = leaveRecord.duration else {
                return nil
            }

            let date = calendar.startOfDay(for: leaveRecord.date)
            return ReportSnapshot.LeaveRow(
                id: leaveRecord.id,
                date: date,
                isoDate: isoDate(from: date, calendar: calendar),
                type: leaveType,
                duration: duration,
                countsAgainstEligibleDay: eligibleLeaveDates.contains(date),
                note: includeNotes ? leaveRecord.note : nil
            )
        }
        .sorted { $0.date < $1.date }
    }

    private func makeCustomExclusionRows(
        from customExcludedDays: [CustomExcludedDay],
        effectiveCustomExcludedDates: Set<Date>,
        calendar: Calendar,
        includeNotes: Bool
    ) -> [ReportSnapshot.CustomExclusionRow] {
        customExcludedDays.map { excludedDay in
            let date = calendar.startOfDay(for: excludedDay.date)
            return ReportSnapshot.CustomExclusionRow(
                id: excludedDay.id,
                date: date,
                isoDate: isoDate(from: date, calendar: calendar),
                reducesEligibleDays: effectiveCustomExcludedDates.contains(date),
                reason: includeNotes ? excludedDay.reason : nil
            )
        }
        .sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.id.uuidString < rhs.id.uuidString
            }

            return lhs.date < rhs.date
        }
    }

    private func makeManualAdjustmentRows(
        from manualAdjustments: [ManualAdjustment],
        attendanceDays: [AttendanceDay],
        periodStart: Date,
        periodEnd: Date,
        calendar: Calendar,
        includeNotes: Bool
    ) -> [ReportSnapshot.ManualAdjustmentRow] {
        let attendanceById = Dictionary(uniqueKeysWithValues: attendanceDays.map { ($0.id, $0) })

        return manualAdjustments.compactMap { adjustment in
            guard let attendanceDay = attendanceById[adjustment.attendanceDayId],
                  let adjustedClassification = adjustment.adjustedClassification,
                  let reason = adjustment.reason else {
                return nil
            }

            let date = calendar.startOfDay(for: attendanceDay.date)
            guard date >= periodStart, date <= periodEnd else {
                return nil
            }

            return ReportSnapshot.ManualAdjustmentRow(
                id: adjustment.id,
                date: date,
                isoDate: isoDate(from: date, calendar: calendar),
                adjustedClassification: adjustedClassification,
                reason: reason,
                note: includeNotes ? adjustment.note : nil
            )
        }
        .sorted { $0.date < $1.date }
    }

    private func makeNoteRows(
        attendanceDays: [AttendanceDay],
        leaveRecords: [LeaveRecord],
        manualAdjustments: [ManualAdjustment],
        attendanceDateById: [UUID: Date],
        periodStart: Date,
        periodEnd: Date,
        calendar: Calendar
    ) -> [ReportSnapshot.NoteRow] {
        let attendanceNotes = attendanceDays.compactMap { day -> ReportSnapshot.NoteRow? in
            noteRow(id: day.id, date: calendar.startOfDay(for: day.date), source: .attendanceDay, text: day.note, calendar: calendar)
        }
        let leaveNotes = leaveRecords.compactMap { record -> ReportSnapshot.NoteRow? in
            noteRow(id: record.id, date: calendar.startOfDay(for: record.date), source: .leave, text: record.note, calendar: calendar)
        }
        let manualAdjustmentNotes = manualAdjustments.compactMap { adjustment -> ReportSnapshot.NoteRow? in
            guard let date = attendanceDateById[adjustment.attendanceDayId], date >= periodStart, date <= periodEnd else {
                return nil
            }

            return noteRow(id: adjustment.id, date: date, source: .manualAdjustment, text: adjustment.note, calendar: calendar)
        }

        return (attendanceNotes + leaveNotes + manualAdjustmentNotes).sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.source.rawValue < rhs.source.rawValue
            }

            return lhs.date < rhs.date
        }
    }

    private func makePublicHolidayRows(
        from publicHolidays: [PublicHoliday],
        calendar: Calendar
    ) -> [ReportSnapshot.PublicHolidayRow] {
        publicHolidays.map { holiday in
            let date = calendar.startOfDay(for: holiday.date)
            return ReportSnapshot.PublicHolidayRow(
                id: holiday.id,
                date: date,
                isoDate: isoDate(from: date, calendar: calendar),
                name: holiday.name,
                countryCode: holiday.countryCode,
                jurisdictionId: holiday.jurisdictionId,
                isRegional: holiday.isRegional,
                sourceName: holiday.sourceName,
                sourceURL: holiday.sourceURL
            )
        }
        .sorted { $0.date < $1.date }
    }

    private func leaveSummary(
        from eligibleLeaveDates: Set<Date>,
        leaveRecords: [LeaveRecord],
        calendar: Calendar
    ) -> ReportSnapshot.LeaveSummary {
        let recordsByDate = Dictionary(grouping: leaveRecords) { calendar.startOfDay(for: $0.date) }
        var annualLeaveDays = 0
        var sickLeaveDays = 0

        for date in eligibleLeaveDates {
            let leaveTypes = Set((recordsByDate[date] ?? []).compactMap(\.leaveType))
            if leaveTypes.contains(.annualLeave) {
                annualLeaveDays += 1
            } else if leaveTypes.contains(.sickLeave) {
                sickLeaveDays += 1
            }
        }

        return ReportSnapshot.LeaveSummary(
            annualLeaveDays: annualLeaveDays,
            sickLeaveDays: sickLeaveDays,
            totalLeaveDays: annualLeaveDays + sickLeaveDays
        )
    }

    private func eligibleLeaveDates(
        from leaveRecords: [LeaveRecord],
        eligibleDates: Set<Date>,
        calendar: Calendar
    ) -> Set<Date> {
        Set(
            leaveRecords.compactMap { leaveRecord in
                guard leaveRecord.duration == .fullDay,
                      leaveRecord.leaveType != nil else {
                    return nil
                }

                let date = calendar.startOfDay(for: leaveRecord.date)
                return eligibleDates.contains(date) ? date : nil
            }
        )
    }

    private func inferredFinalStatus(
        for date: Date,
        calendar: Calendar,
        selectedISOWeekdays: Set<Int>,
        publicHolidayDates: Set<Date>,
        leaveRecords: [LeaveRecord]
    ) -> AttendanceClassification {
        if publicHolidayDates.contains(date) {
            return .publicHoliday
        }

        if let leaveType = leaveRecords.compactMap(\.leaveType).first {
            switch leaveType {
            case .annualLeave:
                return .annualLeave
            case .sickLeave:
                return .sickLeave
            }
        }

        return selectedISOWeekdays.contains(isoWeekday(for: date, calendar: calendar)) ? .unknown : .nonWorkingDay
    }

    private func requirement(from rule: ComplianceRule) throws -> ComplianceCalculator.Requirement {
        guard let requirementType = rule.requirementType else {
            throw ReportSnapshotBuilderError.invalidRequirement
        }

        switch requirementType {
        case .fixedMonthlyDays:
            guard let fixedRequiredDays = rule.fixedRequiredDays else {
                throw ReportSnapshotBuilderError.invalidRequirement
            }

            return .fixedMonthlyDays(
                baseRequiredDays: fixedRequiredDays,
                prorateForLeave: rule.prorateFixedTargetForLeave
            )
        case .percentageOfEligibleDays:
            guard let requiredPercentage = rule.requiredPercentage else {
                throw ReportSnapshotBuilderError.invalidRequirement
            }

            return .percentageOfEligibleDays(requiredPercentage)
        }
    }

    private func ruleSummary(from rule: ComplianceRule) -> ReportSnapshot.RuleSummary {
        ReportSnapshot.RuleSummary(
            ruleName: rule.name,
            countryCode: rule.countryCode,
            jurisdictionId: rule.jurisdictionId,
            requirementType: rule.requirementType ?? .fixedMonthlyDays,
            fixedRequiredDays: rule.fixedRequiredDays,
            requiredPercentage: rule.requiredPercentage,
            prorateFixedTargetForLeave: rule.prorateFixedTargetForLeave,
            minimumOfficeMinutes: rule.minimumOfficeMinutes,
            selectedISOWeekdays: rule.selectedISOWeekdays.sorted()
        )
    }

    private func dates(from periodStart: Date, through periodEnd: Date, calendar: Calendar) -> [Date] {
        var dates: [Date] = []
        var currentDate = calendar.startOfDay(for: periodStart)
        let finalDate = calendar.startOfDay(for: periodEnd)

        while currentDate <= finalDate {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return dates
    }

    private func isoWeekday(for date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    private func isoDate(from date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func noteRow(
        id: UUID,
        date: Date,
        source: ReportSnapshot.NoteRow.Source,
        text: String?,
        calendar: Calendar
    ) -> ReportSnapshot.NoteRow? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }

        return ReportSnapshot.NoteRow(
            id: id,
            date: date,
            isoDate: isoDate(from: date, calendar: calendar),
            source: source,
            text: text
        )
    }
}

private extension Array where Element == AttendanceDay {
    func filtered(to range: ComplianceDateRange, calendar: Calendar) -> [AttendanceDay] {
        filter { range.contains($0.date, calendar: calendar) }
    }
}

private extension Array where Element == LeaveRecord {
    func filtered(to range: ComplianceDateRange, calendar: Calendar) -> [LeaveRecord] {
        filter { range.contains($0.date, calendar: calendar) }
    }
}

private extension Array where Element == CustomExcludedDay {
    func filtered(to range: ComplianceDateRange, calendar: Calendar) -> [CustomExcludedDay] {
        filter { range.contains($0.date, calendar: calendar) }
    }
}
