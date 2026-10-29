# Handoff — LINE Sales Reporting (LIFF → Salesforce)

> **Historical brief (2026-10-28), kept as written.** Current state: `L0-SPEC.md` (spec), `IMPLEMENTATION-PLAN.md`
> (progress), `DECISIONS.md` (decisions that replace the [DECIDE]/[VERIFY] items below), `SETUP-GUIDE.md` (setup).

**For:** a Claude Code session that will build this feature in a **different Salesforce org / project** from LINE Connect.
**Status (2026-10-28):** proposal agreed in principle; nothing built. Requirements still being clarified with the BA.
Read this whole file before writing code. Items marked **[DECIDE]** need the user's answer first; **[VERIFY]** must be
checked against current LINE / Salesforce docs; **[HUMAN]** are steps only the user can do (consoles, logins).

---

## 1. What this is

An internal tool (later to be sold to clients). Sales reps add a dedicated **"Sales Reporting" LINE Official Account** as a
friend. Its **rich menu** has two buttons that open a **LIFF** web form inside LINE:

| Button | Form | Writes |
|---|---|---|
| Log Activity (訪問報告 / 活動登録) | Activity log | **Task** on an Account ([DECIDE] Task vs Event — "訪問報告" sounds like a visit/Event) |
| Update Opportunity (商談更新) | Opportunity update | Existing **Opportunity** on an Account |

Original requirements from the manager:
1. Separate OA under the company's LINE umbrella; rich menu with the two entry points; each opens a LIFF form.
2. **Account auto-complete**: as the rep types a few characters, search Salesforce Accounts in real time, show a dropdown,
   and bind the selection by **Account ID** (never free text). **Debounce** in the frontend to protect API limits.
3. **Direct integration**: LIFF ↔ Salesforce via REST / Apex REST, **no middleware / iPaaS / external server**.
   **One-time login** on first launch maps the LINE user ID to the rep's Salesforce User; no repeat logins afterwards.

## 2. Relationship to LINE Connect (the existing project)

- This is a **separate feature / separate package**, not part of LINE Connect (a managed 2GP that lets each rep chat with
  Contacts through their own OA). Do **not** add this to the LINE Connect package.
- If the LINE Connect repo is available (`git@github.com:Chaipitch/lineOA.git`), use it as a **reference for patterns only**:
  - `LineApiClient` (single HTTP entry point, typed DTOs, `LineApiException`)
  - `LineLogger` (buffered logging, `flush()`, never throws)
  - `LineSettings` (settings with defaults in code), `LineCredentialStore` (secrets in a protected custom setting)
  - `LineHttpMock` (callout mocks), `LineTriggerHandler`, `LineTestFactory`
  - `LineWebhookResource` + Site guest setup (how a public Apex REST endpoint is exposed safely)
  Copy and adapt; do not create a package dependency unless the user decides so.
- **[DECIDE] Packaging.** Options discussed:
  - Own package in the new org's Dev Hub (default assumption for this handoff).
  - Second 2GP package sharing the `tsthlineoa` namespace with `@namespaceAccessible` reuse — only possible from the
    LINE Connect Dev Hub, so it does not fit "a different org" unless the user says otherwise.
  - Unpackaged (internal-only first, package later).
  Ask before creating any package, namespace or package version.

## 2a. Target org and coexistence with LINE Connect

The target org already has the **LINE Connect managed package installed** (namespace `tsthlineoa`). Build this feature as a
**separate, unpackaged project with no dependency on LINE Connect**.

**Why no dependency**
- In a subscriber org only `global` members of a managed package are callable. LINE Connect exposes only
  `LineWebhookResource`, so its classes (`LineApiClient`, `LineLogger`, …) cannot be reused at runtime. Copy the patterns instead.
- LINE Connect stores customers' LINE IDs and reps' OAs, not the reps' own LINE user IDs, so its data does not help here.
- Reading LINE Connect objects would couple this feature to LINE Connect upgrades and would force any future package to
  use the LINE Connect Dev Hub/namespace. Keep it independent.

