# Data dictionary — LINE Sales Reporting

Field-level and configuration-level detail for every object, field, setting and access rule of this feature.
`FILE-INVENTORY.md` lists the files; this document says what is in them. Naming: D-07. Status of the whole document:
**proposed design (L0)** — rows change to *Done* in `FILE-INVENTORY.md` as they are built; update this file in the same
commit whenever a field or setting changes.

Conventions: API names without namespace. "Req" = required at field level. Length in characters.
Every custom field gets a **Description** (for admins) and, where users see it, **Help Text** — both as below.

---

## 1. Custom objects

### 1.1 `SalesReport_Line_Link__c` — LINE user ↔ Salesforce User (D-08)

| Property | Value |
|---|---|
| Label / plural | Sales Report LINE Link / Sales Report LINE Links |
| Record name | Auto Number `LL-{000000}` |
| Sharing (OWD) | Private (internal and external) |
| Who writes | `SalesReportLinkService` only (system mode, see §5.3) — reps have **no** object access |
| Who reads | Site requests via `SalesReportIdentityService` (system mode); admins via `SalesReport_Admin` |
| Field history | On: `User__c`, `Status__c` |
| Records | One per LINE user (upsert by `Line_User_Id__c`); re-linking reuses the record |

| Field | Label | Type | Req | Unique / Ext ID | Default | Description / Help |
|---|---|---|---|---|---|---|
| `Name` | Link No. | Auto Number | — | — | `LL-{000000}` | |
| `Line_User_Id__c` | LINE User ID | Text(64) | Yes | Unique (case-sensitive), External ID | — | LINE user ID (`U` + 32 hex) taken from a **verified** ID token (`sub`). Never from request data. |
| `User__c` | Salesforce User | Lookup(User) | Yes | — | — | The rep who completed the one-time login. |
| `Status__c` | Status | Picklist (restricted): `Active`, `Unlinked` | Yes | — | `Active` | Only `Active` links authorise requests. |
| `Active_User_Key__c` | Active User Key | Text(18) | No | Unique | — | Set to `User__c` Id while Active, blank when Unlinked. Enforces **one active link per User** at database level. Not on layouts. |
| `Linked_At__c` | Linked At | Date/Time | Yes | — | — | When the link page completed. |
| `Unlinked_At__c` | Unlinked At | Date/Time | No | — | — | |
| `Unlink_Reason__c` | Unlink Reason | Picklist (restricted): `Admin`, `User deactivated`, `Relinked to another User` | No | — | — | |
| `Unlinked_By__c` | Unlinked By | Lookup(User) | No | — | — | Admin who unlinked; blank for automatic unlinks. |

### 1.2 `SalesReport_Link_Code__c` — one-time link codes

| Property | Value |
|---|---|
| Label / plural | Sales Report Link Code / Sales Report Link Codes |
| Record name | Auto Number `LC-{000000}` |
| Sharing (OWD) | Private |
| Who writes | `SalesReportLinkService` (create from Site request, consume from link page) — system mode |
| Owner | Created in a Site (guest) context → owned by the Site's **default record owner** (§6, [HUMAN]) |
| Retention | Deleted by `SalesReportLinkCleanupService` 24 h after expiry (L7) |

| Field | Label | Type | Req | Unique / Ext ID | Default | Description / Help |
|---|---|---|---|---|---|---|
| `Name` | Code No. | Auto Number | — | — | `LC-{000000}` | |
| `Code_Hash__c` | Code Hash | Text(64) | Yes | Unique (case-sensitive) | — | SHA-256 hex of the one-time code. The code itself is never stored. |
| `Line_User_Id__c` | LINE User ID | Text(64) | Yes | — | — | From the verified ID token of the `/link/start` request. |
| `Expires_At__c` | Expires At | Date/Time | Yes | — | — | Created + `Link_Code_Ttl_Minutes__c` (default 5). |
| `Used_At__c` | Used At | Date/Time | No | — | — | Set once; a used code is rejected. |
| `Used_By__c` | Used By | Lookup(User) | No | — | — | User who consumed the code on the link page. |

### 1.3 `SalesReport_Log__c` — application log (D-18, decided)

Written by `SalesReportLogService` (buffered, one insert per transaction, never throws). Admin-only.

| Field | Label | Type | Req | Description |
|---|---|---|---|---|
| `Name` | Log No. | Auto Number `LG-{00000000}` | — | |
| `Level__c` | Level | Picklist: `ERROR`, `WARN`, `INFO`, `DEBUG` | Yes | Minimum level written is set by `Log_Level__c` in settings. |
| `Source__c` | Source | Text(255) | Yes | `Class.method`. |
| `Message__c` | Message | Long Text(32,768) | No | **No tokens, secrets, codes or full LINE IDs.** |
| `Request_Id__c` | Request ID | Text(64) | No | `Request.getCurrent().getRequestId()` to correlate. |
| `User__c` | User | Lookup(User) | No | Rep, when known. |
| `Line_User_Ref__c` | LINE User Ref | Text(16) | No | Last 6 chars of the LINE user ID only (enough to correlate, not to identify). |

