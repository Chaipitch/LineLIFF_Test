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
- [ ] BA · Answer the Open items in `DECISIONS.md` (D-11 Task vs Event, D-12 Next Step field, D-13 licences) and HANDOFF §8.
- [~] H · Confirm or change the Proposed decisions — L2 blockers decided; remaining Proposed ones can be confirmed later.

**Exit:** decisions blocking L2 signed off (D-06, D-07, D-09, D-20, D-21 decided).

## L1 — LINE setup (1 d, mostly H)

Follow `LINE-SETUP.md`.

- [x] C · Write `LINE-SETUP.md` with the exact console steps and values to collect (no secrets).
- [ ] H · Choose the provider (irreversible; OA and LINE Login channel must share it) — guide §0.
- [ ] H · Create the "Sales Reporting" OA in LINE Official Account Manager — §1.
- [ ] H · Response settings: auto-response **off**, webhook **off**, greeting message — §2.
- [ ] H · Enable Messaging API on the OA (creates the channel) → send channel ID — §3.
- [ ] H · Create **LINE Login channel** (Web app) in the same provider → send channel ID — §4.
- [ ] H · Link the OA to the LINE Login channel — §5.
- [ ] H · Add testers (Tester role) while the channel is "Developing" — §6.
- [ ] H · Confirm the OA is **not** registered in LINE Connect (no `LINE_OA_Configuration__c` record) — §2.
- [ ] — LIFF app creation is deferred to L2 (needs the Site URL as endpoint).

**Exit:** both channel IDs received; OA exists with no webhook, linked to the LINE Login channel; testers added.

## L2 — Site, LIFF shell, Apex REST skeleton (2 d)

- [ ] C · Re-check `SalesReport_` / `SalesReport` names are unused in the org (D-07) and re-run `COEXISTENCE.md` §4.
- [ ] C · Add package directory `sales-report/` to `sfdx-project.json`; all feature metadata goes there (D-06, P1).
- [ ] C · Metadata: protected custom setting `SalesReport_Settings__c` (LINE Login channel ID, ECA consumer key, cert name).
- [ ] C · Remote Site `SalesReport_LINE_API` → `https://api.line.me` (D-10).
- [ ] C · Permission sets `SalesReport_User`, `SalesReport_Admin`.
- [ ] C · LIFF page: bundle `@line/liff` (npm) into static resource `SalesReport_LiffApp`; VF page `SalesReport_Liff` serving it; `liff.init`,
      `getIDToken`, show display name; CSP-safe, text rendered as text only.
- [ ] C · Apex: `SalesReportMeController` (`GET /salesreport/v1/me`) + `SalesReportLineCalloutService` (ID-token verify callout, `aud`/`iss`/`exp`
      checks) + `SalesReportLineVerifyData` (DTO) + `SalesReportException` + `SalesReportLogService`; callout mocks + tests.
- [ ] H · Setup → Sites → create Site `SalesReport_Site` (path `salesreport`), active; guest profile: Apex classes `SalesReport*Controller`
      + VF page `SalesReport_Liff` only, **no object access** → send Site URL.
- [ ] H · LINE Login channel → LIFF → add app (size Full, endpoint = Site URL of `SalesReport_Liff`, scopes `openid profile`,
      bot link = the OA) → send LIFF ID.
- [ ] H · Rich menu: 2 URI actions → `https://liff.line.me/{liffId}?form=activity` / `?form=opportunity` (OA Manager or API).
- [ ] C · Measure: `sf org list limits` before/after 10 `/me` calls — API request count per call (§6 [VERIFY]).

**Exit / proof point:** tapping a rich-menu button opens the LIFF page from the new Site and shows the rep's LINE display name.

## L3 — Identity linking + Option B session (4–5 d, highest risk)

