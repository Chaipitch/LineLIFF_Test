# Data dictionary — LINE Sales Reporting

Field-level and configuration-level detail for every object, field, setting and access rule of this feature.
`FILE-INVENTORY.md` lists the files; this document says what is in them. Naming: D-07.
**State (2026-11-03): everything below is built and deployed to sandbox `dev5`** (L2–L5c, L7, link rules D-44/D-45). Update Opportunity (L5c)
has the BA's fields (D-46) and is **always on** since 2026-11-04 (switch removed, D-49). Attachments (L5b) are switched off (`Attachments_Enabled__c`).
Update this file in the same commit whenever a field or setting changes.

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
| Who writes | `SalesReportLinkService` (system mode, see §5.3) and admins (**Revoke** button); trigger `SalesReportLineLinkTrigger` keeps the keys and audit fields (D-44) — reps have **no** object access |
| Who reads | Site requests via `SalesReportIdentityService` (system mode); admins via `SalesReport_Admin` |
| Field history | On: `User__c`, `Status__c` |
| Records | **One per link** (D-44): every successful link inserts a new record; ended records are kept unchanged as history. Ended links can't be made Active again, and `Line_User_Id__c` / `User__c` can't be changed after insert (trigger) |
| Layout / action | Layout *Sales Report LINE Link Layout* (in the repo) with quick action **Revoke** (`SalesReport_Line_Link__c.Revoke`, Update type: Status = Revoked, Unlink Reason = Revoked by admin, reason editable in the dialog) |

| Field | Label | Type | Req | Unique / Ext ID | Default | Description / Help |
|---|---|---|---|---|---|---|
| `Name` | Link No. | Auto Number | — | — | `LL-{000000}` | |
| `Line_User_Id__c` | LINE User ID | Text(64) | Yes (enforced in code) | External ID (**not unique** since D-44) | — | LINE user ID (`U` + 32 hex) taken from a **verified** ID token (`sub`). Never from request data. |
| `User__c` | Salesforce User | Lookup(User) | Yes | — | — | The rep who completed the one-time login. |
| `Status__c` | Status | Picklist (restricted): `Active`, `Unlinked`, `Revoked` | Yes | — | `Active` | Only `Active` links authorise requests. **Revoked** = ended by an admin (Revoke button); **Unlinked** = ended automatically (user deactivated) — BA to confirm (D-44). |
| `Active_User_Key__c` | Active User Key | Text(18) | No | Unique (case-sensitive) | — | `User__c` Id while Active, blank once ended; set by the trigger. Enforces **one active link per User** at database level. Read-only on the layout. |
| `Active_Line_Key__c` | Active LINE Key | Text(64) | No | Unique (case-sensitive) | — | `Line_User_Id__c` while Active, blank once ended; set by the trigger. Enforces **one active link per LINE account** (D-44). Read-only on the layout. |
| `Linked_At__c` | Linked At | Date/Time | Yes | — | — | When the link page completed. |
| `Unlinked_At__c` | Unlinked At | Date/Time | No | — | — | Filled by the trigger when a link ends. |
| `Unlink_Reason__c` | Unlink Reason | Picklist (restricted): `Revoked by admin`, `Admin`, `User deactivated`, `Relinked to another User`, `Replaced by new LINE account` | No | — | — | Default when ending: Revoked → `Revoked by admin`, Unlinked by hand → `Admin`. The last two values are only on links ended before D-44 ("latest wins"). |
| `Line_Display_Name__c` | LINE Display Name | Text(255) | No | — | — | LINE display name at linking time (verified token), so admins can recognise the account. |
| `Unlinked_By__c` | Unlinked By | Lookup(User) | No | — | — | Admin who ended the link (filled by the trigger); blank for automatic unlinks by the Site guest. |

### 1.2 `SalesReport_Link_Code__c` — one-time link codes

| Property | Value |
|---|---|
| Label / plural | Sales Report Link Code / Sales Report Link Codes |
| Record name | Auto Number `LC-{000000}` |
| Sharing (OWD) | Private |
| Who writes | `SalesReportLinkService` (create from Site request, consume from link page) — system mode |
| Owner | Created in a Site (guest) context → owned by the Site's **default record owner** (§6, [HUMAN]) |
| Retention | Deleted (and purged from the Recycle Bin) by the nightly `SalesReportCleanupService` 24 h after expiry (L7) |

