import Foundation

struct AttendanceInferenceService {
    struct DailyInference: Equatable {
        let date: Date
        let officeMinutes: Int
        let homeMinutes: Int
        let detectedClassification: AttendanceClassification
        let finalClassification: AttendanceClassification
        let complianceTreatment: ComplianceTreatment
    }

    private let calendar: Calendar
    private let minimumOfficeMinutes: Int

    init(calendar: Calendar = .current, minimumOfficeMinutes: Int = 180) {
        self.calendar = calendar
        self.minimumOfficeMinutes = minimumOfficeMinutes
    }

    func inferDailyAttendance(
        from events: [LocationEvent],
        periodStart: Date,
        periodEnd: Date,
        leaveRecords: [LeaveRecord] = [],
        publicHolidays: [PublicHoliday] = [],
        customExcludedDays: [CustomExcludedDay] = [],
        selectedISOWeekdays: Set<Int> = [1, 2, 3, 4, 5]
    ) -> [DailyInference] {
        let normalizedPeriodStart = calendar.startOfDay(for: periodStart)
        let normalizedPeriodEnd = calendar.startOfDay(for: periodEnd)
        guard normalizedPeriodStart <= normalizedPeriodEnd else {
            return []
        }

        let minuteTotals = estimatedMinutesByDate(
            from: events,
            periodStart: normalizedPeriodStart,
            periodEnd: normalizedPeriodEnd
        )
        let leaveByDate = leaveClassificationByDate(from: leaveRecords)
        let publicHolidayDates = Set(publicHolidays.map { calendar.startOfDay(for: $0.date) })
        let customExcludedDates = Set(customExcludedDays.map { calendar.startOfDay(for: $0.date) })

        return dates(from: normalizedPeriodStart, through: normalizedPeriodEnd).map { date in
            let totals = minuteTotals[date] ?? MinuteTotals()
            let detectedClassification = detectedClassification(
                officeMinutes: totals.officeMinutes,
                homeMinutes: totals.homeMinutes
            )
            let exclusionClassification = exclusionClassification(
                for: date,
                leaveByDate: leaveByDate,
                publicHolidayDates: publicHolidayDates,
                customExcludedDates: customExcludedDates,
                selectedISOWeekdays: selectedISOWeekdays
            )
            let finalClassification = exclusionClassification ?? detectedClassification

            return DailyInference(
                date: date,
                officeMinutes: totals.officeMinutes,
                homeMinutes: totals.homeMinutes,
                detectedClassification: detectedClassification,
                finalClassification: finalClassification,
                complianceTreatment: ComplianceTreatmentResolver.resolve(
                    classification: finalClassification,
                    officeMinutes: totals.officeMinutes,
                    minimumOfficeMinutes: minimumOfficeMinutes
                )
            )
        }
    }

    @discardableResult
    func recalculateAttendanceDays(
        _ attendanceDays: [AttendanceDay],
        affectedDates explicitAffectedDates: Set<Date>? = nil,
        events: [LocationEvent],
        leaveRecords: [LeaveRecord] = [],
        publicHolidays: [PublicHoliday] = [],
        customExcludedDays: [CustomExcludedDay] = [],
        selectedISOWeekdays: Set<Int> = [1, 2, 3, 4, 5],
        updatedAt: Date = .now
    ) -> Set<Date> {
        let affectedDates = Set((explicitAffectedDates ?? affectedDates(from: events)).map { calendar.startOfDay(for: $0) })
        guard !affectedDates.isEmpty else {
            return []
        }

        let sortedDates = affectedDates.sorted()
        guard let periodStart = sortedDates.first,
              let periodEnd = sortedDates.last else {
            return []
        }

        let inferencesByDate = Dictionary(
            uniqueKeysWithValues: inferDailyAttendance(
                from: events,
                periodStart: periodStart,
                periodEnd: periodEnd,
                leaveRecords: leaveRecords,
                publicHolidays: publicHolidays,
                customExcludedDays: customExcludedDays,
                selectedISOWeekdays: selectedISOWeekdays
            ).map { ($0.date, $0) }
        )
        let customExcludedDates = Set(customExcludedDays.map { calendar.startOfDay(for: $0.date) })

        for attendanceDay in attendanceDays {
            let date = calendar.startOfDay(for: attendanceDay.date)
            guard affectedDates.contains(date), let inference = inferencesByDate[date] else {
                continue
            }

            attendanceDay.date = date
            attendanceDay.detectedClassificationRaw = inference.detectedClassification.rawValue
            attendanceDay.officeMinutes = inference.officeMinutes
            attendanceDay.homeMinutes = inference.homeMinutes

            let isCustomExcluded = customExcludedDates.contains(date)
            if isCustomExcluded {
                attendanceDay.finalClassificationRaw = AttendanceClassification.nonWorkingDay.rawValue
            } else if let manualClassification = attendanceDay.manualClassification {
                attendanceDay.finalClassificationRaw = manualClassification.rawValue
            } else {
                attendanceDay.finalClassificationRaw = inference.finalClassification.rawValue
            }

            if isCustomExcluded {
                attendanceDay.complianceTreatmentRaw = ComplianceTreatment.excludedFromRequirement.rawValue
            } else {
                let finalClassification = attendanceDay.finalClassification ?? inference.finalClassification
                attendanceDay.complianceTreatmentRaw = ComplianceTreatmentResolver.resolve(
                    classification: finalClassification,
                    officeMinutes: inference.officeMinutes,
                    minimumOfficeMinutes: minimumOfficeMinutes
                ).rawValue
            }
            attendanceDay.updatedAt = updatedAt
        }

        return affectedDates
    }

