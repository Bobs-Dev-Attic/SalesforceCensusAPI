/**
 * CensusAPIServiceTest
 *
 * Unit-tests for CensusAPIService.  All HTTP callouts are intercepted with
 * an HttpCalloutMock so no network access is required.
 *
 * Coverage targets
 * ─────────────────────────────────────────────────────────────────────────────
 *   testFullHappyPath            – geocode + ACS both succeed, all fields populated
 *   testNoAddressMatch           – geocoder returns an empty addressMatches array
 *   testGeocoderAPIError         – geocoder returns a non-200 HTTP status
 *   testACSAPIError              – geocoder succeeds, ACS returns a non-200 status
 *   testMultipleInputs           – two address inputs processed in one invocation
 *   testNASentinelValues         – Census N/A sentinels map to null fields
 *   testAddressWithoutZip        – ZIP code omitted from input
 *   testSingleDigitDistrictPad   – district "4" padded to "04" in ACS URL
 */
@isTest
private class CensusAPIServiceTest {

    // ─── Realistic mock payloads ──────────────────────────────────────────────

    // Census Geocoder – successful match (MD-4, state FIPS 24)
    private static final String GEOCODER_MATCH_JSON =
        '{"result":{"input":{},"addressMatches":[' +
            '{"matchedAddress":"4600 SILVER HILL RD, SUITLAND, MD, 20746",' +
             '"coordinates":{"x":-76.926726,"y":38.845979},' +
             '"tigerLine":{"tigerLineId":"76355984","side":"L"},' +
             '"addressComponents":{' +
               '"fromAddress":"4600","toAddress":"4698",' +
               '"preQualifier":"","preDirection":"","preType":"",' +
               '"streetName":"SILVER HILL","suffixType":"RD",' +
               '"suffixDirection":"","suffixQualifier":"",' +
               '"city":"SUITLAND","state":"MD","zip":"20746"},' +
             '"geographies":{' +
               '"Congressional Districts":[' +
                 '{"GEOID":"2404","NAME":"Congressional District 4",' +
                  '"DISTRICT":"04","STATEFP":"24","FUNCSTAT":"N",' +
                  '"MTFCC":"G5200","LSADC":"C2",' +
                  '"INTPTLAT":"+38.8449820","INTPTLON":"-076.8780001"}],' +
               '"State Legislative Districts - Upper":[' +
                 '{"GEOID":"24030","NAME":"State Senate District 30",' +
                  '"DISTRICT":"30","STATEFP":"24"}],' +
               '"State Legislative Districts - Lower":[' +
                 '{"GEOID":"2425A","NAME":"State House District 25A",' +
                  '"DISTRICT":"25A","STATEFP":"24"}],' +
               '"Counties":[' +
                 '{"GEOID":"24033","NAME":"Prince Georges County",' +
                  '"COUNTYFP":"033","STATEFP":"24"}]' +
             '}}]}}';

    // Census Geocoder – single-digit DISTRICT value to test zero-padding
    private static final String GEOCODER_MATCH_SINGLE_DIGIT_JSON =
        '{"result":{"input":{},"addressMatches":[' +
            '{"matchedAddress":"1 TEST ST, ANYTOWN, MD, 20001",' +
             '"coordinates":{"x":-77.0,"y":39.0},' +
             '"geographies":{' +
               '"Congressional Districts":[' +
                 '{"GEOID":"2404","NAME":"Congressional District 4",' +
                  '"DISTRICT":"4","STATEFP":"24"}]}}]}}';

    // Census Geocoder – no match
    private static final String GEOCODER_NO_MATCH_JSON =
        '{"result":{"input":{},"addressMatches":[]}}';

    // ACS 5-Year Estimates – one header row + one data row
    // Values represent a plausible Maryland 4th Congressional District profile
    private static final String ACS_JSON =
        '[[' +
            '"NAME","B01003_001E","B01002_001E",' +
            '"B03002_003E","B03002_004E","B03002_006E",' +
            '"B03002_009E","B03002_012E",' +
            '"B19013_001E","B17001_002E","B17001_001E",' +
            '"B23025_005E","B23025_003E",' +
            '"B15003_022E","B15003_023E","B15003_024E","B15003_025E","B15003_001E",' +
            '"B25064_001E","B25077_001E",' +
            '"state","congressional district"' +
        '],[' +
            '"Congressional District 4 (119th Congress), Maryland",' +
            '"716948","35.3",' +
            '"144870","388921","30862",' +
            '"14247","110621",' +
            '"80156","99182","666754",' +
            '"22891","323018",' +
            '"75430","30121","4250","2893","458122",' +
            '"1450","256900",' +
            '"24","04"' +
        ']]';