**Setup rules**
1. **Develop in a sandbox of the target org, never in production.** If needed, the user creates a Developer / Developer Pro
   sandbox (it will include LINE Connect). Deploy to production with a validated deploy
   (`sf project deploy start --test-level RunLocalTests`; managed-package tests are not run).
2. **New repo**, plain SFDX project, no namespace. Distinct naming so nothing is confused with `tsthlineoa__` components:
   e.g. Apex classes `SalesReport*`, custom fields/objects prefixed `SR_`, Custom Labels prefixed `SR_`. [DECIDE] final prefix.
3. **Own Salesforce Site.** Do not reuse LINE Connect's webhook Site. Its guest user keeps only `LINE_Webhook_Guest`; the new
   Site's guest gets only the reporting Apex REST classes and the LIFF page — no object access.
4. **Own LINE setup.** The Sales Reporting OA must **not** be registered in LINE Connect (no `LINE_OA_Configuration__c` record,
   no LINE Connect webhook URL on it), or reps' messages would be stored as customer chats. Turn off auto-response.
   No webhook needed unless OA confirmation messages are added later.
5. **Own security metadata.** Own permission set (e.g. `Sales_Report_User`, plus an admin one), own protected custom setting
   for secrets, own Remote Site Setting for `api.line.me`. Do not rely on LINE Connect's packaged remote site setting.
   [VERIFY] whether a packaged remote site setting applies to non-package code at all.
6. Never modify, deactivate or uninstall LINE Connect components in that org.

**Check in the target org before L2**
- Which org it is (production vs sandbox) and whether a sandbox is available.
- Existing Sites / domain naming conventions.
- SSO / MFA configuration (affects the one-time link login in flow B).
- Validation rules, record types and required fields on Task, Event, Opportunity, Account.
- Installed LINE Connect version (Setup → Installed Packages) — note it in the decisions log.

**First proof point (end of L2):** tapping a rich-menu button opens the LIFF page from the new Site and shows the rep's
LINE display name. **L3 (identity linking) is the highest-risk milestone — prove it before building the forms.**

## 3. Architecture

```
 Rep's phone (LINE app)                        Salesforce org
 ┌──────────────────────────┐            ┌──────────────────────────────────────┐
 │ Sales Reporting OA       │            │ Public Salesforce Site               │
 │  Rich menu               │            │  ├ LIFF page (HTML/JS static resource│
 │  [Log Activity]          │──opens────▶│  │  served by a Visualforce page;    │
 │  [Update Opportunity]    │            │  │  LIFF SDK bundled, no CDN)        │
 │                          │            │  └ Apex REST endpoints  ─────────────┼──▶ api.line.me
 │ LIFF web form (in-app)   │──HTTPS────▶│     /me /accounts /opportunities     │   (verify ID token)
 └──────────────────────────┘            │     /activity /opportunity /link     │
                                         │                                      │
                                         │ Internal page (login required)       │
                                         │  /apex/<LinkPage> — one-time linking │
                                         │                                      │
                                         │ Account · Task · Opportunity · User  │
                                         └──────────────────────────────────────┘
```

