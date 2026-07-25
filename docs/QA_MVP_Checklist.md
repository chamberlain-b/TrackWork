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
2. Add or edit a home place by searching for and selecting an address.
3. Add or edit an office place using a different address.
4. Adjust one selected place on the map and choose its place area.
5. Save both places and revisit Location Setup.

### Expected Results

- Home and office can be configured separately.
- The normal setup UI shows a readable address and does not ask the user to understand latitude or longitude.
- Saved places persist after leaving and returning to Location Setup.
- Opening setup and searching for an address do not request location permission.
- Address search failures leave current-location and map-selection alternatives available.
- No continuous GPS tracking is started by simply opening setup.
- Location setup does not overwrite manual attendance, leave, public holiday, or note data.

## 14. Location Permissions Are Contextual

### Steps

1. Start from a clean install with location permissions reset.
2. Launch the app.
3. Confirm no permission prompt appears on first launch.
4. Navigate to Location Setup and open a place editor.
5. Confirm no permission prompt appears until you choose Use Current Location.
6. Choose Use Current Location and review the in-app explanation before continuing.
7. Continue, grant When In Use or Allow Once access, and wait for the selected address to appear.
8. Repeat after resetting permission, deny access, and confirm address search and map selection remain available.
9. Return to Settings > Automatic Attendance with at least one active saved place.
10. Review the explanation, choose Allow Location While Using First, and handle the first iOS prompt.
11. Confirm the next action explicitly offers background access; continue and handle the Always prompt.
12. Enable Automatic Attendance, leave and re-enter a simulated saved area, then review Location Events and the affected day.
13. Turn Automatic Attendance off and confirm monitored saved areas stop without deleting existing attendance.

### Expected Results

- When In Use authorization is requested only after the explicit current-location action and explanation.
- Current location performs one selection request and does not keep updates running.
- Denial produces a useful fallback instead of blocking saved-place editing or manual attendance.
- Always authorization is requested only from the dedicated Automatic Attendance screen, after the user has seen the value and granted or reviewed foreground access.
- Enabling automation monitors only active saved home/office boundaries and records derived entry/exit events without sampled event coordinates or route history.
- The app does not start continuous GPS updates.
- Leave, public holidays, custom exclusions, and manual corrections remain authoritative when location events arrive.
- Turning automation off stops the app's saved-region monitoring and leaves manual attendance and one-shot Check In available.

## 15. Privacy Checks: No Raw GPS Export By Default

### Steps

1. Configure home and office locations.
2. Create or simulate attendance evidence for the selected month.
3. Generate CSV and PDF exports using default export options.
4. Inspect both exported files.
5. Search for the saved street addresses, latitude, longitude, coordinate pairs, raw event timestamps, and raw enter/exit event names.

### Expected Results

- Default exports contain derived day-level attendance only.
- Raw latitude values are not present.
- Raw longitude values are not present.
- Raw coordinate pairs are not present.
- Saved home and office addresses are not present.
- Raw location events are not present.
- Raw GPS traces are not present.
- Office/home attendance summaries may be included only as derived values such as classification, minutes, or compliance treatment.

## 16. Built-In And Custom Compliance Periods

### Steps

1. Open Compliance, History, and Export.
2. Select current month, last 30 days, previous month, current quarter, previous quarter, and year to date.
3. For each preset, record the displayed inclusive start and end dates.
4. Select Custom, choose an end date before the start date, and leave the controls.
5. Create two saved rules with different effective months, then select a custom range that begins under the earlier rule and ends under the later rule.

### Expected Results

- All six built-in presets resolve to deterministic inclusive boundaries.
- Last 30 days includes today and begins 29 calendar days earlier.
- Quarter boundaries use calendar quarters.
- Year to date begins on January 1 and ends today.
- A reversed custom range is normalized so the earlier date is the start.
- Compliance, History, and Export show the same records and boundaries.
- A range spanning a rule change uses the saved rule effective on the inclusive range end.

## 17. Monthly, Quarterly, And Yearly Trends

### Steps

1. Prepare attendance, leave, and custom exclusions in more than one month.
2. Save a rule change effective at the start of one of those months.
3. Open Summary and switch the trend granularity between Monthly, Quarterly, and Yearly.
4. Compare each visible bucket with the same dates selected in Compliance.

### Expected Results

- All three trend granularities are selectable.
- Empty buckets remain visible rather than collapsing the timeline.
- Completed and required office days match direct period evaluation using the rule effective at each bucket's end.
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

## 19. Supported And Unsupported Holiday Ranges

### Steps

1. Select each supported AU and NZ jurisdiction while viewing dates in 2026 and 2027.
2. For an NZ region, verify both national and regional observed holidays.
3. Navigate Calendar to a month before 2026 or after 2027.
4. In History and Compliance, select a custom range that includes at least one unsupported year.
5. Select the same unsupported custom range in Export and attempt to generate both formats.
6. If testing with the device calendar year outside 2026–2027, relaunch the app and record the launch alert.

