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
| `BA-FAQ.md` | Plain-language answers to BA questions (mapping storage, objects, linking rules, link code) | L3 | Done (living) |
| `BA-QUESTIONS.md` | Questions for the BA session, with recommendations and answer column | L0 | Done (answers pending) |
| `images/mockup-1-overview.webp`, `images/mockup-2-login-mapping.webp` | Concept mockups supplied by the user | L0 | Done |
| `DATA-DICTIONARY.md` | Objects, fields, settings, labels, permissions, Site/ECA configuration | L0 | Done (living) |
| `SETUP-GUIDE.md` | Admin guide: Site, settings, LIFF app, rich menu (L2); ECA, certificate (L3); … | L2–L8 | Done (living) |
| `USER-GUIDE.md` | Rep guide: linking, logging activities, updating opportunities | L8 | Planned |

## 2. Apex classes (`fa/classes/`)

Each class has a `.cls` and `.cls-meta.xml`; each non-test class has a `<Class>Test` with both files too.

| Class | Layer | Purpose | Milestone | Status |
|---|---|---|---|---|
| `SalesReportMeController` | Controller | `GET /salesreport/v1/me` | L2 | Done |
| `SalesReportLinkController` | Controller | `POST /salesreport/v1/link/start` | L3 | Done |
| `SalesReportLinkPageController` | Controller | VF page `SalesReport_Link`: confirm, then link the logged-in rep | L3 | Done |
| `SalesReportAccountController` | Controller | `GET /salesreport/v1/accounts` | L4 | Done |
| `SalesReportOpportunityController` | Controller | `GET /salesreport/v1/opportunities`, `POST /salesreport/v1/opportunity` | L5 | Planned |
| `SalesReportActivityController` | Controller | `GET` (form) / `POST` (create Task) `/salesreport/v1/activity` | L5a | Done |
| `SalesReportIdentityService` | Service | Token → verified LINE user (linked User via `SalesReportLinkService`) | L2–L3 | Done |
| `SalesReportLinkService` | Service | Link codes, consume/link, one active link per User, lazy unlink of deactivated users | L3 | Done |
| `SalesReportAccountService` | Service | Account search: min chars, field-set fields, escaping, ranking, cap | L4 | Done |
| `SalesReportOpportunityService` | Service | Field whitelist, ownership check, error mapping | L5 | Planned |
| `SalesReportActivityService` | Service | Form from field set + UI API as the rep; Task create, Subject/Status rules, input checks | L5a | Done |
| `SalesReportSettingsService` | Service | Only reader of `SalesReport_Settings__c` | L2 | Done |
| `SalesReportLogService` | Service | Buffered logging, `flush()`, never throws | L2 | Done |
| `SalesReportRateLimitService` | Service | Per-LINE-user rate limit | L7 | Planned |
| `SalesReportLinkCleanupService` | Service | Schedulable: delete expired link codes and old logs | L7 | Planned |
| `SalesReportLineCalloutService` | CalloutService | LINE ID-token verify | L2 | Done |
| `SalesReportSessionCalloutService` | CalloutService | JWT bearer exchange (Option B) | L3 | Done |
| `SalesReportOrgApiCalloutService` | CalloutService | Org REST API calls as the rep: userinfo, SOQL, UI API, create (save errors → `SAVE_FAILED` with fields), rep's today | L3–L5 | Done |
| `SalesReportLineVerifyData` | Data | LINE verify response | L2 | Done |
| `SalesReportMeData` | Data | `/me` response | L2 | Done |
| `SalesReportAccountData` | Data | Account search result (`id`, `name`, `detail`) | L4 | Done |
| `SalesReportOpportunityData` | Data | Opportunity list item / update request | L5 | Planned |
| `SalesReportActivityData` | Data | `POST /activity` response (`id`, `subject`, `status`) | L5a | Done |
| `SalesReportActivityFormData` | Data | `GET /activity` response (fields with label, type, required, default, options) | L5a | Done |
| `SalesReportErrorData` | Data | Error response (`code`, `message`, `fields`) | L2, L5a | Done |
| `SalesReportNamespaceService` | Service | Namespace-safe REST and page paths (P6) | L3 | Done |
| `SalesReportLinkStartData` | Data | `/link/start` response (`linkUrl`) | L3 | Done |
| `SalesReportException` | Other | Typed exception, plain-language message | L2 | Done |
| `SalesReportRestService` | Service | Shared JSON responses / error mapping for the REST controllers | L2 | Done |
| `SalesReportLiffPageController` | Controller | Controller of VF page `SalesReport_Liff`: LIFF ID, API base path (P6), labels | L2 | Done |
| `SalesReportHttpMock` | Test only | Callout mocks | L2 | Done |
| `SalesReportTestFactory` | Test only | Test data | L2 | Done |

