# Data dictionary — LINE Sales Reporting

Field-level and configuration-level detail for every object, field, setting and access rule of this feature.
`FILE-INVENTORY.md` lists the files; this document says what is in them. Naming: D-07.
**State (2026-10-29): §1, §2 (except L7 fields), §3a Account search, §4, §5–§8 are built and deployed to sandbox `dev5`
(milestones L2–L4).** Log Activity is built (Task, D-11, D-31–D-35; L5a, L5b). Still open: Update Opportunity
fields (§3, §3a — BA: D-12, Q-O1), attachment limits (Q-A6a) and the L7
items (rate limit, retention, cache). Update this file in the same commit whenever a field or setting changes.

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
| `Line_User_Id__c` | LINE User ID | Text(64) | Yes (enforced in code) | Unique (case-sensitive), External ID | — | LINE user ID (`U` + 32 hex) taken from a **verified** ID token (`sub`). Never from request data. |
| `User__c` | Salesforce User | Lookup(User) | Yes | — | — | The rep who completed the one-time login. |
| `Status__c` | Status | Picklist (restricted): `Active`, `Unlinked` | Yes | — | `Active` | Only `Active` links authorise requests. |
| `Active_User_Key__c` | Active User Key | Text(18) | No | Unique | — | Set to `User__c` Id while Active, blank when Unlinked. Enforces **one active link per User** at database level. Not on layouts. |
| `Linked_At__c` | Linked At | Date/Time | Yes | — | — | When the link page completed. |
| `Unlinked_At__c` | Unlinked At | Date/Time | No | — | — | |
| `Unlink_Reason__c` | Unlink Reason | Picklist (restricted): `Admin`, `User deactivated`, `Relinked to another User`, `Replaced by new LINE account` | No | — | — | |
| `Line_Display_Name__c` | LINE Display Name | Text(255) | No | — | — | LINE display name at linking time (verified token), so admins can recognise the account. |
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
| `Line_User_Id__c` | LINE User ID | Text(64) | Yes (enforced in code) | — | — | From the verified ID token of the `/link/start` request. |
| `Expires_At__c` | Expires At | Date/Time | Yes | — | — | Created + `Link_Code_Ttl_Minutes__c` (default 5). |
| `Used_At__c` | Used At | Date/Time | No | — | — | Set once; a used code is rejected. |
| `Used_By__c` | Used By | Lookup(User) | No | — | — | User who consumed the code on the link page. |
| `Line_Display_Name__c` | LINE Display Name | Text(255) | No | — | — | Shown on the confirm page so the rep can check it is their own LINE account. |

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

| Field | Label | Type | Default in code | Milestone | Description |
|---|---|---|---|---|---|
| `Line_Login_Channel_Id__c` | LINE Login Channel ID | Text(20) | — (required) | L2 | `client_id` for ID-token verify; also the expected `aud`. |
| `Liff_Id__c` | LIFF ID | Text(40) | — (required) | L2 | Passed to the LIFF page for `liff.init`. |
| `Eca_Consumer_Key__c` | ECA Consumer Key | Text(255) | — (required for Option B) | L3 | `iss` of the JWT. Not a secret. |
| `Jwt_Certificate_Name__c` | JWT Certificate Name | Text(64) | `SalesReport_JWT_Signing` | L3 | Unique name of the signing certificate. |
| `Link_Code_Ttl_Minutes__c` | Link Code TTL (min) | Number(3,0) | 5 | L3 | |
| `Account_Search_Min_Chars__c` | Account Search Min Chars | Number(2,0) | 2 | L4 | |
| `Account_Search_Max_Results__c` | Account Search Max Results | Number(3,0) | 10 | L4 | Capped at 50 in code. |
| `Attachment_Max_Files__c` | Attachment Max Files | Number(2,0) | 5 | L5b | Files per activity; capped at 10 in code. |
| `Attachment_Max_Size_Mb__c` | Attachment Max Size MB | Number(1,0) | 4 | L5b | Per file, after photos are shrunk; 4 is also the hard cap (Apex heap, D-34). |
| `Attachment_File_Types__c` | Attachment File Types | Text(255) | jpg,jpeg,png,pdf | L5b | Comma-separated extensions. Photos become .jpg on the phone, so keep jpg in the list. |
| `Rate_Limit_Per_Minute__c` | Rate Limit per Minute | Number(4,0) | 60 | L7 (not built yet) | Per LINE user. |
| `Log_Level__c` | Log Level | Text(10) | `WARN` | L2 | `ERROR`/`WARN`/`INFO`/`DEBUG`. |
| `Log_Retention_Days__c` | Log Retention (days) | Number(3,0) | 30 | L7 (not built yet) | |
| `Enabled__c` | Enabled | Checkbox | true | L2 | Kill switch: when false all endpoints return "temporarily unavailable". |

