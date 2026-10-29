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
| `MOCKUP-REVIEW.md` | Concept mockups vs plan: aligned items and gaps G1–G8 | L0 | Done |
| `BA-QUESTIONS.md` | Questions for the BA session, with recommendations and answer column | L0 | Done (answers pending) |
| `images/mockup-1-overview.webp`, `images/mockup-2-login-mapping.webp` | Concept mockups supplied by the user | L0 | Done |
| `DATA-DICTIONARY.md` | Objects, fields, settings, labels, permissions, Site/ECA configuration | L0 | Done (living) |
| `SETUP-GUIDE.md` | Admin guide: Site, ECA, certificate, permission sets, LINE console | L8 | Planned |
| `USER-GUIDE.md` | Rep guide: linking, logging activities, updating opportunities | L8 | Planned |

## 2. Apex classes (`fa/classes/`)

Each class has a `.cls` and `.cls-meta.xml`; each non-test class has a `<Class>Test` with both files too.

| Class | Layer | Purpose | Milestone | Status |
|---|---|---|---|---|
| `SalesReportMeController` | Controller | `GET /salesreport/v1/me` | L2 | Planned |
| `SalesReportLinkController` | Controller | `POST /salesreport/v1/link/start` | L3 | Planned |
| `SalesReportLinkPageController` | Controller | Controller of VF page `SalesReport_Link` | L3 | Planned |
| `SalesReportAccountController` | Controller | `GET /salesreport/v1/accounts` | L4 | Planned |
| `SalesReportOpportunityController` | Controller | `GET /salesreport/v1/opportunities`, `POST /salesreport/v1/opportunity` | L5 | Planned |
| `SalesReportActivityController` | Controller | `POST /salesreport/v1/activity` | L5 | Planned |
| `SalesReportIdentityService` | Service | Token → LINE user → linked User | L2–L3 | Planned |
| `SalesReportLinkService` | Service | Link codes, link/unlink, deactivated-user cleanup | L3 | Planned |
| `SalesReportAccountService` | Service | Account search rules | L4 | Planned |
| `SalesReportOpportunityService` | Service | Field whitelist, ownership check, error mapping | L5 | Planned |
| `SalesReportActivityService` | Service | Build Event/Task, error mapping | L5 | Planned |
| `SalesReportSettingsService` | Service | Only reader of `SalesReport_Settings__c` | L2 | Planned |
| `SalesReportLogService` | Service | Buffered logging, `flush()`, never throws | L2 | Planned |
| `SalesReportRateLimitService` | Service | Per-LINE-user rate limit | L7 | Planned |
| `SalesReportLinkCleanupService` | Service | Schedulable: delete expired link codes and old logs | L7 | Planned |
| `SalesReportLineCalloutService` | CalloutService | LINE ID-token verify | L2 | Planned |
| `SalesReportSessionCalloutService` | CalloutService | JWT bearer exchange (Option B) | L3 | Planned |
| `SalesReportOrgApiCalloutService` | CalloutService | Org REST API calls as the rep | L3–L5 | Planned |
| `SalesReportLineVerifyData` | Data | LINE verify response | L2 | Planned |
| `SalesReportMeData` | Data | `/me` response | L2 | Planned |
| `SalesReportAccountData` | Data | Account search result | L4 | Planned |
| `SalesReportOpportunityData` | Data | Opportunity list item / update request | L5 | Planned |
| `SalesReportActivityData` | Data | Activity request | L5 | Planned |
| `SalesReportErrorData` | Data | Error response (`code`, `message`, `fields`) | L2 | Planned |
| `SalesReportException` | Other | Typed exception, plain-language message | L2 | Planned |
| `SalesReportHttpMock` | Test only | Callout mocks | L2 | Planned |
| `SalesReportTestFactory` | Test only | Test data | L2 | Planned |

## 3. Apex triggers (`fa/triggers/`)

| Trigger | Purpose | Milestone | Status |
|---|---|---|---|
| `SalesReportUserTrigger` | On User deactivation → `SalesReportLinkService` unlinks (nice to have) | L3 | Planned |

## 4. Visualforce pages (`fa/pages/`)

| Page | Purpose | Access | Milestone | Status |
|---|---|---|---|---|
| `SalesReport_Liff` | Serves the LIFF app (static resource) on the Site | Site guest | L2 | Planned |
| `SalesReport_Link` | One-time link page | Logged-in reps only (not on the Site) | L3 | Planned |

## 5. Static resources and LIFF front-end source

| Path | Purpose | Milestone | Status |
|---|---|---|---|
| `liff-app/` (source: HTML/JS/CSS, `@line/liff` dependency, build script) | LIFF front-end source, built into the static resource | L2 | Planned |
| `fa/staticresources/SalesReport_LiffApp` (+ `.resource-meta.xml`) | Built LIFF bundle (JS, CSS, LIFF SDK) | L2 | Planned |

## 6. Objects, fields and settings (`fa/objects/`)

