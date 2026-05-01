# Architecture & Engineering Review

## Scope
This review covers:
- `README.md`
- `force-app/main/default/classes/CensusAPIService.cls`
- `force-app/main/default/classes/CensusAPIServiceTest.cls`

## Executive Summary
The project is clear, well-commented, and test-backed, but it has several production-grade gaps around callout scaling, secrets/network hardening, resilience, and privacy-by-design. The largest operational risk is **Flow bulk execution exceeding callout governor limits**. The largest security risk is **plain Remote Site Settings instead of Named Credentials with stronger outbound control and observability**.

## Key Findings

### 1) Bulk Flow / Governor Limit Risk (High)
- `lookUpCensusData` performs `processAddress` per input and each process can call 2 APIs (geocoder + ACS).
- In a bulk Flow transaction, this can exceed Salesforce's per-transaction callout limit.
- Effect: partial or full transaction failure under load.

**Recommendation**
- Add an input-size guard (`max addresses per invocation`) and fail fast with actionable error.
- Add Queueable/Batch strategy for high-volume mode.
- Introduce optional caching (Platform Cache / custom object keying by normalized address).

### 2) Outbound Security Posture (High)
- Integrations use Remote Site Settings and raw URL construction.
- This is functional but weaker than Named Credentials in manageability, auditable config, and future auth flexibility.

**Recommendation**
- Migrate endpoints to Named Credentials + External Credentials.
- Enforce explicit endpoint allow-listing through NC references only.

### 3) Resilience Gaps (High)
- No retry/backoff for transient HTTP 429/5xx responses.
- No circuit-breaker behavior; repeated failures can amplify latency.

**Recommendation**
- Implement bounded retry (e.g., max 2 retries with jitter for 429/503).
- Add graceful degradation path and response flags (`demographicsUnavailableReason`).

### 4) Data Freshness / Maintainability (Medium)
- ACS year is hardcoded (`/data/2022/acs/acs5`).
- Data becomes stale over time without code deployment.

**Recommendation**
- Externalize ACS year in Custom Metadata.
- Add health-check/admin report surfacing configured year and endpoint availability.

### 5) Privacy & Ethical Use (Medium)
- Service processes address-level PII and returns demographic attributes that could be used for sensitive segmentation.

**Recommendation**
- Add purpose limitation and anti-discrimination guidance in docs.
- Add data minimization options (toggle which outputs are returned).
- Define retention/deletion policy for stored outputs.

### 6) Input Validation / UX Stability (Medium)
- `state` is not constrained to valid USPS codes at service layer.
- Error messages are technical and not consistently user-friendly for Flow screens.

**Recommendation**
- Validate state format and required fields server-side before callout.
- Return standardized error taxonomy: `VALIDATION_ERROR`, `UPSTREAM_TIMEOUT`, `NO_MATCH`, etc.

### 7) Performance Opportunities (Medium)
- No request deduplication: repeated same address causes duplicate callouts.
- JSON parsing is done per record with full payload materialization.

**Recommendation**
- Add short-lived cache by normalized address hash.
- Consider a thin DTO mapper + selective parsing only for required nodes.

### 8) Test Suite Quality (Low-Medium)
- Current tests are good for happy path and primary failures.
- Missing edge-case tests: malformed JSON, missing headers row, 429 retry behavior, large batch guardrail, invalid state inputs.

**Recommendation**
- Expand test matrix to include resilience and guardrails.

## UX Review (Flow Builder & End-User)
- Strengths: friendly labels, useful output set.
- Gaps:
  - No confidence score or match quality for address selection.
  - No structured remediation hints when `NO_MATCH` occurs.

**Recommendations**
- Expose optional `matchConfidence` / `matchType` (exact/range/interpolated where available).
- Provide UX-facing next actions in output (`suggestedFix`: "Add ZIP", "Use USPS abbreviation").

## Security / White-Hat Perspective
- Positive: URL encoding prevents simple query injection.
- Risks:
  - No explicit TLS pinning/control (platform-limited, but still document trust model).
  - No throttling strategy; susceptible to upstream rate limiting causing cascading failures.
  - Potential misuse for sensitive profiling if unchecked in downstream business processes.

**Recommendations**
- Security controls in design docs: abuse controls, monitoring, least privilege by Flow permission sets.
- Add org-level audit logging for who invoked and purpose context (without logging raw PII where avoidable).

## Better Options / Services
- **Address validation quality**: Evaluate USPS CASS-certified services for mission-critical deliverability.
- **Geospatial enrichment**: Consider commercial geocoders for SLAs if Census API uptime/limits are insufficient.
- **Observability**: Emit Platform Events for integration failures and aggregate in SIEM.
- **Configuration**: Centralize with Custom Metadata + Named Credentials.

## Proposed Roadmap
1. Stabilize reliability (bulk guardrail + retry + standardized errors).
2. Harden security (Named Credentials migration + telemetry).
3. Improve data governance (privacy controls + retention policy).
4. Optimize performance (cache/dedup).
5. Improve UX diagnostics and admin operability.
