# Work Track iOS App Build Plan for Codex

Version: 0.1  
Date: 2026-07-02  
Platform: Native iOS, SwiftUI  
Working app name: **Work Track**

## 1. Purpose

Work Track is a private iOS app that helps a user track office/home attendance and monthly hybrid-work compliance.

The app should:

- Track office and home attendance using iPhone location.
- Support Australia and New Zealand from the MVP.
- Use selected jurisdiction public holidays when calculating business days.
- Allow annual leave and sick leave.
- Reduce eligible business days when leave is taken.
- Allow manual overrides and notes.
- Export a styled PDF report.
- Export an Excel-compatible report, preferably `.xlsx`, with CSV as a fallback during early development.
- Store personal attendance data on-device by default.

This document is intended to guide incremental implementation with Codex. Build in small, testable slices. Do not jump straight into background location tracking. That way lies pain, logs, and despair.

---

## 2. MVP Decisions Locked In

### 2.1 Countries and jurisdictions

The MVP supports:

#### Australia

- ACT
- NSW
- NT
- QLD
- SA
- TAS
- VIC
- WA

#### New Zealand

- NZ National
- NZ regional/provincial anniversary selection:
  - Northland
  - Auckland
  - Taranaki
  - Hawke's Bay
  - Wellington
  - Marlborough
  - Nelson
  - Canterbury
  - South Canterbury
  - Westland
  - Otago
  - Southland
  - Chatham Islands

### 2.2 Compliance period

MVP supports:

- Calendar month only.

Future support:

- Rolling periods.
- Quarterly periods.
- Custom date ranges.

### 2.3 Leave treatment

Annual leave and sick leave reduce the eligible compliance day count.

Default MVP rule:

```text
Eligible compliance days =
    selected workdays
    - public holidays
    - annual leave
    - sick leave
    - custom excluded days
```

Important:

- Leave only reduces eligible days if the date would otherwise have been an eligible workday.
- Leave on a weekend should not reduce eligible days.
- Leave on a public holiday should not double-reduce eligible days.
- For the first calculator version, implement full-day leave.
- Add half-day leave after the full-day rule is stable and tested.

### 2.4 Requirement types

MVP supports two requirement types:

#### Percentage of eligible compliance days

Example:

```text
Required office days = ceil(eligibleComplianceDays * 0.50)
```

#### Fixed monthly target, prorated for leave by default

Example:

```text
Base required office days = 10
Base eligible days before leave = 23
Adjusted eligible days after leave = 19

Adjusted required office days = ceil(10 * 19 / 23)
```

The setting should exist:

```text
Prorate fixed target for leave: true by default
```

### 2.5 Attendance source of truth

The app keeps separate concepts:

```text
Detected status = what the app inferred from location.
Final status = what should be used for compliance after leave, public holidays, and manual overrides.
Note = explanation only, unless paired with leave or override.
```

Do not add a work/badge reconciliation field. The user does not get access to individual employer records.

### 2.6 Privacy defaults

- Store data on-device.
- Do not export raw GPS coordinates by default.
- Do not export raw location events by default.
- Let the user manually include sensitive data in exports later if needed.
- Reports should contain derived day-level attendance by default.

---

## 3. Recommended Technical Stack

### Core app

- SwiftUI for UI.
- SwiftData for persistence.
- Swift Testing or XCTest for unit tests, depending on project template and target compatibility.
- Core Location for geofencing and visit/location events.
- MapKit for selecting home and office locations.
- UserNotifications for future reminders.
- UIKit/PDFKit for PDF generation.
- A Swift Package for `.xlsx` generation after evaluating dependency fit.

### Deployment target

Use **iOS 27.0+** as the minimum deployment target.

Recommended first target:

```text
iOS 27.0+
```

This project intentionally targets iOS 27.0+ for the MVP. That means the project should be created and built with Xcode 27 or a compatible later Xcode release that includes the iOS 27 SDK. Do not use beta-only APIs in the MVP unless they are explicitly documented as stable for the chosen toolchain.

---

## 4. Suggested Xcode Project Setup

Create this manually in Xcode first.

### 4.1 New project

Use:

```text
File > New > Project > iOS > App
```

Recommended settings:

```text
Product Name: Work Track
Internal Swift module / type prefix: WorkTrack
Interface: SwiftUI
Language: Swift
Testing System: XCTest or Swift Testing
Storage: None in template
Bundle Identifier: your personal/team identifier, e.g. com.yourdomain.worktrack
Minimum Deployment: iOS 27.0+
```

Do not enable Core Data from the template. We will add SwiftData explicitly.

### 4.2 Capabilities

Add later, not immediately:

```text
Signing & Capabilities:
- Background Modes
  - Location updates
```

Only add this once the location service milestone starts.

### 4.3 Privacy strings

