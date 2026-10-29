# Spec — LINE Sales Reporting (LIFF → Salesforce)

**Status (2026-10-29):** L0–L3 done, L4 (Account search) deployed and waiting on one setup step and a device test.
Written in L0, kept up to date since. Open: the two form field lists (§7), waiting on the BA (`BA-QUESTIONS.md`).
**Background:** `HANDOFF.md` (original brief). **Decisions:** `DECISIONS.md` (D-xx). **Progress:** `IMPLEMENTATION-PLAN.md`.
**Plain-language overview for non-technical readers:** `SETUP-GUIDE.md` §0 and `BA-FAQ.md`.

---

## 1. Goal and scope (this phase)

Sales reps open a LIFF form from the rich menu of a dedicated "Sales Reporting" LINE OA and:
1. **Log Activity** — record a customer activity on an Account (object: D-11 open — the mockup shows **Task**, see `MOCKUP-REVIEW.md` G1).
2. **Update Opportunity** — update one of the Account's open Opportunities.

Constraints: no middleware (browser → Salesforce Site → `api.line.me` only), one-time Salesforce login per rep,
Account selected by ID via debounced auto-complete, everything runs **as the rep** (Option B, D-02).

Out of scope for this phase (adds scope if requested): photos/attachments, creating Accounts or Opportunities,
OA push messages/reminders, packaging/AppExchange.

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

First-time login (flow B): LIFF "Connect Salesforce" → `POST /link/start` → phone browser opens
`<My Domain>/apex/SalesReport_Link?code=…` → rep logs in (MFA if required) → page shows the LINE account → **Connect** →
`SalesReport_Line_Link__c` written → back to LINE. Proven on a phone 2026-10-29.

## 4. API (Apex REST on the Site, `/services/apexrest/salesreport/v1/...`)

All requests carry the LINE ID token in **`X-Line-Id-Token`** (D-24). Responses are JSON, never cached; errors use
`{ "error": { "code": "...", "message": "<plain-language>" } }` (`fields` added in L5). Error codes: `TOKEN_MISSING`,
`TOKEN_INVALID`, `TOKEN_EXPIRED` (401 — page reloads once), `NOT_LINKED` (403 — page shows Connect), `NOT_AUTHORIZED`
(403), `QUERY_TOO_SHORT` (400), `UNAVAILABLE` / `CONFIG_MISSING` (503), `LINE_ERROR` / `SESSION_ERROR` (502), `INTERNAL` (500).

| Method & path | Purpose | Rep must be linked | Status | Notes |
|---|---|---|---|---|

| `GET /me` | Verify token; return `{ linked, lineDisplayName, salesforceUserName }` | no | Done (L2–L3) | First call on every page load. When linked, the Salesforce name is read **as the rep** (proves the JWT session). |
| `POST /link/start` | Create one-time link code; return link-page URL | no | Done (L3) | 256 random bits, base64url; SHA-256 stored only; 5-min expiry; single use. |
| `GET /accounts?q=` | Account auto-complete | yes | Done (L4) | Min 2 chars, max 10 (settings). Runs as the rep → only visible Accounts. Name + field set `SalesReport_Account_Search` (D-29); prefix matches first. |
| `GET /opportunities?accountId=` | Open Opportunities on the Account visible to the rep | yes | L5 | `IsClosed = false`, ordered by CloseDate. |
| `POST /activity` | Create the activity (Task or Event, D-11) | yes | L5 | `WhatId` = Account ID, `OwnerId` = rep (implicit). |
| `POST /opportunity` | Update one Opportunity | yes | L5 | Only field-set fields (D-21); `Id` must belong to the chosen Account. |

Internal (login required, not on the Site): VF page `SalesReport_Link` at `<My Domain>/apex/SalesReport_Link?code=…` —
needs custom permission `SalesReport_Access`; shows the LINE account; links only after **Connect** (POST, CSRF-protected);
writes `SalesReport_Line_Link__c` through `SalesReportLinkService` (D-27).

## 5. Data model (D-08, decided)

Naming (D-07): components prefixed `SalesReport_`; fields on our own objects unprefixed.

**`SalesReport_Line_Link__c`** — one record per LINE user: `Line_User_Id__c` (unique, external ID), `User__c`, `Status__c`
(Active / Unlinked), `Active_User_Key__c` (unique; enforces one active link per User), `Line_Display_Name__c`,
linked/unlinked audit fields; field history on User and Status. Latest confirmed login wins (`BA-FAQ.md` §4).
**`SalesReport_Link_Code__c`** — `Code_Hash__c` (SHA-256, unique), `Line_User_Id__c`, `Line_Display_Name__c`, `Expires_At__c`,
`Used_At__c`, `Used_By__c`.
**`SalesReport_Log__c`** — application log (D-18).
**Custom setting `SalesReport_Settings__c`** — channel ID, LIFF ID, ECA consumer key, cert name, link-code TTL, Account
search limits, log level, kill switch.
**Field set `SalesReport_Account_Search`** (Account) — extra searched fields (D-29).
No secrets are stored in it (unpackaged "Protected" visibility has no effect); the JWT private key stays in the certificate store.
Reps get **no** access to these objects; only the services write them (justifications in `DATA-DICTIONARY.md` §5.3).