## 3. Apex triggers (`fa/triggers/`)

| Trigger | Purpose | Milestone | Status |
|---|---|---|---|
| `SalesReportUserTrigger` | Not built: deactivated users are unlinked on their next request (`SalesReportLinkService.findActiveLink`), so no trigger on User is needed | L3 | Removed (not needed) |

## 4. Visualforce pages (`fa/pages/`)

| Page | Purpose | Access | Milestone | Status |
|---|---|---|---|---|
| `SalesReport_Liff` | Serves the LIFF app (static resource) on the Site | Site guest | L2 | Done |
| `SalesReport_Link` | One-time link page (confirm button) | Logged-in reps with `SalesReport_User` (not on the Site) | L3 | Done |

## 5. Static resources and LIFF front-end source

| Path | Purpose | Milestone | Status |
|---|---|---|---|
| `liff-app/build.mjs`, `liff-app/src/main.js`, `liff-app/src/api.js`, `liff-app/src/accountPicker.js`, `liff-app/src/activityForm.js` (L5a), `liff-app/src/app.css` | LIFF front-end source (esbuild bundle incl. `@line/liff` 2.31.2), `npm run build:liff` | L2 | Done |
| `fa/staticresources/SalesReport_LiffApp` (+ `.resource-meta.xml`) | Built LIFF bundle (JS, CSS, LIFF SDK) | L2 | Done |

## 6. Objects, fields and settings (`fa/objects/`)

One folder per object: `<Object>.object-meta.xml`, `fields/<Field>.field-meta.xml`, `listViews/`, plus layouts in
`fa/layouts/` and tabs in `fa/tabs/`. Field-level detail: `DATA-DICTIONARY.md` §1–2.

| Object | Fields (files under `fields/`) | Layout / tab | Milestone | Status |
|---|---|---|---|---|
| `SalesReport_Line_Link__c` | `Line_User_Id__c`, `User__c`, `Status__c`, `Active_User_Key__c`, `Linked_At__c`, `Unlinked_At__c`, `Unlink_Reason__c`, `Unlinked_By__c`, `Line_Display_Name__c` | Tab + list views "Active links", "All links" (layout auto-generated); field history on `User__c`, `Status__c` | L3 | Done |
| `SalesReport_Link_Code__c` | `Code_Hash__c`, `Line_User_Id__c`, `Line_Display_Name__c`, `Expires_At__c`, `Used_At__c`, `Used_By__c` | No tab (layout auto-generated) | L3 | Done |
| `SalesReport_Log__c` | `Level__c`, `Source__c`, `Message__c`, `Request_Id__c`, `User__c`, `Line_User_Ref__c` | Tab + list views "All", "Errors today" (layout auto-generated) | L2 | Done |
| `SalesReport_Settings__c` (hierarchy custom setting) | `Line_Login_Channel_Id__c`, `Liff_Id__c`, `Eca_Consumer_Key__c`, `Jwt_Certificate_Name__c`, `Link_Code_Ttl_Minutes__c`, `Account_Search_Min_Chars__c`, `Account_Search_Max_Results__c`, `Rate_Limit_Per_Minute__c`, `Log_Level__c`, `Log_Retention_Days__c`, `Enabled__c` | — | Done: L2 `Line_Login_Channel_Id__c`, `Liff_Id__c`, `Log_Level__c`, `Enabled__c`; L3 `Eca_Consumer_Key__c`, `Jwt_Certificate_Name__c`, `Link_Code_Ttl_Minutes__c`; L4 `Account_Search_Min_Chars__c`, `Account_Search_Max_Results__c`; others in L7 | Partly done |

No fields are added to standard objects. Standard fields read/written as the rep: `DATA-DICTIONARY.md` §3.

