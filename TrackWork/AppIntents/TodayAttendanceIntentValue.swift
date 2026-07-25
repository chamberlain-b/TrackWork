import AppIntents

enum TodayAttendanceIntentValue: String, AppEnum {
    case office
    case home
    case annualLeave
    case sickLeave

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Attendance or Leave"

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .office: DisplayRepresentation(title: "Office", image: .init(systemName: "building.2")),
        .home: DisplayRepresentation(title: "Home", image: .init(systemName: "house")),
        .annualLeave: DisplayRepresentation(title: "Annual Leave", image: .init(systemName: "sun.max")),
        .sickLeave: DisplayRepresentation(title: "Sick Leave", image: .init(systemName: "cross.case"))
    ]
}
