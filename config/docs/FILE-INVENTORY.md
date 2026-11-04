# File inventory — LINE Sales Reporting

Every file and org component that belongs to this feature: where it lives, what it does, which milestone adds it, and its
status. Naming follows D-07 (`DECISIONS.md`); the Apex layer design is in `L0-SPEC.md` §5a. Field, setting and access
detail is in `DATA-DICTIONARY.md`.

**Rule:** any commit that adds, renames or removes a file for this feature updates this inventory in the same commit.
At the end of each milestone, set the status of everything delivered to **Done** and add anything new.

Status: **Done** · **Planned** · **[HUMAN]** (created by the user in Setup / console, not deployed from the repo) ·
**Removed** (keep the row, with the commit that removed it).

Paths are relative to the repo root; `fa/` = `sales-report/main/default/` (own package directory, D-06 / P1).

---

## 1. Documentation (`config/docs/`)

| File | Purpose | Milestone | Status |
|---|---|---|---|
| `HANDOFF.md` | Original brief and rules for this feature | — | Done |
| `L0-SPEC.md` | Spec: scope, org findings, API, data model, Apex classes, [VERIFY] results | L0 | Done |
| `DECISIONS.md` | Decisions log (D-xx) | L0 | Done (living) |
| `IMPLEMENTATION-PLAN.md` | Tasks per milestone, owners, exit criteria | L0 | Done (living) |
| `LINE-SETUP.md` | [HUMAN] guide for the LINE OA, Messaging API and LINE Login channels | L1 | Done |
| `FILE-INVENTORY.md` | This file | L0 | Done (living) |
| `COEXISTENCE.md` | No-clash check with LINE Connect, packaging-readiness rules | L0 | Done (living) |
| `ENVIRONMENTS.md` | Non-secret configuration values per environment (channel IDs, OA ID, LIFF ID, URLs) | L1 | Done (living) |
| `MOCKUP-REVIEW.md` | Concept mockups vs plan: aligned items and gaps G1–G8 | L0 | Done |
| `TA-REVIEW-RESPONSE.md` | Response to the BA's architecture document (TA review v1.0): conflict, gaps, corrections | L8 | Done |
| `REST-ENDPOINTS.md` | How each Apex REST endpoint handles a request, step by step; checklist for adding one | L7 | Done (living) |
| `BA-FAQ.md` | Plain-language answers to BA questions (mapping storage, objects, linking rules, link code) | L3 | Done (living) |
| `BA-QUESTIONS.md` | Questions for the BA session, with recommendations and answer column; Thai checklist at the end (2026-11-02) | L0 | Done (living; answers pending) |
| `images/mockup-1-overview.webp`, `images/mockup-2-login-mapping.webp` | Concept mockups supplied by the user | L0 | Done |
| `DATA-DICTIONARY.md` | Objects, fields, settings, labels, permissions, Site/ECA configuration | L0 | Done (living) |
| `SETUP-GUIDE.md` | Admin guide: Site, settings, LIFF app, rich menu (L2); ECA, certificate (L3); … | L2–L8 | Done (living) |
| `USER-GUIDE.md` | Rep guide: connecting, logging activities, updating opportunities, messages (English) | L8 | Done (2026-11-04) |
| `GO-LIVE-CHECKLIST.md` | Ordered production steps: decisions, deploy, Setup, LINE, cleanup job, smoke test, rollback | L8 | Done (2026-11-04) |

## 2. Apex classes (`fa/classes/`)

Each class has a `.cls` and `.cls-meta.xml`; each non-test class has a `<Class>Test` with both files too.

