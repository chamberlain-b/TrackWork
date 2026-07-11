# Work Track 1.0 App Store Metadata Draft

This draft matches the current local-only iOS MVP. Recheck it against the final archive before submission.

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

Record office and home days manually, add full-day annual or sick leave, preserve explanatory notes, and make a clearly attributed manual correction when detected evidence is incomplete. Custom excluded days remain separate from attendance and reduce eligible workdays without double-counting holidays or leave.

Review the current month at a glance or choose current month, last 30 days, previous month, current quarter, previous quarter, year to date, or an inclusive custom range. Monthly, quarterly, and yearly trends use the same saved rule and exclusions as the detailed compliance view.

The 1.0 bundle includes verified 2026 public-holiday calendars for every Australian state and territory, New Zealand National, and supported New Zealand regional anniversary options. Missing holiday years produce an explicit error instead of silently assuming there are no holidays.

Generate a styled PDF or spreadsheet-compatible CSV report for any supported period. Default reports contain derived day-level attendance and exclude raw location events and GPS coordinates.

Your app data stays in Work Track's on-device storage. There is no account, advertising, analytics SDK, or app-managed cloud sync. Reports leave the app only when you choose to share them. Settings includes clear privacy information and a confirmed option to delete all on-device user data.

Automatic background location detection is intentionally unavailable in this MVP. Home and office places can be saved for future use, while manual attendance remains the supported workflow.

## Keywords

`hybrid work,office attendance,compliance,leave,work calendar,Australia,New Zealand,PDF,CSV`

## What's New In 1.0

- Manual office, home, leave, note, override, and custom-exclusion records.
- Seven deterministic compliance periods and monthly, quarterly, and yearly trends.
- Verified 2026 AU and NZ public holidays.
- Private PDF and CSV reports.
- On-device privacy disclosure and confirmed data reset.

## App Privacy Draft

- Tracking: No.
- Data collected: No. The app has no network client, analytics, advertising, account, or third-party SDK. Apple defines data processed only on the device and never transmitted to the developer as not collected.
- Precise location: Not collected by the developer. Saved place coordinates remain on-device; automatic detection is disabled in 1.0.
- User content: Not collected by the developer. Notes remain on-device unless the user deliberately shares a report.

Re-answer the App Privacy questionnaire if networking, analytics, cloud sync, crash reporting under developer control, or third-party SDKs are added.

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
