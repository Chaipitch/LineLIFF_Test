# Spec — LINE Sales Reporting (LIFF → Salesforce)

**Status (2026-11-02):** L0–L4, L5a (Log Activity), L5b (attachments — built, **switched off** for now), L5c (Update
Opportunity — built with the proposed defaults, D-39, **switched off** for now) and L7 (hardening) done. Since
2026-11-02 the one-time login opens in the phone's browser right away and returns to the form (D-42, device-tested on iOS). L6 (UI polish; English only, D-47) and L8 (QA,
go-live) later. Open BA questions: `BA-QUESTIONS.md`.
Written in L0, kept up to date since.
**Background:** `HANDOFF.md` (original brief). **Decisions:** `DECISIONS.md` (D-xx). **Progress:** `IMPLEMENTATION-PLAN.md`.
**Plain-language overview for non-technical readers:** `SETUP-GUIDE.md` §0 and `BA-FAQ.md`.

---

## 1. Goal and scope (this phase)

Sales reps open a LIFF form from the rich menu of a dedicated "Sales Reporting" LINE OA and:
1. **Log Activity** — record a customer activity on an Account as a **Task** (D-11), optionally with photos/files (D-34, switched off for now).
2. **Update Opportunity** — update one of the Account's open Opportunities.

Constraints: no middleware (browser → Salesforce Site → `api.line.me` only), one-time Salesforce login per rep,
Account selected by ID via debounced auto-complete, everything runs **as the rep** (Option B, D-02).

Out of scope for this phase (adds scope if requested): creating Accounts or Opportunities, OA push messages/reminders,
packaging/AppExchange. (Photos/attachments were added in L5b and are switched off by a setting until the BA confirms them.)

## 2. Target org — findings (read-only checks, 2026-10-28)

