# Adaptive Month Plan design QA

## Comparison target

- Source visual truth: `<local-generated-images>/019fad98-d4ab-7510-95e7-ceaadee8773c/call_64aMhDAuUlmCD2zrUSE1Y4T2.png`
- Rendered implementation: `/tmp/trackwork-adaptive-plan-final-postrefactor.mPwTis/00666267-C653-4E26-B55F-9F1845A03D17.png`
- Durable implementation evidence: `.build/TestResults/AdaptivePlanFinalAll.xcresult`
- Full-view comparison: `/tmp/trackwork-adaptive-plan-final-postrefactor.mPwTis/reference-vs-implementation.png`
- State: light appearance, entered from Summary, Wednesday 29 July 2026 reference date, August 2026 plan, target 8, 6 valid plans, 2 additional days needed, annual leave on 11 August, public holiday on 28 August, and all six Monday-based calendar weeks represented.
- Viewport: iPhone 17 Pro simulator, 402 x 874 points at 3x.
- Source pixels: 853 x 1844.
- Implementation pixels: 1206 x 2622.
- CSS size: not applicable to this native SwiftUI screen.
- Density normalization: the implementation was resampled to 853 x 1844 so both sides of the combined comparison use identical pixel dimensions. The aspect-ratio difference before normalization was less than 0.6%.

## Evidence

The source and final implementation were inspected together in one normalized full-view image. The implementation preserves the selected visual hierarchy: screen identity, planning reference date, monthly target, shortfall status, plan progress, non-color-only legend, and compact Monday-to-Sunday week groups.

A separate focused crop was not needed because the combined image keeps the complete header, card treatment, typography, progress, status markers, week controls, and tab shell legible at full resolution. The planner has no photographic, illustration, or brand-image fidelity surface requiring an additional crop.

Primary interaction evidence:

- `.build/TestResults/AdaptivePlanFinalAll.xcresult`: 173 unit tests and four focused UI tests passed after the final code split. Coverage includes month navigation, bounded August state, leave and holiday semantics, sixth-week coverage, balanced Suggest 2 days flow from 6 to 8, confirmation-protected month re-plan, retained plan notes, the largest Accessibility text size, the agenda layout, and the affected Calendar action-placement journey.

## Findings

No actionable P0, P1, or P2 findings remain.

Required fidelity surfaces:

- Fonts and typography: native San Francisco styles preserve the intended display, subtitle, card-title, status, and calendar hierarchy. Normal text has no clipping or truncation; Accessibility sizes switch to agenda rows and keep the action early in the reading order.
- Spacing and layout: the main card, progress region, week dividers, and 44-point controls follow the source rhythm while retaining practical native hit targets. The full six-week August calendar makes the surface scrollable by design.
- Colors and tokens: existing Work Track blue, warning, leave, holiday, surface, border, shadow, and text tokens preserve the source's calm semantic palette with sufficient contrast.
- Image and asset fidelity: neither artifact uses photographic or custom illustration assets. The implementation uses system SF Symbols rather than handcrafted image substitutes.
- Copy and content: the target, planned count, shortfall, leave, holiday, and reminder disclaimer are direct and standalone. “Target met” and unavailable-plan states remain truthful rather than showing empty or misleading progress.
- Icons and affordances: calendar, status, disclosure, suggestion, re-plan, and tab symbols use one native icon family, align with their labels, and expose semantic accessibility values.
- States and interactions: manual toggles, balanced suggestions, disabled completion state, month re-plan confirmation, confirmation before removing multiple or note-bearing unavailable plans, month navigation, collapsed weeks, and save errors have defined behavior. Re-planning preserves every existing record and note for dates that remain selected.
- Accessibility and responsiveness: statuses do not rely on color alone, static dates are not exposed as disabled buttons, week headers meet the 44-point target, reduced motion is respected, and the largest text size uses agenda rows with actions before the month list.

Intentional adaptations:

- The live four-tab shell is retained instead of adopting the concept image's stale five-tab shell.
- Native iOS 27 navigation and floating-tab chrome are retained instead of recreating older system chrome.
- The concept incorrectly counts 31 July toward August and omits the week containing 31 August. The implementation keeps 31 July outside the August plan, reports Week 1 as 0 planned, and includes the sixth week beginning 31 August.
- The concept compresses five weeks and both actions into one viewport. The implementation keeps native type sizes and hit targets, represents the full six-week month, and allows the normal-size card to scroll. At Accessibility sizes the primary actions move before the long agenda.
- The status and legend wrap when required rather than shrinking text or controls below the app's native accessibility standards.

## Comparison history

1. Initial rendered comparison
   - Finding: P2, the initial card spacing and larger markers amplified vertical-density drift from the source.
   - Fix: tightened header and week spacing, reduced marker sizes without reducing hit targets, and compacted the legend and month heading.
   - Post-fix evidence: `.build/TestResults/AdaptivePlanVisualFinal.xcresult` and `/tmp/trackwork-adaptive-plan-final.LiceO6/reference-vs-implementation.png`.

