# Work Track Privacy Policy Draft

Effective date: 11 July 2026

This document is a source draft for the hosted privacy-policy page required for release. The app owner must publish it at a stable public URL and add that URL to App Store Connect.

## Summary

Work Track is designed as a private, local-first attendance app. It has no account system, advertising, analytics SDK, app-managed cloud sync, or app network service. Work Track does not transmit personal attendance or location data to the developer.

## Information Stored On Your Device

Depending on the features you use, Work Track can store:

- Office, home, mixed, unknown, leave, and final attendance classifications.
- Office and home minute totals.
- Annual and sick leave records.
- Manual overrides, reasons, and notes.
- Custom excluded dates and reasons.
- Compliance rules, workdays, thresholds, and selected jurisdiction.
- Saved home and office names, coordinates, and radii.
- Location-event records created by app foundations.
- User edits to bundled public-holiday records.

This information is stored in the app's on-device SwiftData store. Automatic background location detection and permission requests are unavailable in version 1.0.

## Public-Holiday Data

Work Track bundles verified 2026 public-holiday data and official source attribution for supported Australian and New Zealand jurisdictions. The source URLs are reference metadata; version 1.0 does not contact those sites or download holiday updates.

## Reports And Sharing

Work Track can create PDF and CSV reports at your request. Default reports include derived day-level attendance and can include notes, overrides, leave, custom exclusions, and public-holiday sources. They exclude raw GPS coordinates and raw location events.

Reports remain in managed temporary app storage until they are replaced or you leave the export screen. A report leaves Work Track only when you choose a destination through the iOS share flow. Copies stored by another app, service, person, or device are governed by that destination's privacy and retention practices.

## Data Collection And Tracking

The developer does not collect data from Work Track. Data processed only on your device is not transmitted to the developer or third parties by the app. Work Track does not track you across apps or websites.

Apple may process App Store, device-backup, or diagnostics information according to your Apple settings and Apple's policies. Those platform services are not operated by Work Track.

## Deleting Data

Settings > Privacy & Data > Delete All On-Device Data permanently removes user-owned attendance, leave, notes, manual overrides, compliance settings, custom exclusions, saved places, stored location events, user-edited holidays, and managed temporary reports. It then creates one fresh default compliance rule.

The reset does not revoke permissions in iOS Settings, delete copies you previously shared, or control information retained by your device-backup settings. Bundled public-holiday reference data is not personal data and remains available.

Deleting the Work Track app through iOS also removes its local app container, subject to Apple's device-backup and restoration behavior.

## Changes To This Policy

This policy must be updated before Work Track introduces networking, analytics, advertising, third-party SDKs, cloud sync, accounts, new sensitive-data uses, or materially different export behavior. The hosted page should identify its current effective date.

## Contact

The app owner must publish a support contact or support URL with the hosted version of this policy before App Store submission.
