# Implementation plan — LINE Sales Reporting (LIFF → Salesforce)

Task-level breakdown of HANDOFF §7. Read with `L0-SPEC.md` (what) and `DECISIONS.md` (why; D-xx).
**Owner:** **C** = Claude Code session, **H** = user ([HUMAN] — consoles, logins, approvals), **BA** = business analyst.
Work one milestone at a time. Keep `FILE-INVENTORY.md` up to date in the same commit as any file change. At the end of each, report what was built, tests/coverage, Code Analyzer summary,
[HUMAN] steps with exact paths, [VERIFY] results — then stop and wait for the user.

Status keys: `[x]` done · `[ ]` to do · `[~]` partly done / blocked (reason given).

---

## L0 — Spec + decisions log (2 d) — **done 2026-10-28**

- [x] C · Install Salesforce CLI, log in to sandbox `dev5` (alias `lineliff-sbx`).
- [x] C · Read-only org checks: org type, LINE Connect version, Sites/domains, SSO/MFA, validation rules, record types,
      required fields, automation, licences, remote sites, certs, Platform Cache (`L0-SPEC.md` §2).
- [x] C · Check [VERIFY] items against LINE / Salesforce docs (`L0-SPEC.md` §6).
- [x] C · Write `L0-SPEC.md`, `DECISIONS.md`, this plan, `FILE-INVENTORY.md`.
- [x] C · Review concept mockups (`MOCKUP-REVIEW.md`) and collect all BA questions (`BA-QUESTIONS.md`).
- [ ] BA · Answer `BA-QUESTIONS.md` — Log Activity answered 2026-10-30 (D-11, D-31–D-34); still open: Task Type values (Q-A2), attachment limits (Q-A6a), Opportunity fields (Q-O1–Q-O7, D-12), licences (D-13).
- [x] H · Confirm or change the Proposed decisions — all confirmed 2026-10-29.

**Exit:** decisions blocking L2 signed off (D-06, D-07, D-09, D-20, D-21 decided).

## L1 — LINE setup (1 d, mostly H) — **done 2026-10-29**

Follow `LINE-SETUP.md`.

- [x] C · Write `LINE-SETUP.md` with the exact console steps and values to collect (no secrets).
- [x] H · Choose the provider (irreversible; OA and LINE Login channel must share it) — guide §0.
- [x] H · Create the "Sales Reporting" OA in LINE Official Account Manager — §1.
- [x] H · Response settings: auto-response **off**, webhook **off**, greeting message — §2.
- [x] H · Enable Messaging API on the OA (creates the channel) → send channel ID — §3.
- [x] H · Create **LINE Login channel** (Web app) in the same provider → send channel ID — §4.
- [x] H · Link the OA to the LINE Login channel — §5.
- [x] H · Add testers (Tester role) while the channel is "Developing" — §6.
- [x] H · Confirm the OA is **not** registered in LINE Connect (no `LINE_OA_Configuration__c` record) — §2.
- [ ] — LIFF app creation is deferred to L2 (needs the Site URL as endpoint).

**Exit (met):** values recorded in `ENVIRONMENTS.md`. Both channel IDs received; OA exists with no webhook, linked to the LINE Login channel; testers added.

## L2 — Site, LIFF shell, Apex REST skeleton (2 d) — **done 2026-10-29**

Steps for the human tasks: `SETUP-GUIDE.md` L2-4 … L2-7.


- [x] C · Re-check `SalesReport_` / `SalesReport` names are unused in the org (D-07) and re-run `COEXISTENCE.md` §4.
- [x] C · Add package directory `sales-report/` to `sfdx-project.json`; all feature metadata goes there (D-06, P1).
- [x] C · Metadata: protected custom setting `SalesReport_Settings__c` (LINE Login channel ID, ECA consumer key, cert name).
- [x] C · Remote Site `SalesReport_LINE_API` → `https://api.line.me` (D-10).
- [x] C · Permission sets `SalesReport_User`, `SalesReport_Admin`.
- [x] C · LIFF page: bundle `@line/liff` (npm) into static resource `SalesReport_LiffApp`; VF page `SalesReport_Liff` serving it; `liff.init`,
      `getIDToken`, show display name; CSP-safe, text rendered as text only.