2. Semantic and interaction pass
   - Findings: P2, an already-met target could show empty `0 / 0` progress; plans invalidated by leave, holidays, exclusions, attendance, or time had no direct removal path; noninteractive dates were exposed as disabled buttons.
   - Fixes: added a completed target presentation, unavailable-plan cleanup, eligible-date-bounded attendance, duplicate-plan guards, and static accessibility semantics for noninteractive dates.
   - Post-fix evidence: successful build, focused planner unit tests, and `.build/TestResults/AdaptivePlanVisualFinal.xcresult`.

3. Accessibility visual pass
   - Finding: P1, the primary suggestion action followed the entire 31-row agenda at the largest Accessibility text size.
   - Fix: moved the planning actions before the agenda only at Accessibility text sizes while retaining the week list and normal-size source hierarchy.
   - Post-fix evidence: `.build/TestResults/AdaptivePlanAccessibilityFinal2.xcresult`.

4. Final normalized comparison
   - Result: no actionable P0, P1, or P2 differences remain. Remaining differences are deliberate native-shell, accessibility-density, and calendar-correctness adaptations.
   - Evidence: `.build/TestResults/AdaptivePlanFinalAll.xcresult` and `/tmp/trackwork-adaptive-plan-final-postrefactor.mPwTis/reference-vs-implementation.png`.

## Implementation checklist

- [x] Match the selected adaptive-plan hierarchy and visual language.
- [x] Keep dates bounded to the selected month.
- [x] Include all Monday-based weeks intersecting August 2026.
- [x] Balance suggestions across weeks and prefer configured office weekdays.
- [x] Preserve manual day toggles and confirmation-protected re-planning.
- [x] Preserve records and notes for dates retained by re-planning.
- [x] Distinguish statuses without color alone.
- [x] Preserve native hit targets and VoiceOver semantics.
- [x] Verify the largest Accessibility text size.
- [x] Preserve the live four-tab app shell and existing design tokens.

## Plan Confidence card border polish QA

### Comparison target

- Source visual truth: `/tmp/codex-remote-attachments/019fad98-d4ab-7510-95e7-ceaadee8773c/2DD3AD10-EAE4-492E-8B69-5D4C46F91E4C/1-Pasted-Image-1.jpg`
- Rendered implementation: `/tmp/trackwork-card-border-dark.Ek78CP/0D5A3BCE-9FCA-4442-AFF4-40755A849065.png`
- Durable implementation evidence: `.build/TestResults/CardBorderPolishDarkRetry-20260730.xcresult`
- Full-view comparison: `/tmp/trackwork-card-border-dark.Ek78CP/reference-vs-implementation.png`
- Viewport: iPhone 17 Pro Max simulator, 440 x 956 points at 3x, dark appearance.
- Source pixels: 589 x 1280.
- Implementation pixels: 1320 x 2868.
- CSS size: not applicable to this native SwiftUI screen.
- Density normalization: the implementation was resampled to 589 x 1280. The combined comparison is 1178 x 1280, with each side using identical pixel dimensions.
- State: the source shows a completed target and the deterministic implementation fixture shows a covered target. The requested surface, border, radius, fill, and adjacent trend card are all visible in both states; text-state differences were excluded from the border assessment.

### Evidence and findings

No actionable P0, P1, or P2 findings remain.

- The Plan Confidence card now uses the same top-leading light-to-subtle-border gradient and 0.75-point stroke treatment as the 6-month trend card.
- The hero card keeps its existing blue-tinted material, larger radius, shadow, spacing, content hierarchy, and interaction behavior.
- Fonts and typography: unchanged native San Francisco styles, weights, wrapping, and hierarchy.
- Spacing and layout rhythm: unchanged padding, metric layout, progress treatment, detail rows, button sizing, and hero radius.
- Colors and visual tokens: the border now directly matches the shared card-surface gradient values while preserving the semantic state tint.
- Image and asset fidelity: no raster, icon, illustration, or brand assets changed; existing SF Symbols remain intact.
- Copy and content: unchanged.
- Interaction and accessibility: the focused Plan Confidence UI journey passed with zero runtime warnings. The border is decorative and does not alter the accessibility tree.

A separate focused crop was not needed because the normalized full-view comparison keeps both complete card outlines and their top-left, side, and bottom-edge treatments clearly legible.

### Comparison history

1. Source issue
   - Finding: P2, the main Plan Confidence card's flat subtle stroke was visibly weaker than the outlined 6-month trend card.
   - Fix: replaced the flat stroke with the exact light-to-subtle gradient and line width used by the shared card surface.
   - Post-fix evidence: `.build/TestResults/CardBorderPolishDarkRetry-20260730.xcresult` and `/tmp/trackwork-card-border-dark.Ek78CP/reference-vs-implementation.png`.
   - Result: the two cards now share one clearly related border treatment, with no change to the hero card's functional hierarchy.