## 3. Standard object fields used (no changes to standard objects)

Read and written **as the rep** (Option B), so the rep's own profile/permission sets must grant this access — this
feature does not grant standard-object access.

| Object | Field | Read | Write | Notes |
|---|---|---|---|---|
| User | `Id`, `Name`, `Username`, `IsActive` | ✓ (system) | — | `Username` = JWT `sub`; `IsActive` checked before exchange. |
| Account | `Id`, `Name` + text fields in field set `SalesReport_Account_Search` | ✓ | — | Built in L4 (D-29); which extra fields: BA Q-C1. |
| Opportunity | `Id`, `Name`, `AccountId`, `OwnerId`, `IsClosed` | ✓ | — | List filter: `AccountId = :id AND IsClosed = false`. |
| Opportunity | `StageName` | ✓ | ✓ | Open stages only (`01.`–`03.`) in this phase. |
| Opportunity | `Your_Win_Confidence__c` | ✓ | ✓ | Field-level required picklist. |
| Opportunity | `CloseDate` | ✓ | ✓ | |
| Opportunity | `Amount` (label "Target TCV") | ✓ | ✓ | |
| Opportunity | `NextStep` **or** `Next_Step_Custom__c` | ✓ | ✓ | D-12 open. |
| Opportunity | `Next_Step_Due_Date__c` | ✓ | ✓ | |
| Opportunity | `PreSales_Engineer__c` | ✓ | (BA) | Needed by active VR for Stage ≥ 02. |
| Task (D-11) | `WhatId` (Account only, D-33), `Subject` (built), `Type`, `ActivityPurpose__c`, `ActivityDate`, `Status` (from date, D-32), `Priority` (layout default), `Description` | — | ✓ | `OwnerId` = the rep. Required flags follow Salesforce (D-31). |
| ContentVersion (D-34) | `Title`, `PathOnClient`, `VersionData`, `FirstPublishLocationId` (= Task) | — | ✓ | Attachments, uploaded as the rep (L5b). |

## 3a. Field sets (D-21, D-29)

| Field set | Object | Purpose | Repo members |
|---|---|---|---|
| `SalesReport_Account_Search` | Account | Extra text fields searched by the Account picker; first non-empty one shown under the name | Name only (admins add e.g. `Account_Name_TH__c`, `Account_No__c`) |

Planned for L5 — the forms and the server-side whitelist read these by describe, so no org-specific field is referenced
in code. Activity form decided 2026-10-30; Opportunity form waits on the BA (D-12, Q-O1). The "Required in set" column
is only an extra: a field is also required when the rep's layout or the database requires it (D-31).

| Field set | Object | Initial members (BA to confirm) | Required in set |
|---|---|---|---|
| `SalesReport_Opportunity_Form` | Opportunity | `StageName`, `Your_Win_Confidence__c`, `CloseDate`, `Amount`, `NextStep` or `Next_Step_Custom__c` (D-12), `Next_Step_Due_Date__c` | `StageName`, `CloseDate`, `Your_Win_Confidence__c` |
| `SalesReport_Activity_Form` | Task (D-11) | `Type`, `ActivityDate`, `Description` (built, L5a). Admins may add `ActivityPurpose__c` in Setup (org field, kept out of the repo, P3) | none (follow the layout, D-31) |

Always set by code, never from the field set: `WhatId` (selected Account), `OwnerId` (the rep, implicit), Opportunity `Id`;
for Tasks also `Subject`, `Priority` and (unless `Status` is in the field set) `Status` (D-31, D-32).

## 4. Custom Labels (`SalesReport_*`)

Category `SalesReport`. English only so far; JA / TH translations in L6 (BA Q-S3). The LIFF page gets them through
`SalesReportLiffPageController` (no text hardcoded in JS, P11); the link page uses `$Label` directly.