Full field lists, types, defaults, permissions and Site/ECA settings: **`DATA-DICTIONARY.md`**.

## 5a. Apex classes (D-07 naming)

`SalesReport` + name + layer suffix. Controllers stay thin: parse the request, call a service, map the result/errors to the
response. Services hold the logic. Only `…CalloutService` classes make HTTP callouts. `…Data` classes are plain DTOs
(no logic, no SOQL/DML). Each class has a `<Class>Test`.

Built classes are marked ✓ (deployed to sandbox `dev5`).

| Layer | Class | Purpose | Milestone |
|---|---|---|---|
| Controller | ✓ `SalesReportMeController` | `@RestResource` `GET /salesreport/v1/me` | L2 |
| Controller | ✓ `SalesReportLinkController` | `@RestResource` `POST /salesreport/v1/link/start` | L3 |
| Controller | ✓ `SalesReportLinkPageController` | VF `SalesReport_Link` page (runs as the logged-in rep) | L3 |
| Controller | ✓ `SalesReportAccountController` | `@RestResource` `GET /salesreport/v1/accounts` | L4 |
| Controller | `SalesReportOpportunityController` | `@RestResource` `GET /salesreport/v1/opportunities`, `POST /salesreport/v1/opportunity` | L5 |
| Controller | `SalesReportActivityController` | `@RestResource` `POST /salesreport/v1/activity` | L5 |
| Service | ✓ `SalesReportIdentityService` | Verify request token (via callout service), resolve LINE user → linked User | L2–L3 |
| Service | ✓ `SalesReportLinkService` | Create/consume link codes, link/unlink, deactivated-user cleanup | L3 |
| Service | ✓ `SalesReportAccountService` | Account search rules (min chars, limit, fields) | L4 |
| Service | `SalesReportOpportunityService` | Field whitelist, Account ownership check, error mapping | L5 |
| Service | `SalesReportActivityService` | Build the Event/Task (D-11), error mapping | L5 |
| Service | ✓ `SalesReportSettingsService` | Single reader of `SalesReport_Settings__c` | L2 |
| Service | ✓ `SalesReportLogService` | Buffered logging, `flush()`, never throws | L2 |
| Service | `SalesReportRateLimitService` | Per-LINE-user counter (D-14) | L7 |
| CalloutService | ✓ `SalesReportLineCalloutService` | `POST api.line.me/oauth2/v2.1/verify` | L2 |
| CalloutService | ✓ `SalesReportSessionCalloutService` | JWT bearer exchange for the rep (Option B) | L3 |
| CalloutService | ✓ `SalesReportOrgApiCalloutService` | REST API calls to the org **as the rep** (query, create, update) | L3–L5 |
| Data | ✓ `SalesReportLineVerifyData` | LINE verify response (`sub`, `aud`, `exp`, `name`, …) | L2 |
| Data | ✓ `SalesReportMeData`, ✓ `SalesReportLinkStartData`, ✓ `SalesReportAccountData`, ✓ `SalesReportErrorData`, `SalesReportOpportunityData`, `SalesReportActivityData` | Request/response DTOs | L2–L5 |
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
| `liff.openWindow` | `external: false` → LINE in-app browser; `true` → external browser; "use in an external browser isn't guaranteed"; Universal-link URLs may jump to apps on newer LINE versions. | Confirmed on a phone in L3: `external: true` opens the link page as a plain page (D-15, D-28 closed) |
| LIFF SDK bundling | `@line/liff` 2.31.2 bundled with esbuild into static resource `SalesReport_LiffApp`; at runtime the SDK still fetches optional files from `*.line-scdn.net` (D-26). | Built and working (L2) |
| Packaged remote site applies to non-package code? | **Not confirmed** by docs found. Irrelevant in practice: we ship our own remote site (D-10). | Salesforce docs — unverified, avoided by design |
| JWT bearer with External Client App | ECA with OAuth + JWT bearer enabled, certificate uploaded, **Permitted Users = "Admin approved users are pre-authorized"**, permission set `SalesReport_User`. Scopes must include **`refresh_token`** — without it Salesforce answers "refresh_token scope is required…" even though no refresh token is issued. Apex: `Auth.JWT` → `Auth.JWS(jwt, cert)` → `Auth.JWTBearerTokenExchange(...).getAccessToken()`. | **Verified hands-on in L3** (2026-10-29) |
| Token endpoint / audience in sandbox | Token endpoint `<My Domain>/services/oauth2/token`; `aud` = `https://test.salesforce.com` (sandbox) / `https://login.salesforce.com` (production), from `Organization.IsSandbox`. | **Verified in L3** (sandbox) |
| Callout to own My Domain | **No Remote Site Setting needed** — Apex callouts to the org's own My Domain work without one. | **Verified in L3** (D-27) |
| Access-token caching | Not cached: exchange per request costs 117–185 ms (+ userinfo 53–152 ms) — acceptable (D-16). | Measured in L3 |
| Apex REST via public Site vs API limit | **Measured 2026-10-29 (sandbox):** 100 anonymous `/me` calls through the Site raised `DailyApiRequests` by ~17 (background org traffic), so Site guest Apex REST calls do not count 1:1 against the daily API limit. They do count against Site limits (sandbox: 1,024 MB/day bandwidth, 30 min/day request time, 500k page views/month). Each rep request = 1 Site request + 1 LINE verify callout (+ JWT exchange and 1 REST call as the rep from L3; Account search query 60–170 ms in L4). Re-measure the daily API count with real usage in L8. | Measured |

