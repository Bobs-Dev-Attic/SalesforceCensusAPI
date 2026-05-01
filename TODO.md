# TODO (Prioritized)

## P0 — Critical: Reliability & Security
- [ ] Add **bulk invocation guardrail** in `lookUpCensusData` to prevent callout limit overruns; return explicit error for oversized batches.
- [ ] Migrate outbound integrations from Remote Site Settings to **Named Credentials** (+ External Credentials where applicable).
- [ ] Add **retry with exponential backoff + jitter** for 429/503 responses (bounded attempts).
- [ ] Standardize error codes and messages for Flow consumption (`VALIDATION_ERROR`, `NO_MATCH`, `UPSTREAM_ERROR`, `PARTIAL_DATA`).

## P1 — High: Privacy, Compliance, Governance
- [ ] Create a **Data Protection Impact note**: define PII handling, retention, minimization, and deletion behavior.
- [ ] Add usage policy section addressing **fairness/anti-discrimination** constraints for demographic outputs.
- [ ] Avoid storing full raw upstream payloads; if logging needed, redact address components.

## P2 — High: Performance & Maintainability
- [ ] Externalize ACS year and tunables to **Custom Metadata**.
- [ ] Add request **deduplication/cache** keyed by normalized address (with TTL).
- [ ] Add optional asynchronous mode (Queueable) for high-volume flows.

## P3 — Medium: UX & Developer Experience
- [ ] Return actionable remediation hints for `NO_MATCH` cases.
- [ ] Add optional confidence/match quality fields where available.
- [ ] Provide admin runbook for endpoint outages/rate limits and fallback behavior.

## P4 — Medium: Test Quality
- [ ] Add tests for malformed JSON, missing expected ACS columns, timeout simulation, and 429 retry path.
- [ ] Add tests for invalid input validation (state length/code).
- [ ] Add tests for bulk-size guardrail behavior.

## P5 — Nice-to-have
- [ ] Provide optional GraphQL/Composite wrapper pattern for downstream consumers.
- [ ] Add release checklist and semantic versioning guidance.