| Item | Finding | Impact |
|---|---|---|
| Org | TerraSky (Thailand) Co., Ltd., Enterprise Edition, **sandbox `dev5`**, instance JPN178S, API v68.0. Default locale `ja_JP`, language `en_US`, TZ Asia/Bangkok. | Build and test here; production later via validated deploy. |
| My Domain | `terraskyth` (enhanced domains, stabilized hostnames). Sites domain `terraskyth--dev5.sandbox.my.salesforce-sites.com`; Experience domain `…sandbox.my.site.com`; custom domain `www.terrasky.co.th` (Sites runtime). | Build URLs with `URL.getOrgDomainUrl()` / `Site.getBaseSecureUrl()`; never hardcode. |
| Installed packages | 22, incl. **LINE Connect `tsthlineoa` 0.1.0.10 "MVP"**, mitoco suite, Pardot, Sansan, Stripe, TSTH CalendarConnect, DevOps Center. | No dependency on any. D-04. |
| Existing Sites | 10 active: `LineWebhook` (VF, `/linewebhook`, LINE Connect), `ConnectedLanding` (VF), TerraSky Experience sites, several `xxxDemoSite*`. | Create our own Site (D-09). Sandbox Site limits: 1,024 MB/day bandwidth, 30 min/day request time, 500,000 page views/month (from `Site` fields). |
| SSO | No SAML SSO config. Auth providers exist (Google, DevOps Center, Google Vertex, Salesforce IdPs) but none is a rep login IdP. | Reps log in with username/password (+ MFA if enforced) on the link page. |
| MFA / session | No permission set/profile grants "MFA for UI logins"; `enableMFADirectUILoginOptIn=false`. Session timeout 2 h, `lockSessionsToDomain=true`, `lockSessionsToIp=false`, `forceLogoutOnSessionTimeout=true`, SMS identity confirmation on. | Sandbox shows no explicit MFA enforcement; **production must be checked again before go-live** (Salesforce requires MFA for direct UI logins in production). Link flow must work with MFA either way. |
| Record types | None on Account, Opportunity, Task or Event (single sales process). | No record-type picker needed. |
| Validation rules — Account | none | |
| Validation rules — Task / Event | none | |
| Validation rules — Opportunity | 63 total, **5 active**: closed-won needs signed contract + "reason for winning" (2 rules); closed-lost needs Lost Main Reason + detail; Lead Source `Partners` needs Prime Partner; **Stage ≥ 02 (not Closed Lost) needs `PreSales_Engineer__c`**. | Show these errors in plain language; probably exclude Closed Won/Lost from the stage picker in this phase (BA). |
| Required fields (create, no default) | Account: `Name`. Opportunity: `Name`, `StageName`, `CloseDate`, **`Your_Win_Confidence__c`** (field-level required picklist). Task/Event: none beyond platform rules (Event needs start/end or all-day). | Only matters for updates if a required field is blank on old records. |
| Opportunity picklists | Stage: `01. Before 1st MTG`, `02. Early Stage`, `03. Final Proposal`, `08.Closed Won`, `08.Closed Lost`. Win confidence: `01. 0 - 10%` … `06. 91 - 100%`. `Amount` is labelled **"Target TCV"**. Two "Next Step" fields (D-12). | Field list below. |
| Task picklists | Status: Open (default), Pending, Completed, Overdue, Due Soon, Normal. Type: call outcomes (Connected – Had Conversation, …). Subject combobox: Call, Send Letter, Send Quote, Presale Activity, Other. | Task fits calls, not visits. |
| Event picklists | Type: Web Meeting, **On-site / Visit**, Dinner / Event, Discovery Meeting, Proposal Review, Demo Session, Management Meeting, Renewal Discussion. Subject: Call, Email, Meeting, Send Letter/Quote, Other. | Event fits "訪問報告" (D-11). |
| Automation | Apex triggers: `AccountTrigger`, `EventTrigger`, `OpportunityTrigger` (+ Pardot `LogAccountChange`). Record-triggered flows: Task `Auto_Generate_Call_Subject`; Event Slack note on create, Opp meeting counter, `Event_Log_a_Meeting` (before save), admin-only delete; Opportunity: next-step date stamps, Slack alerts on create/update, close-lost notification. | Records created from LINE fire the same automation as UI edits (expected with Option B). Include them in UAT. |
| Licences | Active users: 9 Salesforce, 18 Salesforce Platform, plus integration/guest users. | **Platform users cannot use Opportunities** (D-13). |
| Remote sites | `LINE_Messaging_API` (unpackaged) and LINE Connect's `LINE_API`, `LINE_API_DATA` → api.line.me / api-data.line.me. | Ship our own `SalesReport_LINE_API` (D-10). |
| Connected / External Client Apps | 33 connected apps (standard + mitoco/Pardot/etc.), 1 ECA `Wix_Pardot_ECA`. No existing app usable for us. | New ECA for Option B (L3, [HUMAN] cert + consumer key). |
| Certificates | Only TSTH homepage/self-signed certs (some expired). | New self-signed cert `SalesReport_JWT_Signing` for JWT (L3). |
| Platform Cache | Only packaged partitions (mitoco, pkgviz). | D-14. |
| API limits | DailyApiRequests 5,000,000 (sandbox). | Site Apex REST calls do not count 1:1; the internal calls as the rep do (§6). |

## 3. Architecture

As HANDOFF §3. Summary:

```
LINE app ─ rich menu ─▶ https://liff.line.me/{liffId}?form=activity|opportunity
   LIFF page (VF page SalesReport_Liff + static resource, LIFF SDK bundled)  ── served by Site "SalesReport_Site"
     │  X-Line-Id-Token: <LINE ID token>   (not Authorization — Salesforce would reject it, D-24)
     ▼
   Apex REST (global, Site guest) ──▶ api.line.me/oauth2/v2.1/verify   (who is it?)
     │  map LINE sub → User (SalesReport_Line_Link__c)
     │  JWT bearer exchange for that User ──▶ <My Domain>/services/oauth2/token
     ▼
   REST API as the rep ──▶ <My Domain>/services/data/v68.0/...  (sharing, FLS, VRs native)
```

First-time login (flow B, D-42): LIFF finds the rep not linked → `POST /link/start` → the **phone's browser** opens
`<My Domain>/apex/SalesReport_Link?code=…&form=…` right away (LINE shows "finish in your browser") → rep logs in (MFA /
passkey works there) → page shows the LINE account → **Connect** → `SalesReport_Line_Link__c` written → redirect to
`liff.line.me/<LIFF ID>?form=…` opens LINE on the form. (A login inside the LINE window, D-40, was tried and dropped:
LINE's browser can't do passkeys, D-41.)