### Implementation checklist

- [x] Match the trend card's visible border treatment.
- [x] Preserve the Plan Confidence card's fill, radius, shadow, copy, and controls.
- [x] Verify the result in dark appearance on iPhone 17 Pro Max.
- [x] Run the focused UI journey.
- [x] Pass strict focused lint and `git diff --check`.

## Calendar and History Summary-direction QA

### Comparison target

- Source visual truth: `/tmp/trackwork-card-border-dark.Ek78CP/implementation-normalized.png`
- Calendar baseline: `/tmp/trackwork-calendar-history-baseline.JHhPoL/E8CFA1A3-2867-4888-88E2-0C0DAEBCF5DD.png`
- Calendar final: `/tmp/trackwork-calendar-history-final.VVtv6q/07548A9B-DB0C-403F-9AF5-88EB140B2875.png`
- History baseline: `/tmp/trackwork-calendar-history-baseline.JHhPoL/380B808E-44AB-4305-B689-7042AB5BC764.png`
- History final: `/tmp/trackwork-calendar-history-final.VVtv6q/06222203-A2B6-42AD-835B-114F336D20F8.png`
- History record and Accessibility evidence: `/tmp/trackwork-calendar-history-final.VVtv6q/D88C1A01-5D0A-4CA4-9436-38AB0E0BE45C.png` and `/tmp/trackwork-calendar-history-final.VVtv6q/2BBD842A-535E-42EF-909A-93B3EB8F3AB8.png`
- Durable implementation evidence: `.build/TestResults/CalendarHistoryDesignRetry-20260730.xcresult`
- Normalized comparisons: `/tmp/trackwork-calendar-history-final.VVtv6q/summary-baseline-final-calendar.png` and `/tmp/trackwork-calendar-history-final.VVtv6q/summary-baseline-final-history.png`
- Viewport: iPhone 17 Pro Max simulator, 440 x 956 points at 3x, dark appearance.
- Source pixels: 589 x 1280.
- Implementation pixels: 1320 x 2868, normalized to 589 x 1280.
- CSS size: not applicable to these native SwiftUI screens.
- Density normalization: each three-panel comparison is 1767 x 1280 and gives the Summary reference, previous implementation, and final implementation equal-width panels.

### Evidence and findings

No actionable P0, P1, or P2 findings remain.

- Typography and hierarchy: both screens now open with the same blue identity label, direct status headline, supporting sentence, and compact metric rhythm used by Summary. Native San Francisco styles remain readable without artificial scaling.
- Card treatment: Calendar and History reuse the Summary hero material, tint, radius, gradient border, and shadow. Secondary controls and record groups use the quieter outlined surface treatment so the hero remains dominant.
- Calendar semantics: the overview distinguishes confirmed records, office days, and planned days; months containing home or leave records no longer incorrectly report that no attendance was recorded. Month navigation, Today, Month/Agenda switching, the full calendar grid, and existing date actions remain intact.
- History semantics: the overview reports period totals rather than filtered-search totals. Manual adjustments show detected-to-final status explicitly, while leave, holiday, exclusion, notes, and final attendance meaning remain separate.
- Copy and content: headings and explanations are short, functional, and standalone. Empty states distinguish an empty period from a search or filter with no matches.
- Icons and affordances: system SF Symbols, native search, export, disclosure, segmented controls, and 44-point navigation targets keep the interaction language consistent with iOS and the Summary screen.
- Accessibility and responsiveness: the largest Accessibility text size reflows History records vertically and uses Calendar's Agenda presentation. Status meaning is present in text and symbols rather than color alone, and the focused Accessibility UI journey passed.

Intentional adaptations:

- Calendar retains a calendar grid because date position and month scanning are primary tasks; the Summary visual direction is applied to the overview and surfaces rather than replacing the grid with dashboard content.
- History retains native searchable List, export placement, grouped month headers, and record navigation. These behaviors are more useful than reproducing Summary's static card stack exactly.
- The existing four-tab floating shell and native iOS 27 navigation remain unchanged.

### Comparison history

1. Baseline review
   - Finding: P2, Calendar opened with several detached controls and weak month context; History opened with filters before explaining the selected period or its record totals.
   - Fix: introduced Summary-style overview cards, contained control surfaces, stronger section grouping, and direct state copy.

2. Semantic review
   - Finding: P1, Calendar could label a month with non-office attendance as having no attendance; History totals could be mistaken for search-result counts.
   - Fix: based Calendar messaging on all recorded classifications and kept History overview totals scoped to the selected period.

3. Accessibility and interaction review
   - Finding: P2, container accessibility identifiers initially hid child controls from the focused UI journey.
   - Fix: moved identifiers to semantic labels, retained discoverable child controls, verified Calendar Agenda and History record reflow at the largest Accessibility text size, and reran the affected journeys.