- [ ] C · Objects `SalesReport_Line_Link__c`, `SalesReport_Link_Code__c` (D-08) with unique/external-ID fields; list views for admins.
- [ ] C · `POST /salesreport/v1/link/start`: verify token, create code (32 random bytes, store SHA-256), 5-min expiry, return link URL.
- [ ] C · VF page `SalesReport_Link` (login required, `with sharing`): consume code once, link `UserInfo.getUserId()` ↔ LINE user ID,
      "Done — return to LINE" page; reject expired/used codes; one active link per LINE user and per User.
- [ ] C · LIFF: "Connect Salesforce" screen → `liff.openWindow({ external: true })` (D-15); re-check `/me` on return.
- [ ] H · Setup → Certificate and Key Management → create self-signed cert `SalesReport_JWT_Signing`.
- [ ] H · Setup → External Client App Manager → new ECA `SalesReport_App`: OAuth on, JWT bearer flow on, cert uploaded,
      scopes `api`, Permitted Users = "Admin approved users are pre-authorized", policy grants `SalesReport_User`
      → send consumer key (not secret).
- [ ] H · Remote Site `SalesReport_Org_Domain` for the org's My Domain (if callout to own domain needs it — [VERIFY]).
- [ ] C · `SalesReportSessionCalloutService`: `Auth.JWT` (iss = consumer key, sub = rep username, aud by `Organization.IsSandbox`) →
      `Auth.JWS` → `Auth.JWTBearerTokenExchange` → access token, per request, never stored (D-16). Measure latency.
- [ ] C · Unlink: admin action + auto-unlink on User deactivation (trigger or scheduled check — nice to have).
- [ ] C · Tests: expired/used/foreign code, double link, token `aud` mismatch, deactivated user, JWT exchange failure (mocked).
- [ ] H+C · Device test: link flow on iOS and Android LINE, with the org's login/MFA.

**Exit:** a test rep links once, reopens LIFF without logging in, and `/me` returns their Salesforce name via a call made as them.

## L4 — Account auto-complete (2 d)

- [ ] C · `GET /salesreport/v1/accounts?q=`: min 2 chars, max 10, SOSL/SOQL on Name (more fields per BA), executed as the rep.
- [ ] C · LIFF: 300 ms debounce, AbortController for in-flight requests, keyboard/touch dropdown, stores **Account ID** only.
- [ ] C · Tests incl. `System.runAs` visibility (rep cannot find Accounts outside sharing).

**Exit:** typing 2–3 characters shows only visible Accounts within ~1 s on a phone.

## L5 — Forms and write endpoints (3–4 d) — needs D-11, D-12 answered

- [ ] C · `POST /salesreport/v1/activity` → Event or Task (D-11), fields per `L0-SPEC.md` §7, `WhatId` = Account.
- [ ] C · `GET /salesreport/v1/opportunities?accountId=` → open Opportunities visible to the rep.
- [ ] C · Field sets `SalesReport_Opportunity_Form`, `SalesReport_Activity_Form` (D-21); forms and whitelist read them by describe.
- [ ] C · `POST /salesreport/v1/opportunity` → whitelisted fields only (Stage 01–03, Win Confidence, CloseDate, Amount, Next Step, due date);
      Opportunity must belong to the chosen Account.
- [ ] C · Map org errors (validation rules, required fields, FLS) to plain-language messages with field highlights; nothing silently dropped.
- [ ] C · Tests: validation-rule failure for Opportunity (e.g. Stage 02 without PreSales Engineer) and for the activity object,
      `runAs` update denied outside sharing, success paths.
- [ ] H · Confirm org automation (Slack flows, Opp meeting counter) behaves as expected for LINE-created records.

**Exit:** both forms save real records as the rep in the sandbox; validation errors shown on the form.

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
| L2 start | L1 channel IDs |
| L2 exit | H: Site created, LIFF app + rich menu |
| L3 Option B | H: certificate + ECA consumer key |
| L5 | BA: D-11, D-12, field lists; D-13 licences |
| L7 rate limiting | H: Platform Cache allocation (D-14) |
| L8 | H: test users and LINE accounts |
