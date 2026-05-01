# SalesforceCensusAPI

An Apex class that lets Salesforce Flow send a mailing address to the US Census Bureau APIs and receive back a validated address, federal and state legislative district identifiers, and a rich set of demographic characteristics useful for marketing and policy work.

---

## What it does

Given a street address, city, state and optional ZIP code the class:

1. **Geocodes / validates the address** via the [Census Geocoder API](https://geocoding.geo.census.gov/geocoder/Geocoding_Services_API.pdf)  
   Returns the standardised matched address, lat/lon coordinates, and all associated geographic identifiers.

2. **Resolves district identifiers**

   | Field | Description |
   |---|---|
   | Federal Congressional District | 2-digit district number (e.g. `04`) |
   | Congressional District GEOID | Full 4-digit GEOID (state FIPS + district) |
   | State FIPS Code | 2-digit state identifier |
   | County FIPS Code | 3-digit county identifier |
   | State Legislative District – Upper | State Senate district name |
   | State Legislative District – Lower | State House district name |

3. **Returns demographic characteristics** for the congressional district via the [ACS 5-Year Estimates API](https://www.census.gov/data/developers/data-sets/acs-5year.html):

   | Category | Fields returned |
   |---|---|
   | **Population** | Total population, Median age |
   | **Ethnicity (counts)** | White (non-Hispanic), Black / African American, Asian, Hispanic / Latino, Two or more races |
   | **Ethnicity (%)** | Percentage share of total population for each group above |
   | **Economic** | Median household income, Population below poverty level, Poverty rate (%), Unemployment rate (%), Median gross rent, Median home value |
   | **Education** | % with bachelor's degree or higher (population 25+) |

---

## Repository layout

```
force-app/
└── main/
    └── default/
        └── classes/
            ├── CensusAPIService.cls           ← invocable service class
            ├── CensusAPIService.cls-meta.xml
            ├── CensusAPIServiceTest.cls        ← unit tests (HttpCalloutMock)
            └── CensusAPIServiceTest.cls-meta.xml
sfdx-project.json
```

---

## Prerequisites

### 1. Remote Site Settings

Both Census Bureau domains must be allow-listed before the callouts will work.

**Setup → Security → Remote Site Settings → New**

| Name | Remote Site URL |
|---|---|
| `Census_Geocoder` | `https://geocoding.geo.census.gov` |
| `Census_ACS` | `https://api.census.gov` |

### 2. Deploy the Apex classes

With the [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli):

```bash
sf org login web --alias myorg
sf project deploy start --source-dir force-app --target-org myorg
```

Or deploy via **Setup → Apex Classes → New** (paste each `.cls` file).

---

## Using the action in a Flow

1. Open **Flow Builder** and add an **Action** element.
2. Search for **"Look Up Census Data for Address"**.
3. Map your address fields to the four input variables:

   | Input | Required | Description |
   |---|---|---|
   | `Street Address` | ✅ | e.g. `4600 Silver Hill Rd` |
   | `City` | ✅ | e.g. `Suitland` |
   | `State (2-letter abbreviation)` | ✅ | e.g. `MD` |
   | `ZIP Code` | ☐ | e.g. `20746` |

4. Use the output variables in subsequent Flow elements (Decision, Assignment, Screen, etc.).

### Key output variables

| Output | Type | Example |
|---|---|---|
| `Match Status` | Text | `MATCH` / `NO_MATCH` / `ERROR` |
| `Validated / Matched Address` | Text | `4600 SILVER HILL RD, SUITLAND, MD, 20746` |
| `Federal Congressional District Number` | Text | `04` |
| `State FIPS Code` | Text | `24` |
| `Total Population` | Number | `716948` |
| `Median Age` | Number | `35.3` |
| `Median Household Income` | Number | `80156` |
| `Poverty Rate (%)` | Number | `14.9` |
| `% Black or African American` | Number | `54.2` |
| `% Bachelor's Degree or Higher` | Number | `24.6` |
| `Error Message` | Text | Only populated on failure |

> **Note:** When `Match Status` is `MATCH` but demographic data could not be fetched the `Error Message` field will describe the ACS failure while all address and district fields remain populated.

---

## Running the tests

```bash
sf apex run test --test-level RunSpecifiedTests \
  --class-names CensusAPIServiceTest \
  --target-org myorg \
  --result-format human \
  --wait 10
```

All tests use `HttpCalloutMock` — no real network calls are made.

---

## External API references

| API | Endpoint | Auth |
|---|---|---|
| Census Geocoder | `https://geocoding.geo.census.gov/geocoder/geographies/address` | None (public) |
| ACS 5-Year Estimates | `https://api.census.gov/data/2022/acs/acs5` | None (public) |
