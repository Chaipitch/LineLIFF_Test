# Go-live checklist — LINE Sales Reporting (production)

Step-by-step list to move Sales Report from sandbox `dev5` to **production**. Each step says who does it
(**C** = Claude / developer, **H** = Salesforce admin, **L** = LINE OA admin, **BA**) and how to check it.
Details of each setting are in `SETUP-GUIDE.md` (Parts A–J); this list only adds the order and the production
differences. Created 2026-11-04.

Tick each box as you go. Values marked `<…>` go into `ENVIRONMENTS.md` → Production.

---

## 0. Decide before you start

- [ ] **BA** · Go-live date, UAT owner and sign-off (Q-S2, Q-T2).
- [ ] **BA / H** · Rep list and licences: Opportunities need a full Salesforce licence; Platform-licence reps can only
      log activities (D-13).
- [ ] **BA / security** · How reps verify their Salesforce login in production (password, authenticator, passkey, SSO —
      checklist item 19). The login opens in the phone's browser, so all of these work (D-42).
- [ ] **H / L** · **LINE setup for production** — choose one:
  - **(a) Recommended:** keep the same OA and LINE Login channel; add a **second LIFF app** whose endpoint is the
    production Site, and point the rich menu at it. `dev5` keeps its own LIFF app for testing, opened by its
    `liff.line.me` link (the menu no longer opens the sandbox).
  - (b) A separate test OA for the sandbox, the main OA for production.
- [ ] **BA / user** · Which switches start **on**: Update Opportunity (needs Q-O3/Q-O5 settled) and Attachments
      (needs Q-A6a). Both default to **off**.
- [ ] **BA** · Activity **Type** values (Q-A2) — added by an admin in production before go-live (step 6).

## 1. Check production first (read-only)

- [ ] **C** · Re-run the coexistence checks against production (`COEXISTENCE.md` §4): LINE Connect version, its
      triggers and fields — nothing named `SalesReport*` may exist already.
- [ ] **C** · The org fields used by the Update Opportunity form exist in production: `Opportunity.PreSales_Engineer__c`
      (User lookup), `Next_Step_Custom__c`, `Next_Step_Due_Date__c` (D-46). The deploy fails otherwise.
- [ ] **C** · The Opportunity validation rule `Require_Main_PreSales_Engineer_When_Stag` — if it also crashes on old
      unnumbered stages in production, give the admin the suggested fix (`IMPLEMENTATION-PLAN.md`, L5c).
- [ ] **H** · Production has **My Domain** deployed and a free **Site** (Setup → Sites shows the domain).

## 2. Deploy the program

- [ ] **C** · Build the LINE page bundle: `npm run build:liff` (the built files are committed; rebuild only if
      `liff-app/src` changed).
- [ ] **C** · Validate first (no changes yet), running the feature's 24 test classes:

```bash
sf project deploy validate -o <prod-alias> --source-dir sales-report --test-level RunSpecifiedTests --tests SalesReportAccountControllerTest --tests SalesReportAccountServiceTest --tests SalesReportActivityControllerTest --tests SalesReportActivityFileControllerTest --tests SalesReportActivityFileServiceTest --tests SalesReportActivityServiceTest --tests SalesReportCleanupServiceTest --tests SalesReportConnectionControllerTest --tests SalesReportFormServiceTest --tests SalesReportIdentityServiceTest --tests SalesReportLiffPageControllerTest --tests SalesReportLineCalloutServiceTest --tests SalesReportLineLinkTriggerHandlerTest --tests SalesReportLinkControllerTest --tests SalesReportLinkPageControllerTest --tests SalesReportLinkServiceTest --tests SalesReportLogServiceTest --tests SalesReportNamespaceServiceTest --tests SalesReportOpportunityControllerTest --tests SalesReportOpportunityServiceTest --tests SalesReportOrgApiCalloutServiceTest --tests SalesReportRateLimitServiceTest --tests SalesReportSessionCalloutServiceTest --tests SalesReportSettingsServiceTest
```

  (If the org's policy requires it, use `--test-level RunLocalTests` instead — note that `dev5` has unrelated failing
  tests from other projects; production must be green on its own.)
- [ ] **C** · On a brand-new org, deploy `sales-report/main/default/objects` first (tests can't see brand-new fields
      in the same check-only run), then validate again.
- [ ] **C** · Quick-deploy the validated run: `sf project deploy quick -o <prod-alias> --job-id <id>`.
- [ ] **Check** · Setup → Apex Classes shows the `SalesReport*` classes; Custom Labels `SalesReport_*` (61) exist.

## 3. Certificate and External Client App (Setup, H)

- [ ] **H** · Create certificate `SalesReport_JWT_Signing` (2048, **not** exportable) — `SETUP-GUIDE.md` Part G.
      Note its expiry date (one year) in `ENVIRONMENTS.md` and set a reminder to renew it.
- [ ] **H** · Create External Client App `SalesReport_App` with JWT bearer flow and the production `.crt`; policies:
      admin-approved users pre-authorized, permission set **Sales Report User**, relax IP restrictions.