Retention: delete after `Log_Retention_Days__c` days (default 30) by the L7 cleanup job.

## 2. Custom setting — `SalesReport_Settings__c`

Hierarchy custom setting; values read **only** by `SalesReportSettingsService`, which also holds the code defaults
used when a field is blank. Edited by admins in Setup → Custom Settings ([HUMAN]).

> Visibility "Protected" only has effect inside a managed package. Unpackaged, admins with "View Setup and Configuration"
> can read these values — so **no secrets are stored here** (none of the fields below is a secret).

| Field | Label | Type | Default in code | Set in | Description |
|---|---|---|---|---|---|
| `Line_Login_Channel_Id__c` | LINE Login Channel ID | Text(20) | — (required) | L2 | `client_id` for ID-token verify; also the expected `aud`. |
| `Liff_Id__c` | LIFF ID | Text(40) | — (required) | L2 | Passed to the LIFF page for `liff.init`. |
| `Eca_Consumer_Key__c` | ECA Consumer Key | Text(255) | — (required for Option B) | L3 | `iss` of the JWT. Not a secret. |
| `Jwt_Certificate_Name__c` | JWT Certificate Name | Text(64) | `SalesReport_JWT_Signing` | L3 | Unique name of the signing certificate. |
| `Link_Code_Ttl_Minutes__c` | Link Code TTL (min) | Number(3,0) | 5 | L3 | |
| `Account_Search_Min_Chars__c` | Account Search Min Chars | Number(2,0) | 2 | L4 | |
| `Account_Search_Max_Results__c` | Account Search Max Results | Number(3,0) | 10 | L4 | Capped at 50 in code. |
| `Rate_Limit_Per_Minute__c` | Rate Limit per Minute | Number(4,0) | 60 | L7 | Per LINE user. |
| `Log_Level__c` | Log Level | Text(10) | `WARN` | L2 | `ERROR`/`WARN`/`INFO`/`DEBUG`. |
| `Log_Retention_Days__c` | Log Retention (days) | Number(3,0) | 30 | L7 | |
| `Enabled__c` | Enabled | Checkbox | true | L2 | Kill switch: when false all endpoints return "temporarily unavailable". |

## 3. Standard object fields used (no changes to standard objects)

Read and written **as the rep** (Option B), so the rep's own profile/permission sets must grant this access — this
feature does not grant standard-object access.

| Object | Field | Read | Write | Notes |
|---|---|---|---|---|
| User | `Id`, `Name`, `Username`, `IsActive` | ✓ (system) | — | `Username` = JWT `sub`; `IsActive` checked before exchange. |
| Account | `Id`, `Name` | ✓ | — | Search fields beyond Name: BA (HANDOFF §8). |
| Opportunity | `Id`, `Name`, `AccountId`, `OwnerId`, `IsClosed` | ✓ | — | List filter: `AccountId = :id AND IsClosed = false`. |
| Opportunity | `StageName` | ✓ | ✓ | Open stages only (`01.`–`03.`) in this phase. |
| Opportunity | `Your_Win_Confidence__c` | ✓ | ✓ | Field-level required picklist. |
| Opportunity | `CloseDate` | ✓ | ✓ | |
| Opportunity | `Amount` (label "Target TCV") | ✓ | ✓ | |
| Opportunity | `NextStep` **or** `Next_Step_Custom__c` | ✓ | ✓ | D-12 open. |
| Opportunity | `Next_Step_Due_Date__c` | ✓ | ✓ | |
| Opportunity | `PreSales_Engineer__c` | ✓ | (BA) | Needed by active VR for Stage ≥ 02. |
| Event (if D-11 = Event) | `WhatId`, `Subject`, `Type`, `StartDateTime`, `EndDateTime` / `DurationInMinutes`, `Description` | — | ✓ | `OwnerId` defaults to the rep. |
| Task (if D-11 = Task) | `WhatId`, `Subject`, `Type`, `ActivityDate`, `Status` (`Completed`), `Description` | — | ✓ | |

## 4. Custom Labels (`SalesReport_*`, L6)

Categories `SalesReport` (label "Sales Report"). Translations JA / EN / TH (BA). Initial set — final list grows with the UI:

| Label | English value |
|---|---|
| `SalesReport_Connect_Title` | Connect your Salesforce account |
| `SalesReport_Connect_Button` | Log in to Salesforce |
| `SalesReport_Connect_Done` | Done — you can return to LINE. |
| `SalesReport_Link_Expired` | This link has expired. Open the form in LINE and try again. |
| `SalesReport_Account_Search_Placeholder` | Type at least 2 characters |
| `SalesReport_No_Results` | No matching accounts |
| `SalesReport_Activity_Title` | Log activity |
| `SalesReport_Opportunity_Title` | Update opportunity |
| `SalesReport_Save` | Save |
| `SalesReport_Saved` | Saved |
| `SalesReport_Error_Generic` | Something went wrong. Please try again. |
| `SalesReport_Error_Session_Expired` | Your session expired. Reopening… |
| `SalesReport_Error_Rate_Limited` | Too many requests. Please wait a moment. |
| `SalesReport_Error_Unavailable` | The service is temporarily unavailable. |