| Class | Layer | Purpose | Milestone | Status |
|---|---|---|---|---|
| `SalesReportConnectionController` | Controller | `GET /salesreport/v1/connection` | L2 | Done |
| `SalesReportMeController`, `SalesReportMeData` | — | Renamed to `SalesReportConnectionController` / `SalesReportConnectionData`, endpoint `/me` → `/connection` (D-38); deleted from `dev5` 2026-11-02 | L2 | Removed (renamed) |
| `SalesReportLinkController` | Controller | `POST /salesreport/v1/link/start` | L3 | Done |
| `SalesReportLinkPageController` | Controller | VF page `SalesReport_Link`: confirm, then link the logged-in rep; return URL to the chosen form; already-linked / expired-code states logged via `logVisit()`; request ID on unexpected errors | L3, D-44/45 | Done |
| `SalesReportAccountController` | Controller | `GET /salesreport/v1/accounts` | L4 | Done |
| `SalesReportOpportunityController` | Controller | `GET` (list / form) and `POST` (update) `/salesreport/v1/opportunities` (D-39) | L5c | Done |
| `SalesReportActivityController` | Controller | `GET` (form) / `POST` (create Task) `/salesreport/v1/activity` | L5a | Done |
| `SalesReportIdentityService` | Service | Token → verified LINE user (linked User via `SalesReportLinkService`) | L2–L3 | Done |
| `SalesReportLinkService` | Service | Link codes, consume/link (new record per link; refuses `ALREADY_LINKED` / `LINE_IN_USE`, D-44), code problem for the log, lazy unlink of deactivated users | L3, D-44 | Done |
| `SalesReportLineLinkTriggerHandler` | Trigger handler | Active keys follow the status; audit fields when a link ends; ended links and link identities locked (D-44) | D-44 | Done |
| `SalesReportAccountService` | Service | Account search: min chars, field-set fields, escaping, ranking, cap | L4 | Done |
| `SalesReportOpportunityService` | Service | Open list, prefilled form, stage limits, update as the rep | L5c | Done |
| `SalesReportFormService` | Service | Shared form engine: field set + UI API as the rep, required flags, value checks (Task + Opportunity) | L5a/L5c | Done |
| `SalesReportActivityFileController` | Controller | `POST /salesreport/v1/activity/files` (one file, raw bytes) | L5b | Done |
| `SalesReportActivityFileService` | Service | Attach a file to the rep's own recent Task as the rep; count/size/type limits, name cleaning | L5b | Done |
| `SalesReportActivityService` | Service | Form from field set + UI API as the rep; Task create, Subject/Status rules, input checks | L5a | Done |
| `SalesReportSettingsService` | Service | Only reader of `SalesReport_Settings__c` | L2 | Done |
| `SalesReportLogService` | Service | Buffered logging, `flush()`, never throws | L2 | Done |
| `SalesReportRateLimitService` | Service | Per-LINE-user rate limit (custom-object counter, D-36) | L7 | Done |
| `SalesReportCleanupService` | Service | Schedulable: delete expired link codes, old logs, old counters (D-37) | L7 | Done |
| `SalesReportLineCalloutService` | CalloutService | LINE ID-token verify | L2 | Done |
| `SalesReportSessionCalloutService` | CalloutService | JWT bearer exchange (Option B) | L3 | Done |
| `SalesReportOrgApiCalloutService` | CalloutService | Org REST API calls as the rep: userinfo, SOQL, UI API, create, file upload (save errors → `SAVE_FAILED` with fields), rep's today and User ID | L3–L5 | Done |
| `SalesReportLineVerifyData` | Data | LINE verify response | L2 | Done |
| `SalesReportConnectionData` | Data | `/connection` response | L2 | Done |
| `SalesReportAccountData` | Data | Account search result (`id`, `name`, `detail`) | L4 | Done |
| `SalesReportOpportunityData` | Data | `GET /opportunities?accountId=` response (open Opportunities) | L5c | Done |
| `SalesReportOpportunityFormData` | Data | `GET /opportunities?id=` (form + current values) and `POST /opportunities` response | L5c | Done |
| `SalesReportActivityData` | Data | `POST /activity` response (`id`, `subject`, `status`) | L5a | Done |
| `SalesReportActivityFileData` | Data | `POST /activity/files` response (`id`, `name`, `size`) | L5b | Done |
| `SalesReportFormData` | Data | Form definition (fields with label, type, required, default/current value, options); was `SalesReportActivityFormData` until L5c | L5a/L5c | Done |
| `SalesReportErrorData` | Data | Error response (`code`, `message`, `fields`, `reference` = request ID, D-45) | L2, L5a, D-45 | Done |
| `SalesReportNamespaceService` | Service | Namespace-safe REST and page paths (P6) | L3 | Done |
| `SalesReportLookupData` | Data | `GET /opportunities?lookup=` response (`records`: `id`, `name`, `detail`) | D-46 | Done |
| `SalesReportLinkStartData` | Data | `/link/start` response (`linkUrl`) | L3 | Done |
| `SalesReportException` | Other | Typed exception, plain-language message | L2 | Done |
| `SalesReportRestService` | Service | Shared JSON responses / error mapping for the REST controllers | L2 | Done |
| `SalesReportLiffPageController` | Controller | Controller of VF page `SalesReport_Liff`: LIFF ID, API base path (P6), labels | L2 | Done |
| `SalesReportHttpMock` | Test only | Callout mocks | L2 | Done |
| `SalesReportTestFactory` | Test only | Test data | L2 | Done |

## 3. Apex triggers (`fa/triggers/`)

| Trigger | Purpose | Milestone | Status |
|---|---|---|---|
| `SalesReportLineLinkTrigger` | Before insert/update on `SalesReport_Line_Link__c` → `SalesReportLineLinkTriggerHandler` (D-44) | D-44 | Done |
| `SalesReportUserTrigger` | Not built: deactivated users are unlinked on their next request (`SalesReportLinkService.findActiveLink`), so no trigger on User is needed | L3 | Removed (not needed) |