Add later when Core Location is introduced:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Work Track uses your location to identify when you are at home or in the office for your private attendance records.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Work Track uses background location events to automatically record office and home attendance.</string>
```

Do not ask for Always location permission on first launch. Explain the value first inside the app.

---

## 5. Target Folder Structure

Create this structure early:

```text
WorkTrack/
├── App/
│   ├── WorkTrackApp.swift
│   └── AppRouter.swift
│
├── Models/
│   ├── Attendance/
│   │   ├── AttendanceDay.swift
│   │   ├── AttendanceClassification.swift
│   │   ├── ComplianceTreatment.swift
│   │   ├── ManualAdjustment.swift
│   │   └── LeaveRecord.swift
│   │
│   ├── Compliance/
│   │   ├── ComplianceRule.swift
│   │   ├── ComplianceSummary.swift
│   │   ├── ComplianceStatus.swift
│   │   └── RequirementType.swift
│   │
│   ├── Location/
│   │   ├── Place.swift
│   │   ├── PlaceType.swift
│   │   └── LocationEvent.swift
│   │
│   └── Holidays/
│       ├── Country.swift
│       ├── Jurisdiction.swift
│       ├── PublicHoliday.swift
│       └── HolidayCalendarSource.swift
│
├── Services/
│   ├── Compliance/
│   │   ├── ComplianceCalculator.swift
│   │   └── BusinessDayCalculator.swift
│   │
│   ├── Holidays/
│   │   ├── HolidayProvider.swift
│   │   ├── LocalJSONHolidayProvider.swift
│   │   └── HolidayService.swift
│   │
│   ├── Location/
│   │   ├── LocationTrackingService.swift
│   │   ├── LocationAuthorizationService.swift
│   │   └── AttendanceInferenceService.swift
│   │
│   └── Export/
│       ├── ReportSnapshot.swift
│       ├── PDFExportService.swift
│       ├── SpreadsheetExportService.swift
│       └── CSVExportService.swift
│
├── Views/
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   └── DashboardMetricCard.swift
│   │
│   ├── Calendar/
│   │   ├── MonthCalendarView.swift
│   │   └── DayCellView.swift
│   │
│   ├── DayDetail/
│   │   ├── DayDetailView.swift
│   │   ├── ManualOverrideView.swift
│   │   └── LeaveEditorView.swift
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── JurisdictionSettingsView.swift
│   │   ├── ComplianceRuleSettingsView.swift
│   │   └── PrivacySettingsView.swift
│   │
│   ├── LocationSetup/
│   │   ├── LocationSetupView.swift
│   │   ├── PlaceEditorView.swift
│   │   └── MapPickerView.swift
│   │
│   └── Export/
│       ├── ExportView.swift
│       └── ReportPreviewView.swift
│
├── Resources/
│   ├── Holidays/
│   │   ├── holidays_au_2026.json
│   │   ├── holidays_nz_2026.json
│   │   └── holiday_schema.md
│   │
│   └── PreviewData/
│       └── preview_attendance.json
│
└── Tests/
    ├── ComplianceCalculatorTests.swift
    ├── BusinessDayCalculatorTests.swift
    ├── HolidayProviderTests.swift
    └── ExportSnapshotTests.swift
```

---

## 6. Core Domain Types

Use these names unless there is a strong reason to change them.

### 6.1 Country

```swift
enum Country: String, Codable, CaseIterable, Identifiable {
    case australia = "AU"
    case newZealand = "NZ"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .australia: return "Australia"
        case .newZealand: return "New Zealand"
        }
    }
}
```

### 6.2 Jurisdiction

Use a struct rather than a giant enum if holiday files need metadata.

```swift
struct Jurisdiction: Codable, Hashable, Identifiable {
    let id: String
    let country: Country
    let displayName: String
    let shortName: String
}
```

Example IDs:

```text
AU-VIC
AU-NSW
AU-QLD
NZ-NATIONAL
NZ-AUCKLAND
NZ-WELLINGTON
```

### 6.3 AttendanceClassification

```swift
enum AttendanceClassification: String, Codable, CaseIterable, Identifiable {
    case office
    case home
    case mixed
    case annualLeave
    case sickLeave
    case publicHoliday
    case weekend
    case nonWorkingDay
    case unknown

    var id: String { rawValue }
}
```

### 6.4 ComplianceTreatment

```swift
enum ComplianceTreatment: String, Codable, CaseIterable {
    case countsAsOffice
    case countsAsHome
    case excludedFromRequirement
    case requiresReview
}
```

### 6.5 LeaveType and LeaveDuration

```swift
enum LeaveType: String, Codable, CaseIterable, Identifiable {
    case annualLeave
    case sickLeave

    var id: String { rawValue }
}

enum LeaveDuration: String, Codable, CaseIterable, Identifiable {
    case fullDay
    case halfDayAM
    case halfDayPM

    var id: String { rawValue }
}
```

For the first calculator milestone, implement only `.fullDay`. Keep the enum ready for half-day support.

### 6.6 RequirementType

```swift
enum RequirementType: String, Codable, CaseIterable {
    case fixedMonthlyDays
    case percentageOfEligibleDays
}
```

### 6.7 ComplianceStatus

```swift
enum ComplianceStatus: String, Codable {
    case complete
    case onTrack
    case atRisk
    case impossible
}
```

---

## 7. SwiftData Model Drafts

### 7.1 AttendanceDay

```swift
import Foundation
import SwiftData

@Model
final class AttendanceDay {
    @Attribute(.unique) var id: UUID
    var date: Date

    var detectedClassificationRaw: String
    var manualClassificationRaw: String?

    var complianceTreatmentRaw: String

    var officeMinutes: Int
    var homeMinutes: Int

    var isPublicHoliday: Bool
    var holidayName: String?

    var note: String?

    var confidence: Double

    var createdAt: Date
    var updatedAt: Date

    init(date: Date) {
        self.id = UUID()
        self.date = date
        self.detectedClassificationRaw = AttendanceClassification.unknown.rawValue
        self.manualClassificationRaw = nil
        self.complianceTreatmentRaw = ComplianceTreatment.requiresReview.rawValue
        self.officeMinutes = 0
        self.homeMinutes = 0
        self.isPublicHoliday = false
        self.holidayName = nil
        self.note = nil
        self.confidence = 0
        self.createdAt = .now
        self.updatedAt = .now
    }
}
```

### 7.2 LeaveRecord

```swift
import Foundation
import SwiftData

@Model
final class LeaveRecord {
    @Attribute(.unique) var id: UUID
    var date: Date
    var leaveTypeRaw: String
    var durationRaw: String
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        date: Date,
        leaveType: LeaveType,
        duration: LeaveDuration = .fullDay,
        note: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.leaveTypeRaw = leaveType.rawValue
        self.durationRaw = duration.rawValue
        self.note = note
        self.createdAt = .now
        self.updatedAt = .now
    }
}
```

### 7.3 ManualAdjustment

```swift
import Foundation
import SwiftData