No middleware. Browser → Salesforce Site only. Apex → `api.line.me` only (plus, under Option B, the org's own token endpoint).

### Components
| Area | What to build |
|---|---|
| LINE | New OA under the **same LINE provider** as the LINE Login channel (LINE has no "sub-OA"; same provider ⇒ same user ID). Messaging API channel + **LINE Login channel** with a **LIFF app** (scopes `openid profile`, size Full). Rich menu: 2 URI actions → `https://liff.line.me/{liffId}?form=activity` / `?form=opportunity`. |
| LIFF page | One mobile web app, two forms, served from the Site. LIFF SDK (`@line/liff`) bundled into a static resource. Labels [DECIDE] JA / EN / TH. Text rendered as text, never `innerHTML` with data. |
| Apex REST | `GET /me`, `GET /accounts?q=`, `GET /opportunities?accountId=`, `POST /activity`, `POST /opportunity`, `POST /link/start`. `@RestResource` classes must be `global`. |
| Identity store | LINE user ID ↔ Salesforce User mapping, plus single-use hashed link codes with 5-min expiry. [DECIDE] storage: custom field on User (unique, external ID) vs small custom object. |
| Admin | List linked reps, unlink. Auto-unlink when the User is deactivated (nice to have). |

## 4. Flows

**A. Every request — who is the rep?**
1. LIFF page: `liff.init({ liffId })`, then `liff.getIDToken()`; send it in a header on every call.
2. Apex: `POST https://api.line.me/oauth2/v2.1/verify` with `id_token` + `client_id` (LINE Login channel ID) → `sub` = LINE user ID.
   Check `aud` = our channel ID and `exp`. **[VERIFY]** current endpoint, params, token lifetime.
3. Look up mapping. None → page shows "Connect Salesforce" (flow B). Never trust a LINE user ID sent as plain data.
4. Optional: cache "token hash → user" in Platform Cache until `exp` to save callouts during auto-complete. Never cache tokens themselves.

**B. First launch — one-time Salesforce login**
1. `POST /link/start` with ID token → Apex verifies, creates random link code (store **hash** only, 5-min expiry, single use).
2. Page opens `https://<MyDomain>/apex/<LinkPage>?code=…` (`liff.openWindow` — [VERIFY] whether in-app or external browser works better with the org's SSO/MFA).
3. Rep logs into Salesforce normally (SSO/MFA as configured).
4. Link page runs **as the logged-in rep** (`with sharing`), consumes the code, saves `UserInfo.getUserId()` ↔ LINE user ID.
5. "Done — return to LINE." No Salesforce token or password ever stored on the phone.

**C. Account auto-complete**
- Frontend: min 2 chars, **300 ms debounce**, cancel in-flight request (AbortController), max 10 results.
- Apex: SOSL/SOQL on Account name ([DECIDE] also phone / customer code / kana), only Accounts the rep can see.
- Selection stores **Account ID**; name is display-only.

**D. Submit**
- Log Activity → Task (`WhatId` = Account; fields [DECIDE]).
- Update Opportunity → pick from the Account's open Opportunities visible to the rep, update stage / amount / close date / next step ([DECIDE]).
- Validation-rule / required-field errors from the org are shown to the rep in plain language; nothing silently dropped.

## 5. Key design decision — whose permissions apply [DECIDE]

| | Option A — Site writes + checks | **Option B — act as the rep (JWT bearer) — recommended** |
|---|---|---|
| How | Site Apex (system mode) checks `UserRecordAccess` for the mapped rep before every read/write; sets `OwnerId` = rep. | Apex mints a JWT (`Auth.JWT` / `Auth.JWS` / `Auth.JWTBearerTokenExchange`) for the mapped rep, gets a short-lived session, calls the org's REST API **as the rep**. |
| Created By | Site guest user | The rep |
| Sharing / FLS / validation | Re-implemented manually | Native |
| Security review | Guest with broad data access — reviewers push back | Clean |
| Cost | Baseline | +~2 days; certificate + connected app / External Client App; extra callout per request |

**[VERIFY]** for B: JWT bearer flow with an External Client App, pre-authorised users / permission set, callout to own
My Domain (build the URL from `URL.getOrgDomainUrl()`, never hardcode), whether the access token can be cached safely
(do **not** put it in Platform Cache unencrypted; prefer per-request exchange unless measured too slow).

## 6. Rules to carry over (from LINE Connect's standards)

- **No middleware, no AI/LLM calls.**
- **Secrets** (channel secret, LINE Login channel secret if used, private key/cert) only in a protected custom setting or
  Salesforce certificate store; one class reads them. Never in DTOs, JS, logs, `System.debug`, error messages, tests, scripts or docs.
  If the user pastes a real secret, use it only in the command that needs it; never write it to a file.
- **Callouts before DML** in every transaction.
- **Security-review standard:** every class declares sharing; user-facing Apex in user mode; `without sharing` only with a
  written justification; Code Analyzer with no Critical/High; guest profile gets only the Apex REST classes and the LIFF page —
  **no object access** for the guest.
- **Unknown orgs** (for later commercialisation): no profile names, hardcoded IDs or org-specific URLs; DML on standard
  objects uses `Database.*(…, false)` and reports per-record errors.
- **Rate limiting** per LINE user (simple counter in Platform Cache) to protect API / Site limits. **[VERIFY]** whether Apex REST
  calls through a public Site count against the org's daily API request limit, and Site request limits.
- **Tests:** ≥ 85% overall, every class ≥ 75%, assert behaviour. All callouts mocked. Fake secrets only. Include a
  validation-rule failure test for Task and Opportunity, and `System.runAs` visibility tests (rep cannot see/update records
  outside their sharing).
- Never invent IDs, URLs, LIFF IDs or channel IDs — ask the user.

## 7. Plan and estimate (20–26 working days, assumes Option B)

| # | Milestone | Days |
|---|---|---|
| L0 | Spec: confirm decisions in §8, field lists, write a short spec + decisions log in the new project | 2 |
| L1 | [HUMAN]-heavy LINE setup: OA, Messaging API channel, LINE Login channel, LIFF app, rich menu | 1 |
| L2 | Salesforce Site + guest config, LIFF page shell (`liff.init`, ID token), Apex REST skeleton | 2 |
| L3 | Identity: ID-token verification, link flow (B), mapping store, unlink, Option B session | 4–5 |
| L4 | Account auto-complete (debounce, visibility) | 2 |
| L5 | Log Activity + Update Opportunity forms and endpoints, validation errors | 3–4 |
| L6 | Mobile UI polish, i18n, loading/error states | 2–3 |
| L7 | Tests, security hardening, rate limiting, Code Analyzer | 3 |
| L8 | Device QA (iOS + Android LINE), UAT, setup + user guides | 2–3 |

Excludes: rich menu artwork, waiting on LINE consoles / admins, AppExchange review queue. Commercial packaging adds ~8–10 days.
Anything below that comes back "yes" adds scope: photos/attachments, creating Accounts or Opportunities from LINE,
Events instead of Tasks, OA push notifications/reminders.

Work one milestone at a time; at the end of each, report what was built, tests/coverage, Code Analyzer summary,
[HUMAN] steps with exact console/Setup paths, [VERIFY] results — then stop and wait for the user.

## 8. Open questions (BA session pending)

**Scope:** number of reps (all need a Salesforce licence); target org(s); internal-only vs commercial in this phase;
languages (JA / EN / TH); target date and sign-off owner; 3–5 acceptance scenarios.

**Log Activity:** Task or Event; fields + required; link to Account only or also Opportunity/Contact; completed-only or planned
too; attachments/photos?

**Update Opportunity:** update only or also create; editable fields; record types / sales processes; existing validation
rules; which Opportunities are listed (own / all open on Account / all visible).

**Account search:** fields searched; own vs all visible Accounts; data volume; create Account from LINE if not found?

**Linking & security:** link lifetime (forever vs expiring); offboarding/unlink owner; SSO/MFA in the org; data-in-LINE policy.

**Notifications:** OA confirmation message after submit? Reminders/daily summary? (extra scope)

**LINE ownership:** who owns the LINE Business ID/provider and creates OA + channels; who designs the rich menu image;
verified (blue-badge) OA needed?

**Technical [DECIDE]:** Option A vs B (§5); packaging (§2); identity storage (§3).

## 9. [HUMAN] checklist for the user (values to send back)

1. LINE Developers Console → the company provider → create **Messaging API channel** for the new OA → send **channel ID**
   (keep channel secret / access token private; enter them only where the build tells you).
2. Same provider → create **LINE Login channel** → add **LIFF app** (endpoint URL = the Site page URL the build gives you,
   scopes `openid profile`, link the OA as bot) → send **LIFF ID** and **LINE Login channel ID**.
3. LINE Official Account Manager → upload rich menu image and set the two URI actions (or let the build create the rich menu via API).
4. Salesforce Setup → Sites → create the Site, set the guest profile access the build lists → send the **Site URL**.
5. Option B only: create the certificate and External Client App as instructed → send the **consumer key** (not secret).
6. Provide a test rep user and a test LINE account for device QA.
