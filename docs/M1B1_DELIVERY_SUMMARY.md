# M1B1 delivery summary

Date: 2026-07-20 (Australia/Sydney)

Status: **TO VALIDATE — automated/provider gates passed; physical iPhone Safari
acceptance remains open**

## Delivered candidate

- Branch: `codex/feat/m1b1-real-text-interpreter`
- Deployed source: `ad9c08999451cbe2ec5ec7addfb8f4481755ba89`
- Draft PR: `https://github.com/olliebigbang/project-forge/pull/3`
- Public Sites version: 15
- Public preview:
  `https://project-forge-weapon-lab.hongningliu0130.chatgpt.site/`
- Stable rollback remains `main` at tag `v0.1.0-m1a`.

The M1B1 branch is not merged or cleaned, and M1B2 has not started.

## What M1B1 delivers

- Free text plus bounded numeric `drawing_summary` is submitted only to the
  same-origin project Worker. Godot never contacts Anthropic and never receives a
  credential.
- The Worker calls Anthropic's native Messages API and native Structured Outputs
  with the immutable model `claude-haiku-4-5-20251001`. There is no compatible
  endpoint, alias, model upgrade, or provider fallback.
- Model output is untrusted semantic data. Server and client independently apply
  Schema, allow-list, runtime repair and deterministic `PowerBudget` gates before
  combat. Player-facing prose is generated from validated labels rather than
  reflecting provider free-form fields.
- Sites D1 atomically owns session/network quotas, caller-namespaced idempotency,
  provider-operation leases, and the lifetime USD 5 reserve/settle ledger. Any
  missing or uncertain durable guard fails closed before provider invocation.
- Normal players do not preselect an attack pattern. The five M1A controls appear
  only in Developer/Test Mode or `MODIFY INTERPRETATION`.
- Loading, CANCEL, stale-response invalidation, TRY AGAIN, confirmation, MODIFY,
  fallback, re-forge, drawing/text preservation, and all five existing combat
  modules remain executable.

## Final evidence

| Gate | Result |
|---|---|
| Godot/M1A regression | 32 cases, 461 assertions, 0 failures |
| Interpreter / request D1 / Anthropic / budget D1 / hostile safety | 68/68, 9/9, 17/17, 14/14, 11/11 PASS |
| Real Anthropic matrix | 42/42 PASS; 100% labelled pattern and element accuracy; 100% final validity |
| Real-provider latency | Median 1.318 s; P95 4.846 s |
| Real-provider matrix cost | USD 0.033588 |
| Final live UI canary | One call; USD 0.001167; boomerang/electric; combat attack PASS |
| Public Chromium + WebKit 2327 | PASS; zero application console errors |
| Public assets | HTTP 200 and five local/public SHA-256 matches |
| Draft PR #3 CI | PASS |
| Physical iPhone Safari | **TO VALIDATE by product owner** |

Detailed evidence is in
[`artifacts/M1B1_TEST_RESULTS.md`](../artifacts/M1B1_TEST_RESULTS.md), with the
privacy-bounded 42-case matrix in
[`artifacts/M1B1_REAL_PROVIDER_MATRIX_V14.json`](../artifacts/M1B1_REAL_PROVIDER_MATRIX_V14.json)
and the public summary in
[`artifacts/M1B1_PUBLIC_V15_RESULTS.json`](../artifacts/M1B1_PUBLIC_V15_RESULTS.json).

## Public v14 failure and v15 fix

Sites correctly returned a gzip-labelled HTTP 200 result, and browser Fetch
already decompressed it. Godot Web then attempted a second gzip decode, produced
an empty body, and selected the safe network fallback. v15 disables only Godot
Web's duplicate gzip decoding; native gzip behavior and all response validation
remain intact. A zero-cost gzip regression and one guarded live UI call both pass
on the public deployment.

## Cost controls

- Application hard cap: USD 5 lifetime, Worker + D1, fail closed.
- Provider-account backstop: configured at or below USD 5 before paid traffic.
- Conservatively reconstructed total development evidence: approximately USD
  0.271, including full reservation for ambiguous earlier canaries. This is not a
  direct final D1 ledger-total query.
- No automatic model upgrade and no automatic retry after an ambiguous sent call.

## Known limitations

- M1B1 interprets text and bounded numeric drawing metadata; it does not inspect
  drawing pixels or claim visual understanding. That is M1B2 scope.
- Physical iPhone Safari remains the authoritative gate for real finger input,
  keyboard, safe areas, toolbar changes, active-request lifecycle, confirmation,
  combat, and re-forge.
- Production authentication, provider-side moderation policy, telemetry
  destination, data retention and traffic-scale behavior remain **TBD** or
  **TO VALIDATE** for later milestones.
- Windows Playwright WebKit emits known renderer notices, and Cloudflare may
  inject one `styleMedia` deprecation warning. The application emitted no new
  errors or warnings in the final runs.

## Shortest physical-iPhone acceptance path

1. Open the public URL in iPhone Safari in portrait and confirm the bilingual
   rotate gate; rotate to landscape without refreshing.
2. Draw, edit Description with the iOS keyboard, close the keyboard, and press
   FORGE. Confirm no five-pattern selector is visible before interpretation.
3. While one request is loading, rotate portrait → landscape; then test CANCEL
   once and verify drawing/text remain. Forge again and wait for the result.
4. On confirmation, verify pattern, element, weakness and Power Score; rotate
   once more and confirm the same result remains.
5. Use MODIFY, switch a pattern, accept it, enter combat, ATTACK, then REFORGE.
6. Expand/collapse Safari toolbars and background/resume once. Confirm no lock,
   clipping, duplicate request, lost input or stale result.

Only an explicit successful product-owner report closes M1B1. Until then, keep
the PR draft, preserve this branch/evidence, do not merge, and do not start M1B2.