One folder per object: `<Object>.object-meta.xml`, `fields/<Field>.field-meta.xml`, `listViews/`, plus layouts in
`fa/layouts/` and tabs in `fa/tabs/`. Field-level detail: `DATA-DICTIONARY.md` §1–2.

| Object | Fields (files under `fields/`) | Layout / tab | Milestone | Status |
|---|---|---|---|---|
| `SalesReport_Line_Link__c` | `Line_User_Id__c`, `User__c`, `Status__c`, `Active_User_Key__c`, `Linked_At__c`, `Unlinked_At__c`, `Unlink_Reason__c`, `Unlinked_By__c` | Layout + tab + list views "Active links", "All links" | L3 | Planned |
| `SalesReport_Link_Code__c` | `Code_Hash__c`, `Line_User_Id__c`, `Expires_At__c`, `Used_At__c`, `Used_By__c` | Layout only (no tab) | L3 | Planned |
| `SalesReport_Log__c` | `Level__c`, `Source__c`, `Message__c`, `Request_Id__c`, `User__c`, `Line_User_Ref__c` | Layout + tab + list view "Errors today" | L2 | Planned |
| `SalesReport_Settings__c` (hierarchy custom setting) | `Line_Login_Channel_Id__c`, `Liff_Id__c`, `Eca_Consumer_Key__c`, `Jwt_Certificate_Name__c`, `Link_Code_Ttl_Minutes__c`, `Account_Search_Min_Chars__c`, `Account_Search_Max_Results__c`, `Rate_Limit_Per_Minute__c`, `Log_Level__c`, `Log_Retention_Days__c`, `Enabled__c` | — | L2 (fields added per milestone) | Planned |

No fields are added to standard objects. Standard fields read/written as the rep: `DATA-DICTIONARY.md` §3.

| Field set | Object | Purpose | Milestone | Status |
|---|---|---|---|---|
| `fa/objects/Opportunity/fieldSets/SalesReport_Opportunity_Form.fieldSet-meta.xml` | Opportunity | Editable fields on Update Opportunity (D-21) | L5 | Planned |
| `fa/objects/Event/fieldSets/SalesReport_Activity_Form.fieldSet-meta.xml` (or Task, D-11) | Event / Task | Fields on Log Activity (D-21) | L5 | Planned |

## 7. Security and access

| Path | Component | Purpose | Milestone | Status |
|---|---|---|---|---|
| `fa/permissionsets/SalesReport_User.permissionset-meta.xml` | Permission set | Reps: link page, our objects as needed; pre-authorises the ECA | L2–L3 | Planned |
| `fa/permissionsets/SalesReport_Admin.permissionset-meta.xml` | Permission set | Admins: manage links, settings | L2–L3 | Planned |
| `fa/remoteSiteSettings/SalesReport_LINE_API.remoteSite-meta.xml` | Remote Site | `https://api.line.me` (D-10) | L2 | Planned |
| `fa/remoteSiteSettings/SalesReport_Org_Domain.remoteSite-meta.xml` | Remote Site | Org My Domain, if needed ([VERIFY] L3) — URL is org-specific, may be [HUMAN] | L3 | Planned |
| `fa/labels/CustomLabels.labels-meta.xml` | Custom Labels `SalesReport_*` | UI text JA / EN / TH | L6 | Planned |
| Site guest profile settings | Profile (org-generated) | Apex `SalesReport*Controller` (REST) + VF `SalesReport_Liff` only, no object access | L2 | [HUMAN] |

## 8. Components created in Setup ([HUMAN], not in the repo)

| Component | Name | Where | Milestone | Status |
|---|---|---|---|---|
| Salesforce Site | `SalesReport_Site` (path `salesreport`) | Setup → Sites | L2 | [HUMAN] |
| Certificate | `SalesReport_JWT_Signing` | Setup → Certificate and Key Management | L3 | [HUMAN] |
| External Client App | `SalesReport_App` | Setup → External Client App Manager | L3 | [HUMAN] |
| Platform Cache partition | `SalesReportCache` | Setup → Platform Cache | L7 | [HUMAN] |
| Settings values | `SalesReport_Settings__c` org defaults | Setup → Custom Settings | L2–L3 | [HUMAN] |
| LINE OA, Messaging API channel, LINE Login channel | "Sales Reporting" | LINE consoles (`LINE-SETUP.md`) | L1 | [HUMAN] |
| LIFF app, rich menu | "Sales Reporting" | LINE Developers Console / OA Manager | L2 | [HUMAN] |

## 9. Project configuration

| File | Change | Milestone | Status |
|---|---|---|---|
| `sfdx-project.json` | Add package directory `sales-report` (P1) | L2 | Planned |
| `manifest/package.xml` (or `manifest/salesreport.xml`) | Lists all deployable components above | L2 | Planned |
| `package.json` | Build script for `liff-app/` and `@line/liff` dependency | L2 | Planned |
| `.forceignore` | Exclude `liff-app/` source and build output from deploys | L2 | Planned |
| `liff-app/` location | Front-end source kept outside the package directory | L2 | Planned |