| Field | Label | Type | Req | Unique / Ext ID | Default | Description / Help |
|---|---|---|---|---|---|---|
| `Name` | Code No. | Auto Number | — | — | `LC-{000000}` | |
| `Code_Hash__c` | Code Hash | Text(64) | Yes | Unique (case-sensitive) | — | SHA-256 hex of the one-time code. The code itself is never stored. |
| `Line_User_Id__c` | LINE User ID | Text(64) | Yes (enforced in code) | — | — | From the verified ID token of the `/link/start` request. |
| `Expires_At__c` | Expires At | Date/Time | Yes | — | — | Created + 5 minutes (fixed, D-48). |
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

Retention: deleted after `Log_Retention_Days__c` days (default 30) by the nightly `SalesReportCleanupService` (L7).

### 1.4 `SalesReport_Rate_Limit__c` — request counter for the rate limit (L7, D-36)

One row per LINE user who used the feature; holds only the current minute's count. Written only by
`SalesReportRateLimitService` (system mode, at the end of each request); rows older than a day are deleted by
`SalesReportCleanupService`. No tab; admins can read it through `SalesReport_Admin`.

| Field | Label | Type | Req | Unique / Ext ID | Description |
|---|---|---|---|---|---|
| `Name` | Counter No. | Auto Number `RL-{000000}` | — | — | |
| `Key__c` | Key | Text(64) | Yes (in code) | Unique (case-sensitive), Ext ID | SHA-256 hex of the LINE user ID — the ID itself is not stored. |
| `Window_Start__c` | Window Start | Date/Time | Yes (in code) | — | Start of the counted minute (GMT, seconds cut off). |
| `Request_Count__c` | Request Count | Number(6,0) | Yes (in code) | — | Requests in that minute. A new minute starts again at 1. |

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
| `Attachments_Enabled__c` | Attachments Enabled | Checkbox | false | L5b | Off (2026-11-02): attachment section hidden in LINE and uploads refused (403). Tick to switch on. |
| `Log_Level__c` | Log Level | Text(10) | `WARN` | L2 | `ERROR`/`WARN`/`INFO`/`DEBUG`. |
| `Log_Retention_Days__c` | Log Retention (days) | Number(3,0) | 30 | L7 | Used by the nightly cleanup; capped at 365. |

Update Opportunity has no switch: it is always on (D-49). Fixed values (D-48): link code 5 min; search from 2 characters, 10 Accounts; attachments 5 files × 4 MB, jpg/jpeg/png/pdf; 60 requests per LINE user per minute; all active open stages. Changing one is a code change in `SalesReportSettingsService`. There is no kill switch any more: to stop the feature for everyone, deactivate the Site `SalesReport_Site`.

## 3. Standard object fields used (no changes to standard objects)

Read and written **as the rep** (Option B), so the rep's own profile/permission sets must grant this access — this
feature does not grant standard-object access.

