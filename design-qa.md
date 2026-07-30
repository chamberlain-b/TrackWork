# Adaptive Month Plan design QA

## Comparison target

- Source visual truth: `/Users/benchamberlain/.codex/generated_images/019fad98-d4ab-7510-95e7-ceaadee8773c/call_64aMhDAuUlmCD2zrUSE1Y4T2.png`
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

final result: passed
