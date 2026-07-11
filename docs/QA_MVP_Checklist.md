# Work Track MVP Manual QA Checklist

Use this checklist for manual QA before an MVP build is considered ready. Each test should be run on a clean simulator or device unless the setup explicitly says otherwise.

## Test Data Assumptions

- Use deterministic dates and verify inclusive start/end boundaries for each selected period.
- Selected workdays are Monday to Friday.
- Use full-day leave only.
- Keep attendance concepts separate:
  - detected status: inferred by location or manual test data.
  - final status: used for compliance after holidays, leave, and manual overrides.
  - note: explanatory text only unless paired with leave or override.
- Default exports must include derived day-level attendance only, not raw location events or raw GPS coordinates.

## 1. First Launch

### Steps

1. Install and launch Work Track with no existing app data.
2. Observe the initial screen.
3. Navigate through the main tabs or primary app sections.
4. Open Settings, Calendar, Export, and Location Setup if available.

### Expected Results

- The app launches without crashing.
- No existing attendance, leave, location, or export data is shown.
- Empty states are understandable and do not imply that tracking has already started.
- No location permission prompt appears immediately on first launch.
- The user can reach settings, calendar, export, and location setup screens.
- Personal attendance data appears local to the app and no account sign-in is required.

## 2. Jurisdiction Settings: AU-VIC

### Steps

1. Open Settings.
2. Select Australia as the country.
3. Select Victoria, `AU-VIC`, as the jurisdiction.
4. Save or leave the screen if settings auto-save.
5. Open the calendar for a month with a bundled Victorian public holiday.

### Expected Results

- Victoria is selectable as an Australian jurisdiction.
- The selected jurisdiction is displayed consistently as Victoria or `AU-VIC`.
- Public holidays from the Victorian holiday source appear on the correct dates.
- Victorian public holidays are excluded from eligible compliance days.
- Changing to `AU-VIC` does not remove existing manual notes or leave records for unrelated dates.

## 3. Jurisdiction Settings: NZ-AUCKLAND

### Steps

1. Open Settings.
2. Select New Zealand as the country.
3. Select Auckland, `NZ-AUCKLAND`, as the jurisdiction.
4. Save or leave the screen if settings auto-save.
5. Open the calendar for a month with a bundled New Zealand national holiday and a bundled Auckland regional anniversary holiday.

### Expected Results

- Auckland is selectable as a New Zealand regional jurisdiction.
- The selected jurisdiction is displayed consistently as Auckland or `NZ-AUCKLAND`.
- New Zealand national holidays appear for Auckland.
- Auckland regional/provincial anniversary holidays also appear.
- Both national and Auckland regional holidays are excluded from eligible compliance days.

## 4. Fixed Monthly Rule With Leave Prorating

### Steps

1. Select a month with known Monday to Friday workdays.
2. Configure a fixed monthly target, for example 10 required office days.
3. Confirm that fixed target leave prorating is enabled.
4. Record the base eligible day count before leave.
5. Add full-day annual leave on eligible workdays.
6. Return to the compliance summary.

### Expected Results

- The rule is shown as a fixed monthly target.
- `prorateFixedTargetForLeave` is enabled by default.
- Eligible days are reduced by leave only for selected workdays.
- Required office days are recalculated with:

```text
ceil(baseRequiredDays * adjustedEligibleDays / baseEligibleDays)
```

- The displayed required count matches the rounded-up prorated result.
- Leave on excluded days does not change the prorated target.

## 5. Percentage Rule

### Steps

1. Select a month with known eligible workdays.
2. Configure a percentage requirement, for example 50%.
3. Add or remove leave to change the adjusted eligible day count.
4. Return to the compliance summary.

### Expected Results

- The rule is shown as a percentage of eligible days.
- Required office days are calculated with:

```text
ceil(adjustedEligibleDays * requiredPercentage)
```

- The displayed required count always rounds up when the percentage result is fractional.
- Public holidays and qualifying leave reduce the denominator before the percentage is applied.

## 6. Annual Leave Reduces Eligible Days

### Steps

1. Select an ordinary weekday that is not a public holiday.
2. Add a full-day annual leave record for that date.
3. Open the calendar and compliance summary.

### Expected Results

- The date is marked as annual leave.
- The final status or compliance treatment excludes the date from the office requirement.
- Eligible compliance days decrease by one.
- Office-day progress is not penalized for that annual leave date.
- Any note attached to the leave record remains visible.