4. Final normalized comparison
   - Result: no actionable P0, P1, or P2 differences remain. Remaining differences are deliberate native calendar, search, export, and accessibility adaptations.
   - Evidence: `.build/TestResults/CalendarHistoryDesignRetry-20260730.xcresult`, `.build/TestResults/CalendarHistoryGoldenRetry-20260730.xcresult`, and the normalized comparison images above.

### Implementation checklist

- [x] Apply the Summary screen's hero hierarchy and border treatment to Calendar and History.
- [x] Preserve Calendar month navigation, Month/Agenda modes, date semantics, and existing actions.
- [x] Preserve History search, filtering, export, grouped records, and record navigation.
- [x] Keep detected status, final status, leave, holidays, exclusions, and notes semantically distinct.
- [x] Use deterministic UI-fixture dates for repeatable verification.
- [x] Verify dark appearance and the largest Accessibility text size.
- [x] Pass the focused UI journeys, full unit suite, build, strict focused lint, and `git diff --check`.

final result: passed


## TrackWork Variation 3 implementation — 14 September 2026

This section records the current implementation and supersedes earlier visual-direction conclusions above. Those earlier results remain historical evidence only.

### Baseline and scope

- Reference composition: `<local-temporary-files>/codex-clipboard-587d3e69-76a8-4714-9b67-992652a9a365.png`.
- Shared styling reference: `<local-design-references>/TrackWork_Variation_3_UI_UX_Implementation_Spec.md`, extended by the approved Home / Log / Insights / Settings and analytics plan.
- Working branch: `main`; implementation remains uncommitted. Existing staged changes were preserved byte-for-byte. Preexisting untracked and unstaged attendance, calendar, planning, records and settings work was retained and migrated.
- Current baseline was captured before editing in `/tmp/trackwork-variation3-baseline/`: `source.tgz`, `staged.patch`, `unstaged.patch` and build logs. The baseline app build succeeded with simulator service access; an earlier sandbox-only build could not load compiler macro services.
- No Xcode project, model schema, persistence migration, package dependency, compliance service, location behavior or export-content changes were made.

### Implementation

- Semantic light, dark and increased-contrast colours; neutral surfaces, 20-point screen insets, 24-point section gaps, 16-point grouped corners, restrained borders and no content glass/shadows. Rounded typography is reserved for metrics. The native system tab/navigation chrome remains native iOS 27 chrome.
- Home places the shared reporting period, greeting, target ring, recorded Office/Home mix and six-bucket trend first. Existing status/correction, current week, actions, review and plan confidence follow under an explicit **Today · Current month** heading.
- Home's ring describes completed versus required office days and office days still needed. Insights' office-share metric remains completed office days divided by eligible days through the reference date. A typical fixture deliberately demonstrates the distinction: 12/10 target progress, 63% office share, and 67% Office / 33% Home among 18 eligible recorded days.
- Log retains Calendar, month navigation, Today, Month/Agenda, selected-day preview and explicit editing. Selection is circular blue; unselected today has an outline. Records is a labelled toolbar destination with its own period, search, filters, details and Export. Embedded Records avoids a second navigation stack.
- Insights provides Overview, Trends and Breakdown. The heatmap uses date-keyed classifications, weekday rows and lazy week columns; long ranges scroll horizontally. Mixed, exclusion and override symbols remain explicit. Unrecorded days are neutral question-mark cells; future and non-working days stay faint. At accessibility text sizes, dates and statuses become readable rows.
- Analytics reuse report-row derivation in memory and CompliancePeriodEvaluator for headline values. No export files are generated. Office/Home mix excludes unknown, missing, future, holiday, leave and excluded days; Mixed uses the existing office-minutes threshold. Zero recorded-day denominators show an empty state. Six-bucket monthly, quarterly and yearly history keeps period-end rule resolution and explicit chart dates and holiday-coverage warnings.
- Shared components, planning, review, editing, location, export, settings, privacy, backup, sheets and the design-system gallery use the updated typography and surface treatments. Existing confirmations and App Intent Home/review/editor handoffs are preserved. Unused custom tab and glass-surface implementation was removed after migration.

### Current validation and evidence