- [ ] **H** · Copy the **Consumer Key** (never the secret) → step 5.

## 4. Site and guest access (Setup, H)

- [ ] **H** · Create Site `SalesReport_Site`, address `salesreport`, home page `SalesReport_Liff`, settings exactly as
      `SETUP-GUIDE.md` Part E (HTTPS only, no guest API access, no Lightning features, no page cache).
- [ ] **H** · Default Record Owner = an active admin.
- [ ] **H** · Guest profile → **Enabled Apex Class Access**: `SalesReportConnectionController`,
      `SalesReportLinkController`, `SalesReportAccountController`, `SalesReportActivityController`,
      `SalesReportActivityFileController`, `SalesReportOpportunityController`.
- [ ] **H** · Guest profile → **Visualforce Page Access**: `SalesReport_Liff` only (remove `SiteLogin`,
      `SiteRegister`, `ForgotPassword` and their confirm pages — the Site has no login).
- [ ] **H** · Guest profile has **no object access**; no permission sets assigned to the guest user.
- [ ] **Check** · `curl -s https://<prod-site-domain>/salesreport/services/apexrest/salesreport/v1/connection`
      answers `TOKEN_MISSING` (HTTP 401).

## 5. Sales Report Settings (Setup, H)

Setup → Custom Settings → **Sales Report Settings** → Manage → **New** (org default). Only 8 fields (D-48):

| Field | Production value |
|---|---|
| LINE Login Channel ID | `<channel ID>` |
| LIFF ID | `<production LIFF ID>` (step 7) |
| ECA Consumer Key | from step 3 |
| JWT Certificate Name | blank (= `SalesReport_JWT_Signing`) |
| Update Opportunity Enabled | as decided in step 0 |
| Attachments Enabled | as decided in step 0 |
| Log Level | `WARN` |
| Log Retention (days) | blank (= 30) |

## 6. Org configuration (Setup, H)

- [ ] **H** · Field set **Sales Report Activity Form** (Task) and **Sales Report Opportunity Form** (Opportunity) came
      with the deploy — check the members match the BA's list.
- [ ] **H** · Field set **Sales Report Account Search** — add extra search fields if the BA wants (e.g. Thai name).
- [ ] **H** · Task **Type** picklist values agreed with the BA (Q-A2).
- [ ] **H** · Assign **Sales Report User** to every rep; **Sales Report Admin** to the admins who manage links and logs.
- [ ] **H** · Add the **Sales Report LINE Links** and **Sales Report Logs** tabs to the admins' app if wanted.

## 7. LINE (LINE Developers Console / OA Manager, L)

- [ ] **L** · LIFF app for production (step 0): Size Full, endpoint
      `https://<prod-site-domain>/salesreport/SalesReport_Liff`, scopes `openid` + `profile` → LIFF ID into step 5.
- [ ] **L** · Rich menu tiles: `https://liff.line.me/<prod LIFF ID>?form=activity` and `…?form=opportunity`.
- [ ] **L** · LINE Login channel: switch from **Developing** to **Published** (`LINE-SETUP.md` §6) — until then only
      Admin/Tester roles can open the app.

## 8. Housekeeping

- [ ] **C/H** · Schedule the nightly cleanup once, as an admin in the Bangkok time zone:
      `sf apex run -o <prod-alias> -f scripts/apex/schedule-cleanup.apex` → Setup → Scheduled Jobs shows
      *Sales Report cleanup* at 02:00.

## 9. Smoke test in production (H + one rep)

- [ ] First login: Log Activity → browser login → **Connect** → back on the form in LINE.
- [ ] Account search shows only Accounts the rep can see.
- [ ] Save an activity → Task on the Account, Created By = the rep.
- [ ] (If switched on) Update a **test** Opportunity — remember the org's Opportunity automation posts Slack alerts.
- [ ] Second LINE account on the same user → "already linked"; admin **Revoke** works; relink creates a new record.
- [ ] Sales Report Logs: no ERROR entries; a forced error shows a **Reference** that matches a log entry.
- [ ] Android and iOS.

## 10. After go-live

- [ ] **C** · Record production values in `ENVIRONMENTS.md` (Site URL, LIFF ID, channel ID, certificate expiry).
- [ ] **BA** · Send reps `USER-GUIDE.md` (or a copy) and the OA invitation.
- [ ] **H** · First week: check *Sales Report Logs* → "Errors today" daily.
- [ ] **H** · Calendar reminder: renew the certificate before it expires (Part G), upload the new `.crt` to the app.

## Rollback

- **Stop for everyone:** Setup → Sites → `SalesReport_Site` → **Deactivate** (D-48). LINE then shows an error; no data
  is touched. Re-activate to resume.
- **Hide one form:** untick *Update Opportunity Enabled* or *Attachments Enabled*.
- **Remove a rep:** revoke their link and/or remove *Sales Report User*.
- Records already saved (Tasks, Opportunity changes, files) are normal Salesforce records and stay.