## 7. Sick Leave Reduces Eligible Days

### Steps

1. Select an ordinary weekday that is not a public holiday.
2. Add a full-day sick leave record for that date.
3. Open the calendar and compliance summary.

### Expected Results

- The date is marked as sick leave.
- The final status or compliance treatment excludes the date from the office requirement.
- Eligible compliance days decrease by one.
- Office-day progress is not penalized for that sick leave date.
- Any note attached to the leave record remains visible.

## 8. Leave On Weekend Has Zero Impact

### Steps

1. Select a Saturday or Sunday outside the selected workdays.
2. Add a full-day annual leave or sick leave record.
3. Open the compliance summary.

### Expected Results

- The leave record can be viewed if the app allows weekend leave entry.
- Eligible compliance days do not change.
- Required office days do not change.
- The weekend is not counted as an eligible day before or after leave.
- The app does not double-count or otherwise inflate leave impact.

## 9. Public Holiday Exclusion

### Steps

1. Select a weekday public holiday from the active jurisdiction.
2. Open the day details.
3. Add no leave for the date.
4. Open the compliance summary.
5. Optionally add leave to the same public holiday and recheck the summary.

### Expected Results

- The date is marked as a public holiday with the holiday name if available.
- The final status or compliance treatment excludes the date from the office requirement.
- Eligible compliance days are reduced by one for the public holiday.
- Adding leave on the same public holiday does not reduce eligible days a second time.
- Public holiday source details may appear in user-facing reports.

## 10. Manual Note For Forgotten Work Pass

### Steps

1. Select an ordinary weekday where the detected status is home, unknown, or below the office threshold.
2. Add a manual note such as `Forgot work pass`.
3. Do not add a manual status override.
4. Save and return to the calendar and compliance summary.
5. Reopen the day details.

### Expected Results

- The note is saved and visible when reopening the day.
- The note alone does not change the final compliance status.
- The detected status remains unchanged.
- The day still requires review or follows the existing detected/final status rules unless a manual override is added.
- The note is included in default user-facing exports if reports include notes.

## 11. CSV Export

### Steps

1. Prepare a selected period containing office days, home days, leave, a public holiday, and a manual note.
2. Open Export.
3. Generate a CSV or Excel-compatible export.
4. Open the exported file in a spreadsheet app or text editor.

### Expected Results

- The export completes without crashing.
- The file contains one row for every day in the inclusive selected period.
- Derived day-level fields are present, such as date, detected status, final status or treatment, office/home summary, leave, holiday, and note where supported.
- The file excludes raw GPS coordinates by default.
- The file excludes raw location events by default.
- The period and compliance totals match the app summary, including custom exclusions.

## 12. PDF Export

### Steps

1. Prepare a selected period containing office days, home days, leave, a public holiday, and a manual note.
2. Open Export.
3. Generate a PDF report.
4. Open the generated PDF.

### Expected Results

- The export completes without crashing.
- The PDF is readable and styled for user-facing review.
- The report includes the selected inclusive period, jurisdiction, compliance rule, required office days, achieved office days, and relevant day-level attendance details.
- Leave, custom exclusions, and public holiday exclusions are visible.
- Manual notes are visible where report detail includes notes.
- The PDF excludes raw GPS coordinates by default.
- The PDF excludes raw location events by default.

## 13. Location Setup

### Steps

1. Open Location Setup.
2. Add or edit a home place.
3. Add or edit an office place.
4. Confirm each place has a clear name and selected area or coordinate-derived location.
5. Save and revisit Location Setup.

### Expected Results

- Home and office can be configured separately.
- Saved places persist after leaving and returning to Location Setup.
- The UI explains location-based attendance before requesting sensitive permissions.
- No continuous GPS tracking is started by simply opening setup.
- Location setup does not overwrite manual attendance, leave, public holiday, or note data.

## 14. Location Permission Is Deferred

### Steps

1. Start from a clean install with location permissions reset.
2. Launch the app.
3. Confirm no permission prompt appears on first launch.
4. Navigate to Location Setup.
5. Confirm Automatic Detection is shown as unavailable.
6. Add or edit places without accepting a location permission prompt.

### Expected Results

- No location permission request is offered while automatic detection is unavailable.
- The app does not request When In Use or Always authorization.
- Saved-place editing and manual attendance remain available.
- Location-based inference remains disabled.
- The app does not enable continuous GPS tracking.

## 15. Privacy Checks: No Raw GPS Export By Default