- Full regression: `/tmp/Variation3-FinalSuite.xcresult` — **183 unit tests and all 28 UI tests passed** on iPhone 17 Pro Max, iOS 27. This run includes correction, review, planning and re-plan confirmation, check-in/location rationale, records/filtering, PDF/CSV export, privacy reset, settings, calendar selection/agenda, modal flows and the four new Variation 3 scenarios.
- Standard iPhone 17: `/tmp/Variation3-StandardPhone.xcresult` — **4/4 Variation 3 UI tests passed**.
- iPad mini (A17 Pro): `/tmp/Variation3-iPad.xcresult` — **4/4 Variation 3 UI tests passed**, including native top tabs and maximum-text reflow.
- Final small iPhone 17e pass: `/tmp/Variation3-AppearanceVerified.xcresult` — **183/183 unit tests and 5/5 UI tests passed**, including actual Bold Text and Reduce Motion settings, extra-large text, maximum text, shared periods, all tabs, corrected Calendar totals and data-state fixtures. These captures use actual Dark Mode with Increase Contrast enabled. Settings changes made by the accessibility test are restored to their initial values.
- Both Debug and Release simulator builds passed. After the final visual-only heatmap label/cell scaling correction, `/tmp/Variation3-HeatmapTypeVerified.xcresult` passed both focused UI tests (actual Bold Text/Reduce Motion and all four reference screens), and the Release build passed again. The final screenshots in `.build/variation3-qa/final-type/` were inspected; weekday labels no longer truncate at extra-large text. These supersede the earlier fixed-column captures.
- Ten focused analytics unit tests were added to the existing registered `ComplianceTrendCalculatorTests.swift` source. They cover Mixed thresholds, exclusion/holiday/leave overlap and precedence, missing/future records, zero denominators, duplicate-record behavior, historical rules, custom inclusive boundaries, stable day identity, overrides, shared presets and holiday coverage.
- The preexisting untracked `TodayPresentationTests.swift` is not registered with the unit target. Its four tests are not included in the 183 count; target membership was left unchanged under the no-project-edit constraint.
- Computed contrast against primary and secondary surfaces across all four asset variants: primary text minimum 13.54:1; secondary text 4.71:1; interactive blue 5.00:1; warning 4.96:1; success 4.79:1. Chart-mark ink against Office/Home/Mixed fills is at least 4.68:1.
- `git diff --check` passed. No diff exists in the Xcode project, models or services. The staged patch still matches the pre-implementation capture.

Screenshot evidence is under `.build/variation3-qa/` (local ignored QA artifacts). Each exported directory includes its original xcresult `manifest.json` and descriptive screenshot aliases:

| Surface / state | Evidence |
| --- | --- |
| Large phone, Home / Log / Insights / Settings | `final-suite/home.png`, `log.png`, `insights-overview.png`, `settings.png` |
| Standard phone, all four tabs | `standard-phone/home.png`, `log.png`, `insights-overview.png`, `settings.png` |
| iPad, native tabs and analytics | `ipad/home.png`, `log.png`, `insights-overview.png` |
| Maximum text, iPhone and iPad | `standard-phone/maximum-text-home.png`, `maximum-text-insights.png`, `maximum-text-log.png`, `maximum-text-records.png`; corresponding `ipad/` files |
| Empty / leave-heavy / override-heavy | `standard-phone/variation3empty-heatmap.png`, `variation3leaveheavy-heatmap.png`, `variation3overrides-heatmap.png` and corresponding Home files |
| Six-bucket short quarterly/yearly history and warnings | `standard-phone/insights-quarterly.png`, `insights-yearly.png` |
| Actual Dark Mode, small phone | `iphone17e-home-dark.jpg`, `iphone17e-insights-dark.jpg` |
| Actual Dark Mode with Increase Contrast | `iphone17e-insights-dark-increased-contrast.jpg`; final captures in `final-small-phone/` |
| Actual Bold Text + Reduce Motion + extra-large text | `final-type/bold-text-reduce-motion-extra-large-home.png`, `bold-text-reduce-motion-extra-large-insights.png`, `bold-text-reduce-motion-extra-large-log.png`, `bold-text-reduce-motion-extra-large-settings.png` |

### Findings and intentional adaptations

- Native large titles, current iOS tab chrome, readable explanatory labels and valid hit targets use more vertical space than the static reference. Content scrolls rather than compressing type or inventing mockup arrival/departure times.
- Maximum text moves the ring to a textual progress summary and the month grid to Agenda. Home's compact accessible trend shows the last three recorded buckets; full six-bucket history remains in Insights.
- The original planner UI test assumed at most eight Home swipes. The redesigned reporting content and maximum text require a longer scroll budget; the functional planner, next-month and suggestion assertions remain intact and pass.
- A visual-fixture error initially left stored calendar totals unset. The fixture now derives stored treatments with the existing resolver and exclusions, and the visual test asserts 12 office days in Calendar. This changes test data only.
- An early screenshot test labelled captures Light/Dark using a launch argument that did not reliably change iOS appearance. These captures are not evidence of dark-mode acceptance. The test now uses “System appearance” labels; actual simulator appearance controls and screenshots provide dark-mode evidence.
- Bold Text with extra-large type exposed weekday-label truncation in the fixed heatmap column. Weekday width, cell size and month-label height now scale together with caption text.
- Heatmap inspection prompted neutral question-mark cells for missing attendance and appearance-aware symbol ink. This prevents missing records looking like partial attendance and preserves symbol contrast on pale dark-mode fills.