- [x] C · Apex: `SalesReportMeController` (`GET /salesreport/v1/me`) + `SalesReportLineCalloutService` (ID-token verify callout, `aud`/`iss`/`exp`
      checks) + `SalesReportLineVerifyData` (DTO) + `SalesReportException` + `SalesReportLogService`; callout mocks + tests.
- [x] H · Setup → Sites → create Site `SalesReport_Site` (path `salesreport`), active; guest profile: Apex classes `SalesReport*Controller`
      + VF page `SalesReport_Liff` only, **no object access** → send Site URL.
- [x] H · LINE Login channel → LIFF → add app (size Full, endpoint = Site URL of `SalesReport_Liff`, scopes `openid profile`,
      bot link = the OA) → send LIFF ID.
- [x] H · Rich menu: 2 URI actions → `https://liff.line.me/{liffId}?form=activity` / `?form=opportunity` (OA Manager or API).
- [x] C · Measure API usage: 100 public `/me` calls raised `DailyApiRequests` by ~17 over 2.5 min, i.e. background org traffic, not 1 per call → Apex REST through the public Site does **not** count 1:1 against the daily API limit (it counts against Site limits instead). Test log entries (146 WARN) deleted afterwards.

- [x] C · Deploy to sandbox `dev5`: 31/31 tests pass, coverage 97.3%; Code Analyzer (Recommended): 0 Critical/High.
- [x] C · Settings org default: LINE Login channel ID, Enabled, Log Level WARN; `SalesReport_Admin` assigned to the deploying admin.
- [x] C · Smoke-test the Site endpoint and page over the public URL (2026-10-29).
- [x] C · Set LIFF ID in settings; `liff.init` succeeds against the public page (headless browser, outside LINE → "open from LINE" message as designed).

**Exit / proof point (met 2026-10-29):** tapping a rich-menu button opens the LIFF page from the new Site and shows the rep's LINE display name — confirmed by the user on their phone.

## L3 — Identity linking + Option B session (4–5 d, highest risk) — **done 2026-10-29**

Human steps: `SETUP-GUIDE.md` L3-2 … L3-6.

- [x] C · Objects `SalesReport_Line_Link__c` (tab, list views, field history), `SalesReport_Link_Code__c` (D-08).
- [x] C · `POST /salesreport/v1/link/start`: verify token, create code (256 random bits, store SHA-256 only), TTL from settings (5 min), return link URL.
- [x] C · VF page `SalesReport_Link` (login required): shows the LINE account, links only after **Connect** (POST, CSRF-protected);
      rejects expired/used codes; one active link per LINE user and per User; requires custom permission `SalesReport_Access` (D-27).
- [x] C · LIFF: "Connect Salesforce" screen → `liff.openWindow({ external: true })` (D-15); re-checks `/me` when the rep returns.
- [x] H · Setup → Certificate and Key Management → create self-signed cert `SalesReport_JWT_Signing` (L3-2).
- [x] H · Setup → External Client App Manager → new ECA `SalesReport_App`: OAuth on, JWT bearer flow on, cert uploaded,
      scopes `api` + `id` + `refresh_token` (required by Salesforce for JWT bearer), Permitted Users = "Admin approved users are pre-authorized", permission set `SalesReport_User`
      → send consumer key (not secret) (L3-3).
- [x] H · Guest profile: add Apex class `SalesReportLinkController` (L3-4).
- [x] C · Remote Site for the org's My Domain: **not needed** — callouts to the own domain work without one (tested).
- [x] C · `SalesReportSessionCalloutService`: `Auth.JWT` (iss = consumer key, sub = rep username, aud by `Organization.IsSandbox`) →
      `Auth.JWS` → `Auth.JWTBearerTokenExchange`, per request, never stored (D-16). `/me` proves it via `userinfo` as the rep.
- [x] C · Unlink: admins set Status = Unlinked (or delete); deactivated users are unlinked on their next request (no User trigger, D-27).
- [x] C · Tests: expired/used/unknown/oversized code, double use, replaced LINE account, relink to another user, deactivated user,
      no-permission user, malformed codes, linked `/me` through the rep session, JWT config errors — 58 tests, 96.4% coverage; Code Analyzer: 0 Critical/High (one documented suppression: named-credential suggestion for the per-request rep session).
