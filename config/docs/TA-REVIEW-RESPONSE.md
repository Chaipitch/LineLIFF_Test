# Response to "LINE LIFF × Salesforce Architecture Design – Technical Architecture Review" (v1.0)

Review of the BA's architecture document (24 pages) against what is built and documented in sandbox `dev5` (branch
`main-9i8y8m`). Reviewed 2026-11-03. **Update 2026-11-03:** §1 and G1–G3 are now built (D-44, D-45). References: `DECISIONS.md` (D-xx), `REST-ENDPOINTS.md`, `DATA-DICTIONARY.md`,
`BA-FAQ.md`, `BA-QUESTIONS.md`.

**Summary:** most of the document matches the build. There is **one design conflict** (what happens when a second LINE
account tries to link to the same Salesforce user), **four gaps** where the document asks for something the build does
differently, and a list of **document corrections** where the text or diagrams don't match what was built. The
development team recommends adopting the document's design for the conflict and the gaps (§1–§2), and asks the BA to
apply the corrections in §3.

---

## 1. Design conflict — second LINE account for the same Salesforce user

| | BA document (§1.1, §2.2, §4.2, §6.2) | Current build (D-27, `BA-FAQ.md` §4, BA Q-L8) |
|---|---|---|
| Rule | **Block** the new link. The user is told the Salesforce user is already linked to another LINE account and must ask an admin to revoke it. The existing link stays active. | **Latest wins.** The new link replaces the old one automatically; the old link is ended with reason "Replaced by new LINE account". |
| Risk | Someone who knows a rep's Salesforce login cannot silently take over the rep's LINE connection. | Same attacker could replace the rep's link without an admin noticing (the rep would notice on next use). |

**Recommendation: adopt the BA's rule (block).** Changes needed in the build:

1. **Link page:** if the Salesforce user already has an active link to a different LINE account, refuse, show
   "This Salesforce user is already linked to another LINE account. Please contact your administrator to revoke the
   existing link before linking a new account.", leave the existing link untouched, and log a WARN entry.
2. **Revoke action for admins:** today an admin unlinks by editing the Status by hand, which does not clear the
   active-user key or fill in the audit fields. With blocking, a forgotten key would stop the rep from ever linking
   again. The build gets a **Revoke** action (or automation on the record) that sets Status, Unlink Reason, Unlinked
   At / By and clears the active-user key in one step.

## 2. Gaps — the document asks for something the build does differently

| # | Topic | BA document | Current build | Recommendation |
|---|---|---|---|---|
| G1 | Link history | §2.2: "The previous mapping record is retained for audit/history and is not deleted or overwritten." | One record per LINE account, reused when the rep relinks. Field history tracks User and Status, but the old dates and reason are overwritten. | **Adopt:** a new link record for every successful link; the LINE user ID stops being a unique key; a separate key keeps "one active link per LINE account". |
| G2 | Status values | §2.2: Active, Unlinked, **Revoked**. | Active, Unlinked. | **Adopt** with this rule (BA to confirm): **Revoked** = ended by an administrator; **Unlinked** = ended automatically (Salesforce user deactivated). |
| G3 | Support reference on errors | §5.1, §6.1, §6.2: unexpected errors include a Request ID the user can quote to support. | The Request ID is written to the Sales Report Log but users only see "Something went wrong". | **Adopt:** return the Request ID with every error and show it on unexpected errors ("Reference: …"). |
| G4 | First-time login | §3.1 / §4.4: user enters username + password on the Salesforce login page; the link code is created **after** login. | The login opens in the **phone's browser** (D-42) because LINE's built-in browser cannot do Salesforce passkeys / Face ID (D-41). The link code is created **before** login, bound to the verified LINE user, and consumed after login with an explicit **Connect** (D-27). | **Keep the build; update the document.** Security is equivalent: the code is single-use, 5 minutes, hashed, bound to the verified LINE identity, and only an authenticated Salesforce user who confirms can consume it. The document should mention MFA / passkeys. |

## 3. Document corrections (text or diagrams that don't match the build)