### Expected Results

- Every catalog jurisdiction loads verified 2026 and 2027 holidays with official source metadata.
- Victoria's 24 September 2027 AFL holiday retains its conditional schedule note for the final pre-submission recheck.
- Only the active jurisdiction affects Calendar, Compliance, History, inference, and Export.
- NZ regional calendars include inherited national holidays.
- Supported 2026–2027 ranges show no coverage warning.
- Calendar, History, and Compliance name the unsupported year or years and state the supported 2026–2027 horizon.
- Export explains the unsupported coverage, disables generation, and creates no PDF or CSV for that range.
- An unsupported current calendar year produces a launch alert after bundled-year synchronization.
- Missing-year data never silently assumes zero holidays.

## 20. Privacy Disclosure And Confirmed Reset

### Steps

1. Create attendance, leave, override, note, custom exclusion, place, location-event, rule, and user-edited holiday data.
2. Generate PDF and CSV reports.
3. Open Settings > Privacy & Data and review the disclosures.
4. Tap Delete All On-Device Data, cancel, and verify data remains.
5. Repeat and confirm deletion.

### Expected Results

- Copy accurately states that app-managed data is on-device, Apple Maps handles user-initiated place lookup, and shared copies are controlled by their destination.
- Cancellation is non-destructive.
- Confirmation removes all user-owned records, user-edited holidays, and managed temporary reports.
- Planned office dates and raw location events are removed, Automatic Attendance and the weekly reminder are turned off, and monitored saved regions stop.
- Bundled holiday reference data remains available.
- Exactly one default compliance rule is restored.
- The action does not claim to revoke iOS permissions or delete copies shared elsewhere.

## 21. Backup, App Lock, Reminder, And Shortcut Controls

### Steps

1. Export a standard portable backup and inspect the JSON for saved addresses, coordinates, and location events.
2. Export a full private backup after reviewing its warning and confirm the sensitive location domains are present.
3. Restore a validated backup with Merge, then with Replace; repeat with a corrupt or unsupported file.
4. Enable App Lock, background and foreground the app, authenticate, then cancel authentication once.
5. Enable and disable the weekly reminder, including notification-denied behavior.
6. Run the Record Today and Review Pending Days App Shortcuts and confirm each opens a reviewable in-app flow rather than silently saving.

### Expected Results

- Standard backup excludes places, addresses, coordinates, and raw location events; standard Replace preserves the local location domains it does not represent.
- Full private export requires an explicit warning and the copy states that Work Track does not encrypt the exported JSON.
- Import validates before mutation, Merge preserves local-only records, Replace matches represented domains, and invalid files leave the store unchanged.
- App Lock obscures the app switcher and keeps content covered until successful device-owner authentication; UI testing is not trapped by the system sheet.
- Reminder permission is requested only after the in-context toggle and notification text contains no attendance, location, date, compliance, or pending-count details.
- App Shortcuts hand off to editable review screens and require an explicit Save.

## 22. Review Queue Lifecycle

### Steps

1. In the current month, leave two earlier eligible workdays unconfirmed.
2. Also prepare a confirmed day, a weekend, an active-jurisdiction holiday, a leave day, a custom exclusion, today, and a future workday.
3. Open Summary > Review Days and note the first date and the waiting count.
4. Open Review next day, confirm it as Office or Home, save, and return to the queue.
5. Confirm the remaining waiting day, then leave and reopen Review Days.

### Expected Results

- Only earlier eligible workdays without a non-unknown final status appear, in chronological order.
- Confirmed days, weekends, holidays, leave, custom exclusions, today, and future dates do not appear.
- Saving a final status removes that date automatically and advances Review next day.
- Completing the queue produces the All caught up state, which remains correct after reopening the screen.

## 23. Office Plan Persistence And Removal

### Steps

1. Open Summary > Plan Office Days for a month with several upcoming eligible workdays.
2. Select one date manually and use Suggest earliest eligible days for the remaining target.
3. Leave the screen, relaunch the app, and reopen the same month.
4. Turn one planned date off and verify the change after reopening.
5. Save final attendance for another planned date from Day Detail or apply a matching Quick Check In.
6. Use Clear this month's plan.

### Expected Results

- Plans are offered only for eligible, non-leave, non-excluded dates from today onward that have not already completed a qualifying office visit.
- Selected plans persist across navigation and relaunch and are reflected in the Summary plan count.
- A plan remains a reminder and does not increase completed attendance or compliance by itself.
- Turning a plan off, clearing the month, or saving final attendance for that date removes the plan.
- Suggested dates do not duplicate existing plans and stop when the remaining target is covered or no candidate remains.

## 24. History Search, Filter, And Day-Detail Deep Link

### Steps

1. Prepare records in one supported period for attendance, leave, a manual override, a public holiday, a custom exclusion, and a distinctive note.
2. Open History and select that period.
3. Search separately by status, distinctive note text, and a visible formatted date.
4. Exercise All records, Attendance, Leave, Manual overrides, and Holidays & exclusions, including one search-and-filter combination.
5. Tap a result, verify the matching Day Detail opens, edit and save it, then return to History.
6. Choose a period with no records and use Review days in Calendar.

