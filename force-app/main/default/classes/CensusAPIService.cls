/**
 * CensusAPIService
 *
 * Invocable Apex class that exposes US Census Bureau geocoding and demographic
 * data to Salesforce Flow.  Given a mailing address the class:
 *
 *   1. Calls the Census Geocoder API to validate / standardise the address and
 *      resolve the federal congressional district, state legislative districts
 *      (upper / lower), and county FIPS identifiers.
 *
 *   2. Calls the Census ACS 5-Year Estimates API to return demographic
 *      characteristics for the matched congressional district including
 *      population, age, ethnicity, household income, poverty rate,
 *      unemployment, educational attainment, median rent and home value.
 *
 * Prerequisites (Salesforce Setup)
 * ─────────────────────────────────────────────────────────────────────────────
 *   Remote Site Settings ▶ add both endpoints:
 *     • https://geocoding.geo.census.gov
 *     • https://api.census.gov
 *
 * Flow Usage
 * ─────────────────────────────────────────────────────────────────────────────
 *   Action type : Apex Action
 *   Label       : Look Up Census Data for Address
 *   Inputs      : Street Address, City, State (2-letter), ZIP Code (optional)
 *   Outputs     : All fields in CensusResult – see inline labels
 */
public with sharing class CensusAPIService {

    // ── API endpoints ─────────────────────────────────────────────────────────

    @TestVisible
    private static final String GEOCODER_BASE_URL =
        'https://geocoding.geo.census.gov/geocoder/geographies/address';

    @TestVisible
    private static final String ACS_BASE_URL =
        'https://api.census.gov/data/2022/acs/acs5';

    // Census sentinel value returned when a figure is not available
    private static final String CENSUS_NA = '-666666666';

    // ACS variable codes requested
    //   B01003_001E  Total population
    //   B01002_001E  Median age
    //   B03002_003E  White alone, not Hispanic or Latino
    //   B03002_004E  Black or African American alone, not Hispanic
    //   B03002_006E  Asian alone, not Hispanic
    //   B03002_009E  Two or more races, not Hispanic
    //   B03002_012E  Hispanic or Latino (any race)
    //   B19013_001E  Median household income (past 12 months)
    //   B17001_002E  Population below poverty level
    //   B17001_001E  Population for whom poverty status is determined
    //   B23025_005E  Civilian labor force – unemployed
    //   B23025_003E  Civilian labor force (total)
    //   B15003_022E  Educational attainment – bachelor's degree
    //   B15003_023E  Educational attainment – master's degree
    //   B15003_024E  Educational attainment – professional school degree
    //   B15003_025E  Educational attainment – doctorate degree
    //   B15003_001E  Population 25 years and over (denominator for education)
    //   B25064_001E  Median gross rent
    //   B25077_001E  Median value of owner-occupied housing units
    @TestVisible
    private static final String ACS_VARIABLES =
        'NAME,B01003_001E,B01002_001E,' +
        'B03002_003E,B03002_004E,B03002_006E,B03002_009E,B03002_012E,' +
        'B19013_001E,B17001_002E,B17001_001E,' +
        'B23025_005E,B23025_003E,' +
        'B15003_022E,B15003_023E,B15003_024E,B15003_025E,B15003_001E,' +
        'B25064_001E,B25077_001E';

    // ── Input wrapper ─────────────────────────────────────────────────────────

    public class AddressInput {
        @InvocableVariable(label='Street Address' required=true)
        public String street;

        @InvocableVariable(label='City' required=true)
        public String city;

        @InvocableVariable(label='State (2-letter abbreviation)' required=true)
        public String state;

        @InvocableVariable(label='ZIP Code')
        public String zip;
    }

    // ── Output wrapper ────────────────────────────────────────────────────────

    public class CensusResult {

        // ── Address validation ────────────────────────────────────────────────
        @InvocableVariable(label='Match Status (MATCH / NO_MATCH / ERROR)')
        public String matchStatus;

        @InvocableVariable(label='Validated / Matched Address')
        public String matchedAddress;

        @InvocableVariable(label='Latitude')
        public Decimal latitude;

        @InvocableVariable(label='Longitude')
        public Decimal longitude;

        // ── District identifiers ──────────────────────────────────────────────
        @InvocableVariable(label='Federal Congressional District Number')
        public String congressionalDistrict;

        @InvocableVariable(label='Congressional District GEOID')
        public String cdGeoId;

        @InvocableVariable(label='State FIPS Code')
        public String stateFips;

        @InvocableVariable(label='County FIPS Code')
        public String countyFips;

        @InvocableVariable(label='State Legislative District (Upper / Senate)')
        public String stateDistrictUpper;

        @InvocableVariable(label='State Legislative District (Lower / House)')
        public String stateDistrictLower;

        // ── Demographics – population ─────────────────────────────────────────
        @InvocableVariable(label='Total Population')
        public Integer totalPopulation;

        @InvocableVariable(label='Median Age')
        public Decimal medianAge;

        // ── Demographics – ethnicity (counts) ────────────────────────────────
        @InvocableVariable(label='White (Non-Hispanic) Population')
        public Integer whitePopulation;

        @InvocableVariable(label='Black or African American Population')
        public Integer blackPopulation;

        @InvocableVariable(label='Asian Population')
        public Integer asianPopulation;

        @InvocableVariable(label='Hispanic or Latino Population')
        public Integer hispanicPopulation;

        @InvocableVariable(label='Two or More Races Population')
        public Integer twoOrMoreRacesPopulation;

        // ── Demographics – ethnicity (percentages) ───────────────────────────
        @InvocableVariable(label='% White (Non-Hispanic)')
        public Decimal pctWhite;

        @InvocableVariable(label='% Black or African American')
        public Decimal pctBlack;

        @InvocableVariable(label='% Asian')
        public Decimal pctAsian;

        @InvocableVariable(label='% Hispanic or Latino')
        public Decimal pctHispanic;

        @InvocableVariable(label='% Two or More Races')
        public Decimal pctTwoOrMore;

        // ── Demographics – economic ───────────────────────────────────────────
        @InvocableVariable(label='Median Household Income')
        public Integer medianHouseholdIncome;

        @InvocableVariable(label='Population Below Poverty Level')
        public Integer populationBelowPoverty;

        @InvocableVariable(label='Poverty Rate (%)')
        public Decimal povertyRate;

        @InvocableVariable(label='Unemployment Rate (%)')
        public Decimal unemploymentRate;

        @InvocableVariable(label='Median Gross Rent')
        public Integer medianGrossRent;

        @InvocableVariable(label='Median Home Value')
        public Integer medianHomeValue;

        // ── Demographics – education ──────────────────────────────────────────
        @InvocableVariable(label='% With Bachelor\'s Degree or Higher')
        public Decimal pctBachelorOrHigher;

        // ── Error ─────────────────────────────────────────────────────────────
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    // ── Salesforce Flow entry point ───────────────────────────────────────────

    @InvocableMethod(
        label='Look Up Census Data for Address'
        description='Validates a mailing address and retrieves congressional district and demographic characteristics from the US Census Bureau APIs.'
        callout=true
    )
    public static List<CensusResult> lookUpCensusData(List<AddressInput> inputs) {
        List<CensusResult> results = new List<CensusResult>();
        for (AddressInput input : inputs) {
            results.add(processAddress(input));
        }
        return results;
    }

    // ── Core processing ───────────────────────────────────────────────────────

    @TestVisible
    private static CensusResult processAddress(AddressInput input) {
        CensusResult result = new CensusResult();
        try {
            // Step 1: Geocode the address
            String geoJson = callGeocoderAPI(input);
            Map<String, Object> root =
                (Map<String, Object>) JSON.deserializeUntyped(geoJson);
            Map<String, Object> geoResult =
                (Map<String, Object>) root.get('result');
            List<Object> matches = geoResult != null
                ? (List<Object>) geoResult.get('addressMatches')
                : null;

            if (matches == null || matches.isEmpty()) {
                result.matchStatus  = 'NO_MATCH';
                result.errorMessage = 'Address could not be matched by Census geocoder.';
                return result;
            }

            Map<String, Object> match = (Map<String, Object>) matches[0];
            result.matchStatus    = 'MATCH';
            result.matchedAddress = (String) match.get('matchedAddress');

            Map<String, Object> coords =
                (Map<String, Object>) match.get('coordinates');
            if (coords != null) {
                result.longitude = toDecimal(coords.get('x'));
                result.latitude  = toDecimal(coords.get('y'));
            }

            Map<String, Object> geographies =
                (Map<String, Object>) match.get('geographies');
            if (geographies != null) {
                extractDistricts(geographies, result);
            }

            // Step 2: Fetch ACS demographics for the resolved district
            if (String.isNotBlank(result.stateFips) &&
                    String.isNotBlank(result.congressionalDistrict)) {
                populateDemographics(result);
            }

        } catch (Exception e) {
            result.matchStatus  = 'ERROR';
            result.errorMessage = e.getMessage();
        }
        return result;
    }

    // ── Census Geocoder callout ───────────────────────────────────────────────

    @TestVisible
    private static String callGeocoderAPI(AddressInput input) {
        String url = GEOCODER_BASE_URL
            + '?benchmark=Public_AR_Current'
            + '&vintage=Current_Current'
            + '&format=json'
            + '&street=' + EncodingUtil.urlEncode(input.street, 'UTF-8')
            + '&city='   + EncodingUtil.urlEncode(input.city,   'UTF-8')
            + '&state='  + EncodingUtil.urlEncode(input.state,  'UTF-8');

        if (String.isNotBlank(input.zip)) {
            url += '&zip=' + EncodingUtil.urlEncode(input.zip, 'UTF-8');
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new CensusAPIException(
                'Geocoder API returned HTTP ' + res.getStatusCode()
                    + ': ' + res.getStatus()
            );
        }
        return res.getBody();
    }

    // ── ACS demographics callout ──────────────────────────────────────────────

    @TestVisible
    private static void populateDemographics(CensusResult result) {
        // Ensure the district number is zero-padded to 2 digits
        String district = result.congressionalDistrict;
        if (district.length() == 1) {
            district = '0' + district;
        }

        String url = ACS_BASE_URL
            + '?get=' + ACS_VARIABLES
            + '&for=congressional%20district:' + district
            + '&in=state:' + result.stateFips;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            // Non-fatal: return partial result with address/district data intact
            result.errorMessage =
                'ACS API returned HTTP ' + res.getStatusCode()
                    + '. Demographic data unavailable.';
            return;
        }
        parseACSResponse(res.getBody(), result);
    }

    // ── ACS response parser ───────────────────────────────────────────────────

    @TestVisible
    private static void parseACSResponse(String jsonBody, CensusResult result) {
        // ACS format: [ [header1, header2, …], [value1, value2, …], … ]
        List<Object> rawArray = (List<Object>) JSON.deserializeUntyped(jsonBody);
        if (rawArray == null || rawArray.size() < 2) {
            return;
        }

        List<Object> headers = (List<Object>) rawArray[0];
        List<Object> data    = (List<Object>) rawArray[1];

        Map<String, Integer> idx = new Map<String, Integer>();
        for (Integer i = 0; i < headers.size(); i++) {
            idx.put((String) headers[i], i);
        }

        // Population
        result.totalPopulation = getInt(data, idx, 'B01003_001E');
        result.medianAge       = getDec(data, idx, 'B01002_001E');

        // Ethnicity counts
        Integer white    = getInt(data, idx, 'B03002_003E');
        Integer black    = getInt(data, idx, 'B03002_004E');
        Integer asian    = getInt(data, idx, 'B03002_006E');
        Integer twoPlus  = getInt(data, idx, 'B03002_009E');
        Integer hispanic = getInt(data, idx, 'B03002_012E');

        result.whitePopulation          = white;
        result.blackPopulation          = black;
        result.asianPopulation          = asian;
        result.twoOrMoreRacesPopulation = twoPlus;
        result.hispanicPopulation       = hispanic;

        // Economic
        result.medianHouseholdIncome  = getInt(data, idx, 'B19013_001E');
        result.populationBelowPoverty = getInt(data, idx, 'B17001_002E');
        result.medianGrossRent        = getInt(data, idx, 'B25064_001E');
        result.medianHomeValue        = getInt(data, idx, 'B25077_001E');

        // Unemployment rate
        Integer unemployed = getInt(data, idx, 'B23025_005E');
        Integer laborForce = getInt(data, idx, 'B23025_003E');
        if (unemployed != null && laborForce != null && laborForce > 0) {
            result.unemploymentRate =
                (Decimal.valueOf(unemployed) / Decimal.valueOf(laborForce) * 100)
                    .setScale(1);
        }

        // Education – bachelor's degree or higher (% of population 25+)
        Integer bach  = getInt(data, idx, 'B15003_022E');
        Integer mast  = getInt(data, idx, 'B15003_023E');
        Integer prof  = getInt(data, idx, 'B15003_024E');
        Integer doct  = getInt(data, idx, 'B15003_025E');
        Integer pop25 = getInt(data, idx, 'B15003_001E');
        if (bach != null && mast != null && prof != null && doct != null
                && pop25 != null && pop25 > 0) {
            Integer totalBachPlus = bach + mast + prof + doct;
            result.pctBachelorOrHigher =
                (Decimal.valueOf(totalBachPlus) / Decimal.valueOf(pop25) * 100)
                    .setScale(1);
        }

        // Ethnicity percentages (share of total population)
        if (result.totalPopulation != null && result.totalPopulation > 0) {
            Decimal pop = Decimal.valueOf(result.totalPopulation);
            result.pctWhite    = white    != null
                ? (Decimal.valueOf(white)    / pop * 100).setScale(1) : null;
            result.pctBlack    = black    != null
                ? (Decimal.valueOf(black)    / pop * 100).setScale(1) : null;
            result.pctAsian    = asian    != null
                ? (Decimal.valueOf(asian)    / pop * 100).setScale(1) : null;
            result.pctHispanic = hispanic != null
                ? (Decimal.valueOf(hispanic) / pop * 100).setScale(1) : null;
            result.pctTwoOrMore = twoPlus != null
                ? (Decimal.valueOf(twoPlus)  / pop * 100).setScale(1) : null;
        }

        // Poverty rate (share of population for whom status was determined)
        Integer povPop = getInt(data, idx, 'B17001_001E');
        if (result.populationBelowPoverty != null && povPop != null && povPop > 0) {
            result.povertyRate =
                (Decimal.valueOf(result.populationBelowPoverty)
                    / Decimal.valueOf(povPop) * 100).setScale(1);
        }
    }

    // ── Geography extraction from geocoder response ───────────────────────────

    private static void extractDistricts(
            Map<String, Object> geographies, CensusResult result) {
        for (String key : geographies.keySet()) {
            String k = key.toLowerCase();
            List<Object> items = (List<Object>) geographies.get(key);
            if (items == null || items.isEmpty()) {
                continue;
            }
            Map<String, Object> first = (Map<String, Object>) items[0];

            if (k.contains('congressional district')) {
                result.cdGeoId               = getStr(first, 'GEOID');
                result.stateFips             = getStr(first, 'STATEFP');
                result.congressionalDistrict = getStr(first, 'DISTRICT');
            } else if (k.contains('upper') || k.contains('senate')) {
                result.stateDistrictUpper = getStr(first, 'NAME');
            } else if (k.contains('lower') || k.contains('house')) {
                result.stateDistrictLower = getStr(first, 'NAME');
            } else if (k.contains('counti') || k.contains('county')) {
                result.countyFips = getStr(first, 'COUNTYFP');
                if (String.isBlank(result.stateFips)) {
                    result.stateFips = getStr(first, 'STATEFP');
                }
            }
        }
    }

    // ── Parsing helpers ───────────────────────────────────────────────────────

    private static String getStr(Map<String, Object> m, String key) {
        Object v = m.get(key);
        return v != null ? String.valueOf(v) : null;
    }

    private static Integer getInt(
            List<Object> data, Map<String, Integer> idx, String key) {
        if (!idx.containsKey(key)) {
            return null;
        }
        Object v = data[idx.get(key)];
        if (v == null) {
            return null;
        }
        String s = String.valueOf(v);
        if (s == 'null' || s.startsWith(CENSUS_NA)) {
            return null;
        }
        try {
            // Strip decimal portion if present (some integer variables include ".0")
            return Integer.valueOf(s.contains('.') ? s.substringBefore('.') : s);
        } catch (Exception e) {
            return null;
        }
    }

    private static Decimal getDec(
            List<Object> data, Map<String, Integer> idx, String key) {
        if (!idx.containsKey(key)) {
            return null;
        }
        Object v = data[idx.get(key)];
        if (v == null) {
            return null;
        }
        String s = String.valueOf(v);
        if (s == 'null' || s.startsWith(CENSUS_NA)) {
            return null;
        }
        try {
            return Decimal.valueOf(s);
        } catch (Exception e) {
            return null;
        }
    }

    private static Decimal toDecimal(Object o) {
        if (o == null) {
            return null;
        }
        try {
            return Decimal.valueOf(String.valueOf(o));
        } catch (Exception e) {
            return null;
        }
    }

    // ── Custom exception ──────────────────────────────────────────────────────

    public class CensusAPIException extends Exception {}
}