| # | Section | Document says | Built (please update the document) |
|---|---|---|---|
| C1 | §1.1, §2, §5.3 | Three custom objects. | Three custom objects, as the document says (a fourth, `SalesReport_Rate_Limit__c`, was replaced by Platform Cache partition `SalesReportCache` on 2026-11-04, D-51). Plus custom setting **Sales Report Settings** (`SalesReport_Settings__c`) and two **field sets** (`SalesReport_Activity_Form` on Task, `SalesReport_Opportunity_Form` on Opportunity). |
| C2 | §2.6 Configuration Model | No settings object. | Add **Sales Report Settings**: LINE Login channel ID, LIFF ID, ECA consumer key, certificate name, Attachments switch, log level and retention (trimmed 2026-11-04, D-48/D-49; was: link-code TTL, Account search limits, Attachments Enabled + limits, Update Opportunity Enabled, Opportunity Stages, rate limit, log level and retention, kill switch) |
| C3 | §5 Figure 5 | "LIFF Web Application (LWC)", "Log Activity Page (LWC)", "Update Opportunity Page (LWC)". | One **Visualforce page** (`SalesReport_Liff`) loading a bundled JavaScript app (static resource `SalesReport_LiffApp`, LIFF SDK included). |
| C4 | §5 Figure 5 | Endpoints `/auth/link`, `/account/search`, `/task/create`, `/opportunity/update`. | `GET /connection`, `POST /link/start`, `GET /accounts`, `GET`/`POST /activity`, `POST /activity/files`, `GET`/`POST /opportunities` (base `/services/apexrest/salesreport/v1`). Details: `REST-ENDPOINTS.md`. |
| C5 | §5.2 Business Service Layer | LinkCodeService, LineLinkService, AccountSearchService, TaskService, OpportunityService, SalesReportLogger. | `SalesReportLinkService` (codes and links), `SalesReportIdentityService` (LINE token + rep session), `SalesReportAccountService`, `SalesReportActivityService`, `SalesReportActivityFileService`, `SalesReportOpportunityService`, `SalesReportFormService` (shared form engine), `SalesReportLogService`, `SalesReportRateLimitService`, `SalesReportCleanupService`. |
| C6 | §1.3 Figure 1 | Salesforce login shown on the Salesforce Site page. | The login is on the org's **My Domain** (`…my.salesforce.com`), opened in the phone's browser; the Site only hosts the LIFF page and the REST endpoints. |
| C7 | §1.1 | "Opportunity search". | The rep chooses an Account, then one of **its open Opportunities they can see** (no free-text Opportunity search) — as §3.5 already describes. |
| C8 | §4.5.4 / Figure 5 "User-mode access where applicable" | User mode. | Stronger: every Account / Task / Opportunity / file read or write goes through the org's REST API **as the rep** (JWT bearer, D-02), so sharing, CRUD, FLS, validation rules and "Created By" are Salesforce's own. System mode is used only for the feature's own objects, each with a written justification (`DATA-DICTIONARY.md` §5.3). |
| C9 | §6.2 | Log level "FATAL". | Levels are ERROR, WARN, INFO, DEBUG. Unexpected exceptions are logged as ERROR. |
| C10 | §6.3 | "Source__c naming include:" (blank). | `Class.method` of the entry point, e.g. `SalesReportConnectionController.getConnection`, `SalesReportActivityController.create`, `SalesReportOpportunityController.save`, `SalesReportLinkPageController.confirm`, `SalesReportCleanupService`. |
| C11 | §4.4.2 | "If the Salesforce session is expired … require re-authentication." | No Salesforce session is stored: a fresh session for the rep is issued per request (D-16). Re-authentication happens when the link ends (revoked, or the Salesforce user deactivated). If the rep loses the *Sales Report User* permission set, requests are refused until it is restored. |

## 4. Not covered by the document (please add)

| Topic | Build |
|---|---|
| Rate limiting | 60 requests per minute per verified LINE user (setting), "Too many requests" message (D-36). |
| Housekeeping | Nightly job deletes link codes 24 h after expiry, logs after 30 days (setting) (D-37); rate-limit counters expire in Platform Cache by themselves (D-51). |
| Attachments | Photos / files on Log Activity: built, **switched on** 2026-11-04 (setting); BA to confirm the limits (D-34, Q-A6a). |
| Update Opportunity | Built with the proposed fields (Stage, Amount, Next Step, Close Date; open stages only), **switched off** (setting) until the BA confirms the fields (D-39, Q-O1–Q-O7). |
| Licences | Reps on a Salesforce Platform licence can log activities but cannot see Opportunities (D-13); they get a clear "no access" message. |
| Org validation rule | `Require_Main_PreSales_Engineer_When_Stag` crashes on old unnumbered stages (e.g. "Proposal"); suggested fix recorded in `IMPLEMENTATION-PLAN.md` (L5c). |

## 5. Already aligned (no change)

- No middleware: LIFF → Salesforce Site → Apex REST, plus LINE's verify endpoint.
- LINE identity is proven by verifying the **LINE ID token server-side**; client-side IDs / names are never trusted.
- Link code: 5-minute expiry, stored only as a SHA-256 hash, 256-bit random, single use, replay rejected; guessing is
  infeasible and requests are rate-limited.
- Site guest user: only the feature's REST endpoints and the LIFF page, **no object access**; protected operations never
  run on guest privileges.
- Account and Opportunity are bound by **record ID**; an Opportunity must be open and belong to the chosen Account; only
  approved (field-set) fields can be updated; record access, CRUD and FLS enforced by Salesforce.
- Task creation checks create access, Account access, field access, required fields (from the rep's layout) and
  validation rules.
- First use: Salesforce login once, then **straight to the selected service**; later uses open the service directly.
- Offboarding: deactivating the Salesforce user stops access immediately and ends the link automatically.
- Debounced Account search; safe client messages (no stack traces, tokens or secrets); single-save updates (no partial
  business records).
- Admin-only management of links and logs (permission set *Sales Report Admin*); reps have no access to the link objects.

## 6. Next steps

| Owner | Action |
|---|---|
| Development | ~~Implement §1 (block + Revoke action) and §2 G1–G3; update the docs.~~ **Done 2026-11-03** (D-44, D-45), deployed to `dev5`; device test pending. |
| Development | Keep Visualforce for the LIFF page (C3) — decided with the user, reasons in D-43. |
| BA | Confirm the Revoked / Unlinked rule (G2); update the document for G4 and §3–§4. |
| BA / Security | Confirm the reps' Salesforce verification method in production (passwords, MFA app, passkeys) — `BA-QUESTIONS.md` item 19. |
