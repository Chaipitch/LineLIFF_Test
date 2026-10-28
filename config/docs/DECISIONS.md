# Decisions log — LINE Sales Reporting (LIFF → Salesforce)

Newest entries at the bottom. Status: **Decided** (user confirmed), **Proposed** (default the build will use unless the
user says otherwise), **Open** (blocked on the BA session / user).
See `HANDOFF.md` for background and `L0-SPEC.md` for the spec these decisions feed.

| # | Date | Topic | Decision | Status | Notes / source |
|---|---|---|---|---|---|
| D-01 | 2026-10-28 | Order of work | Start with milestone **L0** (spec + decisions log). One milestone at a time, stop and report after each. | Decided | User |
| D-02 | 2026-10-28 | Whose permissions apply (HANDOFF §5) | **Option B — JWT bearer, act as the rep.** Site Apex verifies the LINE ID token, then exchanges a JWT for a short-lived session of the mapped rep and calls the org's REST API as that rep. Sharing, FLS, validation rules and "Created By" are native. | Decided | User |
| D-03 | 2026-10-28 | Development org | Develop in sandbox **`dev5`** of the TerraSky (Thailand) org (Enterprise Edition, `IsSandbox = true`). CLI alias `lineliff-sbx`. Never develop in production. | Decided | `sf org display`, Organization query |
| D-04 | 2026-10-28 | LINE Connect in the target org | LINE Connect (`tsthlineoa`) **0.1.0.10 "MVP"** (04tgL000000ZN9pQAG) is installed. No dependency on it; its Site `LineWebhook`, remote sites and objects are not touched. | Decided | `sf package installed list` |
| D-05 | 2026-10-28 | Branch | Work on branch `main-9i8y8m`, created from `main`. | Decided | User |
| D-06 | 2026-10-28 | Packaging (HANDOFF §2) | **Unpackaged** plain SFDX project, no namespace, for this phase. Revisit before commercialisation. No package/namespace/version is created without asking. | Proposed | |
| D-07 | 2026-10-28 | Naming prefix | **Apex classes/triggers and LWC: `SalesReport` prefix** (e.g. `SalesReportRestMe`, `SalesReportLineVerifier`, test classes `SalesReport*Test`; LWC folders `salesReport*`). **Everything else: `SR_` prefix** — custom objects and fields (incl. fields on our own objects), custom settings / metadata types, Custom Labels, permission sets, Visualforce pages, static resources, Remote Site Settings, Site, Platform Cache partition, certificate, External Client App. Checked 2026-10-28: no objects, fields, Apex, LWC, VF pages, static resources, permission sets, labels, remote sites or Sites in the org use `SR_` / `SalesReport` / path `salesreport` (re-check in L2 before first deploy). | Decided | User |
| D-08 | 2026-10-28 | Identity store (HANDOFF §3) | Small custom object **`SR_Line_Link__c`** (LINE user ID unique external ID, lookup to User, linked-at, status) + **`SR_Link_Code__c`** (SHA-256 hash of code, LINE user ID, expires-at, used-at). Preferred over a User field because unlink/audit history and admin list views are easier and it needs no User-object edits. | Proposed | |
| D-09 | 2026-10-28 | Own Site | New Visualforce Site (name `SR_Sales_Report`, path `salesreport`) on `terraskyth--dev5.sandbox.my.salesforce-sites.com`. Guest gets only the reporting Apex REST classes + LIFF VF page, no object access. | Proposed | 10 Sites already exist; none reused |
| D-10 | 2026-10-28 | Remote Site Setting | Ship our own `SR_LINE_API` → `https://api.line.me`. The org already has an unpackaged `LINE_Messaging_API` remote site with the same URL (owner unknown); we do not rely on it or on LINE Connect's packaged `LINE_API`. | Proposed | `RemoteProxy` query |
| D-11 | 2026-10-28 | Activity object | **Open — leaning Event** for "訪問報告" (visit report): the org's Event `Type` already has `On-site / Visit`, `Web Meeting`, `Demo Session` etc., while Task `Type` holds call outcomes. Event has active flows (Slack note on create, Opp meeting counter) that would fire — likely desirable, confirm with BA. | Open | Describe + FlowDefinitionView |
| D-12 | 2026-10-28 | Opportunity "Next Step" | **Open** — two fields labelled "Next Step": standard `NextStep` and `Next_Step_Custom__c`, plus `Next_Step_Due_Date__c`. Flows stamp "Next Step updated date" fields. Ask which one reps use. | Open | Describe |
| D-13 | 2026-10-28 | Rep licences | **Open / risk** — Opportunity update needs a full Salesforce licence: the org has 9 active `Salesforce` and 18 `Salesforce Platform` users. Platform licence users cannot access Opportunities. Confirm which reps will use the tool. | Open | User licence count |
| D-14 | 2026-10-28 | Platform Cache | No unpackaged cache partition exists (only `mitoco` and `pkgviz` ones). Rate limiting / token-hash cache needs a new partition `SR_Cache` with an allocation — **[HUMAN]** in L7, or fall back to a custom-object counter. | Proposed | `PlatformCachePartition` query |
| D-15 | 2026-10-28 | Link page browser | `liff.openWindow({ url, external: true })` to open the one-time link page in the phone's default browser (where the rep is most likely already logged in to Salesforce); in-app browser as fallback. To be validated on devices in L3. | Proposed | LIFF API reference |
| D-16 | 2026-10-28 | Access-token caching (Option B) | Do **per-request** JWT exchange first; no access token stored in Platform Cache or anywhere else. Measure latency in L3; only then consider an encrypted, per-user, short-TTL cache. | Proposed | HANDOFF §5 |
| D-17 | 2026-10-28 | LIFF host channel | Keep the LIFF app on a **LINE Login channel** (HANDOFF §3) rather than a LINE MINI App, although LINE now recommends MINI Apps for new LIFF apps: MINI Apps add a review step and public-service policies that don't fit an internal tool. Revisit for commercialisation. | Proposed | LIFF docs |

## Still open (from HANDOFF §8 — BA session)

Scope (number of reps, languages JA/EN/TH, target date, acceptance scenarios) · activity fields · which Opportunities are
listed and which fields are editable · Account search fields (name only vs phone/code/kana) and own vs all visible ·
link lifetime and offboarding owner · OA confirmation messages · LINE provider ownership and who creates the OA/channels.