enum OverrideReason: String, Codable, CaseIterable, Identifiable {
    case forgotWorkPass
    case phoneLocationIncorrect
    case phoneBatteryFlat
    case manualCorrection
    case other

    var id: String { rawValue }
}

@Model
final class ManualAdjustment {
    @Attribute(.unique) var id: UUID
    var attendanceDayId: UUID
    var adjustedClassificationRaw: String
    var reasonRaw: String
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        attendanceDayId: UUID,
        classification: AttendanceClassification,
        reason: OverrideReason,
        note: String? = nil
    ) {
        self.id = UUID()
        self.attendanceDayId = attendanceDayId
        self.adjustedClassificationRaw = classification.rawValue
        self.reasonRaw = reason.rawValue
        self.note = note
        self.createdAt = .now
        self.updatedAt = .now
    }
}
```

### 7.4 ComplianceRule

```swift
import Foundation
import SwiftData

@Model
final class ComplianceRule {
    @Attribute(.unique) var id: UUID

    var name: String

    var countryCode: String
    var jurisdictionId: String

    var periodTypeRaw: String
    var requirementTypeRaw: String

    var fixedRequiredDays: Int?
    var requiredPercentage: Double?

    var prorateFixedTargetForLeave: Bool

    var minimumOfficeMinutes: Int

    // Store selected workdays as ISO weekday numbers: 1 = Monday, 7 = Sunday.
    var selectedISOWeekdays: [Int]

    var createdAt: Date
    var updatedAt: Date

    init(name: String = "Default Monthly Rule") {
        self.id = UUID()
        self.name = name
        self.countryCode = Country.australia.rawValue
        self.jurisdictionId = "AU-VIC"
        self.periodTypeRaw = "monthly"
        self.requirementTypeRaw = RequirementType.fixedMonthlyDays.rawValue
        self.fixedRequiredDays = 10
        self.requiredPercentage = nil
        self.prorateFixedTargetForLeave = true
        self.minimumOfficeMinutes = 180
        self.selectedISOWeekdays = [1, 2, 3, 4, 5]
        self.createdAt = .now
        self.updatedAt = .now
    }
}
```

### 7.5 Place

```swift
import Foundation
import SwiftData

enum PlaceType: String, Codable, CaseIterable, Identifiable {
    case home
    case office

    var id: String { rawValue }
}

@Model
final class Place {
    @Attribute(.unique) var id: UUID

    var name: String
    var typeRaw: String

    var latitude: Double
    var longitude: Double
    var radiusMeters: Double

    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        type: PlaceType,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 150
    ) {
        self.id = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.isActive = true
        self.createdAt = .now
        self.updatedAt = .now
    }
}
```

### 7.6 PublicHoliday

```swift
import Foundation
import SwiftData

@Model
final class PublicHoliday {
    @Attribute(.unique) var id: UUID

    var date: Date
    var name: String

    var countryCode: String
    var jurisdictionId: String

    var isRegional: Bool
    var sourceName: String
    var sourceURL: String?
    var isUserEdited: Bool

    init(
        date: Date,
        name: String,
        countryCode: String,
        jurisdictionId: String,
        isRegional: Bool,
        sourceName: String,
        sourceURL: String? = nil,
        isUserEdited: Bool = false
    ) {
        self.id = UUID()
        self.date = date
        self.name = name
        self.countryCode = countryCode
        self.jurisdictionId = jurisdictionId
        self.isRegional = isRegional
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.isUserEdited = isUserEdited
    }
}
```

---

## 8. Compliance Calculation Rules

### 8.1 Definitions

```text
Selected workday:
A date whose ISO weekday is in the user's selected workdays.

Public holiday:
A date in the selected jurisdiction holiday set.

Base eligible day:
A selected workday that is not a public holiday.

Adjusted eligible day:
A base eligible day reduced by leave and custom exclusions.

Completed office day:
A date whose final classification counts as office.
```

### 8.2 Leave impact

For MVP full-day leave:

```text
Full-day annual leave impact = 1.0
Full-day sick leave impact = 1.0
```

Rules:

```text
If date is not a selected workday, leave impact = 0.0
If date is a public holiday, leave impact = 0.0
If multiple leave records exist for one date, cap total leave impact at 1.0
```

### 8.3 Percentage requirement

```swift
requiredOfficeDays = Int(ceil(adjustedEligibleDays * requiredPercentage))
```

Example:

```text
Selected workdays: 23
Public holidays: 0
Annual leave: 3
Sick leave: 1
Adjusted eligible days: 19
Requirement: 50%
Required office days: ceil(19 * 0.50) = 10
```

### 8.4 Fixed monthly requirement with leave prorating

```swift
if prorateFixedTargetForLeave {
    requiredOfficeDays = ceil(baseRequiredDays * adjustedEligibleDays / baseEligibleDays)
} else {
    requiredOfficeDays = baseRequiredDays
}
```

Example:

```text
Base required days: 10
Base eligible days before leave: 23
Adjusted eligible days after leave: 19
Required office days: ceil(10 * 19 / 23) = 9
```

### 8.5 Status logic

```text
complete:
    completedOfficeDays >= requiredOfficeDays

impossible:
    remainingRequiredOfficeDays > remainingEligibleDays

atRisk:
    remainingRequiredOfficeDays == remainingEligibleDays
    OR remainingRequiredOfficeDays / max(remainingEligibleDays, 1) >= 0.75

onTrack:
    anything else
```

---

## 9. Export Requirements

### 9.1 PDF export

Generate a styled monthly PDF report with:

1. Report title and period.
2. Jurisdiction.
3. Compliance rule summary.
4. Compliance result.
5. Business day calculation.
6. Leave summary.
7. Day-by-day table.
8. Manual override and notes summary.
9. Public holiday source summary.

Default PDF should not include raw location events or GPS coordinates.

### 9.2 PDF design

Use a simple, clean report:

```text
Header:
Work Track Attendance Report