| Object | Field | Read | Write | Notes |
|---|---|---|---|---|
| User | `Id`, `Name`, `Username`, `IsActive`, `TimeZoneSidKey` | ✓ (system) | — | `Username` = JWT `sub`; `IsActive` checked before exchange; time zone gives the rep's "today" (D-32). |
| Account | `Id`, `Name` + text fields in field set `SalesReport_Account_Search` | ✓ | — | Built in L4 (D-29); which extra fields: BA Q-C1. |
| Opportunity | `Id`, `Name`, `AccountId`, `Owner.Name`, `IsClosed`, `CloseDate` | ✓ | — | List filter: `AccountId = :id AND IsClosed = false` (L5c). Update only when open and on the chosen Account. |
| Opportunity | `StageName` | ✓ | ✓ | Active open stages (`01.`–`03.` in `dev5`) + the current one (D-39). |
| OpportunityStage | `ApiName`, `IsActive`, `IsClosed` | ✓ (system) | — | Which stages are open (setup data, read in system mode). |
| Opportunity | `Your_Win_Confidence__c` | ✓ | ✓ | Field-level required picklist. |
| Opportunity | `CloseDate` | ✓ | ✓ | |
| Opportunity | `Amount` (label "Target TCV") | ✓ | ✓ | |
| Opportunity | `NextStep` (default) **or** `Next_Step_Custom__c` | ✓ | ✓ | D-12: standard `NextStep` in the field set until the BA decides. |
| Opportunity | `Next_Step_Due_Date__c` | ✓ | ✓ | |
| Opportunity | `PreSales_Engineer__c` | ✓ | (BA) | Needed by active VR for Stage ≥ 02. |
| Task (D-11) | `WhatId` (Account only, D-33), `Subject` (built), `Type`, `ActivityPurpose__c` (only if an admin adds it to the field set), `ActivityDate`, `Status` (from date, D-32), `Priority` (layout default), `Description` | — | ✓ | `OwnerId` = the rep. Required flags follow Salesforce (D-31). |
| ContentVersion (D-34) | `Title`, `PathOnClient`, `VersionData`, `FirstPublishLocationId` (= Task) | — | ✓ | Attachments, uploaded as the rep (L5b; switched off for now). |
| Task / ContentDocumentLink | `Id`, `CreatedById`, `CreatedDate` / `LinkedEntityId` | ✓ | — | Upload checks: the rep's own Task within 60 min; file count per Task. |

## 3a. Field sets (D-21, D-29)

| Field set | Object | Purpose | Repo members |
|---|---|---|---|
| `SalesReport_Account_Search` | Account | Extra text fields searched by the Account picker; first non-empty one shown under the name | Name only (admins add e.g. `Account_Name_TH__c`, `Account_No__c`) |

Form field sets — the forms and the server-side whitelist read these by describe, so no org-specific field is referenced
in code. Activity form built 2026-10-30 (L5a); Opportunity form built 2026-11-02 with the proposed defaults (L5c, D-39). The "Required in set" column
is only an extra: a field is also required when the rep's layout or the database requires it (D-31).

| Field set | Object | Initial members (BA to confirm) | Required in set |
|---|---|---|---|
| `SalesReport_Opportunity_Form` | Opportunity | BA's list (2026-11-03, D-46): `StageName`, `Amount`, `PreSales_Engineer__c` (User lookup → search box of active Users), `Next_Step_Custom__c`, `Next_Step_Due_Date__c`. Org fields, so this field set is a P3 exception for TerraSky Thailand orgs. Account and Opportunity are chosen above the fields, not in the set | none (follow the edit layout, D-31) |
| `SalesReport_Activity_Form` | Task (D-11) | `Type`, `ActivityDate`, `Description` (built, L5a). Admins may add `ActivityPurpose__c` in Setup (org field, kept out of the repo, P3) | none (follow the layout, D-31) |

Always set by code, never from the field set: `WhatId` (selected Account), `OwnerId` (the rep, implicit), Opportunity `Id`;
for Tasks also `Subject`, `Priority` and (unless `Status` is in the field set) `Status` (D-31, D-32).

## 4. Custom Labels (`SalesReport_*`)

Category `SalesReport`. **English only** (D-47, Q-S3) — no translations; admins can change any wording in Setup → Custom Labels without a deploy. The LIFF page gets them through
`SalesReportLiffPageController` (no text hardcoded in JS, P11); the link page uses `$Label` directly.