- [x] C · `SalesReport_User` assigned to the test admin/rep in the sandbox.
- [x] C · ECA consumer key set; real JWT exchange for the test user works (3 runs: exchange 117–185 ms, userinfo 53–152 ms, i.e. ~0.2–0.35 s extra per request) → per-request exchange kept (D-16). Public `/link/start` answers through the Site (401 for a fake token).
- [x] H+C · Device test on the user's phone (2026-10-29): Connect → browser login → confirm page (plain page, no Lightning redirect, so D-28 not needed) → back in LINE shows the Salesforce name. Link `LL-000000` Active, code used once. Second platform (iOS/Android, whichever wasn't used) moves to L8 device QA.

**Exit (met 2026-10-29):** a test rep links once, reopens LIFF without logging in, and `/me` returns their Salesforce name via a call made as them.

## L4 — Account auto-complete (2 d) — **done 2026-10-29**

Human steps: `SETUP-GUIDE.md` L4-2 … L4-4.

- [x] C · `GET /salesreport/v1/accounts?q=`: min chars / max results from settings (2 / 10), SOQL `LIKE '%term%'` on Name plus the
      text fields of field set `SalesReport_Account_Search` (D-29), executed **as the rep** through the org REST API (Option B);
      name-prefix matches first; quotes, backslashes and LIKE wildcards escaped.
- [x] C · `SalesReportIdentityService.repSession()`: verified LINE user → active link → JWT session; not linked → `NOT_LINKED` (page shows Connect).
- [x] C · LIFF Account picker: 300 ms debounce, min chars, AbortController for in-flight requests, tap to select (stores **Account ID**), Change.
- [x] C · Tests: ranking, cap, too-short term, escaping, field-set fields, empty result, linked / not linked / no token — 69 tests, 96.6% coverage; Code Analyzer 0 Critical/High.
- [x] C · Live check in the sandbox through the real JWT session: 'com' → 10 results (prefix first), 'mo7' → 4, `o'b%` → 0 (safe); 60–170 ms per query.
- [x] H · Guest profile: add Apex class `SalesReportAccountController` (L4-2) — checked 2026-10-29; public `/accounts` answers (401 for a fake token).
- [x] H+C · Device test (L4-4): search on the user's phone shows Accounts (2026-10-29).
- [ ] C · Visibility test with a non-admin rep (sees only Accounts in their sharing) — needs a test rep without "View All" (BA Q-T1); enforced natively because the query runs in the rep's session.

**Exit (met 2026-10-29, except the non-admin visibility check below the line, moved to L8 with Q-T1):** typing 2–3 characters shows only visible Accounts within ~1 s on a phone.

## L5 — Forms and write endpoints (4–5 d)

BA answers 2026-10-30: Task (D-11), required fields follow Salesforce (D-31), any date (D-32), Account only (D-33),
attachments in scope (D-34). Update Opportunity fields: BA confirms later, so L5 is split.

### L5a — Log Activity (ready to build)

- [ ] H · Admin adds the agreed Task `Type` values in `dev5` (Q-A2) — the form works without them, using whatever values exist.
- [x] C · Field set `SalesReport_Activity_Form` on Task: Type, ActivityDate, Description (D-21). Standard fields only in the repo (P3); admins add org fields such as `ActivityPurpose__c` in Setup.
- [x] C · `GET /salesreport/v1/activity` → field-set fields with label, type, picklist values, defaults and the
      required flag from the rep's layout, the database and the field set (D-31), via three small UI API reads as the rep (D-35).
- [x] C · `POST /salesreport/v1/activity` → Task as the rep: `WhatId` = Account, Subject built, Status from the date (D-32);
      only field-set fields accepted; Account must be visible to the rep.
- [x] C · Map org errors (validation rules, required fields, FLS) to plain-language messages with field highlights; nothing silently dropped.
- [x] C · LIFF form: dynamic fields from `GET /activity`, client-side required check, errors cleared on change, success screen with "Log another" / Close (checked headless 2026-10-30).
- [x] C · Tests: success, required field missing, validation-rule error (mocked), field outside field set rejected, not linked — 92 tests, 95.8% coverage; Code Analyzer 0 Critical/High.
- [x] C · Live check through the real JWT session: form (Type 4 values, Due Date Only, Description; none required in `dev5`) ~1.0 s; past date → `Completed`, future → `Open`, Priority `Normal`, owner = rep; test Tasks deleted.
- [ ] H · Guest profile: add Apex class `SalesReportActivityController` (public `/activity` answers 403 "no access to the Apex class" until then).
- [ ] H+C · Device test: log a Task from the phone, check it on the Account.

