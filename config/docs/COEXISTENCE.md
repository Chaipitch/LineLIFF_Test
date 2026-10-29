# Coexistence with LINE Connect and packaging readiness

**Purpose:** prove this feature does not clash with the LINE Connect managed package (`tsthlineoa`) in the target org, and
keep it ready to be packaged later without rework. Checked 2026-10-28 against sandbox `dev5` (LINE Connect 0.1.0.10)
and the LINE Connect source (`Chaipitch/lineOA`, read-only). Re-run §4 before every production deploy and after any
LINE Connect upgrade.

---

## 1. Component-by-component check

LINE Connect is a namespaced managed package: every one of its API names carries `tsthlineoa__` (objects, fields,
classes, labels, permission sets, remote sites), so it can't collide with our unpackaged names. The table also checks
the things a namespace does **not** separate (URLs, Sites, shared standard objects, limits).

| Area | LINE Connect (`tsthlineoa`) in the org | This feature | Clash? |
|---|---|---|---|
| Custom objects | `LINE_Conversation__c`, `LINE_Message__c`, `LINE_OA_Configuration__c`, `LINE_Error_Log__c`, `LINE_Settings__c`, `LINE_Webhook_Event__e` | `SalesReport_Line_Link__c`, `SalesReport_Link_Code__c`, `SalesReport_Log__c`, `SalesReport_Settings__c` | No — different names and labels; we never read or write theirs. |
| Fields on standard objects | Contact: `LINE_User_Id__c`, `LINE_OA_Configuration__c`, `LINE_Invite_*`, `LINE_Auto_Created__c`. Event/Task: `LINE_Conversation__c`, `LINE_Sync_Key__c` | **None** added. We write standard Event/Task fields only. | No |
| Apex classes | 47 `Line*` classes (e.g. `LineLinkService`, `LineLogger`) | `SalesReport*` only | No — and no unpackaged `SalesReport*`/`Line*` classes exist in the org. |
| Apex REST URL | `LineWebhookResource` → `/services/apexrest/tsthlineoa/line/webhook` | `/services/apexrest/salesreport/v1/...` (D-20) | No. Unpackaged URL mappings in the org: `/lic-check/*`, `/WebFormLead/*` — no overlap. |
| Triggers | Only on its own `LINE_OA_Configuration__c` and `LINE_Webhook_Event__e` | None (no trigger on User either — deactivated users are unlinked on their next request) | No — package has no trigger on User, Event, Task, Account or Opportunity. |
| Flows | none packaged | none | No |
| Event records | `LineDailyEventSyncBatch` creates one Event per conversation per day (Who = Contact, What = Account) and only finds/rebuilds Events by its own `LINE_Sync_Key__c` | Our Events (if D-11 = Event) leave `tsthlineoa__LINE_Sync_Key__c` and `tsthlineoa__LINE_Conversation__c` blank | No — the batch never touches Events without its sync key. Both kinds appear in the Account's activity timeline; ours are told apart by `Type` (e.g. "On-site / Visit") and the blank LINE Conversation field. |
| Sites | `LineWebhook` (path `/linewebhook`), guest permission set `LINE_Webhook_Guest` | Own Site `SalesReport_Site` (path `salesreport`), own guest profile settings | No — separate Site and guest user; we never assign `LINE_Webhook_Guest` or grant anything to their guest. |
| Permission sets | `LINE_Admin`, `LINE_Chat_User`, `LINE_Webhook_Guest` | `SalesReport_User`, `SalesReport_Admin` | No |
| Tabs / app | `LINE Admin`, `LINE Conversations`, `LINE OA Configurations` | `Sales Report LINE Links`, `Sales Report Logs` | No — distinct labels so admins can't confuse them. |
| Remote sites | `tsthlineoa__LINE_API`, `tsthlineoa__LINE_API_DATA` (+ an unpackaged `LINE_Messaging_API`) | `SalesReport_LINE_API` | No — two remote sites for the same URL are allowed; we depend on none of theirs (D-10). |
| Custom settings / labels | `tsthlineoa__LINE_Settings__c`, `tsthlineoa__LINE_*` labels | `SalesReport_Settings__c`, `SalesReport_*` labels | No |
| Static resources | `tsthlineoa__qrcode` | `SalesReport_LiffApp` | No |
| Platform Cache | none | `SalesReportCache` (L7) | No |
| LINE OA / channels | Each rep's own OA, registered as `LINE_OA_Configuration__c`, with LINE Connect's webhook | Separate "Sales Reporting" OA, **not** registered in LINE Connect, no webhook (`LINE-SETUP.md` §2) | No, as long as nobody registers our OA in LINE Connect. |
| LINE API quotas | Per channel (their OAs' channels) | Our own channels; ID-token verify only | No shared LINE quota. |
| Shared org limits | Uses Apex callouts, async jobs, API requests, Site bandwidth of `LineWebhook` | Uses API requests, callouts, our own Site's bandwidth | **Shared pool**: daily API requests (5M in sandbox) and per-org async limits are common to both. Low volume expected; measured in L2 (§6 of `L0-SPEC.md`). |
| Data | Stores **customers'** LINE user IDs on Contact | Stores **reps'** LINE user IDs in `SalesReport_Line_Link__c` | No — separate stores; even under the same LINE provider, a rep's ID in our table never mixes with Contact data. |

## 2. Rules that keep it clash-free

1. Never reference any `tsthlineoa__` component, in code, metadata, permission sets or tests (HANDOFF §2a).
2. Never modify, deactivate or reassign LINE Connect components, its Site, its guest permission set or its records.
3. Never add fields to standard objects with a `LINE_` prefix; any standard-object field we need uses `SalesReport_`.
4. Apex REST URLs always start with `/salesreport/`.
5. The Sales Reporting OA is never added as a `LINE_OA_Configuration__c` record.
6. Event/Task we create never set `tsthlineoa__*` fields.

## 3. Packaging readiness (not packaged now — D-06)

The feature ships unpackaged. These rules keep the option open of an **unlocked package without namespace** (no code
changes at all) or a **managed/unlocked package with its own namespace** (registered in our own Dev Hub — never the LINE
Connect namespace or Dev Hub).

| # | Rule | Why it matters if we package |
|---|---|---|
| P1 | All feature metadata lives in its own package directory **`sales-report/`** (added to `sfdx-project.json` in L2), not mixed into `force-app/` | `sf package create --path sales-report` works as-is; org-specific config stays out. |
| P2 | No hardcoded IDs, profile names, user names, org URLs or record type names; URLs from `URL.getOrgDomainUrl()` / `Site.getBaseSecureUrl()` | Subscriber orgs differ. |
| P3 | **No static references to org-specific custom fields** (`Your_Win_Confidence__c`, `Next_Step_Due_Date__c`, `PreSales_Engineer__c`, …). Editable/visible form fields come from **field sets** `SalesReport_Opportunity_Form` (Opportunity) and `SalesReport_Activity_Form` (Event/Task) (D-21) | A package can't contain references to fields that exist only in one org; field sets let each org choose its fields. |
| P4 | Field and object names in REST paths, JSON and dynamic SOQL are built from schema tokens / describe (`Schema.SObjectField.getDescribe().getName()`), never string literals | A namespace changes `Foo__c` to `ns__Foo__c`; describe returns the right name. |
| P5 | JSON between LIFF and Apex uses `…Data` DTOs with our own property names, never raw sObject field names | Front end stays the same with or without a namespace. |
| P6 | Front end builds the Apex REST base path from one value provided by the VF page (`/services/apexrest/` + optional namespace + `salesreport/v1`) | Namespaced Apex REST URLs gain `/<ns>/`. |
| P7 | `global` only where the platform requires it (`@RestResource` classes and their HTTP methods); everything else `public` | Global signatures can never change in a managed package. |
| P8 | Tests create all their own data (`SeeAllData=false`), mock all callouts, and don't depend on this org's validation rules; VR-failure tests create their own failure (e.g. invalid value) or skip gracefully when no VR exists | Subscriber orgs run package tests with their own rules. |
| P9 | Standard-object DML through the org REST API reports per-record errors (HANDOFF §6 "unknown orgs") | Subscriber VRs/triggers vary. |
| P10 | Org-specific setup (Site, guest profile, certificate, ECA consumer key, settings values, cache allocation) is **[HUMAN] setup**, documented in `SETUP-GUIDE.md`, not deployed metadata | These can't (or shouldn't) be packaged. |
| P11 | Custom Labels for all UI text; no text hardcoded in JS | Translations ship with the package. |
| P12 | Keep the dependency list empty: no dependency on LINE Connect or any other package | Cross-package dependencies would force install order and the other package's Dev Hub. |

What would still be needed to package later (estimate in HANDOFF §7: ~8–10 days): choose package type, register a
namespace in our Dev Hub (managed only), create the package and versions, External Client App packaging decision,
code coverage per package, Code Analyzer/AppExchange review if commercial.

## 4. Re-check commands (read-only)

```bash
sf package installed list -o lineliff-sbx
```

```bash
sf data query -o lineliff-sbx --use-tooling-api -q "SELECT Name, TableEnumOrId FROM ApexTrigger WHERE NamespacePrefix='tsthlineoa'"
```

```bash
sf data query -o lineliff-sbx -q "SELECT EntityDefinition.QualifiedApiName, QualifiedApiName FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName IN ('User','Account','Opportunity','Event','Task') AND NamespacePrefix='tsthlineoa'"
```

```bash
sf data query -o lineliff-sbx -q "SELECT Name, UrlPathPrefix FROM Site"
```

Expected: no new LINE Connect triggers on User/Account/Opportunity/Event/Task; no package Site using path `salesreport`.