| Label | English value | Used on | Milestone |
|---|---|---|---|
| `SalesReport_Menu_Title` | Sales Report | LIFF | L2 |
| `SalesReport_Activity_Title` | Log activity | LIFF | L2 |
| `SalesReport_Opportunity_Title` | Update opportunity | LIFF | L2 |
| `SalesReport_Hello` | Hello, {0} | LIFF | L2 |
| `SalesReport_Loading` | Loading… | LIFF | L2 |
| `SalesReport_Coming_Soon` | This form is coming soon. | LIFF (until L5) | L2 |
| `SalesReport_Close` | Close | LIFF | L2 |
| `SalesReport_Open_In_Line` | Please open this page from the Sales Reporting menu in LINE. | LIFF | L2 |
| `SalesReport_Error_Generic` | Something went wrong. Please try again. | LIFF | L2 |
| `SalesReport_Error_Session_Expired` | Your session expired. Reopening… | LIFF | L2 |
| `SalesReport_Error_Unavailable` | The service is temporarily unavailable. | LIFF | L2 |
| `SalesReport_Connect_Title` | Connect Salesforce | LIFF | L3 |
| `SalesReport_Connect_Body` | To use Sales Report, log in to Salesforce once. After that you will not need to log in again. | LIFF | L3 |
| `SalesReport_Connect_Button` | Log in to Salesforce | LIFF | L3 |
| `SalesReport_Connect_Waiting` | Finish logging in to Salesforce in your browser, then come back here. | LIFF | L3 |
| `SalesReport_Connect_Check` | I've finished | LIFF | L3 |
| `SalesReport_Linked_As` | Salesforce: {0} | LIFF | L3 |
| `SalesReport_Error_Not_Authorized` | Your Salesforce user is not set up for Sales Report. Please ask your administrator. | LIFF, link page | L3 |
| `SalesReport_Link_Title` | Connect LINE to Salesforce | Link page | L3 |
| `SalesReport_Link_Confirm_Body` | Connect the LINE account "{0}" to your Salesforce user {1}? | Link page | L3 |
| `SalesReport_Link_Confirm_Note` | Only continue if you opened this page yourself from the Sales Report menu in LINE. | Link page | L3 |
| `SalesReport_Link_Confirm_Button` | Connect | Link page | L3 |
| `SalesReport_Link_Done` | Done. Your LINE account is connected. You can go back to LINE. | Link page | L3 |
| `SalesReport_Link_Return` | Open Sales Report in LINE | Link page | L3 |
| `SalesReport_Link_Invalid` | This link has expired or was already used. Open the form in LINE and try again. | Link page | L3 |
| `SalesReport_Account_Label` | Account | LIFF | L4 |
| `SalesReport_Account_Search_Placeholder` | Type at least {0} characters | LIFF | L4 |
| `SalesReport_Searching` | Searching… | LIFF | L4 |
| `SalesReport_No_Results` | No matching accounts | LIFF | L4 |
| `SalesReport_Change` | Change | LIFF | L4 |
| `SalesReport_Activity_Subject` | {0} – {1} | Task Subject (Apex): {0} = Type label or "Task", {1} = Account name | L5a |
| `SalesReport_Save` | Save | LIFF | L5a |
| `SalesReport_Saving` | Saving… | LIFF | L5a |
| `SalesReport_Activity_Saved` | Activity saved: {0} | LIFF ({0} = Task subject) | L5a |
| `SalesReport_Log_Another` | Log another activity | LIFF | L5a |
| `SalesReport_Required` | Required | LIFF | L5a |
| `SalesReport_Check_Fields` | Please check the highlighted fields. | LIFF | L5a |
| `SalesReport_Select_Placeholder` | — Select — | LIFF | L5a |
| `SalesReport_Choose_Account` | Choose an Account first. | LIFF | L5a |
| `SalesReport_Attachments_Label` | Photos and files | LIFF | L5b |
| `SalesReport_Add_File` | Add photo or file | LIFF | L5b |
| `SalesReport_Remove_File` | Remove | LIFF | L5b |
| `SalesReport_File_Too_Large` | {0} is larger than {1} MB. | LIFF | L5b |
| `SalesReport_File_Type_Not_Allowed` | {0}: this file type can’t be attached. | LIFF | L5b |
| `SalesReport_Max_Files` | You can attach up to {0} files. | LIFF | L5b |
| `SalesReport_Uploading` | Uploading {0} of {1}… | LIFF (Save button) | L5b |
| `SalesReport_Upload_Failed` | The activity was saved, but {0} file(s) could not be attached. | LIFF | L5b |
| `SalesReport_Retry` | Try again | LIFF | L5b |

Planned: Update Opportunity texts (L5c), rate-limit message (L7). Note: the Subject label is
read in the Site guest user's language (en_US), not the rep's.