## 4. API (Apex REST on the Site, `/services/apexrest/salesreport/v1/...`)

Step-by-step walkthrough of each endpoint: **`REST-ENDPOINTS.md`**.

All requests carry the LINE ID token in **`X-Line-Id-Token`** (D-24) and count towards the per-LINE-user rate limit (D-36). Responses are JSON, never cached; errors use
`{ "error": { "code": "...", "message": "<plain-language>", "fields": { … }, "reference": "<request ID>" } }` (`fields` only on form errors; `reference` = Salesforce request ID, same as the Sales Report Log entry, shown in LINE on server errors — D-45). Error codes: `TOKEN_MISSING`,
`TOKEN_INVALID`, `TOKEN_EXPIRED` (401 — page reloads once), `NOT_LINKED` (403 — page shows Connect), `NOT_AUTHORIZED`
(403), `QUERY_TOO_SHORT` (400), `INVALID_INPUT` / `SAVE_FAILED` (400, with `fields`: field API name → message; L5), `RATE_LIMITED` (429; L7), `NO_ACCESS` (403 — the rep can't read that object/field, e.g. Opportunity on a Platform licence; L5c), `UNAVAILABLE` / `CONFIG_MISSING` (503), `LINE_ERROR` / `SESSION_ERROR` (502), `INTERNAL` (500).

| Method & path | Purpose | Rep must be linked | Status | Notes |
|---|---|---|---|---|
| `GET /connection` | Verify token; return `{ linked, lineDisplayName, salesforceUserName }` | no | Done (L2–L3) | First call on every page load. When linked, the Salesforce name is read **as the rep** (proves the JWT session). Was `/me` until 2026-11-02 (D-38). |
| `POST /link/start` | Create one-time link code; return link-page URL | no | Done (L3) | 256 random bits, base64url; SHA-256 stored only; 5-min expiry; single use. |
| `GET /accounts?q=` | Account auto-complete | yes | Done (L4) | Min 2 chars, max 10 (settings). Runs as the rep → only visible Accounts. Name + field set `SalesReport_Account_Search` (D-29); prefix matches first. |
| `GET /opportunities?accountId=` | Open Opportunities on the Account visible to the rep | yes | Done (L5c) | `IsClosed = false`, ordered by CloseDate, ≤ 50. Returns `{ opportunities: [{ id, name, stage, closeDate, ownerName }] }`. |
| `GET /opportunities?lookup=<field>&q=` | Search for a lookup field of the form (Main PreSales Engineer → active Users) | yes | Done (D-46) | Only single-object lookups of the field set; as the rep; ≤ 10. Returns `{ records: [{ id, name, detail }] }`. |
| `GET /opportunities?id=` | Update form for one open Opportunity, filled with current values | yes | Done (L5c) | Field set `SalesReport_Opportunity_Form` via `SalesReportFormService` (Edit layout, D-31); Stage = open stages (+ current). Returns `{ id, name, accountId, fields }`. |
| `GET /activity` | Form definition for the rep: field-set fields with label, type, picklist values, required flag and defaults | yes | Done (L5a) | Field set `SalesReport_Activity_Form` + UI API object-info, layout, picklist-values read **as the rep** (D-31, D-35). |
| `POST /activity` | Create the **Task** (D-11): body `{ accountId, values: { <field>: <value> } }` | yes | Done (L5a) | Only field-set fields accepted; `WhatId` = Account ID only (D-33), checked visible to the rep; `OwnerId` = rep, Subject built from Type + Account, Status from date in the rep's time zone (D-32). Returns `{ id, subject, status }`. Errors: `INVALID_INPUT` / `SAVE_FAILED` (400) with `fields`. |
| `POST /activity/files?taskId=&name=` | Attach one file (raw bytes, `application/octet-stream`) to a Task the rep just created | yes | Done (L5b) | `ContentVersion` with `FirstPublishLocationId` = Task, as the rep (D-34). Only the rep's own Task, within 60 min; count/size/type limits from settings. Returns `{ id, name, size }`. **Off** while setting *Attachments Enabled* is unticked (403 `NOT_AUTHORIZED`). |
| `POST /opportunities` | Update one Opportunity: body `{ id, accountId, values }` | yes | Done (L5c; all `/opportunities` calls answer 403 while *Update Opportunity Enabled* is unticked) | Only form fields; open Opportunity of the chosen Account; empty optional fields cleared; PATCH as the rep. Returns `{ id, name, accountId }`. (D-39) |

Internal (login required, not on the Site): VF page `SalesReport_Link` at `<My Domain>/apex/SalesReport_Link?code=…` —
needs custom permission `SalesReport_Access`; shows the LINE account; links only after **Connect** (POST, CSRF-protected);
writes `SalesReport_Line_Link__c` through `SalesReportLinkService` (D-27): a **new link record** per link; refused
with "contact your administrator" when the rep's user already has an active link to another LINE account
(`ALREADY_LINKED`) or the LINE account is actively linked to another user (`LINE_IN_USE`), existing link untouched,
WARN logged; expired, used and unknown codes are logged too (D-44).

## 5. Data model (D-08, decided)

Naming (D-07): components prefixed `SalesReport_`; fields on our own objects unprefixed.

**`SalesReport_Line_Link__c`** — one record **per link** (D-44): `Line_User_Id__c` (external ID, not unique), `User__c`,
`Status__c` (Active / Unlinked / Revoked), `Active_User_Key__c` and `Active_Line_Key__c` (unique; one active link per User
and per LINE account, kept by trigger `SalesReportLineLinkTrigger`), `Line_Display_Name__c`, linked/ended audit fields;
field history on User and Status. A second LINE account is refused until an admin **Revokes** the first (`BA-FAQ.md` §4).
**`SalesReport_Link_Code__c`** — `Code_Hash__c` (SHA-256, unique), `Line_User_Id__c`, `Line_Display_Name__c`, `Expires_At__c`,
`Used_At__c`, `Used_By__c`.
**`SalesReport_Log__c`** — application log (D-18).
**`SalesReport_Rate_Limit__c`** — per-LINE-user request counter for the rate limit (L7, D-36); key = SHA-256 of the LINE user ID.
**Custom setting `SalesReport_Settings__c`** — channel ID, LIFF ID, ECA consumer key, cert name, link-code TTL, Account
search limits, attachments switch and limits, rate limit, log level and retention, kill switch. No secrets are stored in
it (unpackaged "Protected" visibility has no effect); the JWT private key stays in the certificate store.
**Field sets** `SalesReport_Account_Search` (Account, D-29) and `SalesReport_Activity_Form` (Task, D-21/D-31).
Reps get **no** access to our objects; only the services write them (justifications in `DATA-DICTIONARY.md` §5.3).

Full field lists, types, defaults, permissions and Site/ECA settings: **`DATA-DICTIONARY.md`**.

## 5a. Apex classes (D-07 naming)

`SalesReport` + name + layer suffix. Controllers stay thin: parse the request, call a service, map the result/errors to the
response. Services hold the logic. Only `…CalloutService` classes make HTTP callouts. `…Data` classes are plain DTOs
(no logic, no SOQL/DML). Each class has a `<Class>Test`.

Built classes are marked ✓ (deployed to sandbox `dev5`).

| Layer | Class | Purpose | Milestone |
|---|---|---|---|
| Controller | ✓ `SalesReportConnectionController` | `@RestResource` `GET /salesreport/v1/connection` | L2 |
| Controller | ✓ `SalesReportLinkController` | `@RestResource` `POST /salesreport/v1/link/start` | L3 |
| Controller | ✓ `SalesReportLinkPageController` | VF `SalesReport_Link` page (runs as the logged-in rep) | L3 |
| Controller | ✓ `SalesReportAccountController` | `@RestResource` `GET /salesreport/v1/accounts` | L4 |
| Controller | ✓ `SalesReportOpportunityController` | `@RestResource` `GET` (list / form) / `POST` (update) `/salesreport/v1/opportunities` | L5c |
| Controller | ✓ `SalesReportActivityController` | `@RestResource` `GET` (form) / `POST` (create) `/salesreport/v1/activity` | L5a |
| Controller | ✓ `SalesReportActivityFileController` | `@RestResource` `POST /salesreport/v1/activity/files` | L5b |
| Service | ✓ `SalesReportIdentityService` | Verify request token (via callout service), resolve LINE user → linked User | L2–L3 |
| Service | ✓ `SalesReportLinkService` | Create/consume link codes, link/unlink, deactivated-user cleanup | L3 |
| Service | ✓ `SalesReportAccountService` | Account search rules (min chars, limit, fields) | L4 |
| Service | ✓ `SalesReportOpportunityService` | Open list, prefilled form, stage limits, update as the rep (D-39) | L5c |
| Service | ✓ `SalesReportFormService` | Shared form engine: field set + UI API as the rep, required flags, value checks (D-31, D-35) | L5a/L5c |
| Service | ✓ `SalesReportActivityService` | Form definition from field set + UI API, Task create as the rep (D-11, D-31–D-35) | L5a |
| Service | ✓ `SalesReportActivityFileService` | Attach a file to the rep's own recent Task as the rep (D-34) | L5b |
| Service | ✓ `SalesReportSettingsService` | Single reader of `SalesReport_Settings__c` | L2 |
| Service | ✓ `SalesReportLogService` | Buffered logging, `flush()`, never throws | L2 |
| Service | ✓ `SalesReportRateLimitService` | Per-LINE-user counter, custom object (D-36) | L7 |
| Service | ✓ `SalesReportCleanupService` | Nightly cleanup of codes, logs, counters (D-37) | L7 |
| CalloutService | ✓ `SalesReportLineCalloutService` | `POST api.line.me/oauth2/v2.1/verify` | L2 |
| CalloutService | ✓ `SalesReportSessionCalloutService` | JWT bearer exchange for the rep (Option B) | L3 |
| CalloutService | ✓ `SalesReportOrgApiCalloutService` | REST API calls to the org **as the rep** (userinfo, SOQL, UI API, create, file upload) | L3–L5 |
| Data | ✓ `SalesReportLineVerifyData` | LINE verify response (`sub`, `aud`, `exp`, `name`, …) | L2 |
| Data | ✓ `SalesReportConnectionData`, ✓ `SalesReportLinkStartData`, ✓ `SalesReportAccountData`, ✓ `SalesReportErrorData`, ✓ `SalesReportFormData`, ✓ `SalesReportActivityData`, ✓ `SalesReportActivityFileData`, ✓ `SalesReportOpportunityData`, ✓ `SalesReportOpportunityFormData` | Request/response DTOs | L2–L5 |
| Controller | ✓ `SalesReportLiffPageController` | VF `SalesReport_Liff`: LIFF ID, API base path (P6), labels, search limits | L2 |
| Service | ✓ `SalesReportRestService` | Shared JSON responses and error mapping | L2 |
| Service | ✓ `SalesReportNamespaceService` | Namespace-safe REST/page paths (P6) | L3 |
| Other | ✓ `SalesReportException` | Typed exception with a plain-language message | L2 |
| Test only | ✓ `SalesReportHttpMock`, ✓ `SalesReportTestFactory` | Callout mocks (per-endpoint routes), test data | L2 |

## 6. [VERIFY] results

| Item | Result | Source / confidence |
|---|---|---|
| ID token verify endpoint | `POST https://api.line.me/oauth2/v2.1/verify`, `application/x-www-form-urlencoded`, params `id_token` (req), `client_id` (req, LINE Login channel ID), `nonce`, `user_id` (opt). Returns `iss`, `sub`, `aud`, `exp`, `iat`, `amr`, `name`, `picture` (with `profile` scope). Errors as JSON `error_description`: `Invalid IdToken.`, `… Issuer.`, `IdToken expired.`, `… Audience.`, `… Nonce.`, `… Subject Identifier.` | LINE Login v2.1 API reference — **confirmed** |
| Also check in Apex | `aud` == our channel ID, `iss` == `https://access.line.me`, `exp` > now (the endpoint already checks these; re-check defensively). LIFF tokens are ES256-signed. | LINE docs — confirmed |
| ID token lifetime | **1 hour** after issue (`liff.getIDToken()` docs). Token is obtained at `liff.init()`; a page left open > 1 h must re-init (reload) when the server returns `token_expired`. | LIFF API reference — confirmed |
| What to send to the server | Send the **ID token** (or access token), never the profile from `liff.getProfile()` / `getDecodedIDToken()`. | "Using user data in LIFF apps and servers" — confirmed |
| `liff.openWindow` | Used with `external: true` for the login (D-42). `external: false` → LINE in-app browser; `true` → external browser; "use in an external browser isn't guaranteed"; Universal-link URLs may jump to apps on newer LINE versions. | Confirmed on a phone in L3: `external: true` opens the link page as a plain page (D-15, D-28 closed) |
| LIFF SDK bundling | `@line/liff` 2.31.2 bundled with esbuild into static resource `SalesReport_LiffApp`; at runtime the SDK still fetches optional files from `*.line-scdn.net` (D-26). | Built and working (L2) |
| Packaged remote site applies to non-package code? | **Not confirmed** by docs found. Irrelevant in practice: we ship our own remote site (D-10). | Salesforce docs — unverified, avoided by design |
| JWT bearer with External Client App | ECA with OAuth + JWT bearer enabled, certificate uploaded, **Permitted Users = "Admin approved users are pre-authorized"**, permission set `SalesReport_User`. Scopes must include **`refresh_token`** — without it Salesforce answers "refresh_token scope is required…" even though no refresh token is issued. Apex: `Auth.JWT` → `Auth.JWS(jwt, cert)` → `Auth.JWTBearerTokenExchange(...).getAccessToken()`. | **Verified hands-on in L3** (2026-10-29) |
| Token endpoint / audience in sandbox | Token endpoint `<My Domain>/services/oauth2/token`; `aud` = `https://test.salesforce.com` (sandbox) / `https://login.salesforce.com` (production), from `Organization.IsSandbox`. | **Verified in L3** (sandbox) |
| Callout to own My Domain | **No Remote Site Setting needed** — Apex callouts to the org's own My Domain work without one. | **Verified in L3** (D-27) |
| Access-token caching | Not cached: exchange per request costs 117–185 ms (+ userinfo 53–152 ms) — acceptable (D-16). | Measured in L3 |
| Apex REST via public Site vs API limit | **Measured 2026-10-29 (sandbox):** 100 anonymous `/connection` calls through the Site raised `DailyApiRequests` by ~17 (background org traffic), so Site guest Apex REST calls do not count 1:1 against the daily API limit. They do count against Site limits (sandbox: 1,024 MB/day bandwidth, 30 min/day request time, 500k page views/month). Each rep request = 1 Site request + 1 LINE verify callout (+ JWT exchange and 1 REST call as the rep from L3; Account search query 60–170 ms in L4). Re-measure the daily API count with real usage in L8. | Measured |

## 7. Field lists

Field lists below are the **initial members of the field sets** (D-21); admins can change them without code.

**Log Activity — decided 2026-10-30 (D-11, D-31–D-34).** Saved as a **Task** linked to the Account only.

| Shown on the form | Task field | Required? | Notes |
|---|---|---|---|
| Account | `WhatId` | always | From the search (L4); not in the field set. |
| Activity Type | `Type` | as Salesforce says (D-31) | Values to be agreed and added by an admin (Q-A2); today only call outcomes exist. |
| Activity Purpose | `ActivityPurpose__c` | as Salesforce says | Existing org picklist (1. Initial Meeting … 6. Other). Not in the repo field set (org field, P3): an admin adds it in Setup if the BA wants it. |
| Date | `ActivityDate` | as Salesforce says | Any date (D-32). |
| Comments | `Description` | as Salesforce says | Long text. |
| Attachments | Salesforce Files | no | After save; limits Q-A6a (D-34). **Switched off** (setting *Attachments Enabled*) since 2026-11-02. |
| — (server) | `Subject` | layout | "<Type label> – <Account name>" (or "Task – <Account name>" without a Type; format in label `SalesReport_Activity_Subject`). |
| — (server) | `OwnerId` | layout | The rep. |
| — (server) | `Status` | layout | Date ≤ today → `Completed`, future → layout default (`Open`) (D-32). |
| — (server) | `Priority` | layout | Layout default (`Normal`). |

"As Salesforce says" = required if required on the rep's Task layout, required in the database, or ticked *Required* in
the field set; validation rules are checked on save (D-31). In `dev5` (2026-10-30) the Task layout requires only Subject,
Assigned To, Priority and Status, so Type, Date and Comments are optional unless an admin changes the layout.

**Update Opportunity — built 2026-11-02 with the proposed defaults (D-39); BA may change it in Setup (Q-O1–Q-O7).**

| Shown on the form | Field (`dev5` label) | Required? | Notes |
|---|---|---|---|
| Account, Opportunity | `AccountId`, `Id` | always | Account search (L4) → its open Opportunities the rep can see. |
| Stage | `StageName` (Stage) | as Salesforce says (required) | Active open stages only (01–03 in `dev5`) + the current one; setting `Opportunity_Stages__c` narrows them. |
| Amount | `Amount` (Target TCV) | as Salesforce says (required on the edit layout) | |
| Next Step | `NextStep` (Next Step) | as Salesforce says | Standard field (D-12 default); swap for `Next_Step_Custom__c` in the field set if the BA says so. |
| Close Date | `CloseDate` (Target Close Date) | as Salesforce says (required) | |

Not in the repo field set (org fields, P3) — add in Setup if the BA wants them: `Your_Win_Confidence__c`,
`Next_Step_Due_Date__c`, `Next_Step_Custom__c`. `PreSales_Engineer__c` is a lookup, which the form can't show yet: the
active validation rule (Stage ≥ 02 needs it) shows its message on the form instead (Q-O4).

## 8. Security outline

Coexistence with LINE Connect and packaging-readiness rules: `COEXISTENCE.md`.

- Every class declares sharing. Controllers, most services and the link trigger handler are `with sharing`; only `SalesReportLinkService`,
  `SalesReportLogService`, `SalesReportRateLimitService` and `SalesReportCleanupService` are `without sharing` and state
  system mode explicitly (D-25), with written justifications (`DATA-DICTIONARY.md` §5.3). All business-data reads/writes
  go through the rep's own session (Option B).
- Guest profile: our 5 Apex REST controllers + LIFF VF page only, **no object permissions** (audited 2026-10-30, L7).
- Link page: custom permission required, explicit Connect, single-use 5-min codes stored as hashes (D-27).
- Code Analyzer (Recommended rules): 0 Critical/High after each milestone; one documented suppression (named-credential
  suggestion for the per-request rep session).
- No secrets in code, JS, logs or docs. LINE channel ID and ECA consumer key are configuration, not secrets; the JWT
  private key stays in the certificate store.
- Rate limit per verified LINE user, 60/min by default (D-36); nightly cleanup of codes, logs and counters (D-37).
  Never trust a LINE user ID sent as data.

## 9. Draft acceptance scenarios (for BA to confirm)

1. New rep taps **Log Activity** → the Salesforce login opens in the phone's browser → logs in once → **Connect** → back
   in LINE on the form with their name (D-42).
2. Rep types "ter" → within ~1 s sees ≤ 10 Accounts they can see; cannot find an Account outside their sharing.
3. Rep logs a visit → a Task appears on the Account, Created By = the rep (with photos under Files once attachments are switched on).
4. Rep moves an Opportunity to Stage 02 without PreSales Engineer → sees the org's validation message, nothing saved.
   Rep changes Next Step and Close Date → the Opportunity shows the new values, Last Modified By = the rep.
5. Admin deactivates the rep or clicks **Revoke** on the link → next LIFF open asks for the Salesforce login again.
6. A second LINE account logs in as a rep who is already linked → "contact your administrator", the existing link stays
   (D-44).

## 10. Where we are

| Milestone | State |
|---|---|
| L0 Spec + decisions | Done |
| L1 LINE setup | Done |
| L2 Site, LIFF shell, `/connection` | Done — LINE name shown on the phone |
| L3 One-time login + rep session | Done — linked on the phone, Salesforce name shown |
| L4 Account search | Done — search works on the phone |
| L5 Forms | L5a Log Activity done — Task saved from the phone (2026-10-30); L5b attachments done on iOS, **switched off** 2026-11-02 (Android check when switched on); L5c Update Opportunity built 2026-11-02 with the proposed defaults (D-39) — guest-profile grant done; **switched off** 2026-11-02 (`Opportunity_Form_Enabled__c`); BA answers = Setup changes |
| L6 UI polish | Later (user, 2026-11-02); English only, no translations (D-47) |
| L7 Hardening | Done (2026-10-30): rate limit, nightly cleanup, audits |
| BA architecture review | Done (2026-11-03): link rules D-44 (block, Revoke, history, Revoked status) and support reference D-45 — deployed to `dev5`, device test pending |
| L8 QA, UAT, go-live | Not started |