### Remaining verification limits

- VoiceOver labels, values, selection traits and accessible date/status alternatives were inspected through runtime accessibility snapshots and UI assertions. Spoken VoiceOver navigation, rotor behavior and end-to-end Shortcuts/Siri handoffs still require a physical-device pass. Intent submission/router unit tests passed; source review confirms that handoffs still select Home and present the existing flows.
- The captured matrix covers small/standard/large iPhones and iPad mini portrait, default/extra-large/maximum text, light/dark and Increase Contrast, with representative empty, typical, dense, below-target, compliant, leave-heavy and override-heavy data. It is not an exhaustive cross-product of every state and appearance. iPad landscape, split-screen widths and every device size have not been visually accepted.
- Holiday coverage is still limited to the existing bundled years. Six-bucket quarterly/yearly views intentionally retain coverage warnings for earlier years.
- Evidence is simulator-based. No device release, App Store submission or real background location acceptance is implied.


## Phone-based Home refinement — 6 November 2026

This section covers only the approved compact-correction change. Earlier design reports above remain historical evidence; their larger redesigns are outside this change.

### Approved scope and source

- Base: the approved existing-app Home visual reference; private phone screenshots are not part of the repository.
- Approved visual: `TrackWork-review-2026-11-06/phone-base-revision/trackwork-home-compact-correction.png` (851 × 1847). The approved instruction was to keep the current app, move Correct today into the second Today card as a smaller button, and use the first concept's card treatment.
- Change: a trailing, secondary pencil capsule inside Today; the previous full-width button below the card is removed. The card uses existing semantic charcoal surfaces in a subtle gradient, a continuous 20-point corner and a restrained outline. Existing correction titles, editor handoff, attendance evidence, target/share calculations, week actions, Check location, plan link, insights and native tabs remain intact.
- Production attendance processing, permissions, persistence and navigation logic were not changed. Three deterministic UI-only phone fixtures use the existing in-memory test launch path; they never seed the normal app database or enable location tracking.

### Rendered comparison and fidelity review

All evidence below is under `<local-qa-workspace>/TrackWork-review-2026-11-06/implementation/`.

- `screenshots/comparison-full.png`: approved source on the left; actual simulator rendering on the right, normalized to the same 402 × 874 comparison canvas per image.
- `screenshots/comparison-today-card.png`: matching crop of the same pair, focused on Today and the correction action.
- Actual full-resolution rendering: `screenshots/home-large-dark.png` (1320 × 2868), iPhone 17 Pro Max, iOS 27, 440 × 956 points, default text, actual system Dark appearance. `home-large-light.jpg` records the same layout in actual Light appearance. `home-dark.jpg` is the smaller iPhone 17 viewport and is not the final density comparison.
- Deterministic in-memory UI fixtures exercise target completion versus recorded-day share, detected Home/Office, leave, holidays and unknown attendance. Unknown attendance is separately tested and never labelled as detected.
- Reviewed composition, hierarchy, typography, line wrapping, spacing, corners, gradient/outline, icon identity and colours, visible copy and navigation. The target remains dominant; the detected status precedes correction; the small correction stays inside Today before Check location and the week. There is no competing full-width manual-recording call to action.
- Intentional native adaptation (minor visual variance): the capsule has a minimum 44-point hit area and the existing week keeps accessible date/status targets, so Today is roughly 30 normalized points taller than the raster mockup. Existing native text metrics, status bar values and tab chrome also differ. On the matching large-phone viewport, the plan and insights destinations remain visible; smaller viewports scroll normally. Text was not shrunk to force a mockup fit.
- Final review: no actionable P0, P1 or P2 fidelity defects remain in the approved scope. The minor native sizing difference above is accepted as an accessibility adaptation.

### Functional and accessibility validation

- `FocusedRegression.xcresult`: 29 passed, zero failed. Covers automated attendance event processing, all six Today design tests, actual Bold Text/Reduce Motion, action placement, fresh navigation/no permission prompt, automatic tracking initially off and manual override/note/Calendar regression journeys.
- `FinalFocusedRetest.xcresult`: 16 passed, zero failed after extracting the compact button and phone-fixture helpers. Covers access-state presentation (including that Always permission does not imply automatic tracking is enabled), attendance persistence/queued and duplicate events, all three new compact-correction scenarios and a fresh-launch journey.
- Together: 41 distinct tests passed, 45 executions including four repeats. The new scenarios cover detected Home, detected Office and unknown states; one compact correction control inside Today; minimum 44-point height; cancel retaining the current status; saving Home → Office updating the final/manual source, target and week; and the largest Accessibility text size opening the editor without horizontal overflow.
- The larger simulator was additionally inspected through runtime snapshots; Correct today opens the existing Status/Leave/Exclusion/Note editor and Cancel returns to detected Home unchanged. No personal app data was edited.
- Primary and secondary labels retain existing semantic colour assets. Computed contrast across all light/dark/increased-contrast variants and the new surface endpoints is at least 5.00:1 for the text introduced or displayed on the changed card/button (`contrast-check.json`). This is a focused contrast calculation, not a complete accessibility certification.
- Strict focused SwiftLint passes for the changed Today components, new button, new fixture helper and Today UI tests. Across all changed Swift files, no new file/rule violations were introduced. Eight existing lint findings remain in the preexisting large DashboardView/AppModelContainer files; three preexisting unused-result compiler warnings remain in LocalJSONHolidayProviderTests. These unrelated files/sections were not refactored.
- Spoken VoiceOver and real background location delivery on a physical iPhone were not tested. Automated access/persistence tests protect existing behaviour; simulator fixtures and UI checks do not claim real-world tracking succeeded.

