# Work Track iOS MVP Build and Release Plan

Version: 1.0 release candidate
Updated: 2026-07-11
Platform: Native iOS, SwiftUI
Minimum deployment: iOS 27.0+
User-facing app name: **Work Track**

## 1. Purpose

Work Track is a private, on-device iPhone app for recording office/home attendance and evaluating hybrid-work compliance. It supports manual attendance, full-day annual and sick leave, public holidays, custom excluded days, manual overrides and notes, compliance trends, and user-facing PDF and CSV reports.

This document describes the implemented MVP contract and the remaining release work. When it differs from an older milestone prompt or roadmap note, this document and `AGENTS.md` are the current source of truth.

## 2. MVP Product Contract

### 2.1 Countries and jurisdictions

The MVP supports these bundled jurisdiction choices:

- Australia: ACT, NSW, NT, QLD, SA, TAS, VIC, and WA.
- New Zealand: NZ National plus Northland, Auckland, Taranaki, Hawke's Bay, Wellington, Marlborough, Nelson, Canterbury, South Canterbury, Westland, Otago, Southland, and Chatham Islands.

New Zealand regional fixtures inherit the national holiday set. Calculations and reports must use only the active jurisdiction.

### 2.2 Compliance periods

The dashboard defaults to the current calendar month. The Compliance, Records, and Export surfaces support the same seven period choices:

1. Current month.
2. Last 30 days, including today.
3. Previous month.
4. Current quarter.
5. Previous quarter.
6. Year to date.
7. Custom date range.

All period boundaries are inclusive and normalized to calendar days. If a custom end date precedes its start date, the range is normalized before calculation.

Do not add open-ended analytics periods to the MVP.

### 2.3 Compliance trends

The dashboard includes recent-progress views at these granularities:

- Monthly.
- Quarterly.
- Yearly.

Trend buckets use the same workdays, jurisdiction holidays, leave, custom exclusions, attendance treatment, and compliance rule as the period evaluator. A period is marked as containing recorded data when it includes attendance, leave, or a custom exclusion.

### 2.4 Attendance source of truth

Keep these concepts separate:

```text
Detected status = evidence inferred by the app.
Final status = the classification used for compliance after exclusions and overrides.
Note = explanatory text only unless paired with leave or an override.
```

A note alone must never change the final status. Manual overrides take precedence over detected attendance. Leave, holidays, weekends, non-working days, and custom exclusions remain excluded even when attendance evidence exists.

Do not add employer badge/work reconciliation fields or reports.

### 2.5 Eligible compliance days

```text
Eligible compliance days =
    selected workdays
    - active-jurisdiction public holidays
    - full-day annual leave
    - full-day sick leave
    - custom excluded days
```

Rules:

- Selected workdays use ISO weekdays, Monday = 1 and Sunday = 7.
- Leave reduces eligibility only when the date would otherwise be an eligible workday.
- Weekend leave has no eligible-day impact.
- Leave on a public holiday has no additional impact.
- Multiple leave records on one date are capped at one full day.
- A custom exclusion affects only an otherwise eligible workday.
- A custom exclusion does not double-reduce a day already excluded by leave or a holiday.
- Custom excluded days may include an optional user-entered reason.
- Half-day leave is not part of the MVP calculation contract.

### 2.6 Requirement types

The MVP supports two saved rule types.

Percentage of eligible days:

```text
requiredOfficeDays = ceil(adjustedEligibleDays * requiredPercentage)
```

Fixed days for the selected period, with leave/exclusion prorating on by default:

```text
requiredOfficeDays = ceil(baseRequiredDays * adjustedEligibleDays / baseEligibleDays)
```

When fixed-target prorating is off, the saved fixed requirement is unchanged. When there are no base eligible days, the calculator must avoid division by zero.

### 2.7 Exports

The MVP provides:

- Styled PDF.
- CSV as the supported Excel-compatible format.

Reports use the selected built-in or custom period and include summary totals and day-level records. Notes, manual overrides, custom exclusions, and public holiday source details may be included. Native `.xlsx` is not required for MVP and must not introduce a package dependency without a separate dependency review.

Default exports must exclude:

- Raw GPS coordinates.
- Raw location events.
- Raw location traces.
- Employer badge/work reconciliation data.

CSV fields must remain safe when opened in spreadsheet software, including neutralizing formula-like user text.

### 2.8 Privacy and data management