Summary cards:
- Required office days
- Completed office days
- Remaining office days
- Eligible compliance days
- Status

Tables:
- Daily records
- Leave records
- Manual adjustments
- Public holidays
```

### 9.3 Excel export

Final MVP target:

```text
.xlsx workbook
```

Early development fallback:

```text
.csv export
```

Dependency decision:

- CSV remains the MVP Excel-compatible export.
- Native `.xlsx` export is deferred until CSV/PDF export foundations are stable and a true workbook format is needed.
- Do not add an `.xlsx` package for the MVP CSV milestone.

Workbook tabs:

```text
Summary
Daily Records
Leave
Manual Overrides
Public Holidays
Settings
```

Do not include a work reconciliation tab.

Daily Records columns:

```text
Date
Day
Detected Status
Final Status
Compliance Treatment
Office Minutes
Home Minutes
Public Holiday
Holiday Name
Leave Type
Leave Duration
Eligible Day Impact
Manual Override
Override Reason
Note
Confidence
```

Leave columns:

```text
Date
Leave Type
Duration
Eligible Day Impact
Note
Created At
Updated At
```

Export privacy toggles:

```text
Include notes: on by default
Include manual overrides: on by default
Include public holiday source: on by default
Include raw location events: off by default
Include GPS coordinates: off by default
```

---

## 10. Holiday Data Strategy

### 10.1 MVP strategy

Use local JSON holiday files bundled with the app.

Benefits:

- Predictable.
- Works offline.
- Easy to test.
- Avoids dealing with every government site/API format during the first build.

### 10.2 Later strategy

Add refresh/import support later.

Possible later sources:

- Australian state/territory sources.
- Fair Work public holiday pages for cross-checking.
- DataVic Important Dates API for Victoria.
- New Zealand government public holidays and anniversary dates.

### 10.3 Holiday JSON schema

Use this schema:

```json
{
  "country": "AU",
  "jurisdictionId": "AU-VIC",
  "year": 2026,
  "sourceName": "Business Victoria",
  "sourceURL": "https://business.vic.gov.au/business-information/public-holidays",
  "holidays": [
    {
      "date": "2026-01-01",
      "name": "New Year's Day",
      "isRegional": false
    }
  ]
}
```

For NZ regional anniversary days:

```json
{
  "country": "NZ",
  "jurisdictionId": "NZ-AUCKLAND",
  "year": 2026,
  "sourceName": "Employment New Zealand",
  "sourceURL": "https://www.employment.govt.nz/leave-and-holidays/public-holidays/public-holidays-and-anniversary-dates",
  "inherits": ["NZ-NATIONAL"],
  "holidays": [
    {
      "date": "2026-01-26",
      "name": "Auckland Anniversary Day",
      "isRegional": true
    }
  ]
}
```

---

## 11. Screens and Navigation

### 11.1 Initial tabs

Use a `TabView`:

```text
Dashboard
Calendar
Export
Settings
```

### 11.2 Dashboard

Shows:

```text
Current month
Compliance status
Office days completed / required
Office days remaining
Eligible compliance days
Leave excluded
Public holidays excluded
Manual overrides count
Days needing review
```

### 11.3 Calendar

Month grid.

Day badges:

```text
O = Office
H = Home
M = Mixed
AL = Annual leave
SL = Sick leave
PH = Public holiday
? = Unknown
✎ = Manual override
```

### 11.4 Day detail

Shows:

```text
Date
Detected status
Final status
Office minutes
Home minutes
Public holiday status
Leave status
Manual override status
Note
```

Actions:

```text
Add/edit note
Add annual leave
Add sick leave
Set manual status
Clear manual override
```

### 11.5 Settings

Sections:

```text
Jurisdiction
Compliance rule
Workdays
Location setup
Privacy
Data management
```

### 11.6 Export

Inputs:

```text
Period
Format: PDF / Excel / CSV
Include notes
Include manual overrides
Include raw location events, off by default
```

Actions:

```text
Generate report
Preview PDF
Share file
```

---

## 12. Incremental Build Plan

## Milestone 0: Create Xcode Project

### Goal

Create a clean SwiftUI project that builds and runs.

### Manual steps

1. Create the Xcode project.
2. Set deployment target to iOS 27.0+.
3. Confirm the blank app runs in Simulator.
4. Commit the clean initial project.

### Acceptance criteria

- App launches in Simulator.
- No warnings from missing files.
- Git repo initialized.
- Initial commit exists.

### Suggested commit

```text
chore: create initial SwiftUI iOS project
```

---

## Milestone 1: Project Scaffold

### Goal

Create the folder structure, placeholder views, and app shell.

### Codex prompt

```text
Create the initial Work Track project scaffold.

Do not implement business logic yet.

Tasks:
1. Create folders matching the structure in docs/WorkTrack_Codex_Build_Plan.md.
2. Add AppRouter.swift if useful.
3. Replace the default ContentView with a TabView containing Dashboard, Calendar, Export, and Settings tabs.
4. Add placeholder SwiftUI views:
   - DashboardView
   - MonthCalendarView
   - ExportView
   - SettingsView
5. Each placeholder should compile and show a simple title.
6. Do not add SwiftData models yet.
7. Ensure the app builds.
```

### Acceptance criteria

- App launches.
- Four tabs are visible.
- Each tab has a placeholder screen.
- No business logic implemented.

### Suggested commit

```text
chore: scaffold app shell and primary tabs
```

---

## Milestone 2: Domain Enums and Jurisdiction List

### Goal

Add core enums and jurisdiction definitions.

### Codex prompt

```text
Add the core domain enums and static jurisdiction list.

Implement:
1. Country enum.
2. Jurisdiction struct.
3. A JurisdictionCatalog with:
   - all AU states/territories
   - NZ National
   - NZ regional/provincial anniversary options listed in the build plan