| Label | English value | Used on | Milestone |
|---|---|---|---|
| `SalesReport_Menu_Title` | Sales Report | LIFF — title of the form menu shown when opened without `?form=` | L2 |
| `SalesReport_Activity_Title` | Log activity | LIFF | L2 |
| `SalesReport_Opportunity_Title` | Update opportunity | LIFF | L2 |
| `SalesReport_Hello` | Hello, {0} | LIFF | L2 |
| `SalesReport_Loading` | Loading… | LIFF | L2 |
| `SalesReport_Close` | Close | LIFF | L2 |
| `SalesReport_Open_In_Line` | Please open this page from the Sales Reporting menu in LINE. | LIFF | L2 |
| `SalesReport_Error_Generic` | Something went wrong. Please try again. | LIFF | L2 |
| `SalesReport_Error_Session_Expired` | Your session expired. Reopening… | LIFF | L2 |
| `SalesReport_Error_Unavailable` | The service is temporarily unavailable. | LIFF | L2 |
| `SalesReport_Connect_Title` | Connect Salesforce | LIFF — while the rep logs in in the phone's browser (D-42) | L3 |
| `SalesReport_Connect_Body` | To use Sales Report, log in to Salesforce once in your phone’s browser. You will come back to LINE afterwards, and you will not need to log in again. | LIFF (D-42) | L3 |
| `SalesReport_Connect_Button` | Log in to Salesforce | LIFF — (re)opens the login in the phone's browser (D-42) | L3 |
| `SalesReport_Connect_Waiting` | Finish logging in to Salesforce in your browser, then come back here. | LIFF — shown after the browser login opened (D-42) | L3 |
| `SalesReport_Linked_As` | Salesforce: {0} | LIFF | L3 |
| `SalesReport_Error_Not_Authorized` | Your Salesforce user is not set up for Sales Report. Please ask your administrator. | LIFF, link page | L3 |
| `SalesReport_Link_Title` | Connect LINE to Salesforce | Link page | L3 |
| `SalesReport_Link_Confirm_Body` | Connect the LINE account "{0}" to your Salesforce user {1}? | Link page | L3 |
| `SalesReport_Link_Confirm_Note` | Only continue if you opened this page yourself from the Sales Report menu in LINE. | Link page | L3 |
| `SalesReport_Link_Confirm_Button` | Connect | Link page | L3 |
| `SalesReport_Link_Done` | Done. Your LINE account is connected. You can go back to LINE. | Link page | L3 |
| `SalesReport_Link_Return` | Open Sales Report in LINE | Link page — only if no LIFF ID is set; normally Connect redirects straight to the form (D-40) | L3 |
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
| `SalesReport_Error_Rate_Limited` | Too many requests. Please wait a minute and try again. | LIFF | L7 |
| `SalesReport_Opportunity_Label` | Opportunity | LIFF | L5c |
| `SalesReport_No_Open_Opportunities` | No open opportunities for this account. | LIFF | L5c |
| `SalesReport_Choose_Opportunity` | Choose an opportunity first. | LIFF | L5c |
| `SalesReport_Opportunity_Saved` | Opportunity updated: {0} | LIFF ({0} = Opportunity name) | L5c |
| `SalesReport_Update_Another` | Update another opportunity | LIFF | L5c |
| `SalesReport_Save_Failed` | Salesforce couldn’t save your changes: | LIFF — first line above Salesforce's own save error | L5c |
| `SalesReport_Rule_Error` | A Salesforce rule couldn’t run, so nothing was saved. Please send this message to your administrator: | LIFF — when a validation-rule formula itself fails ("Validation Formula … Invalid") | L5c |
| `SalesReport_Error_No_Access` | Your Salesforce user can’t open this data. Please ask your administrator. | LIFF (`NO_ACCESS`) | L5c |
| `SalesReport_No_Matches` | No matches | LIFF — lookup search (e.g. Main PreSales Engineer) found nothing | D-46 |
| `SalesReport_Error_Offline` | Can’t reach Salesforce. Check your internet connection and try again. | LIFF — no connection or timeout (L6) | L6 |
| `SalesReport_Error_Reference` | Reference: {0} | LIFF and link page — under unexpected errors, {0} = request ID (D-45) | D-45 |
| `SalesReport_Link_Already_Linked` | This Salesforce user is already linked to another LINE account. Please contact your administrator to revoke the existing link before linking a new account. | Link page (`ALREADY_LINKED`) | D-44 |
| `SalesReport_Link_Line_In_Use` | This LINE account is already linked to another Salesforce user. Please contact your administrator to revoke that link first. | Link page (`LINE_IN_USE`) | D-44 |
| `SalesReport_Link_Already_Ended` | This link has already ended and its status can't be changed. The rep links again from LINE, which creates a new link. | Record error (trigger) | D-44 |
| `SalesReport_Link_Identity_Locked` | The LINE user and Salesforce user of a link can't be changed. Revoke the link; the rep then links again from LINE. | Record error (trigger) | D-44 |

