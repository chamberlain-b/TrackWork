# Work Track 1.0 App Store Metadata Draft

This draft matches the current local-first iOS MVP. Recheck it against the final archive before submission.

## App Information

- Name: `Work Track`
- Subtitle: `Private hybrid-work tracking`
- Bundle ID: `com.benchamberlain.worktrack`
- Primary category: `Business`
- Version: `1.0`
- Build: `1`
- Minimum OS: `iOS 27.0`
- Platforms: iPhone and iPad
- Suggested SKU: `work-track-ios` — owner must confirm before creating the App Store record.

## Promotional Text

Privately record office days, leave, exclusions, and hybrid-work progress with AU and NZ public holidays and shareable reports.

## Description

Work Track is a private, on-device companion for understanding hybrid-work attendance and compliance.

Record office and home days manually, with a one-shot saved-place check-in, or through optional private geofence automation. Add full-day annual or sick leave, preserve explanatory notes, and make a clearly attributed manual correction when detected evidence is incomplete. Manual corrections remain authoritative on ordinary attendance days; holidays, leave, and exclusions stay protected. Custom excluded days remain separate from attendance and reduce eligible workdays without double-counting holidays or leave.

Review the current month at a glance or choose current month, last 30 days, previous month, current quarter, previous quarter, year to date, or an inclusive custom range. Monthly, quarterly, and yearly trends use the same saved rule and exclusions as the detailed compliance view.

The 1.0 bundle includes sourced 2026 and 2027 public-holiday calendars for every Australian state and territory, New Zealand National, and supported New Zealand regional anniversary options. Victoria's 24 September 2027 Friday before the AFL Grand Final date follows the official Victorian Department of Education calendar and remains subject to final AFL schedule confirmation. Ranges containing missing holiday years are explicitly flagged, and exports are blocked, rather than silently assuming there are no holidays.

Generate a styled PDF or spreadsheet-compatible CSV report for any supported period. Default reports contain derived day-level attendance and exclude raw location events and GPS coordinates.

Your app data stays in Work Track's on-device storage. There is no account, advertising, analytics SDK, or app-managed cloud sync. Reports and portable backups leave the app only when you choose a destination. Standard backups omit saved addresses, coordinates, and raw location events; full private backups include them only after an explicit warning. Optional device authentication can lock the app, and a privacy-safe local reminder can prompt you to review recent days.

Save home and office places by searching for an address, using your current location, or adjusting the pin on a map. Selected addresses and coordinates stay in on-device storage. One-shot actions request a single foreground location sample. If you explicitly enable Automatic Attendance, Work Track requests Always access so iOS can deliver saved-area entry and exit events while the app is closed. This uses geofences rather than continuous GPS, stores no route, and keeps raw events on-device.

## Keywords

`hybrid work,office attendance,compliance,leave,work calendar,Australia,New Zealand,PDF,CSV`

## What's New In 1.0

- Manual office, home, leave, note, override, and custom-exclusion records.
- A focused review queue, office-day planning, searchable History, and actionable Insights.
- Seven deterministic compliance periods and monthly, quarterly, and yearly trends.
- Effective-dated rule history and bundled 2026–2027 AU and NZ public holidays.
- Address-first place setup, one-shot check-in, and optional private geofence automation.
- App Shortcuts for recording today and reviewing pending days.
- Private PDF and CSV reports.
- Standard/full portable backups, optional app lock, private review reminders, and confirmed data reset.

## Release Accuracy Note

This note is not customer-facing App Store copy. Recheck Victoria's bundled 24 September 2027 Friday before the AFL Grand Final date against Business Victoria after the final 2027 AFL schedule is published.

## App Privacy Draft

- Tracking: No.
- Data collected: No. The app has no developer-operated network service, analytics, advertising, account, or third-party SDK. User-initiated place lookup uses Apple Maps, and no lookup or location data is sent to the Work Track developer.
- Precise location: Not collected by the developer. Selected addresses and coordinates remain on-device. One-shot actions discard the sampled coordinate after use. Optional Automatic Attendance uses Always authorization for saved-area boundary events, never continuous GPS; those events remain on-device and are excluded from default reports and standard backups.
- User content: Not collected by the developer. Notes remain on-device unless the user deliberately shares a report.

Re-answer the App Privacy questionnaire if developer-operated networking, analytics, cloud sync, crash reporting under developer control, third-party SDKs, or new location uses are added.

## Owner-Only Submission Inputs

These cannot be completed safely from the repository and must be supplied in App Store Connect:

- Apple Developer team, distribution certificate, provisioning profile, and signing confirmation.
- App Store Connect app record, final SKU, availability, and pricing.
- Hosted support URL.
- Hosted privacy-policy URL using `docs/PRIVACY_POLICY.md` as the source draft.
- Age-rating questionnaire.
- Copyright and contact details.
- Final App Privacy answers.
- App Store screenshots and any preview video.

The Bundle ID cannot be changed after the first build is uploaded, so the owner must confirm `com.benchamberlain.worktrack` before that upload.
