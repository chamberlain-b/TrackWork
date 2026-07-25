# Holiday Fixture Schema

These JSON files are the app's offline public-holiday calendars. They do not perform network fetching. A file is eligible for compliance calculations only when `verifiedExhaustive` is `true` and its dates have been checked against the named official source.

The bundled release coverage is calendar years 2026 and 2027 for every jurisdiction in `JurisdictionCatalog`. `HolidayCoverage.supportedYears` is the code-level source of truth for those bundled years. Requests for another year fail with a typed missing-data error; they must never be interpreted as a year with zero public holidays.

Australian fixtures contain full-day, state- or territory-wide public holidays. Capital-city, municipal, regional, bank-only, industry-only, and part-day evening holidays are outside the state-level MVP jurisdiction model and are not treated as whole-day compliance exclusions. When an official source lists both an actual date and an additional full-day holiday, both are included. When it lists only a substitute date, only that substitute is included. Victoria uses the statewide Melbourne Cup default; some regional councils substitute another local date.

New Zealand national fixtures include the actual date and an additional observed date when the government publishes both. Regional fixtures contain the government-published observed anniversary date and inherit the national fixture. This ensures a normal weekday work pattern receives the observed exclusion while preserving the published actual date for weekend work patterns.

## Official Sources

The 2027 fixtures were checked on 12 July 2026 against these government sources. Each JSON file preserves its applicable source in `sourceName` and `sourceURL`.

| Jurisdiction | Official source |
| --- | --- |
| ACT | [ACT Government public holidays](https://www.act.gov.au/living-in-the-act/public-holidays-school-terms-and-daylight-saving) |
| NSW | [NSW Government public holidays](https://www.nsw.gov.au/about-nsw/public-holidays) |
| NT | [Northern Territory Government public holidays](https://nt.gov.au/nt-public-holidays) |
| Queensland | [Queensland Government public holidays](https://www.qld.gov.au/recreation/travel/holidays/public) |
| South Australia | [SafeWork SA public holidays](https://www.safework.sa.gov.au/resources/public-holidays) |
| Tasmania | [WorkSafe Tasmania public holidays](https://worksafe.tas.gov.au/topics/laws-and-compliance/public-holidays) |
| Victoria | [Business Victoria 2027 public holidays](https://business.vic.gov.au/business-information/public-holidays/victorian-public-holidays-2027) |
| Western Australia | [Western Australian Government public holidays](https://www.wa.gov.au/service/employment/workplace-arrangements/public-holidays-western-australia) |
| New Zealand | [New Zealand Government public holidays and anniversary dates](https://www.govt.nz/browse/work/public-holidays-and-work/public-holidays-and-anniversary-dates/) |

Business Victoria still marks the 2027 Friday before the AFL Grand Final as subject to the AFL schedule. The bundled 24 September date is published in the official [Victorian Department of Education 2026–2030 calendar](https://www.education.vic.gov.au/Documents/about/department/term-dates.pdf), whose URL is preserved on that holiday entry. Recheck it against Business Victoria when the 2027 AFL schedule is released.

## File Naming

Use lowercase file names in this pattern:

```text
holidays_<country-or-country-region>_<year>.json
```

Examples:

```text
holidays_au_vic_2026.json
holidays_au_vic_2027.json
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
| `verifiedExhaustive` | Boolean | Yes | Must be `true` for release data after verification against the official source. The provider rejects `false`. |
| `inheritsFrom` | Array of String | No | Jurisdiction codes whose holidays should be inherited by this fixture. Use this for regional NZ fixtures that build on `NZ-NATIONAL`. |
| `holidays` | Array | Yes | Holiday entries for this fixture. |

## Holiday Entry

Each item in `holidays` has these fields:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `date` | String | Yes | Holiday date in `yyyy-MM-dd` format. |
| `name` | String | Yes | Display name for the holiday. |
| `sourceName` | String | No | Per-date source override. Defaults to the fixture's source name. |
| `sourceURL` | String | No | Per-date source override. Defaults to the fixture's source URL. |
| `notes` | String | No | Short clarification, such as observed-day or fixture-scope notes. |

## Inheritance

Regional NZ fixtures can inherit national holidays by declaring:

```json
"inheritsFrom": ["NZ-NATIONAL"]
```

The regional fixture lists only its regional/provincial anniversary date. The provider merges inherited holidays with the regional entry and assigns the selected effective jurisdiction ID to the complete result so downstream jurisdiction filtering cannot discard national holidays.

## Example

```json
{
  "schemaVersion": "1.0",
  "countryCode": "NZ",
  "jurisdictionCode": "NZ-AUCKLAND",
  "year": 2027,
  "sourceName": "New Zealand Government regional anniversary dates",
  "sourceURL": "https://www.govt.nz/browse/work/public-holidays-and-work/public-holidays-and-anniversary-dates/",
  "verifiedExhaustive": true,
  "inheritsFrom": ["NZ-NATIONAL"],
  "holidays": [
    {
      "date": "2027-02-01",
      "name": "Auckland Anniversary Day",
      "notes": "Observed date."
    }
  ]
}
```