## 4. Visualforce pages (`fa/pages/`)

| Page | Purpose | Access | Milestone | Status |
|---|---|---|---|---|
| `SalesReport_Liff` | Serves the LIFF app (static resource) on the Site | Site guest | L2 | Done |
| `SalesReport_Link` | One-time link page, opened in the phone's browser (D-42): Salesforce login → Connect → redirect to LINE on the chosen form (`?form=`) | Logged-in reps with `SalesReport_User` (not on the Site) | L3, D-40 | Done |

## 5. Static resources and LIFF front-end source

| Path | Purpose | Milestone | Status |
|---|---|---|---|
| `liff-app/build.mjs`, `liff-app/src/main.js`, `liff-app/src/api.js`, `liff-app/src/accountPicker.js`, `liff-app/src/formFields.js` (shared fields, L5c), `liff-app/src/activityForm.js` (L5a), `liff-app/src/opportunityForm.js` (L5c), `liff-app/src/attachments.js` (L5b), `liff-app/src/app.css` | LIFF front-end source (esbuild bundle incl. `@line/liff` 2.31.2), `npm run build:liff` | L2 | Done |
| `fa/staticresources/SalesReport_LiffApp` (+ `.resource-meta.xml`) | Built LIFF bundle (JS, CSS, LIFF SDK) | L2 | Done |

## 6. Objects, fields and settings (`fa/objects/`)

One folder per object: `<Object>.object-meta.xml`, `fields/<Field>.field-meta.xml`, `listViews/`, plus layouts in
`fa/layouts/` and tabs in `fa/tabs/`. Field-level detail: `DATA-DICTIONARY.md` §1–2.

| Object | Fields (files under `fields/`) | Layout / tab | Milestone | Status |
|---|---|---|---|---|
| `SalesReport_Line_Link__c` | `Line_User_Id__c` (not unique since D-44), `User__c`, `Status__c` (+ Revoked), `Active_User_Key__c`, `Active_Line_Key__c` (D-44), `Linked_At__c`, `Unlinked_At__c`, `Unlink_Reason__c` (+ Revoked by admin), `Unlinked_By__c`, `Line_Display_Name__c` | Tab + list views "Active links", "All links"; layout `SalesReport_Line_Link__c-Sales Report LINE Link Layout` and quick action `SalesReport_Line_Link__c.Revoke` in the repo (D-44); field history on `User__c`, `Status__c` | L3, D-44 | Done |
| `SalesReport_Link_Code__c` | `Code_Hash__c`, `Line_User_Id__c`, `Line_Display_Name__c`, `Expires_At__c`, `Used_At__c`, `Used_By__c` | No tab (layout auto-generated) | L3 | Done |
| `SalesReport_Log__c` | `Level__c`, `Source__c`, `Message__c`, `Request_Id__c`, `User__c`, `Line_User_Ref__c` | Tab + list views "All", "Errors today" (layout auto-generated) | L2 | Done |
| `SalesReport_Rate_Limit__c` | `Key__c` (SHA-256 of the LINE user ID), `Window_Start__c`, `Request_Count__c` | No tab, no layout changes; admin read via `SalesReport_Admin` (D-36) | L7 | Done |
| `SalesReport_Settings__c` (hierarchy custom setting) | `Line_Login_Channel_Id__c`, `Liff_Id__c`, `Eca_Consumer_Key__c`, `Jwt_Certificate_Name__c`, `Attachments_Enabled__c`, `Log_Level__c`, `Log_Retention_Days__c` (7 fields; 10 others deleted 2026-11-04, D-48/D-49) | — | L2–L7, trimmed D-48/D-49 | Done |

No fields are added to standard objects. Standard fields read/written as the rep: `DATA-DICTIONARY.md` §3.

| Field set | Object | Purpose | Milestone | Status |
|---|---|---|---|---|
| `fa/objects/Account/fieldSets/SalesReport_Account_Search.fieldSet-meta.xml` | Account | Extra text fields searched by the Account picker (D-29); repo holds Name only | L4 | Done |
| `fa/objects/Opportunity/fieldSets/SalesReport_Opportunity_Form.fieldSet-meta.xml` | Opportunity | Fields on Update Opportunity (D-21, D-39): Stage, Amount, Next Step, Close Date | L5c | Done |
| `fa/objects/Task/fieldSets/SalesReport_Activity_Form.fieldSet-meta.xml` | Task | Fields on Log Activity (D-21): Type, ActivityDate, Description | L5a | Done |

## 7. Security and access

