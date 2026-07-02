# Holiday Fixture Schema

These JSON files are development and test fixtures for bundled public holiday data. They are not a provider implementation and they do not perform network fetching.

The fixture files intentionally avoid claiming to be exhaustive. Treat each file as sample data unless the dates and jurisdiction coverage have been verified separately against the named public source.

## File Naming

Use lowercase file names in this pattern:

```text
holidays_<country-or-country-region>_<year>.json
```

Examples:

```text
holidays_au_vic_2026.json
holidays_nz_national_2026.json
holidays_nz_auckland_2026.json
```

## Date Format

All holiday dates use ISO `yyyy-MM-dd` strings.

Dates are day-level values. Provider and calculator code should normalize them for day-level comparison before use.

## Top-Level Object

Each fixture is a JSON object with these fields:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `schemaVersion` | String | Yes | Fixture schema version. Current value: `1.0`. |
| `countryCode` | String | Yes | ISO-like country code used by the app, such as `AU` or `NZ`. |
| `jurisdictionCode` | String | Yes | App jurisdiction code, such as `AU-VIC`, `NZ-NATIONAL`, or `NZ-AUCKLAND`. |
| `year` | Number | Yes | Gregorian calendar year covered by the fixture. |
| `sourceName` | String | Yes | Human-readable source name for the fixture collection. |
| `sourceURL` | String | Yes | Public URL for the named source. |
| `verifiedExhaustive` | Boolean | Yes | `true` only when the fixture has been separately verified as exhaustive. Development fixtures should normally use `false`. |
| `inheritsFrom` | Array of String | No | Jurisdiction codes whose holidays should be inherited by this fixture. Use this for regional NZ fixtures that build on `NZ-NATIONAL`. |
| `holidays` | Array | Yes | Holiday entries for this fixture. |

## Holiday Entry

Each item in `holidays` has these fields:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `date` | String | Yes | Holiday date in `yyyy-MM-dd` format. |
| `name` | String | Yes | Display name for the holiday. |
| `sourceName` | String | Yes | Human-readable source name for this date. |
| `sourceURL` | String | Yes | Public URL for this date's source. |
| `notes` | String | No | Short clarification, such as observed-day or fixture-scope notes. |

## Inheritance

Regional NZ fixtures can inherit national holidays by declaring:

```json
"inheritsFrom": ["NZ-NATIONAL"]
```

The regional fixture should then list only regional/provincial anniversary dates in its own `holidays` array. Provider code added later can merge inherited holidays with the regional entries and handle duplicate dates deterministically.

## Example

```json
{
  "schemaVersion": "1.0",
  "countryCode": "NZ",
  "jurisdictionCode": "NZ-AUCKLAND",
  "year": 2026,
  "sourceName": "Employment New Zealand public holidays",
  "sourceURL": "https://www.employment.govt.nz/leave-and-holidays/public-holidays/public-holidays-and-anniversary-dates/",
  "verifiedExhaustive": false,
  "inheritsFrom": ["NZ-NATIONAL"],
  "holidays": [
    {
      "date": "2026-01-26",
      "name": "Auckland Anniversary Day",
      "sourceName": "Employment New Zealand public holidays",
      "sourceURL": "https://www.employment.govt.nz/leave-and-holidays/public-holidays/public-holidays-and-anniversary-dates/"
    }
  ]
}
```