## 7. Field lists (open — waiting on the BA, `BA-QUESTIONS.md` §2–3)

The mockup (`MOCKUP-REVIEW.md`) suggests: Log Activity = Account, Activity Type, Date, Comments as a **Task**; Update
Opportunity = Opportunity, Stage, Amount, Next Step. The org-based draft below is kept until the BA decides.

**Log Activity (if Event, D-11)**: Account (ID, required) · Type (Event `Type`, default `On-site / Visit`) · Subject
(default from Type + Account name, editable) · Date + start time + duration (default now, 60 min) · Description / notes
(required) · Related open Opportunity (optional `WhatId` alternative — BA). If Task: Subject, ActivityDate, Status
`Completed`, Type, Description.

Field lists below are the **initial members of the field sets** (D-21); admins can change them without code.

**Update Opportunity**: Opportunity (from Account's open list) · `StageName` (open stages only, `01`–`03`) ·
`Your_Win_Confidence__c` · `CloseDate` · `Amount` ("Target TCV") · Next Step (`NextStep` or `Next_Step_Custom__c`, D-12) ·
`Next_Step_Due_Date__c`. Read-only header: name, current stage, owner. Moving to Stage 02/03 requires
`PreSales_Engineer__c` — either show the error from the org or add the field to the form (BA).

## 8. Security outline

Coexistence with LINE Connect and packaging-readiness rules: `COEXISTENCE.md`.

- Every class declares sharing. Controllers and most services are `with sharing`; only `SalesReportLinkService` and
  `SalesReportLogService` are `without sharing` and state system mode explicitly (D-25), with written justifications
  (`DATA-DICTIONARY.md` §5.3). All business-data reads/writes go through the rep's own session (Option B).
- Guest profile: our Apex REST controllers + LIFF VF page only, **no object permissions** (checked by query).
- Link page: custom permission required, explicit Connect, single-use 5-min codes stored as hashes (D-27).
- Code Analyzer (Recommended rules): 0 Critical/High after each milestone; one documented suppression (named-credential
  suggestion for the per-request rep session).
- No secrets in code, JS, logs or docs. LINE channel ID and ECA consumer key are configuration, not secrets; the JWT
  private key stays in the certificate store.
- Rate limit per LINE user (D-14). Never trust a LINE user ID sent as data.

## 9. Draft acceptance scenarios (for BA to confirm)

1. New rep taps **Log Activity** → sees "Connect Salesforce" → logs in once → returns to LINE → form shows their name.
2. Rep types "ter" → within ~1 s sees ≤ 10 Accounts they can see; cannot find an Account outside their sharing.
3. Rep logs a visit → Event (or Task) appears on the Account, Created By = the rep, Slack flow fires as for UI entries.
4. Rep moves an Opportunity to Stage 02 without PreSales Engineer → sees the org's validation message, nothing saved.
5. Admin deactivates/unlinks the rep → next LIFF open shows "Connect Salesforce" again.

## 10. Where we are

| Milestone | State |
|---|---|
| L0 Spec + decisions | Done |
| L1 LINE setup | Done |
| L2 Site, LIFF shell, `/me` | Done — LINE name shown on the phone |
| L3 One-time login + rep session | Done — linked on the phone, Salesforce name shown |
| L4 Account search | Deployed; waiting on guest access (`SETUP-GUIDE.md` L4-2) and a device test |
| L5 Forms | Blocked on BA answers (D-11, D-12, field lists) |
| L6–L8 | Not started |