4. AttendanceClassification enum.
5. ComplianceTreatment enum.
6. LeaveType enum.
7. LeaveDuration enum.
8. RequirementType enum.
9. ComplianceStatus enum.

Add unit tests for:
- Country display names.
- AU jurisdictions count.
- NZ jurisdictions include NZ-NATIONAL and NZ-AUCKLAND.
- Jurisdiction IDs are unique.
```

### Acceptance criteria

- Enums compile.
- Jurisdiction catalog exists.
- Unit tests pass.

### Suggested commit

```text
feat: add core domain types and jurisdiction catalog
```

---

## Milestone 3: SwiftData Models

### Goal

Add persistence models without UI integration yet.

### Codex prompt

```text
Add SwiftData models for the initial MVP.

Implement:
1. AttendanceDay
2. LeaveRecord
3. ManualAdjustment
4. ComplianceRule
5. Place
6. PublicHoliday

Update WorkTrackApp to create a SwiftData model container for these models.

Do not build full views yet.

Add preview-safe sample data helpers if useful.
```

### Acceptance criteria

- App builds with SwiftData model container.
- Models compile.
- No UI depends on incomplete services.

### Suggested commit

```text
feat: add SwiftData persistence models
```

---

## Milestone 4: Business Day and Compliance Calculator

### Goal

Implement the core calculation engine using in-memory values.

This is the most important milestone. The app should be able to calculate compliance without any UI, location tracking, or persistence weirdness.

### Codex prompt

```text
Implement the business day and compliance calculation engine.

Create:
1. BusinessDayCalculator
2. ComplianceCalculator
3. ComplianceSummary
4. Supporting structs if needed.

Rules:
- Selected workdays are ISO weekdays, where Monday = 1 and Sunday = 7.
- Public holidays exclude eligible days.
- Annual leave and sick leave reduce eligible days only if the date would otherwise be eligible.
- Full-day leave reduces eligible days by 1.0.
- Multiple leave records on the same date are capped at 1.0.
- Leave on a weekend has 0.0 eligible day impact.
- Leave on a public holiday has 0.0 eligible day impact.
- Percentage requirement uses ceil(adjustedEligibleDays * percentage).
- Fixed monthly requirement prorates by leave when prorateFixedTargetForLeave is true:
  ceil(baseRequiredDays * adjustedEligibleDays / baseEligibleDays)
- Fixed monthly requirement does not prorate when prorateFixedTargetForLeave is false.

Add unit tests for:
1. 23 workdays, 0 holidays, 3 annual leave, 1 sick leave, 50% requirement -> eligible 19, required 10.
2. Fixed requirement 10, base eligible 23, adjusted eligible 19, prorated -> required 9.
3. Fixed requirement 10, prorating off -> required 10.
4. Leave on weekend does not reduce eligible days.
5. Leave on public holiday does not double-reduce eligible days.
6. Multiple leave records on same date are capped at one day.
```

### Acceptance criteria

- All calculator tests pass.
- No UI dependencies.
- No Core Location dependencies.
- Date handling is deterministic in tests.

### Suggested commit

```text
feat: implement leave-adjusted compliance calculator
```

---

## Milestone 5: Holiday Provider from Local JSON

### Goal

Load public holidays from bundled JSON.

### Codex prompt

```text
Implement local JSON holiday loading.

Create:
1. HolidayProvider protocol.
2. LocalJSONHolidayProvider.
3. HolidayService.
4. Holiday JSON decoding models.
5. Sample JSON files for AU-VIC and NZ-NATIONAL for development only.
6. A holiday_schema.md resource explaining the bundled format.

Rules:
- Holiday files are bundled resources.
- Dates are ISO yyyy-MM-dd.
- Provider returns holidays for country, jurisdiction, and year.
- NZ regional files can inherit NZ-NATIONAL.
- If data is missing, return a clear typed error rather than silently returning no holidays.

Add unit tests for:
- AU-VIC fixture loads.
- NZ-NATIONAL fixture loads.
- NZ regional inheritance combines national and regional holidays.
- Missing file produces a typed error.
```

### Acceptance criteria

- Holiday fixtures load from bundle.
- Tests pass.
- Error handling is explicit.

### Suggested commit

```text
feat: load jurisdiction holidays from bundled JSON
```

---

## Milestone 6: Settings UI for Jurisdiction and Rule

### Goal

Let user choose country, jurisdiction, and compliance rule.

### Codex prompt

```text
Build the initial Settings UI.

Implement:
1. SettingsView sections for:
   - Country
   - Jurisdiction
   - Requirement type
   - Fixed required days
   - Percentage required
   - Prorate fixed target for leave
   - Minimum office minutes
   - Workdays
2. Use a temporary in-memory SettingsModel or SwiftData-backed ComplianceRule, whichever is simpler and clean.
3. AU jurisdiction picker appears when Australia is selected.
4. NZ jurisdiction picker appears when New Zealand is selected.
5. Save changes locally.
6. Keep UI simple and native SwiftUI.

Do not add location setup yet.
```

### Acceptance criteria

- User can change country and jurisdiction.
- User can switch requirement type.
- Fixed and percentage inputs validate basic ranges.
- App relaunch retains settings if SwiftData persistence is used.

### Suggested commit

```text
feat: add compliance and jurisdiction settings
```

---

## Milestone 7: Manual Attendance, Leave, and Notes

### Goal

Allow manual use of the app before location tracking exists.

### Codex prompt

```text
Build manual attendance editing.

Implement:
1. MonthCalendarView with a basic month grid.
2. DayDetailView.
3. Ability to set final status manually:
   - Office
   - Home
   - Mixed
   - Annual leave
   - Sick leave
   - Unknown
4. Ability to add/edit a note.
5. Ability to add full-day annual leave or sick leave.
6. Leave records must update the compliance calculation.
7. Show a badge on calendar cells.
8. Show public holiday labels when loaded from HolidayService.

