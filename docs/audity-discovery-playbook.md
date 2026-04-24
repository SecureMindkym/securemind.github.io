# Audity Discovery Playbook

## Objective
Increase discovery quality while reducing operational failures in the `policy_override -> policy_db -> fallback -> promote` pipeline.
System direction: `policy_db` handles discovery + ranking; Audity handles execution + scoring + learning; `fallback` should shrink over time.

## Non-negotiable routing and safety
- Preserve stage order: `policy_override -> policy_db -> fallback -> promote`.
- Verify hostname before any action.
- Keep code and config changes minimal (no broad refactors).

## Stage-by-stage controls

### `policy_override`
- Treat as the highest-authority source.
- Record explicit override reason and expiry.
- Alert when override usage spikes beyond normal band.

### `policy_db`
- Prefer deterministic policy matches.
- Treat as the default discovery source.
- Store versioned policy snapshots to support trace replay.
- Emit `policy_miss` vs `policy_conflict` distinctly.
- Improve ranking/selection first; avoid broad crawl expansion as a primary tactic.

### `fallback`
- Never use untyped fallback outcomes.
- Use only when `policy_override` and `policy_db` cannot produce an eligible policy URL.
- Return safe defaults with reason code.
- Use transient-only retries and jittered backoff.
- Prefer no-result over wrong-result when policy confidence is low.

### `promote`
- Promote only validated or strong PDF privacy documents.
- Require promotion gates (sample size, confidence, rollback risk).
- Keep full lineage from candidate -> fallback decision -> promoted rule.
- Support one-click rollback with reason retention.

## URL policy gate

### Require candidate URL to include
- `privacy` OR `privacy-policy` OR `data-protection`

### Ranking boosts
- `/privacy`
- `/privacy-policy`
- short top-level paths
- PDF policy docs

### Reject candidate URL containing
- `login`, `signin`, `account`, `auth`
- `cart`, `checkout`
- `about`, `contact`
- `careers`, `jobs`
- `blog`, `news`

### Ranking penalties
- `/training`, `/courses`
- `/services`, `/products`
- deeply nested paths
- non-policy marketing pages

## Service endpoints
- `audityscraper`: API on `:8000`, scraper worker on `:5000`
- `auditydb`: policy DB API on `:8001`

## Failure classification focus
- real no-policy cases
- blocked (`403`)
- PDF missed
- filter too strict
- wrong domain/brand
- policy-db missing candidates

## Suggested SLOs
- Discovery precision@10: upward trend each release window.
- End-to-end failure rate: downward trend each release window.
- P95 latency: no regression beyond agreed threshold.
- Rollback ratio: stable or decreasing.

## Weekly review template
1. What failed? (by typed fallback reason)
2. What was discovered? (novel accepted items)
3. What was promoted? (with post-promotion impact)
4. What was rolled back? (and why)
5. What should change next week?