### Steps

1. Configure home and office locations.
2. Create or simulate attendance evidence for the selected month.
3. Generate CSV and PDF exports using default export options.
4. Inspect both exported files.
5. Search for latitude, longitude, coordinate pairs, raw event timestamps, and raw enter/exit event names.

### Expected Results

- Default exports contain derived day-level attendance only.
- Raw latitude values are not present.
- Raw longitude values are not present.
- Raw coordinate pairs are not present.
- Raw location events are not present.
- Raw GPS traces are not present.
- Office/home attendance summaries may be included only as derived values such as classification, minutes, or compliance treatment.

## 16. Built-In And Custom Compliance Periods

### Steps

1. Open Compliance, History, and Export.
2. Select current month, last 30 days, previous month, current quarter, previous quarter, and year to date.
3. For each preset, record the displayed inclusive start and end dates.
4. Select Custom, choose an end date before the start date, and leave the controls.

### Expected Results

- All six built-in presets resolve to deterministic inclusive boundaries.
- Last 30 days includes today and begins 29 calendar days earlier.
- Quarter boundaries use calendar quarters.
- Year to date begins on January 1 and ends today.
- A reversed custom range is normalized so the earlier date is the start.
- Compliance, History, and Export show the same records and boundaries.

## 17. Monthly, Quarterly, And Yearly Trends

### Steps

1. Prepare attendance, leave, and custom exclusions in more than one month.
2. Open Summary and switch the trend granularity between Monthly, Quarterly, and Yearly.
3. Compare each visible bucket with the same dates selected in Compliance.

### Expected Results

- All three trend granularities are selectable.
- Empty buckets remain visible rather than collapsing the timeline.
- Completed and required office days match direct period evaluation using the saved rule.
- Holidays, leave, and custom exclusions have the same effect in trend and period calculations.

## 18. Custom Excluded Day

### Steps

1. Open an ordinary eligible weekday in Calendar.
2. Enable Custom exclusion and enter a reason.
3. Save, then review Calendar, Summary, Compliance, History, CSV, and PDF.
4. Repeat on a weekend, a holiday, and a day already containing leave.

### Expected Results

- The weekday displays an `EX` badge and its reason remains visible.
- Detected attendance remains separate while compliance treatment is Excluded from requirement.
- The eligible-day count decreases by one only for an otherwise eligible weekday.
- Weekend, holiday, leave, and duplicate exclusions do not double-reduce eligibility.
- App and export totals agree and exports contain a dedicated custom-exclusion section.

## 19. Holiday Coverage And Missing-Year Recovery

### Steps

1. Select each supported AU and NZ jurisdiction while viewing dates in 2026.
2. For an NZ region, verify both national and regional observed holidays.
3. Navigate to a period outside the bundled 2026 holiday horizon.

### Expected Results

- Every catalog jurisdiction loads verified 2026 holidays with official source metadata.
- Only the active jurisdiction affects Calendar, Compliance, History, inference, and Export.
- NZ regional calendars include inherited national holidays.
- Missing-year data produces a visible typed error and never silently assumes zero holidays.

## 20. Privacy Disclosure And Confirmed Reset

### Steps

1. Create attendance, leave, override, note, custom exclusion, place, location-event, rule, and user-edited holiday data.
2. Generate PDF and CSV reports.
3. Open Settings > Privacy & Data and review the disclosures.
4. Tap Delete All On-Device Data, cancel, and verify data remains.
5. Repeat and confirm deletion.

### Expected Results

- Copy accurately states that app-managed data is on-device and that shared copies are controlled by their destination.
- Cancellation is non-destructive.
- Confirmation removes all user-owned records, user-edited holidays, and managed temporary reports.
- Bundled holiday reference data remains available.
- Exactly one default compliance rule is restored.
- The action does not claim to revoke iOS permissions or delete copies shared elsewhere.

## 21. Release Regression Gate

### Steps

1. Run the full TrackWorkTests target.
2. Run TrackWorkUITests serially on an iOS 27 simulator.
3. Build Debug and Release and run static analysis.
4. Inspect the app icon, privacy manifest, bundle identifier, version/build, and category.

### Expected Results

- All unit and golden-journey tests pass without skips.
- Debug, Release, and static-analysis gates succeed.
- The app targets iPhone and iPad only.
- The production icon has standard, dark, and tinted variants.
- The privacy manifest and App Store privacy answers match the no-network, no-tracking binary.
