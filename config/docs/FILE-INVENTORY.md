# File inventory — LINE Sales Reporting

Every file and org component that belongs to this feature: where it lives, what it does, which milestone adds it, and its
status. Naming follows D-07 (`DECISIONS.md`); the Apex layer design is in `L0-SPEC.md` §5a.

**Rule:** any commit that adds, renames or removes a file for this feature updates this inventory in the same commit.
At the end of each milestone, set the status of everything delivered to **Done** and add anything new.

Status: **Done** · **Planned** · **[HUMAN]** (created by the user in Setup / console, not deployed from the repo) ·
**Removed** (keep the row, with the commit that removed it).

Paths are relative to the repo root; `fa/` = `force-app/main/default/`.

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
| `SETUP-GUIDE.md` | Admin guide: Site, ECA, certificate, permission sets, LINE console | L8 | Planned |
| `USER-GUIDE.md` | Rep guide: linking, logging activities, updating opportunities | L8 | Planned |

## 2. Apex classes (`fa/classes/`)

Each class has a `.cls` and `.cls-meta.xml`; each non-test class has a `<Class>Test` with both files too.

| Class | Layer | Purpose | Milestone | Status |
|---|---|---|---|---|
| `SalesReportMeController` | Controller | `GET /sr/v1/me` | L2 | Planned |
| `SalesReportLinkController` | Controller | `POST /sr/v1/link/start` | L3 | Planned |
| `SalesReportLinkPageController` | Controller | Controller of VF page `SalesReport_Link` | L3 | Planned |
| `SalesReportAccountController` | Controller | `GET /sr/v1/accounts` | L4 | Planned |
| `SalesReportOpportunityController` | Controller | `GET /sr/v1/opportunities`, `POST /sr/v1/opportunity` | L5 | Planned |
| `SalesReportActivityController` | Controller | `POST /sr/v1/activity` | L5 | Planned |
| `SalesReportIdentityService` | Service | Token → LINE user → linked User | L2–L3 | Planned |
| `SalesReportLinkService` | Service | Link codes, link/unlink, deactivated-user cleanup | L3 | Planned |
| `SalesReportAccountService` | Service | Account search rules | L4 | Planned |
| `SalesReportOpportunityService` | Service | Field whitelist, ownership check, error mapping | L5 | Planned |
| `SalesReportActivityService` | Service | Build Event/Task, error mapping | L5 | Planned |
| `SalesReportSettingsService` | Service | Only reader of `SalesReport_Settings__c` | L2 | Planned |
| `SalesReportLogService` | Service | Buffered logging, `flush()`, never throws | L2 | Planned |
| `SalesReportRateLimitService` | Service | Per-LINE-user rate limit | L7 | Planned |
| `SalesReportLinkCleanupService` | Service | Schedulable: delete expired link codes | L7 | Planned |
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

## 6. Objects and fields (`fa/objects/`)

| Object / field | Purpose | Milestone | Status |
|---|---|---|---|
| `SalesReport_Line_Link__c` | LINE user ↔ Salesforce User mapping (D-08) | L3 | Planned |
| ↳ `Line_User_Id__c` | Text 64, unique, external ID | L3 | Planned |
| ↳ `User__c` | Lookup(User) | L3 | Planned |
| ↳ `Linked_At__c`, `Unlinked_At__c` | Date/Time | L3 | Planned |
| ↳ `Status__c` | Picklist: Active / Unlinked | L3 | Planned |
| `SalesReport_Link_Code__c` | One-time link codes (hash only) | L3 | Planned |
| ↳ `Code_Hash__c` | Text 64, unique (SHA-256) | L3 | Planned |
| ↳ `Line_User_Id__c` | Text 64 | L3 | Planned |
| ↳ `Expires_At__c`, `Used_At__c` | Date/Time | L3 | Planned |
| `SalesReport_Settings__c` | Protected hierarchy custom setting | L2 | Planned |
| ↳ `Line_Login_Channel_Id__c` | LINE Login channel ID (not a secret) | L2 | Planned |
| ↳ `Eca_Consumer_Key__c` | External Client App consumer key (not a secret) | L3 | Planned |
| ↳ `Jwt_Certificate_Name__c` | Unique name of the JWT signing certificate | L3 | Planned |
| List views / page layouts for both objects | Admin view of linked reps and codes | L3 | Planned |

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
| `manifest/package.xml` (or `manifest/salesreport.xml`) | Lists all deployable components above | L2 | Planned |
| `package.json` | Build script for `liff-app/` and `@line/liff` dependency | L2 | Planned |
| `.forceignore` | Exclude `liff-app/` source and build output from deploys | L2 | Planned |
