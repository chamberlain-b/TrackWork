# Work Track Privacy Policy Draft

Effective date: 15 July 2026

This document is a source draft for the hosted privacy-policy page required for release. The app owner must publish it at a stable public URL and add that URL to App Store Connect.

## Summary

Work Track is designed as a private, local-first attendance app. It has no account system, advertising, analytics SDK, app-managed cloud sync, or developer-operated network service. Work Track does not transmit personal attendance or location data to the developer.

## Information Stored On Your Device

Depending on the features you use, Work Track can store:

- Office, home, mixed, unknown, leave, and final attendance classifications.
- Office and home minute totals.
- Annual and sick leave records.
- Manual overrides, reasons, and notes.
- Custom excluded dates and reasons.
- Compliance rules, workdays, thresholds, and selected jurisdiction.
- Planned office dates that do not count as attendance until confirmed.
- Saved home and office names, formatted addresses, coordinates, and radii.
- Saved-area entry and exit events created only when Automatic Attendance is enabled.
- User edits to bundled public-holiday records.
- Local preferences for Automatic Attendance and the optional app lock.

Most records are stored in the app's on-device SwiftData store. Small feature preferences are stored in iOS app preferences. Work Track does not operate an account or cloud database.

## Address Search And Current Location

When you search for an address, adjust a place on the map, or use your current location, Apple Maps may process the search text, map context, or location needed to return a result. These requests are user-initiated and governed by [Apple Maps & Privacy](https://www.apple.com/legal/privacy/data/en/apple-maps/). Work Track's developer does not receive this information.

The address and coordinates you select are stored in Work Track's on-device storage. Place selection and Check In each request one foreground location sample and discard that sample after completing the action.

## Optional Automatic Attendance

Automatic Attendance is off by default. It can be enabled only from its settings screen after at least one home or office area is saved. Work Track first requests When In Use access, then separately requests Always access so iOS can deliver saved-area boundary events while the app is closed. No location prompt appears on first launch or merely from opening Location Setup.

Automatic Attendance uses iOS geographic-region monitoring rather than continuous GPS. Work Track stores the saved area, an entry or exit event, its time, and the derived home/office attendance needed for the feature. It does not store a continuously sampled route or the coordinate of each boundary event. Manual corrections, leave, public holidays, and custom exclusions remain authoritative. iOS may delay or miss a boundary event, so Work Track continues to surface unresolved days for review.

You can turn Automatic Attendance off in Work Track, revoke location access in iOS Settings, review the stored entry/exit history, or clear that history. Raw location events are excluded from standard reports and standard portable backups.

## Public-Holiday Data

Work Track bundles verified 2026–2027 public-holiday data and official source attribution for supported Australian and New Zealand jurisdictions. The source URLs are reference metadata; version 1.0 does not contact those sites or download holiday updates.

## Reports And Sharing

Work Track can create PDF and CSV reports at your request. Default reports include derived day-level attendance and can include notes, overrides, leave, custom exclusions, and public-holiday sources. They exclude raw GPS coordinates and raw location events.

Reports remain in managed temporary app storage until they are replaced or you leave the export screen. A report leaves Work Track only when you choose a destination through the iOS share flow. Copies stored by another app, service, person, or device are governed by that destination's privacy and retention practices.

## Portable Backups

Standard JSON backups contain attendance, leave, notes, manual adjustments, rules, plans, exclusions, and user-edited holidays. They omit saved places, addresses, coordinates, and raw location events. Full private backups include those sensitive location records only after an explicit warning. Exported backup files are not encrypted by Work Track; the destination you choose controls their security and retention.

Restores are validated before Work Track changes the on-device store. You can merge backup values with local records or replace the data areas represented by the backup. A standard replace preserves local saved places and raw location events because those areas are absent from the standard file.

## App Lock And Review Reminders

If you enable App Lock, iOS performs Face ID, Touch ID, or device-passcode authentication. Work Track receives only whether authentication succeeded and does not access or store biometric data. The app also obscures attendance while inactive so it is not exposed in the app switcher.

If you enable the weekly review reminder, iOS stores and delivers a local notification. Its title and body contain no attendance, compliance, date, location, or unresolved-day details. Work Track requests notification permission only after you turn this feature on in Settings.

## Data Collection And Tracking

The developer does not collect data from Work Track. Attendance records and saved-place data are not transmitted to the developer. Work Track does not track you across apps or websites.

Apple may process user-initiated Maps requests, App Store information, device backups, or diagnostics according to your Apple settings and Apple's policies. Those platform services are not operated by Work Track.

## Deleting Data

Settings > Privacy & Data > Delete All On-Device Data permanently removes user-owned attendance, leave, notes, manual overrides, compliance settings, plans, custom exclusions, saved places, stored location events, user-edited holidays, and managed temporary reports. It turns off Automatic Attendance and the weekly review reminder, then creates one fresh default compliance rule. The optional app lock remains enabled so the app does not silently reduce an existing privacy protection.

The reset does not revoke permissions in iOS Settings, delete copies you previously shared, or control information retained by your device-backup settings. Bundled public-holiday reference data is not personal data and remains available.

Deleting the Work Track app through iOS also removes its local app container, subject to Apple's device-backup and restoration behavior.

## Changes To This Policy

This policy must be updated before Work Track introduces developer-operated networking, analytics, advertising, third-party SDKs, cloud sync, accounts, new sensitive-data uses, or materially different export behavior. The hosted page should identify its current effective date.

## Contact

The app owner must publish a support contact or support URL with the hosted version of this policy before App Store submission.