### Working-tree preservation

The original checkout was snapshotted before editing (278 tracked/untracked source files; 126 preexisting status entries). Implementation and testing occurred in an isolated copy first. A guarded seven-file patch checks the original HEAD, staged diff and all baseline file hashes before applying only the four modified Swift files, two new Swift files and this appended report. No Xcode project, package, entitlement, database, commit, push, merge or deployment is part of this change. Detailed baseline, patch, lint and test evidence is retained in the implementation directory above.

final result: passed


## Calendar and Insights approved direction — 7 November 2026

This section covers implementation of the three approved Calendar/Insights mockups following the Home refinement. Earlier reports above remain historical evidence.

### Visual truth and scope

- Approved images: `TrackWork-review-2026-11-06/calendar-insights-design/mockups/trackwork-calendar-month-concept.png` (852 × 1847), `trackwork-insights-overview-concept.png` (852 × 1847), and the final `trackwork-insights-trends-concept.png` (934 × 1684). The superseded tall Trends draft is not a target.
- Native SwiftUI implementation in the existing app. No generated raster assets are needed: the references use SF Symbols, native controls, charts and intentional neutral UI surfaces. Typography and semantic colours remain the app's existing system tokens.
- Calendar gets grouped month and selected-day surfaces. Edit day becomes a compact secondary capsule with a 44-point minimum hit area and the same native editor navigation. The selected source caption distinguishes detected evidence, manual correction and other recorded attendance; leave, holiday, excluded, unknown and planned states do not claim detection.
- Insights retains its real target count/progress/remaining-days presentation and brings the existing eligible recorded Office/Home mix above the historical chart. The chart, exclusions, attendance pattern, Breakdown, period menus and detail destinations remain. Trends groups its existing controls, chart, legend and explanation. No domain calculations, stored models, location automation, permission flows or navigation destinations change.
- The shared neutral summary surface uses the same gradient endpoints, 20-point corner and restrained outline as the approved Home implementation. Home itself is not edited.

### State and comparison normalization

Evidence lives under `<local-qa-workspace>/TrackWork-review-2026-11-06/calendar-insights-implementation/`.

- Simulator: dedicated iPhone 17 Pro Max, iOS 27, 440 × 956 points at 3× density. Existing in-memory `phoneHome` fixture, Friday 6 November 2026, actual Dark appearance.
- Deterministic in-memory fixture values are used to verify target completion, recorded-day denominators, selected-day source labels and per-period requirements. No personal attendance store, raw location trace or private screenshot is included in the repository.
- Comparison helper preserves aspect ratio at 440-point width, puts approved source left and implementation right, and top-aligns them with padding for differing export heights. It does not warp the compact Trends reference into the taller phone viewport. Native status/navigation chrome is retained; the mockups omit OS status content. Focused crops align app-owned card regions separately from native chrome.
- Initial full-view and focused boards are `screenshots/calendar-comparison-*.png`, `insights-overview-comparison-*.png` and `insights-trends-comparison-*.png`. Initial native PNGs have the `-dark-initial.png` suffix.

### Findings and iteration history

- [P2, initial comparison] Calendar grid used extra spacing and taller blank cells, placing selected-day context roughly 60 points below the raster target. Fix: use the existing 48-point day-cell height for blank slots, remove extra row gaps and reduce outer vertical padding. Date controls retain their existing width and minimum 48-point height. The post-fix 255-test run passed. `screenshots/calendar-verified-comparison-full.png` and `calendar-verified-comparison-focus.png` show the corrected grid: dates align closely with the source and the selected-day card is fully visible above navigation. No actionable P2 spacing issue remains.
- [Capture issue] Initial Trends capture omitted navigation/period glyphs during rendering even though runtime labels were present. Complete settled native and test captures resolve this evidence issue: `insights-trends-dark-verified.png` and the final Light capture include the title and period controls. Transitional captures are not acceptance evidence.
- Native SF font metrics, segmented controls, tab chrome and the existing 190-point chart intentionally take precedence over raster-only approximations. Minor variations in neutral gradient texture, faint outline and caption wrapping are P3 if content, hierarchy and controls remain clear. No decorative texture is added to native cards.