Do not implement Core Location yet.
```

### Acceptance criteria

- User can mark a day as annual leave.
- Annual leave reduces eligible days.
- User can mark a day as sick leave.
- Sick leave reduces eligible days.
- User can add a note, for example "Forgot work pass".
- Calendar updates after edits.
- Dashboard summary updates after edits.

### Suggested commit

```text
feat: add manual attendance leave and notes
```

---

## Milestone 8: Dashboard Summary

### Goal

Show compliance summary clearly.

### Codex prompt

```text
Build the DashboardView using the compliance calculator.

Show:
1. Current month.
2. Completed office days.
3. Required office days.
4. Remaining office days.
5. Base eligible days before leave.
6. Annual leave excluded.
7. Sick leave excluded.
8. Adjusted eligible compliance days.
9. Public holidays excluded.
10. Status: complete, on track, at risk, impossible.
11. Days requiring review.

Add simple metric cards.
Use real calculated data where available.
Use preview data for SwiftUI previews.
```

### Acceptance criteria

- Dashboard reflects manual leave and attendance changes.
- Fixed prorated rule displays adjusted requirement.
- Percentage rule displays requirement from adjusted eligible days.
- No raw event/location logic is required.

### Suggested commit

```text
feat: add compliance dashboard
```

---

## Milestone 9: CSV Export First

### Goal

Create a practical export path before styled PDF or real XLSX.

### Codex prompt

```text
Implement CSV export.

Create:
1. ReportSnapshot model that gathers summary, daily records, leave records, manual adjustments, public holidays, and settings.
2. CSVExportService.
3. ExportView with:
   - selected month
   - include notes toggle
   - generate CSV button
   - ShareLink for generated file

CSV files:
- summary.csv
- daily_records.csv
- leave.csv
- manual_overrides.csv
- public_holidays.csv

If multiple CSV files are awkward to share, create one CSV file with sections.

Do not include raw location events.
Do not include GPS coordinates.
```

### Acceptance criteria

- User can generate and share a CSV export.
- CSV contains summary and daily records.
- Notes are included only when toggle is on.
- No raw location data is exported.

### Suggested commit

```text
feat: add CSV attendance export
```

---

## Milestone 10: Styled PDF Export

### Goal

Generate a shareable monthly PDF report.

### Codex prompt

```text
Implement styled PDF export.

Create:
1. PDFExportService.
2. A simple report layout:
   - title
   - period
   - jurisdiction
   - compliance rule
   - result summary
   - business day and leave calculation
   - daily records table
   - leave summary
   - manual notes and overrides
   - public holiday source summary
3. ExportView option for PDF.
4. ShareLink for the generated PDF file.

Use native Apple PDF APIs. Keep styling simple and maintainable.

Do not include raw location events.
Do not include GPS coordinates.
```

### Acceptance criteria

- PDF is generated to a temporary or documents directory.
- PDF opens in iOS preview/share sheet.
- PDF includes leave-adjusted requirement.
- PDF contains notes only when include-notes toggle is on.
- PDF does not include raw GPS data.

### Suggested commit

```text
feat: add styled PDF report export
```

---

## Milestone 11: Excel-Compatible Export

### Goal

Add Excel-compatible export.

Current dependency decision:

- Keep CSV as the MVP Excel-compatible export.
- Defer native `.xlsx` workbook generation to a later enhancement.
- Do not add a Swift Package for this milestone unless the milestone is explicitly reopened for native `.xlsx` implementation.

### Recommended sequence

1. Keep CSV export working.
2. Document CSV as the supported MVP Excel-compatible format.
3. If native `.xlsx` is later required, re-check Swift Package options before implementation.
4. Add one package only after checking:
   - active maintenance
   - iOS support
   - license
   - app size impact
   - whether it supports writing, not just reading
5. For native `.xlsx`, implement workbook tabs:
   - Summary
   - Daily Records
   - Leave
   - Manual Overrides
   - Public Holidays
   - Settings

### Codex prompt

```text
Implement Excel-compatible export.

First inspect the project and current export services.

Preferred:
- Keep CSV as the MVP Excel-compatible export.
- Do not add an .xlsx package unless this prompt is explicitly revised to request native .xlsx.
- Document native .xlsx as a later enhancement.

The workbook or CSV sections should include:
1. Summary
2. Daily Records
3. Leave
4. Manual Overrides
5. Public Holidays
6. Settings

Rules:
- No raw location events by default.
- No GPS coordinates by default.
- Notes controlled by include-notes toggle.
- The Summary sheet must show base eligible days, annual leave, sick leave, adjusted eligible days, base requirement, adjusted requirement, completed office days, remaining office days, and status.
```

### Acceptance criteria

- Export creates either a valid `.xlsx` workbook or a clearly labelled CSV fallback.
- Excel/Numbers can open the file.
- Workbook/CSV includes required tabs or sections.
- No private raw location data is exported by default.

### Suggested commit

```text
feat: add excel-compatible attendance export
```

---

## Milestone 12: Location Setup UI

### Goal

Let the user configure home and office places.

### Codex prompt

```text
Build location setup UI without background tracking yet.

Implement:
1. LocationSetupView.
2. PlaceEditorView.
3. MapPickerView using MapKit.
4. Ability to create/edit:
   - Home place
   - Office place
5. Radius selector with default 150 metres.
6. Store places using SwiftData.

Do not request Always location yet.
Do not start geofence monitoring yet.
```

### Acceptance criteria

- User can add home location.
- User can add office location.
- Places persist.
- Radius is configurable.
- Map picker works in Simulator with manual pin selection.

### Suggested commit

```text
feat: add home and office location setup
```

---

## Milestone 13: Location Authorization

### Goal

Add a careful location permission flow.

### Codex prompt

```text
Implement location authorization flow.