### Expected Results

- Search is case-insensitive and matches visible date, final status, detected status, or note text.
- Each filter includes records matching its category, and search narrows the active filter rather than replacing it.
- Pending unconfirmed dates do not appear as records until they are saved.
- A result opens the correct date and preserves its attendance, leave, exclusion, holiday, note, and override context.
- Saved edits are reflected when returning to History, and the empty-state action opens Calendar.

## 25. Quick Check In And Manual Preservation

### Steps

1. Save active, non-overlapping home and office areas and keep Automatic Attendance off.
2. Give today an existing manual Home or Office final status and, separately, prepare a case protected by leave, holiday, or custom exclusion.
3. Open Location Setup > Check In from Current Location and choose Use Current Location Once.
4. Review the detected saved-place result before tapping Apply to Today.
5. Apply the result and inspect today's detected status, final status, and Location Events.
6. Repeat with a sample outside both areas, overlapping areas, and denied foreground permission where practical.

### Expected Results

- Permission is requested only after the explicit one-shot action, and Automatic Attendance remains off.
- The sampled coordinate is discarded after classification and no raw boundary event is created by Quick Check In.
- Nothing changes until Apply to Today is tapped.
- A matched result updates detected attendance while preserving an existing manual final status, leave, holiday, or custom exclusion.
- Outside, ambiguous, invalid, or denied samples explain the fallback and do not change attendance.
- Manual Calendar editing remains available in every outcome.

## 26. Clear Raw Location Events Without Clearing Attendance

### Steps

1. Create a completed automatic home or office visit and verify its derived attendance result.
2. Open Settings > Location Events and review the full stored entry/exit list.
3. Tap Clear, cancel once, and verify the events remain.
4. Repeat, confirm Clear Events, and reopen both Location Events and the affected Calendar day.

### Expected Results

- Every stored on-device boundary event is reviewable with place, kind, and timestamp, without sampled coordinates.
- Cancellation is non-destructive.
- Confirmation removes the existing raw entry/exit history while retaining already-derived attendance and manual corrections.
- If the device is currently inside a monitored area, state reseeding may create a new current entry after the clear; it must not restore the deleted history.
- The retained attendance remains editable manually and default exports still omit raw events.

## 27. Physical-Device Background And Terminated Geofence Delivery

### Steps

1. Install the release candidate on a physical iPhone and record its model, iOS version, battery state, location settings, and Background App Refresh state.
2. Save active, non-overlapping home and office areas, grant Always access through Automatic Attendance, and turn automation on.
3. Cross an office boundary with the app backgrounded, allow time for iOS delivery, cross it again to exit, then review Location Events and the affected day.
4. Repeat after the process has been terminated by the system or stopped from Xcode without swiping the app away, then reopen it after the boundary transitions.
5. Repeat for the home region and verify its events remain paired independently from the office region.
6. Downgrade permission to When In Use or Denied, then turn automation off while a visit is open.
7. Separately document the user force-quit case; relaunch before expecting region events again.

### Expected Results

- Simulator-only results do not satisfy this flow; background and terminated delivery is evidenced on the physical device.
- Location Services, Always access, and Background App Refresh are enabled for the passing run; power or accuracy conditions that delay delivery are recorded.
- Background and system-terminated entry/exit callbacks are stored, reviewable, and converted into the expected derived attendance when iOS delivers them.
- Home and office visits pair by monitored region, duplicate callbacks do not duplicate events, and a newer entry repairs a missed exit.
- Non-positive or longer-than-18-hour pairs do not contribute attendance, and overlapping active home/office areas cannot enable automation.
- Permission loss, region replacement, unavailable monitoring, or turning automation off explicitly closes open visits before monitoring stops.
- Manual attendance remains available when delivery is delayed or permission is insufficient.
- A user force-quit is outside the supported terminated-delivery claim; its observed behavior is recorded separately and the app is relaunched before subsequent delivery is judged.
- No continuous GPS updates, coordinates, or route history are created.

## 28. Release Regression Gate

### Steps

1. Run the full TrackWorkTests target.
2. Run TrackWorkUITests serially on an iOS 27 simulator.
3. Build Debug and Release and run static analysis.
4. Complete the physical-device geofence flow above and retain its evidence.
5. Inspect the app icon, privacy manifest, bundle identifier, version/build, and category.

### Expected Results

- All unit and golden-journey tests pass without skips.
- Debug, Release, and static-analysis gates succeed.
- Physical-device background and system-terminated geofence delivery is verified or remains an explicit release blocker.
- The app targets iPhone and iPad only.
- The production icon has standard, dark, and tinted variants.
- The privacy manifest and App Store privacy answers match the no-developer-collection, no-tracking binary and disclosed Apple Maps lookups.