    private func estimatedMinutesByDate(
        from events: [LocationEvent],
        periodStart: Date,
        periodEnd: Date
    ) -> [Date: MinuteTotals] {
        guard let periodExclusiveEnd = calendar.date(byAdding: .day, value: 1, to: periodEnd) else {
            return [:]
        }

        var activeEntryByPlaceType: [PlaceType: Date] = [:]
        var totalsByDate: [Date: MinuteTotals] = [:]

        for event in events.sorted(by: { $0.occurredAt < $1.occurredAt }) {
            guard let placeType = event.placeType,
                  let eventKind = event.eventKind else {
                continue
            }

            switch eventKind {
            case .entered:
                if activeEntryByPlaceType[placeType] == nil {
                    activeEntryByPlaceType[placeType] = event.occurredAt
                }
            case .exited:
                guard let enteredAt = activeEntryByPlaceType[placeType], event.occurredAt > enteredAt else {
                    continue
                }

                allocateMinutes(
                    from: max(enteredAt, periodStart),
                    to: min(event.occurredAt, periodExclusiveEnd),
                    placeType: placeType,
                    totalsByDate: &totalsByDate
                )
                activeEntryByPlaceType[placeType] = nil
            }
        }

        return totalsByDate
    }

    private func allocateMinutes(
        from start: Date,
        to end: Date,
        placeType: PlaceType,
        totalsByDate: inout [Date: MinuteTotals]
    ) {
        guard end > start else {
            return
        }

        var segmentStart = start
        while segmentStart < end {
            let day = calendar.startOfDay(for: segmentStart)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }

            let segmentEnd = min(end, nextDay)
            let minutes = max(0, Int(segmentEnd.timeIntervalSince(segmentStart) / 60))

            switch placeType {
            case .office:
                totalsByDate[day, default: MinuteTotals()].officeMinutes += minutes
            case .home:
                totalsByDate[day, default: MinuteTotals()].homeMinutes += minutes
            }

            segmentStart = segmentEnd
        }
    }

    private func affectedDates(from events: [LocationEvent]) -> Set<Date> {
        var affectedDates = Set(events.map { calendar.startOfDay(for: $0.occurredAt) })
        var activeEntryByPlaceType: [PlaceType: Date] = [:]

        for event in events.sorted(by: { $0.occurredAt < $1.occurredAt }) {
            guard let placeType = event.placeType,
                  let eventKind = event.eventKind else {
                continue
            }

            switch eventKind {
            case .entered:
                if activeEntryByPlaceType[placeType] == nil {
                    activeEntryByPlaceType[placeType] = event.occurredAt
                }
            case .exited:
                if let enteredAt = activeEntryByPlaceType[placeType], event.occurredAt > enteredAt {
                    affectedDates.formUnion(dates(from: enteredAt, through: event.occurredAt))
                    activeEntryByPlaceType[placeType] = nil
                }
            }
        }

        return affectedDates
    }

    private func detectedClassification(officeMinutes: Int, homeMinutes: Int) -> AttendanceClassification {
        if officeMinutes >= minimumOfficeMinutes {
            return homeMinutes > 0 ? .mixed : .office
        }

        if homeMinutes > 0 {
            return .home
        }

        return .unknown
    }

    private func exclusionClassification(
        for date: Date,
        leaveByDate: [Date: AttendanceClassification],
        publicHolidayDates: Set<Date>,
        customExcludedDates: Set<Date>,
        selectedISOWeekdays: Set<Int>
    ) -> AttendanceClassification? {
        if customExcludedDates.contains(date) {
            return .nonWorkingDay
        }

        if publicHolidayDates.contains(date) {
            return .publicHoliday
        }

        if let leaveClassification = leaveByDate[date] {
            return leaveClassification
        }

        return selectedISOWeekdays.contains(isoWeekday(for: date)) ? nil : .nonWorkingDay
    }

    private func leaveClassificationByDate(from leaveRecords: [LeaveRecord]) -> [Date: AttendanceClassification] {
        var classificationsByDate: [Date: AttendanceClassification] = [:]

        for leaveRecord in leaveRecords where leaveRecord.duration == .fullDay {
            let date = calendar.startOfDay(for: leaveRecord.date)
            guard classificationsByDate[date] == nil else {
                continue
            }

            switch leaveRecord.leaveType {
            case .annualLeave:
                classificationsByDate[date] = .annualLeave
            case .sickLeave:
                classificationsByDate[date] = .sickLeave
            case nil:
                continue
            }
        }

        return classificationsByDate
    }

    private func dates(from periodStart: Date, through periodEnd: Date) -> [Date] {
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

    private func isoWeekday(for date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }
}

private struct MinuteTotals {
    var officeMinutes = 0
    var homeMinutes = 0
}