- User data is stored in the app's local SwiftData store by default.
- The app has no account, analytics, advertising, app-managed cloud sync, or developer-operated network service in the MVP.
- User-initiated address search and address lookup use Apple Maps. Apple may process the search text, map context, or location under its privacy terms; the Work Track developer does not receive that data.
- Saved place names, formatted addresses, coordinates, and radii remain in the app's on-device SwiftData store.
- Bundled holiday source URLs are attribution metadata; the MVP does not fetch those URLs.
- Generated reports leave the app only when the user invokes the system share flow.
- Settings provides a Privacy & Data screen describing local storage and export behavior.
- Delete All On-Device Data requires destructive confirmation.
- Reset deletes user attendance, leave, notes, overrides, rules, custom exclusions, places, stored location events, user-edited holidays, and generated reports, then restores one default compliance rule.
- Reset does not revoke iOS permissions, erase copies previously shared to another destination, or control data retained by device backups.

### 2.9 Location scope

The MVP supports saving one home and one office place primarily by address search or current location, with map adjustment as a fallback. Coordinates remain stored on-device for location logic but are not exposed as normal user input. Automatic background detection is intentionally unavailable:

- Do not request location permission on first launch, when opening setup, or when searching for an address.
- Request When In Use authorization only after the user explicitly chooses Use Current Location and sees an in-app explanation.
- Use a single current-location request to select the place; do not keep location updates running.
- Do not request Always authorization in the MVP.
- Do not enable the Background Modes location capability.
- Do not start geofence monitoring in the production MVP path.
- Do not continuously track GPS.
- Manual attendance remains the supported path when automatic detection is unavailable.

Location domain and inference foundations may remain in the codebase, but user-facing copy must not promise automatic background tracking.

## 3. Implemented MVP Baseline

The live implementation includes:

- A SwiftUI tab shell for Dashboard, Records, Calendar, Export, and Settings.
- SwiftData persistence for attendance, leave, overrides, compliance rules, places, location events, public holidays, and custom excluded days.
- Manual day editing, full-day annual/sick leave, notes, overrides, and batch leave entry.
- The seven deterministic compliance period presets and normalized custom ranges.
- Monthly, quarterly, and yearly compliance trend calculations.
- Percentage and fixed-target compliance calculations with exclusion handling.
- Bundled 2026 holiday data for every supported AU and NZ jurisdiction.
- NZ national-to-regional holiday inheritance and active-jurisdiction filtering.
- Styled PDF and spreadsheet-safe CSV export.
- Address-first home and office place setup with explicit, one-shot current-location selection.
- Privacy explanations and confirmed on-device reset.
- Unit and UI test targets in the shared Xcode scheme.
- A privacy manifest declaring no tracking or data collection by the developer for the current build.

This baseline must continue to compile and pass tests as release work proceeds.

## 4. Date and Period Handling

- Normalize day-level data with a Gregorian calendar before comparison.
- Keep test calendars and time zones deterministic.
- Treat period start and end dates as inclusive.
- Current month spans the first through last day of the current month.
- Last 30 days starts 29 days before today and ends today.
- Previous month spans the complete preceding calendar month.
- Current and previous quarters use calendar-quarter boundaries.
- Year to date starts on January 1 and ends today.
- Custom ranges normalize reversed boundaries rather than calculating an invalid interval.
- Future attendance must not count as completed or as requiring review.

## 5. Holiday Data Contract

### 5.1 Bundled horizon

The release bundle contains verified-exhaustive holiday fixtures for calendar year **2026 only**. Each supported Australian jurisdiction has its own fixture. NZ National has its own fixture, and every supported NZ regional fixture inherits NZ National.

This is an explicit release horizon, not a promise of perpetual holiday coverage. A period that requires holiday data outside 2026 is not fully supported by the bundled MVP dataset and must never silently imply that there are no holidays.

Before shipping a build intended for use beyond 2026, add and verify the next required year for every supported jurisdiction, extend tests, and update user-facing release notes.

### 5.2 Fixture validation

Holiday files use ISO `yyyy-MM-dd` dates and include:

- Schema version.
- Country and jurisdiction IDs.
- Calendar year.
- Official source name and HTTPS source URL.
- `verifiedExhaustive` status.
- Optional NZ National inheritance.
- Holiday names, dates, and regional status.

The local provider must return typed errors for missing files, unsupported jurisdictions, unverified files, and invalid data. It must not treat missing data as an empty holiday calendar.

### 5.3 Persistence

Bundled holidays are synchronized into local storage for the active country, jurisdiction, and current year. Stable IDs make synchronization repeatable. A user-edited holiday is preserved instead of overwritten by a later local sync.

There is no remote holiday refresh in MVP.

## 6. Core User Journeys

### 6.1 First launch and settings

