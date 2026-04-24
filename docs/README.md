# Audity — Privacy Audit System

## Current architecture

Audity currently routes decisions through a layered trust path:

1. `policy_override`
2. `policy_db`
3. `fallback`
4. `promote`

This ordering is stable and should be preserved unless we can prove an improvement on both safety and discovery quality.

### Architecture rules (must enforce)
- `policy_override` is highest priority (learned URLs).
- `policy_db` is the main discovery source.
- `fallback` is last resort only.
- `promote` only accepts validated or strong PDF privacy documents.

## Current state snapshot

- System is stable in production-like traffic.
- Learning loop is functioning end-to-end.
- Filters and ranking have already been improved from baseline.

## Iteration goal

Improve **discovery quality** while reducing **request failures**.
Primary direction: make `policy_db` the discovery brain and shrink `fallback` usage over time.

## Discovery strategy constraints
- Prioritize ranking improvements over broad crawl expansion.
- Keep selection deterministic (same input -> same output).
- Prefer quality over coverage; return no result instead of low-confidence wrong policy.
- Use `fallback` only for true misses after `policy_db` ranking/filtering is exhausted.

## URL eligibility policy (hard filters)

### Required URL tokens
URL must include at least one of:
- `privacy`
- `privacy-policy`
- `data-protection`

### Ranking boosts
- `/privacy`
- `/privacy-policy`
- short top-level paths
- PDF documents (especially enterprise/government policy docs)

### Rejected URL tokens
Reject URL when path contains any of:
- `login`
- `signin`
- `account`
- `auth`
- `cart`
- `checkout`
- `about`
- `contact`
- `careers`
- `jobs`
- `blog`
- `news`

### Ranking penalties
- `/training`
- `/courses`
- `/services`
- `/products`
- deeply nested paths
- non-policy marketing pages

## Runtime environment map
- `audityscraper` = discovery/scraper engine (`API :8000`, `scraper :5000`)
- `auditydb` = policy database service (`API :8001`)

## Safety invariants
- Verify hostname before any discovery, fetch, or promotion action.
- Keep changes minimal and localized (no broad refactors).

---

## Plan: Discovery Quality + Failure Reduction

### 1) Discovery quality upgrades

#### 1.1 Candidate breadth before rank depth
- Increase candidate retrieval breadth *before* ranking to avoid overfitting to known good clusters.
- Add diversity constraints so discovery does not collapse around a small policy family.
- Keep per-source attribution metadata attached through ranking for later diagnostics.

#### 1.2 Confidence-aware ranking
- Split ranking score into:
  - relevance score
  - privacy risk score
  - confidence score
- Down-rank high-variance candidates unless they are explicitly whitelisted by `policy_override`.

#### 1.3 Exploration guardrails in the learning loop
- Add capped exploration budget (example: 5–10% of eligible requests).
- Require minimum confidence and policy compatibility before exploration can surface.
- Log every exploration promotion path (`fallback -> promote`) for auditability.

### 2) Failure reduction upgrades

#### 2.1 Typed fallback reasons
Standardize fallback reasons so each failure is actionable:
- `policy_miss`
- `policy_conflict`
- `candidate_timeout`
- `ranker_low_confidence`
- `upstream_error`

Add classification coverage for discovery diagnostics:
- `real_no_policy`
- `blocked_403`
- `pdf_missed`
- `filter_too_strict`
- `wrong_domain_or_brand`
- `policy_db_missing_candidates`

#### 2.2 Retry and circuit behavior
- Use bounded retry only for transient classes (`candidate_timeout`, `upstream_error`).
- Add circuit-break threshold per subsystem to prevent cascading failures.
- Keep a safe default response path when all retries are exhausted.

#### 2.3 Promotion safety gates
Before `promote`, require:
- minimum successful sample size,
- low rollback indicator,
- no active policy conflict signals.

---

## Metrics to track every release

### Discovery quality
- Discovery precision@k
- Novelty rate (new but valid policies discovered)
- Manual-review acceptance rate

### Reliability
- End-to-end failure rate
- Fallback rate by typed reason
- Retry success rate
- P95 latency across each architecture stage

### Safety
- Policy conflict incidence
- Rollback count after promote
- Override usage rate (`policy_override`) and drift trend

---

## Delivery sequence

### Phase A — Instrumentation first
1. Add typed fallback reasons.
2. Add stage-level timers and failure counters.
3. Build dashboard slices by architecture stage.

### Phase B — Ranking and exploration tuning
1. Introduce confidence-aware ranking decomposition.
2. Enable exploration budget with hard caps.
3. Run shadow evaluation on historical traces.

### Phase C — Promotion hardening
1. Add promotion safety gates.
2. Enable rollback-on-regression automation.
3. Review weekly with quality + reliability scorecard.

---

## Definition of done for this cycle

- Discovery precision@k improves against baseline.
- End-to-end failure rate decreases with no safety regression.
- Promote events become fully explainable from logs.
- Rollbacks stay within agreed error budget.
