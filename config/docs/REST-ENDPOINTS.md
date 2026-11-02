# REST endpoints — how each one works

How the Apex REST endpoints of LINE Sales Reporting handle a request, step by step. Contract summary (paths, request
and response shapes, error codes): `L0-SPEC.md` §4. Classes: `L0-SPEC.md` §5a. Decisions: `DECISIONS.md` (D-xx).
Last updated 2026-11-02 (L5c added).

Base URL (sandbox `dev5`):
`https://terraskyth--dev5.sandbox.my.salesforce-sites.com/salesreport/services/apexrest/salesreport/v1/…`

All six endpoints are `@RestResource` classes on the public Site `SalesReport_Site`, run as the Site guest user, and
follow the same pattern.

---

## The pipeline every request goes through

```
LIFF page ──(X-Line-Id-Token: <LINE ID token>)──▶ Controller
  1. identify()      checks: Enabled setting on, channel ID set, token present
                     → POST api.line.me/oauth2/v2.1/verify   (LINE: "who is this?")
                     → rate-limit check for that LINE user (60/min, D-36)
  2. [repSession()]  only for business-data endpoints:
                     LINE user → active SalesReport_Line_Link__c → rep's username
                     → JWT bearer exchange → short-lived access token for the rep (D-02, D-16)
  3. the endpoint's own work (as the rep, via the org REST API)
  4. ok(body) or fail(error) → JSON, Cache-Control: no-store
  5. finally finish() → write the rate-limit count + flush the log (after all callouts)
```

**Controllers stay thin.** Each one only calls a service and turns the result or error into JSON
(`SalesReportRestService`).

**Errors** always come back as `{ "error": { "code", "message", "fields"? } }`:

| Code | HTTP status | Meaning |
|---|---|---|
| `TOKEN_MISSING` / `TOKEN_INVALID` / `TOKEN_EXPIRED` | 401 | Missing, invalid or expired LINE token (the page reloads once to get a fresh token) |
| `NOT_LINKED` | 403 | This LINE account isn't connected; the page shows **Connect Salesforce** |
| `NOT_AUTHORIZED` | 403 | Not allowed (e.g. someone else's Task, attachments switched off) |
| `RATE_LIMITED` | 429 | Over the per-minute limit for this LINE user |
| `QUERY_TOO_SHORT` / `INVALID_INPUT` / `SAVE_FAILED` | 400 | Bad input or a Salesforce save error, usually with `fields` (field API name → message) |
| `NO_ACCESS` | 403 | The rep's Salesforce user can't read that object or field (e.g. Opportunity on a Platform licence) |
| `UNAVAILABLE` / `CONFIG_MISSING` | 503 | Switched off in settings, or settings incomplete |
| `LINE_ERROR` / `SESSION_ERROR` | 502 | LINE or the Salesforce API could not be reached or refused the session |
| `INTERNAL` | 500 | Unexpected error (logged in full, answered with a generic message) |

---

## 1. `GET /connection` — "who is this and are they connected?"

`SalesReportConnectionController` (was `/me` until 2026-11-02, D-38)

**When:** first call every time the form opens.

**Steps:**
1. Verify the LINE token, which gives the LINE user ID and display name.
2. Look up the active link for that LINE user. If the linked Salesforce user was deactivated, the link is ended here.
3. If linked: run the JWT exchange as the rep and call `/services/oauth2/userinfo` as them. This also proves the "act as
   the rep" setup works for this user.

**Returns:** `{ linked, lineDisplayName, salesforceUserName }`. The page then shows the form, or the Connect screen if
`linked` is false.

## 2. `POST /link/start` — start the one-time login

`SalesReportLinkController` → `SalesReportLinkService`

**When:** the rep taps **Log in to Salesforce**.

**Steps:**
1. Verify the LINE token.
2. Create a random 256-bit code. Only its SHA-256 hash is stored in `SalesReport_Link_Code__c`, with the LINE user ID,
   display name and a 5-minute expiry.
3. Build the URL `<My Domain>/apex/SalesReport_Link?code=…`.

**Returns:** `{ linkUrl }`. The app opens it in the phone's browser (D-15).

**Not a REST endpoint, but part of the same flow:** the Visualforce page `SalesReport_Link`, which requires a Salesforce
login and the custom permission `SalesReport_Access`. It shows the LINE name, and on **Connect** (a CSRF-protected POST)
checks the code (unused, not expired, matching hash), marks it used, and creates or updates the
`SalesReport_Line_Link__c` for the logged-in rep. The newest link wins (D-27, `BA-FAQ.md` §4).

## 3. `GET /accounts?q=…` — Account search

`SalesReportAccountController` → `SalesReportAccountService`

**When:** the rep types in the Account box (300 ms after they stop typing, at least 2 characters).

**Steps:**
1. Verify the token and get the rep's session (`NOT_LINKED` if not connected).
2. Run a SOQL `LIKE '%term%'` on Name and the text fields in field set `SalesReport_Account_Search`, through the REST API
   as the rep. Sharing therefore decides which Accounts appear. The search term is escaped first.
3. Rank names that start with the term first, and cap the list at 10 (settings).

**Returns:** `{ accounts: [{ id, name, detail }] }`. Terms that are too short get `QUERY_TOO_SHORT` (400).

## 4. `/activity` — Log Activity

`SalesReportActivityController` → `SalesReportActivityService`

### `GET /activity` — the form definition

1. Verify the token and get the rep's session.
2. Read the members of field set `SalesReport_Activity_Form` on Task.
3. Make three small UI API calls as the rep (D-35):
   - `object-info/Task` for labels, types, required-in-database and create access;
   - `layout/Task?mode=Create` for what's required on the rep's own page layout;
   - `picklist-values` for picklist options and defaults.
4. Drop fields the rep can't create. A field is marked required if the layout, the database or the field set says so
   (D-31).

**Returns:** `{ fields: [{ name, label, type, required, defaultValue, maxLength, options }] }`. The page builds the form
from this.

### `POST /activity` — create the Task

Body: `{ accountId, values: { Type, ActivityDate, Description } }`

1. Verify the token, get the rep's session, and load the same form definition.
2. Reject any field that isn't on the form. Check each value: picklist values must be in the list, dates must be valid,
   text within length, required fields filled. Problems come back as `INVALID_INPUT` with `fields`.
3. Query the Account as the rep, to prove they can see it and to get its name.
4. Build the Task:
   - `WhatId` = the Account (D-33); the owner is the rep by default.
   - Subject = "<Type label> – <Account name>".
   - Status: `Completed` if the date is today or earlier in the rep's time zone, otherwise `Open` (D-32).
   - Other fields the layout requires take their defaults, such as Priority = Normal.
5. `POST /sobjects/Task` as the rep. Validation-rule errors come back as `SAVE_FAILED` with the field they name.

**Returns:** `{ id, subject, status }`.

## 5. `POST /activity/files?taskId=…&name=…` — attach one file

`SalesReportActivityFileController` → `SalesReportActivityFileService` (D-34). **Currently switched off** (setting
*Attachments Enabled*).

**When:** after a Task is saved, once per photo or file. The body is the raw file bytes (`application/octet-stream`).

**Steps:**
1. Verify the token and get the rep's session.
2. Refuse with 403 if **Attachments Enabled** is off.
3. Check the file: the Task ID format, a clean file name, an allowed extension, size up to 4 MB, not empty.
4. As the rep, check the Task exists, was **created by this rep**, and was created **within the last 60 minutes**. Also
   check it has fewer than the maximum number of files (default 5).
5. `POST /sobjects/ContentVersion` as the rep with the file and `FirstPublishLocationId` = the Task, so it shows under the
   Task's Files.

**Returns:** `{ id, name, size }`.

## 6. `/opportunities` — Update Opportunity

`SalesReportOpportunityController` → `SalesReportOpportunityService` (D-39). One class for the whole form, so the guest
profile needs one grant. **Currently switched off** (setting *Update Opportunity Enabled*): every call answers 403
`NOT_AUTHORIZED` before any callout, and the LINE page shows "This form is coming soon".

### `GET /opportunities?accountId=…` — the Account's open Opportunities

1. Verify the token and get the rep's session.
2. Run `SELECT Id, Name, toLabel(StageName), CloseDate, Owner.Name FROM Opportunity WHERE AccountId = … AND IsClosed =
   false ORDER BY CloseDate LIMIT 50` **as the rep**, so only Opportunities they can see appear.

**Returns:** `{ opportunities: [{ id, name, stage, closeDate, ownerName }] }` (stage label in the rep's language).

### `GET /opportunities?id=…` — the update form

1. Verify the token and get the rep's session.
2. Build the form from field set `SalesReport_Opportunity_Form` with the same three UI API reads as Log Activity, but
   for **editing**: fields the rep can update, required flags from the rep's Opportunity *edit* layout (D-31).
3. Read the Opportunity as the rep with those fields; refuse it if it is closed or not visible.
4. Stage choices: active **open** stages (optionally narrowed by setting *Opportunity Stages*), plus the record's current
   stage even if that stage is no longer active, so an unchanged stage can still be saved.

**Returns:** `{ id, name, accountId, fields }` — each field's `defaultValue` is the current value.

### `POST /opportunities` — save

Body: `{ id, accountId, values: { StageName, Amount, NextStep, CloseDate } }`

1. Verify the token, get the rep's session.
2. Read the Opportunity as the rep: it must be open and belong to the chosen Account.
3. Check the values like Log Activity (only form fields, picklist values, types, required). Optional fields sent empty
   are **cleared** (set to null).
4. Update as the rep (`POST /sobjects/Opportunity/<id>?_HttpMethod=PATCH`, because Apex can't send PATCH). Validation-rule
   errors (e.g. Stage 02 without PreSales Engineer) come back as `SAVE_FAILED`.

**Returns:** `{ id, name, accountId }`.

A rep who can't read Opportunities at all (Platform licence, D-13) gets `NO_ACCESS` (403) and a plain message in LINE.

---

## Why it's built this way

- **The guest user never touches business data.** It only reads and writes our own objects (links, codes, logs,
  counters) in system mode. Accounts, Tasks and files are always read and written through the org REST API **as the
  rep**, so sharing, field security, validation rules and "Created By" are Salesforce's own (D-02, D-19, D-25).
- **The LINE user ID is never taken from the request body.** It always comes from LINE verifying the token.
- **Nothing is written to the database before a callout.** Salesforce forbids a callout after a write in the same
  request, which is why the rate-limit count and the log are written at the very end, in `finish()`.

## Adding a new endpoint (checklist)

1. Controller `SalesReport<Name>Controller` with `@RestResource(urlMapping='/salesreport/v1/<path>')`, `global with
   sharing`, a `SOURCE` constant, `try` → service → `SalesReportRestService.ok`, `catch` → `fail`, `finally` → `finish()`.
2. Logic in a `…Service`; HTTP only in `…CalloutService`; response shape in a `…Data` class (D-07).
3. Start with `identify()` (or `repSession()` for business data) so the token check and rate limit always apply.
4. Tests with `SalesReportHttpMock` routes; no real callouts.
5. **[HUMAN]** add the controller to the Site guest profile (Public Access Settings → Enabled Apex Class Access) —
   until then the endpoint answers 403 "no access to the Apex class".
6. Update `L0-SPEC.md` §4/§5a, `FILE-INVENTORY.md`, `DATA-DICTIONARY.md` §5.4 and this file.