### Required fidelity and validation gates

- Fonts/typography: native SF family, semantic sizes/weights, rounded target metric, readable caption wrapping and default/Accessibility reflow were inspected. Existing system font metrics and optical rendering are retained rather than rasterized; there is no truncation of the compact correction label. The native caption and metric scale differ slightly from the generated image.
- Spacing/layout: full composition and focused selected-day, target/mix and chart regions were compared together with their sources. The P2 grid density finding is fixed. Existing 20-point outer insets, adaptive controls and 190-point chart are retained; OS status/navigation chrome explains the remaining vertical offset on Insights. All essential controls remain reachable, with native text scrolling at maximum size.
- Colours/tokens: existing Light/Dark/increased-contrast semantic assets are used. Office blue, Home teal, leave lavender, neutral unknowns and the coral required target remain distinct. The subtle neutral gradient and faint border match the approved Home treatment; no content glass or shadows are introduced.
- Image/asset fidelity: crisp native SF Symbols and chart marks were inspected at full and focused scales. No bitmap UI, placeholder art or custom icon approximation is introduced. The generated mockup's incidental texture is intentionally absent from native surfaces.
- Copy/content: verified dates, recorded-day denominators, target completion, per-period requirements and unknown/manual/detected distinctions remain accurate. No new metric, forecast, tracking-success promise or prominent recording CTA is introduced.
- `FinalRegression.xcresult`: 230 unit tests and 25 UI tests passed, zero failures or skips. `AccessibilityCorrection.xcresult`: one additional maximum-Accessibility-text Calendar correction test passed, zero failures or skips. Total: 256 distinct passing checks.
- Covered actual Bold Text and Reduce Motion (settings restored), Calendar Month/Agenda, detected/manual/unknown/leave/holiday sources, correction and note/leave/exclusion saves, first-launch and automatic-permission defaults, Insights empty/leave-heavy/unconfigured states, period/custom-date and Monthly/Quarterly/Yearly navigation, calculation details, Records navigation and the approved Home regression suite.
- Actual Light captures for all three screens were inspected. Maximum-text and Bold Text/Reduce Motion evidence is exported under `accessibility-screenshots/` and `bold-motion-screenshots/`.
- Strict lint passes for the changed Calendar components, shared surface and new UI tests. The two existing large Insights files retain the same ten baseline lint findings; no new file/rule violations were introduced.
- `contrast-check.json` covers the actual semantic text/state colours across both gradient endpoints in Light, Dark and increased-contrast variants; all listed foreground/surface combinations are at least 5.11:1. This is a focused calculation, not a complete accessibility certification.
- The original-checkout integration build is checked after guarded application; its result is retained with the implementation evidence. The functional and visual gates above verify the exact source patch before that application.
- Initial test attempt hit the connector's five-minute timeout and stalled. Two new test assertions also assumed a Cancel button for a pushed Calendar editor and a numeric segmented-control value. The editor correctly retains its native Calendar back action; tests now use that navigation and verify Trends through its dedicated control. Initial log retained in `initial-regression-attempt.log`; the final run uses Xcode directly to avoid the connector timeout.

### Final visual acceptance and limits

- Accepted native captures: `screenshots/calendar-dark-verified.png`, `insights-overview-dark-settled.png`, and `insights-trends-dark-verified.png`. Calendar/Trends are exported from the passing new workflow tests; Overview is a complete settled native capture of the same final code. Native screenshots are 1320 × 2868. Transitional captures are retained for history and are not deliverables.
- Full-view acceptance boards: `calendar-verified-comparison-full.png`, `insights-overview-final-comparison-full.png`, `insights-trends-verified-comparison-full.png`. Matching focused boards use the same prefixes with `-focus.png`; these were inspected alongside the full-view pairs. Source is left, implementation right. The compact Trends source is 440 × 793 after width normalization, rather than stretched to the actual 440 × 956 viewport.
- After the grid fix and replacement of transitional captures, no actionable P0/P1/P2 finding remains. Minor native metric/caption sizing, system chrome, faint outline and texture differences are P3/native adaptations. The existing responsive chart height and system font scaling are retained for legibility.
- All three actual Light screenshots, largest Calendar text/editor evidence and the Bold Text/Reduce Motion captures were reviewed. Text and actions remain readable; maximum text uses the existing Agenda fallback and scrolling, without compressing type.
- No physical-device background location delivery, spoken VoiceOver or exhaustive iPad/landscape matrix was tested. Location processing and data storage are unchanged. Simulator fixtures do not claim real tracking succeeded.
- Implementation checklist: preserve all existing navigation/metrics; keep manual editing secondary; distinguish evidence sources; pass focused and regression tests; compare rendered sources; retain original working-tree/index contents; leave a simulator preview. No dependency, Xcode project, entitlement, persistence or model edit is included.

final result: passed
