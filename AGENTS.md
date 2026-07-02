# AGENTS.md

Guidance for coding agents working on Work Track.

## App Purpose

Work Track is a private native SwiftUI iOS app for tracking office/home attendance and monthly hybrid-work compliance. It supports Australia and New Zealand from the MVP, uses selected jurisdiction public holidays, supports annual and sick leave, allows manual overrides and notes, and exports user-facing monthly reports.

Personal attendance data must be stored on-device by default.

## MVP Scope

- Platform: native iOS, SwiftUI.
- Minimum deployment target: iOS 27.0+.
- Compliance period: calendar month only.
- Jurisdictions: all AU states/territories plus NZ National and listed NZ regional/provincial anniversary options.
- Attendance concepts must remain separate:
  - detected status: inferred by the app.
  - final status: used for compliance after holidays, leave, and manual overrides.
  - note: explanatory text only unless paired with leave or override.
- Initial exports: styled PDF and Excel-compatible output, with CSV acceptable as an early fallback.
- Build in small, testable slices. Do not jump ahead to background location tracking before manual attendance, compliance calculation, and export foundations are stable.

## Coding Standards

- Follow existing project structure and SwiftUI patterns.
- Use SwiftUI for UI and SwiftData for persistence when persistence is needed.
- Prefer async/await APIs. Avoid adding Combine.
- Use PascalCase for types and camelCase for properties and methods.
- Use `@State private var` for SwiftUI-local state and `let` for constants.
- Keep changes scoped to the requested task.
- Do not add dependencies unless the task explicitly requires dependency evaluation and the dependency has been checked for maintenance, iOS support, license, and app-size impact.
- Do not modify the Xcode project unless explicitly requested.

## Date Handling

- Use deterministic date handling in tests.
- Selected workdays use ISO weekdays: Monday = 1, Sunday = 7.
- Public holiday dates use ISO `yyyy-MM-dd` in bundled holiday JSON.
- Calculations must be month-bound for the MVP.
- Avoid timezone-sensitive comparisons by normalizing dates for day-level logic.

## Compliance Rules

Eligible compliance days:

```text
selected workdays
- public holidays
- annual leave
- sick leave
- custom excluded days
```

- Leave reduces eligible compliance days only when the date would otherwise be an eligible workday.
- Leave on weekends has zero eligible-day impact.
- Leave on public holidays has zero eligible-day impact and must not double-reduce eligibility.
- Multiple leave records on one date are capped at one full day of eligible-day impact.
- Implement full-day leave first. Half-day leave can be added only after full-day behavior is stable and tested.
- Percentage target: `ceil(adjustedEligibleDays * requiredPercentage)`.
- Fixed monthly target defaults to prorating for leave:
  `ceil(baseRequiredDays * adjustedEligibleDays / baseEligibleDays)`.
- The default setting for `prorateFixedTargetForLeave` is `true`.

## Privacy Defaults

- Store data on-device by default.
- Do not export raw GPS coordinates by default.
- Do not export raw location events by default.
- Default reports should contain derived day-level attendance, not sensitive raw location traces.
- Notes, manual overrides, and public holiday source details may be included by default in reports.
- Sensitive export options may be added later only as explicit user-controlled toggles.
- Do not request Always location permission on first launch. Explain value in-app first.
- Do not implement continuous GPS tracking. Use privacy-preserving Core Location capabilities such as geofencing or visit/location events when the location milestone is reached.

## Testing Expectations

- Add focused unit tests for domain logic and calculators.
- Compliance tests must cover:
  - leave reducing eligible days.
  - leave on weekends not reducing eligible days.
  - leave on public holidays not double-reducing days.
  - multiple leave records on one date capped at one day.
  - percentage requirements using `ceil`.
  - fixed monthly requirements with and without leave prorating.
- Holiday provider tests should cover bundled JSON loading, NZ regional inheritance, and typed missing-data errors.
- Export tests should validate report snapshots and confirm default exports exclude raw location events and GPS coordinates.

## Forbidden Overbuild

- No work/badge reconciliation field or report tab. Users do not have access to individual employer records.
- No continuous GPS tracking.
- No raw location export by default.
- No raw GPS coordinate export by default.
- No rolling, quarterly, or custom compliance periods in the MVP.
- No half-day leave in the first calculator milestone.
- No background location mode or Always permission flow until the planned location milestone.
- No new package dependencies during early scaffold, domain, calculator, or manual-entry milestones.
