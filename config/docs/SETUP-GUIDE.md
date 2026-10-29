# Setup guide — LINE Sales Reporting (admin)

Steps an admin does by hand in Salesforce Setup and the LINE consoles ([HUMAN]). Everything else is deployed from the
repo (`sales-report/`). Values for each environment are recorded in `ENVIRONMENTS.md`. Sections are added per
milestone; L1 (LINE OA and channels) is in `LINE-SETUP.md`.

> Never paste secrets (channel secret, access tokens, consumer secret, private keys) into chat, email or the repo.

---

## L2-1. Deploy (done by Claude for sandbox `dev5`)

```bash
npm run build:liff
```

Sandbox (only this feature's tests):

```bash
sf project deploy start -o lineliff-sbx --source-dir sales-report --test-level RunSpecifiedTests --tests SalesReportSettingsServiceTest --tests SalesReportLogServiceTest --tests SalesReportLineCalloutServiceTest --tests SalesReportIdentityServiceTest --tests SalesReportMeControllerTest --tests SalesReportLiffPageControllerTest
```

Production: validate first with `--test-level RunLocalTests` (`sf project deploy validate`), then quick-deploy.

On a brand-new org, deploy `sales-report/main/default/objects` first: Apex tests can't see brand-new fields during the
same check-only validation.

Deploys: Apex classes, VF page `SalesReport_Liff`, static resource `SalesReport_LiffApp`, `SalesReport_Settings__c`,
`SalesReport_Log__c` (+ tab, list views), Custom Labels `SalesReport_*`, permission sets `SalesReport_User` /
`SalesReport_Admin`, Remote Site `SalesReport_LINE_API`.

## L2-2. Settings

Setup → Custom Settings → **Sales Report Settings** → Manage → **Edit** (org default):

| Field | Value |
|---|---|
| LINE Login Channel ID | LINE Login channel ID (`ENVIRONMENTS.md`) |
| LIFF ID | LIFF ID from step L2-5 |
| Enabled | ✓ |
| Log Level | `WARN` (use `INFO` or `DEBUG` only while investigating) |

Sandbox `dev5`: channel ID, Enabled and Log Level were set by Claude on 2026-10-29; LIFF ID follows step L2-5.

## L2-3. Admin permission set

Setup → Users → your user → Permission Set Assignments → add **Sales Report Admin**. Gives the *Sales Report Logs*
tab and read access to the log fields. (Sandbox `dev5`: assigned to the deploying admin on 2026-10-29.)

## L2-4. Create the Site

Setup → **Sites** (User Interface → Sites and Domains → Sites) → **New**:

| Field | Value |
|---|---|
| Site Label | `Sales Report` |
| Site Name | `SalesReport_Site` |
| Site Description | `LINE Sales Reporting (LIFF) — public page and Apex REST for the LINE app` |
| Site Contact | yourself (an admin) |
| Default Web Address | `salesreport` |
| Active | ✓ |
| Active Site Home Page | `SalesReport_Liff` |
| Clickjack Protection Level | Allow framing by the same origin only (recommended) |
| Require Secure Connections (HTTPS) | ✓ |
| Upgrade all requests to HTTPS | ✓ (if shown) |
| Guest Access to the Payments API / Salesforce APIs | off |
| Lightning Features for Guest Users | off (metadata `enableAuraRequests`) |
| Cache Public Visualforce Pages | off |
| Redirect to custom domain | off (the Site must answer on the `salesforce-sites.com` URL registered as the LIFF endpoint) |

Save. Then on the Site detail page:

1. **Default Record Owner** (Site detail → Edit, or "Assign new records created by guest users…"): an active admin user.
   (Used from L3, when the guest creates link codes.)
2. **Public Access Settings** → this opens the Site's guest profile (`Sales Report Profile`):
   - **Enabled Apex Class Access** → Edit → add **`SalesReportMeController`** only.
   - **Enabled Visualforce Page Access** → Edit → make sure **`SalesReport_Liff`** is enabled (often added automatically).
   - Object Settings: leave **all objects without access**. Don't assign `LINE_Webhook_Guest` or any other permission set.
3. Do **not** change the existing `LineWebhook` Site (LINE Connect).

Check (Claude can do this once the Site is active):

```bash
curl -s https://terraskyth--dev5.sandbox.my.salesforce-sites.com/salesreport/services/apexrest/salesreport/v1/me
```

Expected: `{"error":{"message":"No LINE ID token was sent.","code":"TOKEN_MISSING"}}` (HTTP 401).

## L2-5. Add the LIFF app

LINE Developers Console → provider **Terrasky Sales Report** → the **LINE Login** channel → **LIFF** tab → **Add**:

| Field | Value |
|---|---|
| LIFF app name | `Sales Reporting` |
| Size | **Full** |
| Endpoint URL | `https://terraskyth--dev5.sandbox.my.salesforce-sites.com/salesreport/SalesReport_Liff` |
| Scopes | **openid**, **profile** (nothing else) |
| Add friend option | On (normal) |
| Scan QR | off |
| Module mode | off |

Click **Add** → send back the **LIFF ID** (format `1234567890-AbcdEfgh`). It goes into Sales Report Settings → LIFF ID
(L2-2); Claude can set it in the sandbox.

## L2-6. Rich menu

LINE Official Account Manager → the OA **@939eyqft** → **Home → Rich menus → Create**:

| Setting | Value |
|---|---|
| Title | `Sales Report menu` (internal) |
| Display period | today → far future |
| Template | 2 tiles side by side (Large or Compact) |
| Image | upload the designed image, or use "Create image" with the two labels |
| Tile A — Action **Link** | `https://liff.line.me/<LIFF ID>?form=activity`, label `Log Activity` |
| Tile B — Action **Link** | `https://liff.line.me/<LIFF ID>?form=opportunity`, label `Update Opportunity` |
| Menu bar label | `Menu` |
| Default behaviour | Shown |

Save.

## L2-7. Proof point (device test)

1. On your phone, add the OA as a friend: `https://line.me/R/ti/p/@939eyqft`.
2. Open the chat → tap **Log Activity**.
3. First time only: LINE asks for permission (profile, ID token) → Allow.
4. Expected: page titled **Log activity**, "Hello, <your LINE name>", "This form is coming soon."
5. Tap **Update Opportunity** → same, titled **Update opportunity**.

If something else appears, check Setup → **Sales Report Logs** (tab) → "Errors today" / "All", and send Claude the
message shown on the phone.