Create:
1. LocationAuthorizationService.
2. UI in LocationSetupView explaining why location is needed.
3. Request When In Use authorization first.
4. Add an explicit second step for Always authorization, only after the user enables automatic background tracking.
5. Show current permission status.
6. Add required Info.plist privacy usage strings.

Do not start geofence monitoring yet.
```

### Acceptance criteria

- App requests When In Use permission only after user action.
- Always permission is not requested on first launch.
- User can see current permission state.
- App handles denied/restricted states gracefully.

### Suggested commit

```text
feat: add location authorization flow
```

---

## Milestone 14: Geofence Tracking

### Goal

Detect entering/exiting home and office regions.

### Codex prompt

```text
Implement geofence tracking.

Create:
1. LocationTrackingService.
2. Register monitored regions for active home and office places.
3. Persist LocationEvent records for:
   - enter home
   - exit home
   - enter office
   - exit office
4. Add debug screen or log view visible only in debug builds.
5. Handle iOS region monitoring limitations gracefully.
6. Do not continuously track GPS.

Rules:
- Use geofencing/region monitoring rather than constant GPS.
- Store derived events.
- Do not export raw location events by default.
```

### Acceptance criteria

- Service registers geofences for active places.
- Entry/exit events are stored.
- Debug view can show recent events.
- App still works manually if permission is denied.

### Suggested commit

```text
feat: add geofence event tracking
```

---

## Milestone 15: Attendance Inference

### Goal

Convert location events into daily attendance classifications.

### Codex prompt

```text
Implement attendance inference from location events.

Create:
1. AttendanceInferenceService.
2. Logic to estimate officeMinutes and homeMinutes per date using enter/exit events.
3. If officeMinutes >= rule.minimumOfficeMinutes, classify as Office or Mixed.
4. If homeMinutes > 0 and office threshold is not met, classify as Home.
5. If insufficient data, classify as Unknown.
6. Preserve manual overrides.
7. Preserve leave/public holiday exclusions.
8. Recalculate affected AttendanceDay records when events change.

Rules:
- Manual override wins over detected status.
- Leave/public holiday exclusion affects compliance treatment.
- Detection is evidence, not the final truth.
```

### Acceptance criteria

- Office visit above threshold counts as office.
- Office visit below threshold does not count as office unless manually overridden.
- Manual override is not overwritten by later inference.
- Leave day remains excluded even if location events exist.

### Suggested commit

```text
feat: infer attendance from location events
```

---

## Milestone 16: Polish and Hardening

### Goal

Make the MVP usable.

### Tasks

- Empty states.
- Error messages.
- Data reset option.
- Privacy explanation.
- Export file naming.
- Better date formatting.
- Basic accessibility labels.
- Unit test cleanup.
- Manual QA script.

### Suggested commit

```text
chore: polish MVP usability and privacy defaults
```

---

## 13. Manual QA Script

Run this before calling the MVP usable.

### Setup

1. Select Australia.
2. Select Victoria.
3. Set fixed monthly target to 10 days.
4. Keep prorate for leave on.
5. Set minimum office minutes to 180.
6. Use Monday-Friday workdays.

### Manual data

For a month with 23 weekdays and 0 public holidays in the loaded test fixture:

1. Mark 7 office days.
2. Add 3 annual leave days.
3. Add 1 sick leave day.
4. Add note to one office day:
   ```text
   Forgot work pass. Entered via reception.
   ```

### Expected result

```text
Base eligible days: 23
Annual leave excluded: 3
Sick leave excluded: 1
Adjusted eligible days: 19
Base required days: 10
Adjusted required days: 9
Office days completed: 7
Office days remaining: 2
```

### Export checks

CSV/PDF/Excel should include:

- Summary.
- Daily records.
- Leave records.
- Manual override/note.
- Public holiday source.

Exports should not include:

- GPS coordinates.
- Raw location events.
- Work reconciliation fields.

---

## 14. Coding Standards

### 14.1 General

- Keep business logic out of SwiftUI views.
- Put calculations in services with tests.
- Prefer value types for calculation inputs/outputs.
- Keep SwiftData models thin.
- Use clear names rather than clever abstractions.
- Avoid force unwraps.
- Use dependency injection for services where practical.
- Keep date handling deterministic in tests.

### 14.2 Date handling

- Store day records using start-of-day dates.
- Use Gregorian calendar.
- Use the user’s selected locale/time zone unless a specific jurisdiction time zone is required.
- Tests should use a fixed calendar and time zone.
- Avoid comparing raw `Date` values when the intention is calendar day equality.

### 14.3 Privacy

- Do not show or export raw GPS by default.
- Do not track continuously unless explicitly required.
- Keep location permission messaging clear.
- Store only derived day-level data where possible.

### 14.4 Dependencies

Before adding a package:

- Check license.
- Check iOS support.
- Check recent maintenance.
- Check whether it supports writing, not just reading.
- Prefer Swift Package Manager.
- Document why the dependency was added.

---

## 15. Backlog After MVP

Do not build these until the MVP is stable:

- Half-day leave support.
- Custom leave hours.
- iCloud sync.
- Import public holiday updates from official APIs.
- Calendar app integration.
- Widgets.
- Watch app.
- Multiple office locations beyond the first office.
- Quarterly and rolling compliance periods.
- Import/export backup file.
- App lock / Face ID.
- Charts and trends.
- Siri Shortcuts.
- Badge/report import. Not currently needed.

---

## 16. Useful Codex Working Rules

Use these rules when assigning tasks to Codex.

### 16.1 One task at a time

Each Codex task should have:

```text
Goal
Files to touch
Files not to touch
Acceptance criteria
Tests to run
Commit message
```

### 16.2 Start with tests for calculators

For compliance, holidays, and exports:

```text
Tests first where practical.
```

For UI:

```text
Small view first, then wire data.
```

### 16.3 Do not let Codex overbuild

Tell Codex explicitly:

```text
Do not implement future backlog items.
Do not add network calls unless the task asks for them.
Do not add a work reconciliation field.
Do not use continuous GPS tracking.
Do not export raw location data by default.
```

### 16.4 Ask Codex to summarize changes

After each task, ask Codex for:

```text
Files changed
Tests added
Tests run
Known limitations
Next recommended task
```

---

## 17. First Three Codex Prompts to Use

### Prompt 1: Scaffold

```text
You are working on a native SwiftUI iOS app named Work Track.