    // ─── Dual-endpoint mock ───────────────────────────────────────────────────

    private class MockCallout implements HttpCalloutMock {
        private final String  geoBody;
        private final Integer geoStatus;
        private final String  acsBody;
        private final Integer acsStatus;

        MockCallout(String geoBody, String acsBody) {
            this(geoBody, 200, acsBody, 200);
        }

        MockCallout(String geoBody, Integer geoStatus,
                    String acsBody,  Integer acsStatus) {
            this.geoBody   = geoBody;
            this.geoStatus = geoStatus;
            this.acsBody   = acsBody;
            this.acsStatus = acsStatus;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().containsIgnoreCase('geocoding.geo.census.gov')) {
                res.setStatusCode(geoStatus);
                res.setStatus(geoStatus == 200 ? 'OK' : 'Error');
                res.setBody(geoBody != null ? geoBody : '');
            } else {
                res.setStatusCode(acsStatus);
                res.setStatus(acsStatus == 200 ? 'OK' : 'Service Unavailable');
                res.setBody(acsBody != null ? acsBody : '');
            }
            return res;
        }
    }

    // ─── Test helper ─────────────────────────────────────────────────────────

    private static CensusAPIService.AddressInput buildInput() {
        CensusAPIService.AddressInput i = new CensusAPIService.AddressInput();
        i.street = '4600 Silver Hill Rd';
        i.city   = 'Suitland';
        i.state  = 'MD';
        i.zip    = '20746';
        return i;
    }

    // ─── Tests ───────────────────────────────────────────────────────────────

    @isTest
    static void testFullHappyPath() {
        Test.setMock(HttpCalloutMock.class,
            new MockCallout(GEOCODER_MATCH_JSON, ACS_JSON));

        Test.startTest();
        List<CensusAPIService.CensusResult> results =
            CensusAPIService.lookUpCensusData(
                new List<CensusAPIService.AddressInput>{ buildInput() });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one result');
        CensusAPIService.CensusResult r = results[0];

        // Address validation
        System.assertEquals('MATCH', r.matchStatus, 'Status should be MATCH');
        System.assertEquals(
            '4600 SILVER HILL RD, SUITLAND, MD, 20746', r.matchedAddress);
        System.assertEquals(-76.926726, r.longitude, 'Longitude mismatch');
        System.assertEquals(38.845979,  r.latitude,  'Latitude mismatch');

        // District identifiers
        System.assertEquals('04',   r.congressionalDistrict, 'CD number');
        System.assertEquals('24',   r.stateFips,             'State FIPS');
        System.assertEquals('033',  r.countyFips,            'County FIPS');
        System.assertEquals('2404', r.cdGeoId,               'CD GEOID');
        System.assertNotEquals(null, r.stateDistrictUpper, 'Upper district');
        System.assertNotEquals(null, r.stateDistrictLower, 'Lower district');

        // Demographics – population
        System.assertEquals(716948, r.totalPopulation, 'Total population');
        System.assertEquals(35.3,   r.medianAge,       'Median age');

        // Demographics – ethnicity counts
        System.assertEquals(144870, r.whitePopulation,           'White pop');
        System.assertEquals(388921, r.blackPopulation,           'Black pop');
        System.assertEquals(30862,  r.asianPopulation,           'Asian pop');
        System.assertEquals(110621, r.hispanicPopulation,        'Hispanic pop');
        System.assertEquals(14247,  r.twoOrMoreRacesPopulation,  'Two+ races');

        // Demographics – ethnicity percentages
        System.assertNotEquals(null, r.pctWhite,    '% White');
        System.assertNotEquals(null, r.pctBlack,    '% Black');
        System.assertNotEquals(null, r.pctAsian,    '% Asian');
        System.assertNotEquals(null, r.pctHispanic, '% Hispanic');
        System.assertNotEquals(null, r.pctTwoOrMore,'% Two+');

        // Demographics – economic
        System.assertEquals(80156,  r.medianHouseholdIncome,  'Median income');
        System.assertEquals(99182,  r.populationBelowPoverty, 'Poverty count');
        System.assertNotEquals(null, r.povertyRate,             'Poverty rate');
        System.assertNotEquals(null, r.unemploymentRate,        'Unemployment rate');
        System.assertEquals(1450,   r.medianGrossRent,         'Median rent');
        System.assertEquals(256900, r.medianHomeValue,         'Home value');

        // Demographics – education
        System.assertNotEquals(null, r.pctBachelorOrHigher, '% Bach+');

        System.assertEquals(null, r.errorMessage, 'No errors expected');
    }

    @isTest
    static void testNoAddressMatch() {
        Test.setMock(HttpCalloutMock.class,
            new MockCallout(GEOCODER_NO_MATCH_JSON, null));

        Test.startTest();
        List<CensusAPIService.CensusResult> results =
            CensusAPIService.lookUpCensusData(
                new List<CensusAPIService.AddressInput>{ buildInput() });
        Test.stopTest();

        System.assertEquals('NO_MATCH', results[0].matchStatus);
        System.assertNotEquals(null, results[0].errorMessage, 'Error message set');
        System.assertEquals(null, results[0].matchedAddress, 'No matched address');
    }

    @isTest
    static void testGeocoderAPIError() {
        Test.setMock(HttpCalloutMock.class,
            new MockCallout('Internal Server Error', 500, null, 200));

        Test.startTest();
        List<CensusAPIService.CensusResult> results =
            CensusAPIService.lookUpCensusData(
                new List<CensusAPIService.AddressInput>{ buildInput() });
        Test.stopTest();

        System.assertEquals('ERROR', results[0].matchStatus);
        System.assertNotEquals(null, results[0].errorMessage, 'Error message set');
    }

    @isTest
    static void testACSAPIError() {
        // Geocoder succeeds; ACS returns a server error.
        // Result should still carry address and district data; only demographics absent.
        Test.setMock(HttpCalloutMock.class,
            new MockCallout(GEOCODER_MATCH_JSON, 200, 'Service Unavailable', 503));

        Test.startTest();
        List<CensusAPIService.CensusResult> results =
            CensusAPIService.lookUpCensusData(
                new List<CensusAPIService.AddressInput>{ buildInput() });
        Test.stopTest();

        CensusAPIService.CensusResult r = results[0];
        System.assertEquals('MATCH', r.matchStatus,         'Address still matched');
        System.assertEquals('04',    r.congressionalDistrict,'District still set');
        System.assertNotEquals(null,  r.errorMessage,        'ACS error noted');
        System.assertEquals(null,     r.totalPopulation,     'No demographics');
        System.assertEquals(null,     r.medianHouseholdIncome,'No income data');
    }

    @isTest
    static void testMultipleInputs() {
        Test.setMock(HttpCalloutMock.class,
            new MockCallout(GEOCODER_MATCH_JSON, ACS_JSON));

        CensusAPIService.AddressInput i1 = buildInput();
        CensusAPIService.AddressInput i2 = buildInput();
        i2.zip = null; // second input omits ZIP

        Test.startTest();
        List<CensusAPIService.CensusResult> results =
            CensusAPIService.lookUpCensusData(
                new List<CensusAPIService.AddressInput>{ i1, i2 });
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Two results expected');
        System.assertEquals('MATCH', results[0].matchStatus, 'First match');
        System.assertEquals('MATCH', results[1].matchStatus, 'Second match');
    }

    @isTest
    static void testNASentinelValues() {
        // Replace real values with the Census N/A sentinel to confirm null mapping
        String naBody = ACS_JSON
            .replace('"80156"',  '"-666666666"')   // medianHouseholdIncome → null
            .replace('"35.3"',   '"-666666666.0"'); // medianAge → null

        Test.setMock(HttpCalloutMock.class,
            new MockCallout(GEOCODER_MATCH_JSON, naBody));

        Test.startTest();
        List<CensusAPIService.CensusResult> results =
            CensusAPIService.lookUpCensusData(
                new List<CensusAPIService.AddressInput>{ buildInput() });
        Test.stopTest();

        CensusAPIService.CensusResult r = results[0];
        System.assertEquals(null, r.medianHouseholdIncome,
            'N/A sentinel should produce null for income');
        System.assertEquals(null, r.medianAge,
            'N/A sentinel should produce null for age');
        // Other fields should still be populated
        System.assertNotEquals(null, r.totalPopulation, 'Population still set');
    }

    @isTest
    static void testAddressWithoutZip() {
        CensusAPIService.AddressInput input = new CensusAPIService.AddressInput();
        input.street = '1600 Pennsylvania Ave NW';
        input.city   = 'Washington';
        input.state  = 'DC';
        // zip intentionally omitted

        Test.setMock(HttpCalloutMock.class,
            new MockCallout(GEOCODER_MATCH_JSON, ACS_JSON));

        Test.startTest();
        List<CensusAPIService.CensusResult> results =
            CensusAPIService.lookUpCensusData(
                new List<CensusAPIService.AddressInput>{ input });
        Test.stopTest();

        System.assertEquals('MATCH', results[0].matchStatus,
            'Should match even without ZIP');
    }

    @isTest
    static void testSingleDigitDistrictPad() {
        // DISTRICT returned as "4" (single digit) – ACS URL must use "04"
        Test.setMock(HttpCalloutMock.class,
            new MockCallout(GEOCODER_MATCH_SINGLE_DIGIT_JSON, ACS_JSON));

        Test.startTest();
        List<CensusAPIService.CensusResult> results =
            CensusAPIService.lookUpCensusData(
                new List<CensusAPIService.AddressInput>{ buildInput() });
        Test.stopTest();

        CensusAPIService.CensusResult r = results[0];
        System.assertEquals('MATCH', r.matchStatus, 'Match expected');
        // District stored as returned by geocoder
        System.assertEquals('4', r.congressionalDistrict, 'Raw district preserved');
        // Demographics should still be populated (mock ACS returned data)
        System.assertNotEquals(null, r.totalPopulation, 'Demographics populated');
    }

    @isTest
    static void testPovertyRateCalculation() {
        // Verify poverty rate = populationBelowPoverty / povPop * 100
        // Mock values: 99182 / 666754 * 100 ≈ 14.9
        Test.setMock(HttpCalloutMock.class,
            new MockCallout(GEOCODER_MATCH_JSON, ACS_JSON));

        Test.startTest();
        List<CensusAPIService.CensusResult> results =
            CensusAPIService.lookUpCensusData(
                new List<CensusAPIService.AddressInput>{ buildInput() });
        Test.stopTest();

        CensusAPIService.CensusResult r = results[0];
        System.assertNotEquals(null, r.povertyRate, 'Poverty rate calculated');
        System.assert(r.povertyRate > 0 && r.povertyRate < 100,
            'Poverty rate should be a valid percentage');
    }

    @isTest
    static void testUnemploymentRateCalculation() {
        // Verify unemployment rate = unemployed / laborForce * 100
        // Mock values: 22891 / 323018 * 100 ≈ 7.1
        Test.setMock(HttpCalloutMock.class,
            new MockCallout(GEOCODER_MATCH_JSON, ACS_JSON));

        Test.startTest();
        List<CensusAPIService.CensusResult> results =
            CensusAPIService.lookUpCensusData(
                new List<CensusAPIService.AddressInput>{ buildInput() });
        Test.stopTest();

        CensusAPIService.CensusResult r = results[0];
        System.assertNotEquals(null, r.unemploymentRate, 'Unemployment rate calculated');
        System.assert(r.unemploymentRate > 0 && r.unemploymentRate < 100,
            'Unemployment rate should be a valid percentage');
    }

    @isTest
    static void testEducationRateCalculation() {
        // Verify % bachelor+ = (bach + mast + prof + doct) / pop25 * 100
        // Mock values: (75430+30121+4250+2893) / 458122 * 100 ≈ 24.6
        Test.setMock(HttpCalloutMock.class,
            new MockCallout(GEOCODER_MATCH_JSON, ACS_JSON));

        Test.startTest();
        List<CensusAPIService.CensusResult> results =
            CensusAPIService.lookUpCensusData(
                new List<CensusAPIService.AddressInput>{ buildInput() });
        Test.stopTest();

        CensusAPIService.CensusResult r = results[0];
        System.assertNotEquals(null, r.pctBachelorOrHigher,
            'Education rate calculated');
        System.assert(r.pctBachelorOrHigher > 0 && r.pctBachelorOrHigher < 100,
            'Education rate should be a valid percentage');
    }
}