### L5b — Attachments (after L5a works)

- [ ] BA · Limits: count, size, types (Q-A6a; proposed 5 × 4 MB, photos + PDF).
- [ ] C · Settings fields for the limits; `POST /salesreport/v1/activity/files` → `ContentVersion` on the Task as the rep (D-34).
- [ ] C · LIFF: camera/gallery picker, resize photos in the browser (~1600 px JPEG), upload one by one with progress and retry.
- [ ] C · Tests: size/type/count limits, Task not the rep's, upload error.
- [ ] H+C · Device test on iOS and Android (camera and gallery). Keep test files small (sandbox file storage: 59 MB free).

### L5c — Update Opportunity (waiting on BA: Q-O1–Q-O7, D-12; D-13 licences)

- [ ] C · `GET /salesreport/v1/opportunities?accountId=` → open Opportunities visible to the rep.
- [ ] C · Field set `SalesReport_Opportunity_Form`; required flags per D-31.
- [ ] C · `POST /salesreport/v1/opportunity` → field-set fields only; Opportunity must belong to the chosen Account.
- [ ] C · Tests: validation-rule failure (e.g. Stage 02 without PreSales Engineer), update denied outside sharing, success.
- [ ] H · Confirm org automation (Next Step date stamps, Opp meeting counter) behaves as expected for LINE updates.

**Exit:** both forms save real records as the rep in the sandbox; validation errors shown on the form; photos attached to the Task.

## L6 — Mobile UI polish + i18n (2–3 d)

- [ ] C · Labels via Custom Labels `SalesReport_*` in the agreed languages (JA / EN / TH — BA), picked from LINE/browser language.
- [ ] C · Loading, empty, offline, token-expired (> 1 h → reload) and error states; success screen with "close" (`liff.closeWindow`).
- [ ] C · Accessibility basics (tap targets, contrast, font scaling).

## L7 — Hardening (3 d)

- [ ] H · Setup → Platform Cache → new partition `SalesReportCache` with an allocation (D-14), or approve custom-object fallback.
- [ ] C · Per-LINE-user rate limit; optional token-hash → user cache until `exp` (never the token itself).
- [ ] C · Scheduled cleanup of expired link codes.
- [ ] C · Code Analyzer: no Critical/High; every class declares sharing; `without sharing` justified in a comment.
- [ ] C · Coverage ≥ 85% overall, every class ≥ 75%; all callouts mocked; fake secrets only.
- [ ] C · Guest profile audit: only `SalesReport*Controller` classes + `SalesReport_Liff` page, zero object permissions.

## L8 — QA, UAT, guides (2–3 d)

- [ ] H · Provide test rep user(s) (full Salesforce licence — D-13) and test LINE accounts.
- [ ] H+C · Device QA on iOS and Android LINE: link, search, both forms, expiry, unlink.
- [ ] BA · UAT against the acceptance scenarios (`L0-SPEC.md` §9).
- [ ] H · Switch the LINE Login channel from Developing to **Published** (LINE-SETUP.md §6).
- [ ] C · `docs/SETUP-GUIDE.md` (admin: Site, ECA, cert, permission sets, LINE console) and `docs/USER-GUIDE.md` (rep).
- [ ] C · Re-run `COEXISTENCE.md` §4 against production (LINE Connect version may differ).
- [ ] C · Production deploy plan: `sf project deploy start --test-level RunLocalTests` (validate first); re-check production MFA/SSO.

---

## Dependencies at a glance

| Blocks | Waiting on |
|---|---|
| L2 start | — (L1 values received 2026-10-29) |
| L2 exit | H: Site created, LIFF app + rich menu |
| L3 Option B | H: certificate + ECA consumer key |
| L5a | — (Task `Type` values from admin are nice to have) |
| L5b | BA: attachment limits (Q-A6a) — proposed defaults used until then |
| L5c | BA: Opportunity fields (Q-O1–Q-O7, D-12); D-13 licences |
| L7 rate limiting | H: Platform Cache allocation (D-14) |
| L8 | H: test users and LINE accounts |