Use docs/WorkTrack_Codex_Build_Plan.md as the product and technical guide.

Task:
Create the initial app scaffold only.

Implement:
- App shell with TabView.
- Dashboard tab.
- Calendar tab.
- Export tab.
- Settings tab.
- Folder structure from the build plan.
- Placeholder SwiftUI views with simple titles.

Do not add SwiftData models yet.
Do not add business logic yet.
Do not add location permissions yet.
Do not add dependencies.

Acceptance criteria:
- App builds.
- App runs in Simulator.
- Four tabs are visible.
- Placeholder views compile.
```

### Prompt 2: Domain Types

```text
Use docs/WorkTrack_Codex_Build_Plan.md.

Task:
Add the core domain types and jurisdiction catalog.

Implement:
- Country
- Jurisdiction
- JurisdictionCatalog
- AttendanceClassification
- ComplianceTreatment
- LeaveType
- LeaveDuration
- RequirementType
- ComplianceStatus

Add unit tests:
- AU jurisdictions include ACT, NSW, NT, QLD, SA, TAS, VIC, WA.
- NZ jurisdictions include NZ-NATIONAL and NZ-AUCKLAND.
- Jurisdiction IDs are unique.
- Country display names are correct.

Do not add SwiftData models yet.
Do not add UI beyond what already exists.
```

### Prompt 3: Compliance Calculator

```text
Use docs/WorkTrack_Codex_Build_Plan.md.

Task:
Implement the leave-adjusted compliance calculator.

Rules:
- Selected workdays use ISO weekdays, Monday = 1.
- Public holidays exclude eligible days.
- Full-day annual leave reduces eligible days by 1.0.
- Full-day sick leave reduces eligible days by 1.0.
- Leave only reduces eligible days if the date would otherwise be eligible.
- Leave on weekends has zero impact.
- Leave on public holidays has zero impact.
- Multiple leave records on one date are capped at 1.0.
- Percentage rule uses ceil(adjustedEligibleDays * percentage).
- Fixed monthly rule prorates if enabled:
  ceil(baseRequiredDays * adjustedEligibleDays / baseEligibleDays)

Add tests:
1. 23 workdays, no holidays, 3 annual leave, 1 sick leave, 50% rule -> eligible 19, required 10.
2. Fixed target 10, base eligible 23, adjusted 19, prorated -> required 9.
3. Fixed target 10, prorating off -> required 10.
4. Weekend leave does not reduce eligible days.
5. Public holiday leave does not double reduce.
6. Duplicate leave records are capped.

Do not add UI.
Do not add location tracking.
```

---

## 18. Reference Links

Apple documentation:

- Xcode support and SDK/deployment target ranges: https://developer.apple.com/support/xcode/
- SwiftUI: https://developer.apple.com/documentation/swiftui
- SwiftData: https://developer.apple.com/documentation/swiftdata
- Core Location: https://developer.apple.com/documentation/corelocation
- Requesting location authorization: https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services
- Request Always authorization: https://developer.apple.com/documentation/corelocation/cllocationmanager/requestalwaysauthorization%28%29
- Choosing location services authorization: https://developer.apple.com/documentation/bundleresources/choosing-the-location-services-authorization-to-request
- MapKit for SwiftUI: https://developer.apple.com/documentation/mapkit/mapkit-for-swiftui
- UIGraphicsPDFRenderer: https://developer.apple.com/documentation/uikit/uigraphicspdfrenderer

Public holiday sources:

- Fair Work Australia public holidays: https://www.fairwork.gov.au/employment-conditions/public-holidays
- Fair Work 2026 public holidays: https://www.fairwork.gov.au/employment-conditions/public-holidays/2026-public-holidays
- Victorian Government Important Dates API: https://discover.data.vic.gov.au/dataset/government-dates-api-data
- New Zealand public holidays and anniversary dates: https://www.employment.govt.nz/leave-and-holidays/public-holidays/public-holidays-and-anniversary-dates
- New Zealand government public holidays: https://www.govt.nz/browse/work/public-holidays-and-work/public-holidays-and-anniversary-dates/

OpenAI Codex references:

- Codex overview: https://developers.openai.com/codex
- Codex CLI: https://developers.openai.com/codex/cli
- Codex IDE extension: https://developers.openai.com/codex/ide
- Using Codex with ChatGPT plan: https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan

Possible Excel export packages to evaluate:

- Objects2XLSX: https://swiftpackageindex.com/fatbobman/Objects2XLSX
  - Preferred future SwiftPM candidate if native `.xlsx` export becomes necessary.
  - Supports writing `.xlsx` files and has iOS support.
- libxlsxwriter: https://swiftpackageindex.com/jmcnamara/libxlsxwriter
  - Mature writer, but higher integration complexity because it is a C API.
- CoreXLSX: https://swiftpackageindex.com/CoreOffice/CoreXLSX
  - Read-only parser, not suitable for export generation.
- SwiftXLSX: https://github.com/3973770/SwiftXLSX
  - Writes `.xlsx`, but appears stale compared with other options.
- XlsxReaderWriter: https://charlymr.github.io/XlsxReaderWriter/
  - Can modify and save workbooks, but cannot create workbooks from scratch.
- xlsxwriter.swift: https://github.com/damuellen/xlsxwriter.swift
  - Swift wrapper around libxlsxwriter, but still carries the underlying C library integration considerations.

Current recommendation:

- Keep CSV as the MVP Excel-compatible export and document native `.xlsx` as a later enhancement.
