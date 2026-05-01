# Agent Quickstart (Token-Minimizing Context)

## Project Purpose
Apex invocable action for Salesforce Flow:
1) Geocode address via US Census Geocoder.
2) Extract district identifiers.
3) Fetch ACS demographics for congressional district.

## Files to Read First
1. `force-app/main/default/classes/CensusAPIService.cls`
2. `force-app/main/default/classes/CensusAPIServiceTest.cls`
3. `README.md`

## Hotspots (Most Likely Change Areas)
- `lookUpCensusData` / `processAddress`: orchestration and error behavior.
- `callGeocoderAPI` / `populateDemographics`: network reliability.
- `parseACSResponse`: field mapping/calculations.

## Known Constraints
- Public APIs, no auth currently.
- Uses Remote Site Settings (recommended migration: Named Credentials).
- Potential governor limit issues in bulk Flow runs (2 callouts per input).

## Fast Validation Checklist
- Compile/deploy Apex class changes.
- Run `CensusAPIServiceTest`.
- Re-check mappings for ACS variable names when changing census year.

## If Updating Behavior
- Keep output contract stable for Flow labels/fields.
- Preserve partial-success behavior when ACS fails after successful geocode.
- Add/update unit tests for every branch touched.