1. Launch without an account or immediate permission request.
2. Choose country and jurisdiction.
3. Choose fixed or percentage requirement.
4. Configure workdays and the minimum office minutes value.
5. Review Privacy & Data behavior.

### 6.2 Manual attendance

1. Open a calendar day.
2. Set or clear a manual attendance override.
3. Add annual leave or sick leave.
4. Add an explanatory note.
5. Optionally mark an eligible workday as custom excluded with a reason.
6. Verify the calendar, dashboard, compliance, records, and exports agree.

### 6.3 Compliance review

1. Review the current-month dashboard.
2. Inspect recent monthly, quarterly, or yearly progress.
3. Open Compliance or Records.
4. Select any built-in period or a custom range.
5. Verify inclusive boundaries, exclusions, required days, completed days, and review-required days.

### 6.4 Reporting

1. Select a built-in or custom report period.
2. Choose PDF or CSV.
3. Choose whether notes are included where offered.
4. Generate, preview where supported, and share through the system share flow.
5. Verify the file excludes raw location data.

### 6.5 Delete/reset

1. Open Settings > Privacy & Data.
2. Read the deletion scope.
3. Cancel once to prove no accidental deletion.
4. Confirm Delete All On-Device Data.
5. Verify all user records and generated reports are removed and one default compliance rule is restored.

## 7. UI and Accessibility Bar

- Use native SwiftUI controls and established design-system tokens.
- Keep status and metric hierarchy calm and readable.
- Provide meaningful empty, error, disabled, permission-denied, and destructive-confirmation states.
- Support Dynamic Type without clipping primary controls or values.
- Preserve VoiceOver labels and identifiers for primary QA journeys.
- Keep touch targets at least the system-recommended size.
- Do not rely on color alone for attendance or compliance meaning.
- Use user-facing language that distinguishes detected status, final status, leave, holiday, and custom exclusion.

## 8. Test and Release Gates

Before declaring the MVP ready:

1. Build Debug and Release for an iOS simulator destination.
2. Run the full unit-test target.
3. Run the golden-journey UI test target serially on a supported iOS 27 simulator.
4. Run static analysis.
5. Complete `docs/QA_MVP_Checklist.md` on a clean install.
6. Inspect generated PDF and CSV files for content, formatting, and privacy.
7. Verify every supported 2026 holiday fixture loads and includes source metadata.
8. Confirm missing-year holiday data produces a visible error rather than a zero-holiday assumption.
9. Confirm the privacy manifest and App Store privacy answers match the release binary.
10. Recheck signing, bundle ID, app category, version/build, icon, screenshots, and hosted support/privacy URLs.

Record the simulator/device, OS version, test result bundle, screenshots, and any unverified risk in the release handoff.

## 9. Release Configuration

Current intended App Store values:

```text
Display name: Work Track
Bundle identifier: com.benchamberlain.worktrack
Category: Business
Marketing version: 1.0
Build number: 1
Minimum iOS version: 27.0
```

The repository can define these values, but the owner must supply or confirm signing and App Store Connect information. See `docs/APP_STORE_METADATA.md` for the release copy draft and owner-only inputs.

## 10. External Owner Inputs Required Before Submission

Do not invent any of these values:

- Apple Developer team and distribution signing configuration.
- App Store Connect app record and SKU.
- Hosted support URL.
- Hosted privacy-policy URL.
- App privacy questionnaire confirmation against the final binary.
- Content-rating questionnaire.
- Final App Store screenshots and preview decisions.
- Availability, pricing, copyright, and contact details.

These are release blockers for submission but are not code defects.

## 11. Post-MVP Backlog

Keep these outside the current MVP unless explicitly reopened:

- Holiday datasets beyond the currently verified 2026 horizon.
- Remote holiday update/import service.
- Half-day leave and custom leave hours.
- Native `.xlsx` workbook output.
- Automatic background location detection, geofencing, or Always permission.
- Continuous GPS tracking, which remains prohibited.
- iCloud or other app-managed sync.
- Backup-file import/export.
- App lock or Face ID.
- Widgets, Watch app, Siri Shortcuts, and calendar integration.
- Multiple office locations.
- Employer badge/report reconciliation.
- Additional open-ended analytics period types.

## 12. Working Rules for Future Changes

- Start with the smallest testable slice.
- Keep business logic out of SwiftUI views.
- Use SwiftData for local persistence and async/await where asynchronous work is needed.
- Add no dependency without checking maintenance, iOS support, license, and app-size impact.
- Preserve privacy-safe export defaults.
- Update tests, this plan, QA documentation, metadata, and privacy language when behavior changes.
- Report files changed, tests run, known limitations, and the next release risk after each slice.