Validation-rule messages from the org are shown as returned (they are already in the org's language).

## 5. Access

### 5.1 Permission set `SalesReport_User` (assign to every rep) — D-19 decided

| Area | Grant |
|---|---|
| Visualforce pages | `SalesReport_Link` |
| Apex classes | `SalesReportLinkPageController` |
| Custom objects | **none** (links/codes are written by the service, so reps can't tamper with mappings) |
| External Client App | `SalesReport_App` pre-authorised via this permission set (§7) |
| Standard objects | none — reps' existing profile access applies (§3) |

### 5.2 Permission set `SalesReport_Admin`

| Area | Grant |
|---|---|
| `SalesReport_Line_Link__c` | Read, Edit, Delete, View All (Edit limited to unlink via action/flow; fields `Line_User_Id__c`, `User__c` read-only on layout) |
| `SalesReport_Link_Code__c` | Read, Delete, View All |
| `SalesReport_Log__c` | Read, Delete, View All |
| Tabs | `SalesReport_Line_Link__c`, `SalesReport_Log__c` visible |
| Apex | none beyond the above (unlink via `SalesReportLinkService` invocable, L3) |

### 5.3 `without sharing` justifications (to be repeated in class headers)

| Class | Why |
|---|---|
| `SalesReportIdentityService` | Guest context must read the link for a **verified** LINE user ID; guest has no object access by design. Reads only `User__c`, `Status__c`. |
| `SalesReportLinkService` | Creates/consumes link codes from the guest context and writes links on behalf of the logged-in rep (`UserInfo.getUserId()`); reps get no object access so mappings can't be edited by hand. |
| `SalesReportLogService` | Logs must be written whoever the running user is. |

All other classes: `with sharing`; queries/DML on business data happen through the org REST API as the rep.

### 5.4 Site guest profile (`SalesReport_Site`, [HUMAN] in L2)

| Area | Grant |
|---|---|
| Apex classes | `SalesReportMeController`, `SalesReportLinkController`, `SalesReportAccountController`, `SalesReportOpportunityController`, `SalesReportActivityController` |
| Visualforce pages | `SalesReport_Liff` |
| Objects | **none** |
| Other | Leave all "View …"/API permissions off |

## 6. Salesforce Site `SalesReport_Site` ([HUMAN], L2)

| Setting | Value |
|---|---|
| Site label / name | Sales Report / `SalesReport_Site` |
| Default web address | `https://<sites domain>/salesreport` |
| Active site home page | `SalesReport_Liff` |
| Site contact | Admin user |
| Default record owner | An active admin/integration user (owns guest-created `SalesReport_Link_Code__c` records) |
| Require secure connections (HTTPS) | On |
| Upgrade insecure requests | On |
| Clickjack protection | "Allow framing by the same origin only" (LIFF does not frame the page) |
| Guest access to Salesforce APIs | Off (Apex REST through the Site does not need it) |
| Lightning features for guest | Off |
| Cache public Visualforce pages | Off for `SalesReport_Liff` (LIFF ID is injected) |

## 7. External Client App `SalesReport_App` ([HUMAN], L3)

| Setting | Value |
|---|---|
| Distribution | Local |
| OAuth | Enabled; callback URL `https://localhost/callback` (unused by JWT flow, but required) |
| OAuth scopes | `api` (add `refresh_token` only if the exchange requires it — [VERIFY] L3) |
| Flow enablement | **JWT Bearer Flow** on; certificate = public cert of `SalesReport_JWT_Signing` |
| Permitted users | Admin approved users are pre-authorized → permission set `SalesReport_User` |
| IP relaxation | Relax IP restrictions (callouts come from Salesforce IPs) |
| Session policy | Short session timeout (15 min); tokens are not stored (D-16) |
| Value sent back | Consumer key → `SalesReport_Settings__c.Eca_Consumer_Key__c` (consumer secret not needed, never sent) |

## 8. Other org components

| Component | Name | Value |
|---|---|---|
| Remote Site Setting | `SalesReport_LINE_API` | `https://api.line.me`, protocol security on, description "Sales Report: LINE ID token verification" |
| Remote Site Setting | `SalesReport_Org_Domain` | Org My Domain URL (org-specific; [VERIFY] whether needed, L3) |
| Certificate | `SalesReport_JWT_Signing` | Self-signed, 2048-bit, **not** exportable; renew before expiry (default 1 year) and re-upload to the ECA |
| Platform Cache partition | `SalesReportCache` | Org cache only, smallest allocation (~1 MB); session cache 0 (D-14, L7) |
| Scheduled job | "Sales Report cleanup" | `SalesReportLinkCleanupService`, daily, 02:00 Asia/Bangkok (L7) |