| Field set | Object | Purpose | Milestone | Status |
|---|---|---|---|---|
| `fa/objects/Account/fieldSets/SalesReport_Account_Search.fieldSet-meta.xml` | Account | Extra text fields searched by the Account picker (D-29); repo holds Name only | L4 | Done |
| `fa/objects/Opportunity/fieldSets/SalesReport_Opportunity_Form.fieldSet-meta.xml` | Opportunity | Editable fields on Update Opportunity (D-21) | L5 | Planned |
| `fa/objects/Task/fieldSets/SalesReport_Activity_Form.fieldSet-meta.xml` | Task | Fields on Log Activity (D-21): Type, ActivityDate, Description | L5a | Done |

## 7. Security and access

| Path | Component | Purpose | Milestone | Status |
|---|---|---|---|---|
| `fa/permissionsets/SalesReport_User.permissionset-meta.xml` | Permission set | Reps: link page (L3); no object access (D-19); pre-authorises the ECA (L3) | L2–L3 | Done (L2: empty shell) |
| `fa/permissionsets/SalesReport_Admin.permissionset-meta.xml` | Permission set | Admins: logs (L2), settings view (L2), manage links (L3) | L2–L3 | Done (L2 part) |
| `fa/remoteSiteSettings/SalesReport_LINE_API.remoteSite-meta.xml` | Remote Site | `https://api.line.me` (D-10) | L2 | Done |
| `fa/remoteSiteSettings/SalesReport_Org_Domain.remoteSite-meta.xml` | Remote Site | Not needed: callouts to the org's own My Domain work without one (tested 2026-10-29) | L3 | Removed (not needed) |
| `fa/cachePartitions/SalesReportCache.cachePartition-meta.xml` | Platform Cache partition | For the link-code comparison (D-30; the object stays) and rate limits (L7). Deployed to `dev5` with **0 MB** — the org has no free capacity; capacity is set in Setup, not in the repo | L3/L7 | Done (0 MB) |
| `fa/labels/CustomLabels.labels-meta.xml` | Custom Labels `SalesReport_*` | UI text; 39 English labels (L2 shell, L3 connect / link page, L4 Account picker, L5a activity form), translations JA / TH in L6 | L2–L5, L6 | Done (L2–L5a part) |
| `fa/customPermissions/SalesReport_Access.customPermission-meta.xml` | Custom permission | Checked by the link page; granted by `SalesReport_User` | L3 | Done |
| Site guest profile settings | Profile (org-generated) | Apex `SalesReportMeController`, `SalesReportLinkController` (done), `SalesReportAccountController` (done), `SalesReportActivityController` (L5a, to add) + VF `SalesReport_Liff`; no object access | L2–L5 | [HUMAN] — done for L2–L4, L5a pending |

## 8. Components created in Setup ([HUMAN], not in the repo)

| Component | Name | Where | Milestone | Status |
|---|---|---|---|---|
| Salesforce Site | `SalesReport_Site` (path `salesreport`) | Setup → Sites | L2 | [HUMAN] — done |
| Certificate | `SalesReport_JWT_Signing` | Setup → Certificate and Key Management | L3 | [HUMAN] — done |
| External Client App | `SalesReport_App` | Setup → External Client App Manager | L3 | [HUMAN] — done |
| Platform Cache partition | `SalesReportCache` | Setup → Platform Cache | L7 | [HUMAN] |
| Settings values | `SalesReport_Settings__c` org defaults | Setup → Custom Settings | L2–L3 | [HUMAN] — done |
| LINE OA, Messaging API channel, LINE Login channel | "Sales Reporting" | LINE consoles (`LINE-SETUP.md`) | L1 | [HUMAN] — done |
| LIFF app, rich menu | "Sales Reporting" | LINE Developers Console / OA Manager | L2 | [HUMAN] — done |

## 9. Project configuration

| File | Change | Milestone | Status |
|---|---|---|---|
| `scripts/apex/benchmark-link-codes-object.apex`, `scripts/apex/benchmark-link-codes-cache.apex` | Anonymous Apex benchmarks: link codes in the object vs Platform Cache (D-30); clean up after themselves | L3 | Done |
| `sfdx-project.json` | Add package directory `sales-report` (P1) | L2 | Done |
| `manifest/package.xml` | Not used: deploys use `--source-dir sales-report` | L2 | Removed (not needed) |
| `package.json` | Build script for `liff-app/` and `@line/liff` dependency | L2 | Done |
| `.forceignore` | Not needed: `liff-app/` is outside the package directory | L2 | Removed (not needed) |
| `liff-app/` location | Front-end source kept outside the package directory | L2 | Done |