| Path | Component | Purpose | Milestone | Status |
|---|---|---|---|---|
| `fa/permissionsets/SalesReport_User.permissionset-meta.xml` | Permission set | Reps: link page (L3); no object access (D-19); pre-authorises the ECA (L3) | L2–L3 | Done |
| `fa/permissionsets/SalesReport_Admin.permissionset-meta.xml` | Permission set | Admins: logs (L2), settings view (L2), manage links and link codes (L3), rate-limit counters (L7) | L2–L7 | Done |
| `fa/remoteSiteSettings/SalesReport_LINE_API.remoteSite-meta.xml` | Remote Site | `https://api.line.me` (D-10) | L2 | Done |
| `fa/remoteSiteSettings/SalesReport_Org_Domain.remoteSite-meta.xml` | Remote Site | Not needed: callouts to the org's own My Domain work without one (tested 2026-10-29) | L3 | Removed (not needed) |
| `fa/cachePartitions/SalesReportCache.cachePartition-meta.xml` | Platform Cache partition | For the link-code comparison (D-30; the object stays). Deployed to `dev5` with **0 MB** — the org has no free capacity; not used (rate limit uses a custom object, D-36) | L3/L7 | Done (0 MB, unused) |
| `fa/labels/CustomLabels.labels-meta.xml` | Custom Labels `SalesReport_*` | UI text; 56 English labels (L2 shell, L3 connect / link page, L4 Account picker, L5a activity form, L5b attachments, L7 rate-limit message, L5c Update Opportunity), English only, no translations (D-47); 61 labels after D-44–D-46 | L2–D-46 | Done |
| `fa/customPermissions/SalesReport_Access.customPermission-meta.xml` | Custom permission | Checked by the link page; granted by `SalesReport_User` | L3 | Done |
| Site guest profile settings | Profile (org-generated) | Apex `SalesReportConnectionController`, `SalesReportLinkController` (done), `SalesReportAccountController` (done), `SalesReportActivityController` (L5a, done), `SalesReportActivityFileController` (L5b, done), `SalesReportOpportunityController` (L5c, done) + VF `SalesReport_Liff`; no object access | L2–L5 | [HUMAN] — done for L2–L5c |

## 8. Components created in Setup ([HUMAN], not in the repo)

| Component | Name | Where | Milestone | Status |
|---|---|---|---|---|
| Salesforce Site | `SalesReport_Site` (path `salesreport`) | Setup → Sites | L2 | [HUMAN] — done |
| Certificate | `SalesReport_JWT_Signing` | Setup → Certificate and Key Management | L3 | [HUMAN] — done |
| External Client App | `SalesReport_App` | Setup → External Client App Manager | L3 | [HUMAN] — done |
| Platform Cache partition allocation | `SalesReportCache` | Setup → Platform Cache | L7 | Not allocated — no free capacity; not needed (D-36) |
| Scheduled job | "Sales Report cleanup" (nightly 02:00) | Setup → Scheduled Jobs; created with `scripts/apex/schedule-cleanup.apex` | L7 | Done in `dev5` (by Claude, 2026-10-30) |
| Settings value | *Update Opportunity Enabled* = off | Setup → Custom Settings → Sales Report Settings | L5c | Field removed 2026-11-04: Update Opportunity always on (D-49) |
| Settings value | *Attachments Enabled* = off | Setup → Custom Settings → Sales Report Settings | L5b | Off since 2026-11-02 |
| Settings values | `SalesReport_Settings__c` org defaults | Setup → Custom Settings | L2–L3 | [HUMAN] — done |
| LINE OA, Messaging API channel, LINE Login channel | "Sales Reporting" | LINE consoles (`LINE-SETUP.md`) | L1 | [HUMAN] — done |
| LIFF app, rich menu | "Sales Reporting" | LINE Developers Console / OA Manager | L2 | [HUMAN] — done |

## 9. Project configuration

| File | Change | Milestone | Status |
|---|---|---|---|
| `scripts/apex/benchmark-link-codes-object.apex`, `scripts/apex/benchmark-link-codes-cache.apex` | Anonymous Apex benchmarks: link codes in the object vs Platform Cache (D-30); clean up after themselves | L3 | Done |
| `scripts/apex/schedule-cleanup.apex` | Anonymous Apex: schedules the nightly cleanup once per org (D-37) | L7 | Done |
| `README.md` | Project README: what the feature is, folders, build/deploy/test commands, doc index (replaced the Salesforce DX template text) | L8 | Done |
| `sfdx-project.json` | Add package directory `sales-report` (P1) | L2 | Done |
| `manifest/package.xml` | Not used: deploys use `--source-dir sales-report` | L2 | Removed (not needed) |
| `package.json` | Build script for `liff-app/` and `@line/liff` dependency | L2 | Done |
| `.forceignore` | Not needed: `liff-app/` is outside the package directory | L2 | Removed (not needed) |
| `liff-app/` location | Front-end source kept outside the package directory | L2 | Done |