Validation-rule messages from the org are shown as returned (they are already in the org's language).

## 5. Access

### 5.1 Permission set `SalesReport_User` (assign to every rep) — D-19 decided

| Area | Grant |
|---|---|
| Visualforce pages | `SalesReport_Link` |
| Apex classes | `SalesReportLinkPageController` |
| Custom permission | `SalesReport_Access` (checked by the link page) |
| Custom objects | **none** (links/codes are written by the service, so reps can't tamper with mappings) |
| External Client App | `SalesReport_App` pre-authorised via this permission set (§7) |
| Standard objects | none — reps' existing profile access applies (§3) |

### 5.2 Permission set `SalesReport_Admin`

| Area | Grant |
|---|---|
| `SalesReport_Line_Link__c` | Read, Edit, Delete, View All. Unlink = set `Status__c` to Unlinked (or delete); all other fields read-only via FLS |
| `SalesReport_Link_Code__c` | Read, Edit (required by Salesforce for Delete), Delete, View All; fields read-only |
| `SalesReport_Log__c` | Read, Edit, Delete, View All (Edit is required by Salesforce for Delete; all log fields are read-only via FLS) |
| Tabs | `SalesReport_Line_Link__c`, `SalesReport_Log__c` visible |
| Apex | none (unlink = set Status to Unlinked in the tab; no extra action needed) |

### 5.3 `without sharing` justifications

Observed in this org (API 68.0): Apex SOQL/DML on fields the running user has no field-level access to failed
("No such column") unless run explicitly in system mode. Services that must work for the Site guest therefore use
`AccessLevel.SYSTEM_MODE` / `WITH SYSTEM_MODE` explicitly, not only `without sharing` (D-25).

Justifications (repeated in class headers):

| Class | Why |
|---|---|
| `SalesReportLinkService` | Creates link codes and reads the active link from the guest context (only for a **verified** LINE user ID), consumes codes and writes links on behalf of the logged-in rep (`UserInfo.getUserId()`), ends links of deactivated users. Reps and the guest get no object access, so mappings can't be edited by hand. |
| `SalesReportLogService` | Logs must be written whoever the running user is. |

All other classes: `with sharing`; queries/DML on business data happen through the org REST API as the rep. (`SalesReportSessionCalloutService` reads `Organization.IsSandbox` with `WITH SYSTEM_MODE` — no business data.)

### 5.4 Site guest profile (`SalesReport_Site`, [HUMAN])

| Area | Grant |
|---|---|
| Apex classes | `SalesReportMeController` (L2), `SalesReportLinkController` (L3), `SalesReportAccountController` (L4), `SalesReportActivityController` (L5a), `SalesReportActivityFileController` (L5b); later `SalesReportOpportunityController` (L5c). Page controllers need no class access. |
| Visualforce pages | `SalesReport_Liff` (+ Salesforce's default Site pages, harmless) |
| Objects | **none** (checked by query 2026-10-29) |
| Other | Leave all "View …"/API permissions off |

## 6. Salesforce Site `SalesReport_Site` ([HUMAN], L2 — created and checked 2026-10-29)

| Setting | Value |
|---|---|
| Site label / name | Sales Report / `SalesReport_Site` |
| Default web address | `https://<sites domain>/salesreport` |
| Active site home page | `SalesReport_Liff` |
| Site contact | Admin user |
| Default record owner | An active admin user (owns guest-created `SalesReport_Link_Code__c` and `SalesReport_Log__c` records) |
| Require secure connections (HTTPS) | On |
| Upgrade insecure requests | On |
| Clickjack protection | "Allow framing by the same origin only" (LIFF does not frame the page) |
| Guest access to Salesforce APIs | Off (Apex REST through the Site does not need it; `/services/data` as guest → 401, checked) |
| Lightning features for guest | Off |
| Redirect to custom domain | Off (the LIFF endpoint uses the `salesforce-sites.com` URL) |
| Cache public Visualforce pages | Off for `SalesReport_Liff` (LIFF ID is injected) |

## 7. External Client App `SalesReport_App` ([HUMAN], L3 — created and checked 2026-10-29)

| Setting | Value |
|---|---|
| Distribution | Local |
| OAuth | Enabled; callback URL `https://login.salesforce.com/services/oauth2/success` (unused by the JWT flow, but required) |
| OAuth scopes | `api`, `id` (for `/services/oauth2/userinfo`) and `refresh_token` (required by Salesforce for the JWT bearer flow; no refresh token is issued) |
| Flow enablement | **JWT Bearer Flow** on; certificate = public cert of `SalesReport_JWT_Signing` |
| Permitted users | Admin approved users are pre-authorized → permission set `SalesReport_User` |
| IP relaxation | Relax IP restrictions (callouts come from Salesforce IPs) |
| Session / refresh-token policy | Defaults kept; tokens are never stored (D-16), so they don't matter here |
| Value sent back | Consumer key → `SalesReport_Settings__c.Eca_Consumer_Key__c` (consumer secret not needed, never sent) |

## 8. Other org components

| Component | Name | Value |
|---|---|---|
| Remote Site Setting | `SalesReport_LINE_API` | `https://api.line.me`, protocol security on, description "Sales Report: LINE ID token verification" |
| Remote Site Setting | ~~`SalesReport_Org_Domain`~~ | Not needed: callouts to the org's own My Domain work without one (tested 2026-10-29) |
| Certificate | `SalesReport_JWT_Signing` | Self-signed, 2048-bit, **not** exportable; expires **2027-10-29** — renew before then and re-upload to the ECA |
| Platform Cache partition | `SalesReportCache` | Org cache only, smallest allocation (~1 MB); session cache 0 (D-14, L7 — not built yet) |
| Scheduled job | "Sales Report cleanup" | `SalesReportLinkCleanupService`, daily, 02:00 Asia/Bangkok (L7 — not built yet) |