Note: the Subject label is
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
| `SalesReport_Line_Link__c` | Read, Edit, Delete, View All. Disconnect = **Revoke** button (or delete test data); `Unlink_Reason__c` editable, all other fields read-only via FLS (`Status__c` is required, so editable, but the trigger refuses changes to an ended link) |
| `SalesReport_Link_Code__c` | Read, Edit (required by Salesforce for Delete), Delete, View All; fields read-only |
| `SalesReport_Log__c` | Read, Edit, Delete, View All (Edit is required by Salesforce for Delete; all log fields are read-only via FLS) |
| `SalesReport_Rate_Limit__c` | Read, Edit (required for Delete), Delete, View All; fields read-only. No tab (L7) |
| Tabs | `SalesReport_Line_Link__c`, `SalesReport_Log__c` visible |
| Apex | none (Revoke is a quick action; the trigger runs in system context) |

### 5.3 `without sharing` justifications

Observed in this org (API 68.0): Apex SOQL/DML on fields the running user has no field-level access to failed
("No such column") unless run explicitly in system mode. Services that must work for the Site guest therefore use
`AccessLevel.SYSTEM_MODE` / `WITH SYSTEM_MODE` explicitly, not only `without sharing` (D-25).

Justifications (repeated in class headers):

| Class | Why |
|---|---|
| `SalesReportLinkService` | Creates link codes and reads the active link from the guest context (only for a **verified** LINE user ID), consumes codes and writes links on behalf of the logged-in rep (`UserInfo.getUserId()`), ends links of deactivated users. Reps and the guest get no object access, so mappings can't be edited by hand. |
| `SalesReportLogService` | Logs must be written whoever the running user is. |
| — | `SalesReportLineLinkTriggerHandler` is `with sharing`: it only sets fields on the records being saved, no queries. |
| `SalesReportRateLimitService` | Reads and writes the per-LINE-user counter for the Site guest (only after the LINE token is verified); stores only a hash of the LINE user ID. |
| `SalesReportCleanupService` | Deletes expired link codes, old logs and old counters owned by the guest / default record owner, whoever schedules the job. |

All other classes: `with sharing`; queries/DML on business data happen through the org REST API as the rep. (`SalesReportSessionCalloutService` reads `Organization.IsSandbox` with `WITH SYSTEM_MODE` — no business data.)

### 5.4 Site guest profile (`SalesReport_Site`, [HUMAN])

| Area | Grant |
|---|---|
| Apex classes | `SalesReportConnectionController` (L2), `SalesReportLinkController` (L3), `SalesReportAccountController` (L4), `SalesReportActivityController` (L5a), `SalesReportActivityFileController` (L5b), `SalesReportOpportunityController` (L5c). Page controllers need no class access. |
| Visualforce pages | `SalesReport_Liff` (+ Salesforce's default Site pages: error pages, `SiteLogin`, `SiteRegister`, `ForgotPassword` … — optional tidy-up: remove the login/register/password pages, the Site has no login) |
| Objects | **none** (audit 2026-10-30: 0 object permissions; the 440 field-permission rows are Salesforce defaults on standard/org objects — ineffective without object access, none on `SalesReport_*`) |
| Other | Leave all "View …"/API permissions off (audit 2026-10-30: API Enabled, View All Data, Modify All Data, View Setup, Run Reports all off; no permission sets assigned to the guest user) |

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
| Platform Cache partition | `SalesReportCache` | Deployed with 0 MB (no free org capacity, D-30). Not used: rate limiting uses `SalesReport_Rate_Limit__c` instead (D-36) |
| Scheduled job | "Sales Report cleanup" | `SalesReportCleanupService`, daily 02:00 in the scheduling user's time zone (Asia/Bangkok). Scheduled in `dev5` on 2026-10-30 with `scripts/apex/schedule-cleanup.apex` |
