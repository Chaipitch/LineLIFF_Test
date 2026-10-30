# Setup guide — LINE Sales Reporting

For admins, and readable by the BA and other non-technical readers. Each part starts with **what it is for** in plain
language, then gives the exact steps. Step IDs (L2-4, L3-3, …) match `IMPLEMENTATION-PLAN.md`. The values used in
sandbox `dev5` are in `ENVIRONMENTS.md`. The LINE console steps of L1 are in `LINE-SETUP.md`.

> Never paste secrets (channel secret, access tokens, consumer secret, private keys) into chat, email or the repo.

---

## 0. The big picture

**What the rep sees:** a "Sales Reporting" chat in LINE with two menu buttons. A button opens a small web form inside
LINE. The first time, the rep logs in to Salesforce once; after that the form just works, and everything it saves
appears in Salesforce under the rep's own name.

```
 Rep's phone                     Salesforce (sandbox dev5)
 ┌───────────────────┐           ┌─────────────────────────────────────────────┐
 │ LINE chat         │  tap      │ Public Site "SalesReport_Site"  (part E)    │
 │ "Sales Reporting" │ ───────▶  │   the form page + the doors it talks to     │
 │  [Log Activity]   │           │                                             │
 │  [Update Opp.]    │           │ "Who is this?"  → asks LINE (part A)        │
 │                   │           │ "Which rep?"    → Sales Report LINE Links   │
 │ form inside LINE  │ ◀───────  │ "Act as the rep"→ certificate + app (part G)│
 └───────────────────┘           │ Accounts, Tasks, Opportunities — as the rep │
                                 └─────────────────────────────────────────────┘
```

| Part | What it is (plain language) | Why it is needed | Who | Status in `dev5` |
|---|---|---|---|---|
| **A. LINE accounts** | The "Sales Reporting" chat account and LINE's login service | Gives reps the chat and buttons, and lets us know which LINE user is using the form | Admin (LINE consoles) | Done |
| **B. Deploy** | Installing the Sales Report program into Salesforce | The program itself | Claude | Done (L2–L4) |
| **C. Settings** | A small settings page for Sales Report | Tells the program which LINE app to trust and how to behave, without code changes | Admin / Claude | Done |
| **D. Permission sets** | Two "access badges": one for admins, one for reps | Controls who may manage links/logs and who may use the forms | Admin | Done for the test user |
| **E. Site** | A public web address in Salesforce | The form must be reachable from LINE without a Salesforce login screen every time | Admin | Done |
| **F. LIFF app & rich menu** | Registering the form with LINE and adding the two menu buttons | Makes the buttons open our form inside LINE | Admin (LINE consoles) | Done |
| **G. Certificate & External Client App** | A digital stamp and an "app pass" in Salesforce | Lets the system safely act **as the rep** after the one-time login, so data is saved under the rep's name with the rep's permissions | Admin | Done |
| **H. Optional tuning** | Extra search fields and limits | Lets admins adjust the forms without a developer | Admin | Optional |
| **I. Device tests** | Trying it on a phone | Proves each step works for real | Admin + Claude | L2, L3, L4 done |

### Words used in this guide

| Word | Meaning |
|---|---|
| **LINE Official Account (OA)** | A business chat account in LINE — here "Sales Reporting" (@939eyqft). |
| **Rich menu** | The big buttons at the bottom of a LINE chat. |
| **LIFF** | "LINE Front-end Framework": LINE's way to open a web page *inside* LINE and tell it who the LINE user is. |
| **LINE ID token** | A short-lived proof from LINE saying "this is LINE user X". Checked with LINE on every request. |
| **Site** | A public web address served by Salesforce, used here for the form page and its data "doors". |
| **Guest user** | The anonymous user a Site runs as before we know who the rep is. It gets almost no access on purpose. |
| **Endpoint / Apex REST** | A "door" the form calls to get or save data (e.g. "search Accounts"). |
| **Permission set** | A bundle of access rights given to users, like a badge. |
| **Certificate** | A digital stamp Salesforce uses to sign a request so other parts of Salesforce can trust it. |
| **External Client App (ECA)** | A registered "app pass" in Salesforce that says which users the system may act for. |
| **JWT** | The signed note ("let me act as Roj") the system sends to Salesforce, stamped with the certificate. |
| **Consumer key** | The public ID of the External Client App. Not a secret. (The *consumer secret* is — never share it.) |
| **Custom setting** | A small settings record admins can edit in Setup. |
| **Field set** | An admin-editable list of fields; the program reads it to know which fields to use. |
| **Remote Site Setting** | Salesforce's allow-list of outside websites the program may call (here: LINE). |

---

## Part A — LINE accounts (L1)

**What it is for.** The Official Account is the chat reps add as a friend. The *Messaging API channel* is that chat's
technical side. The *LINE Login channel* is LINE's login service: it lets the form ask LINE "who is this user?" and get a
proof (the LINE ID token) that Salesforce can check. Both must be under the same LINE *provider* (the company's
container in LINE), so the same person has the same LINE ID in both.

**Steps:** `LINE-SETUP.md` §0–§7. **Status:** done (provider "Terrasky Sales Report", values in `ENVIRONMENTS.md`).

---

## Part B — Deploy the program (L2-1, L3-1, L4-1)

**What it is for.** Installs everything that is code or configuration in the repo: the form page, the "doors"
(endpoints), the LINE Link / Link Code / Log objects, labels, permission sets, the LINE remote site, settings fields and
the Account search field set. Done by Claude; an admin only needs this when moving to another org (e.g. production).

```bash
npm run build:liff
```

Sandbox (only this feature's tests):

```bash
sf project deploy start -o lineliff-sbx --source-dir sales-report --test-level RunSpecifiedTests --tests SalesReportAccountControllerTest --tests SalesReportAccountServiceTest --tests SalesReportActivityControllerTest --tests SalesReportActivityServiceTest --tests SalesReportActivityFileControllerTest --tests SalesReportActivityFileServiceTest --tests SalesReportIdentityServiceTest --tests SalesReportLiffPageControllerTest --tests SalesReportLineCalloutServiceTest --tests SalesReportLinkControllerTest --tests SalesReportLinkPageControllerTest --tests SalesReportLinkServiceTest --tests SalesReportLogServiceTest --tests SalesReportMeControllerTest --tests SalesReportNamespaceServiceTest --tests SalesReportOrgApiCalloutServiceTest --tests SalesReportSessionCalloutServiceTest --tests SalesReportSettingsServiceTest
```

Production: validate first with `--test-level RunLocalTests` (`sf project deploy validate`), then quick-deploy.
On a brand-new org, deploy `sales-report/main/default/objects` first: Apex tests can't see brand-new fields during the
same check-only validation.

**Status:** deployed to `dev5` (L2, L3, L4).

---

## Part C — Sales Report Settings (L2-2, L3-5)

**What it is for.** One settings record that tells the program which LINE app and Salesforce app to trust, plus a few
switches. Changing a value here takes effect immediately — no developer needed. Nothing in it is secret.

Setup → Custom Settings → **Sales Report Settings** → Manage → **Edit** (org default):

| Field | What it does | Value |
|---|---|---|
| LINE Login Channel ID | Which LINE login service to trust | From `ENVIRONMENTS.md` |
| LIFF ID | Which LINE form registration the page belongs to | From part F |
| ECA Consumer Key | Which Salesforce "app pass" to use when acting as the rep | From part G |
| JWT Certificate Name | Which digital stamp to sign with | Blank = `SalesReport_JWT_Signing` |
| Link Code TTL (min) | How long a first-login link stays valid | Blank = 5 |
| Account Search Min Chars / Max Results | How many letters before search starts / how many results | Blank = 2 / 10 |
| Log Level | How much the program writes to the log | `WARN` (`INFO`/`DEBUG` only while investigating) |
| Enabled | Emergency off switch for everyone | ✓ |

**Status:** all set in `dev5` (2026-10-29).

---

## Part D — Permission sets (L2-3, L3-5)

**What it is for.** Access badges.

- **Sales Report Admin** — for admins: see and clean up the *Sales Report Logs*, see and end LINE links
  (*Sales Report LINE Links* tab), view the settings.
- **Sales Report User** — for every rep who will use the forms. Without it the rep can't finish the one-time login and
  Salesforce refuses to let the system act as them. It gives **no** access to records by itself; reps keep their
  normal Salesforce access to Accounts, Opportunities and activities.

Setup → Users → *user* → Permission Set Assignments → Edit Assignments → add the badge → Save.

**Status in `dev5`:** both assigned to the test admin/rep. For real reps: assign *Sales Report User* to each (BA Q-S1).

---

## Part E — The Site (L2-4, L3-4, L4-2)

**What it is for.** The form lives on a public Salesforce web address so LINE can open it without a Salesforce login
screen. The Site runs as an anonymous *guest user* that is allowed to do almost nothing: show the form page and open a
few "doors". Each door checks the LINE proof itself, and anything that touches business data is done as the rep, not
as the guest. Each new door has to be allowed for the guest — that's why this part grows with each milestone.

Setup → **Sites** (User Interface → Sites and Domains → Sites) → **New**:

| Field | Value | Why |
|---|---|---|
| Site Label / Site Name | `Sales Report` / `SalesReport_Site` | Naming rule |
| Site Description | `LINE Sales Reporting (LIFF) — public page and Apex REST for the LINE app` | |
| Site Contact | yourself (an admin) | |
| Default Web Address | `salesreport` | Part of the address registered in LINE |
| Active | ✓ | |
| Active Site Home Page | `SalesReport_Liff` | The form page |
| Clickjack Protection Level | Allow framing by the same origin only | Other websites can't embed the form |
| Require Secure Connections (HTTPS) / Upgrade all requests to HTTPS | ✓ | Encrypted only |
| Guest Access to the Payments API / Salesforce APIs | off | The guest must not reach Salesforce data |
| Lightning Features for Guest Users | off | Not used; less exposed |
| Cache Public Visualforce Pages | off | The page carries settings that may change |
| Redirect to custom domain | off | The form must stay on the address registered in LINE |

Save. Then on the Site detail page:

1. **Default Record Owner** = an active admin. *Why:* the few records the guest creates (one-time link codes, log
   entries) need an owner.
2. **Public Access Settings** (opens the guest profile *Sales Report Profile*):
   - **Enabled Apex Class Access** → add the doors — *why: each door must be allowed explicitly*:
     - `SalesReportMeController` — "who am I?" (L2)
     - `SalesReportLinkController` — "start my one-time login" (L3)
     - `SalesReportAccountController` — "search Accounts" (L4)
     - `SalesReportActivityController` — "show the Log Activity form and save it" (L5a)
     - `SalesReportActivityFileController` — "attach a photo or file to the activity just saved" (L5b)
     - later `SalesReportOpportunityController` (L5c)
   - **Enabled Visualforce Page Access** → `SalesReport_Liff` (often added automatically).
   - Object Settings: leave **all objects without access**. Don't assign `LINE_Webhook_Guest` or any other permission set.
3. Do **not** change the existing `LineWebhook` Site (that belongs to LINE Connect).

Check (Claude can do this):

```bash
curl -s https://terraskyth--dev5.sandbox.my.salesforce-sites.com/salesreport/services/apexrest/salesreport/v1/me
```

Expected: `{"error":{"message":"No LINE ID token was sent.","code":"TOKEN_MISSING"}}` (HTTP 401).

**Status in `dev5`:** Site created and checked; doors 1–3 allowed (checked 2026-10-29).

---

## Part F — LIFF app and rich menu (L2-5, L2-6)

**What it is for.** The *LIFF app* registers our form page with LINE, so LINE opens it inside the chat and gives it the
LINE user's proof. The *rich menu* is the two buttons that open the form, one per form.

**LIFF app** — LINE Developers Console → provider **Terrasky Sales Report** → **LINE Login** channel → **LIFF** → **Add**:

| Field | Value | Why |
|---|---|---|
| LIFF app name | `Sales Reporting` | Shown to users |
| Size | **Full** | Full-screen form |
| Endpoint URL | `https://terraskyth--dev5.sandbox.my.salesforce-sites.com/salesreport/SalesReport_Liff` | Where the form lives (part E) |
| Scopes | **openid**, **profile** only | openid = the proof of who the user is; profile = display name |
| Add friend option | On (normal) | Offers to add the OA if the rep hasn't yet |
| Scan QR / Module mode | off | Not used |

Add → send the **LIFF ID** to Claude (it goes into part C).

**Rich menu** — LINE Official Account Manager → OA **@939eyqft** → **Home → Rich menus → Create**:

| Setting | Value |
|---|---|
| Title | `Sales Report menu` (internal) |
| Display period | today → far future |
| Template | 2 tiles side by side |
| Image | the designed image, or "Create image" with the two labels |
| Tile A — Action **Link** | `https://liff.line.me/<LIFF ID>?form=activity`, label `Log Activity` |
| Tile B — Action **Link** | `https://liff.line.me/<LIFF ID>?form=opportunity`, label `Update Opportunity` |
| Menu bar label / default | `Menu` / Shown |

**Status:** done — LIFF ID 2012273127-wBh0Giwq.

---

## Part G — Certificate and External Client App (L3-2, L3-3)

**What it is for.** After the one-time login, the program must save data **as the rep** — so records show the rep as
creator, and Salesforce applies the rep's own sharing, field access and validation rules. To do that safely without
storing any password or token:

- the **certificate** is the program's digital stamp; it signs a short note "let the Sales Report program act as Roj
  for a moment" (a *JWT*);
- the **External Client App** is the "app pass" that tells Salesforce to accept such notes — but only for users who
  hold the *Sales Report User* badge (part D). Salesforce then gives a short-lived session for that one request.

Nothing is stored: a new session is requested for each request and thrown away (about 0.2–0.35 s extra).

**L3-2 Certificate** — Setup → **Certificate and Key Management** → **Create Self-Signed Certificate**:

| Field | Value | Why |
|---|---|---|
| Label / Unique Name | `SalesReport JWT Signing` / `SalesReport_JWT_Signing` | Name the program looks for |
| Key Size | 2048 | Standard strength |
| Exportable Private Key | **off** | The private part can never leave Salesforce |
| Use Platform Encryption | off | |

Save → **Download Certificate** (`.crt`, public part only — for L3-3). It expires after one year: **renew before
2027-10-29** and upload the new `.crt` to the app.

**L3-3 External Client App** — Setup → **External Client App Manager** → **New External Client App**:

| Section | Field | Value | Why |
|---|---|---|---|
| Basic | Name / API Name | `Sales Report App` / `SalesReport_App` | |
| | Contact Email | an admin email | |
| | Distribution State | **Local** | Only this org |
| API (Enable OAuth Settings) | Enable OAuth | ✓ | |
| | Callback URL | `https://login.salesforce.com/services/oauth2/success` | Required by the form; not used by this flow |
| | OAuth Scopes | **api**, **id** (Access the identity URL service), **refresh_token** (Perform requests at any time) | api = read/save data as the rep; id = read the rep's name; refresh_token = Salesforce requires it for this flow even though no refresh token is issued |
| Flow Enablement | Enable JWT Bearer Flow | ✓ → upload the `.crt` | Accept notes stamped with our certificate |
| Security | other options | defaults | |

Create, then:

1. **Policies** → Edit → OAuth Policies: Permitted Users = **Admin approved users are pre-authorized**; Select
   Permission Sets = **Sales Report User**; IP Relaxation = **Relax IP restrictions** → Save.
   *Why:* only reps with the badge can be acted for; the requests come from Salesforce's own servers.
2. **Settings** → OAuth Settings → **Consumer Key and Secret** (email verification) → send Claude the **Consumer Key**
   only (it goes into part C). **Never send the Consumer Secret.**

**Status:** done and tested (2026-10-29).

---

## Part H — Optional tuning (L4-3)

**What it is for.** Admin changes without a developer.

- **More Account search fields.** By default the Account search looks at **Account Name** only. To also search e.g.
  *Account Name (TH)* or *Account No.*: Setup → Object Manager → Account → **Field Sets** → *Sales Report Account Search*
  → drag the fields in → Save. The first of these fields with a value is shown under the name — useful when two
  Accounts have the same name. Reps must be able to read every field in the set, or their search fails. (BA Q-C1.)
- **Search limits.** Part C: *Account Search Min Chars* / *Max Results*.
- **Fields on the Log Activity form (L5a).** Setup → Object Manager → **Activity** (Task fields) → **Field Sets** →
  *Sales Report Activity Form* → drag fields in or out, change the order → Save. The form in LINE changes on the next
  open; no code change. Labels shown are the field labels in Salesforce (e.g. *Due Date Only* — rename the field label
  if the reps should see "Date"). *Why:* the business decides the fields, not the program (D-21).
- **Make a field required on the form.** The form follows Salesforce (D-31): make the field required on the Task
  **page layout** of the reps' profile, or tick *Required* for it in the field set. Validation rules on Task also apply
  and their message is shown on the form. If you make a field required on the layout but **don't** add it to the field
  set, reps get the message "Salesforce requires *X* … ask your admin to add it to field set SalesReport_Activity_Form".
- **Attachment limits (L5b).** Part C settings: *Attachment Max Files* (blank = 5, at most 10), *Attachment Max Size MB*
  (blank = 4; 4 is the most Salesforce can handle on this route), *Attachment File Types* (blank = `jpg,jpeg,png,pdf`).
  Photos are shrunk on the phone and always arrive as .jpg, so keep `jpg` in the list. Files count against the org's
  **file storage** (Setup → Storage Usage). *Why:* keeps uploads quick on mobile data and storage under control.
- **Rate limit (L7).** Part C setting *Rate Limit per Minute* (blank = 60): how many requests one LINE user may make per
  minute before seeing "Too many requests. Please wait a minute". *Why:* stops a stuck phone or a misuse from flooding
  Salesforce. Normal use (search, save, a few photos) stays far below 60.
- **Nightly cleanup (L7).** Scheduled job *Sales Report cleanup* (Setup → Scheduled Jobs) runs every night at 02:00 and
  deletes used-up one-time codes, logs older than *Log Retention (days)* (blank = 30) and old rate-limit counters.
  *Why:* keeps temporary data from piling up. In a new org (e.g. production) schedule it once:
  `sf apex run -o <alias> -f scripts/apex/schedule-cleanup.apex` (run it as an admin in the Bangkok time zone).
- **Activity Type values.** The Type list is Salesforce's Task *Type* picklist (BA Q-A2): Object Manager → Activity →
  Fields → Type → add values such as *Customer Visit*. They also appear for normal Task entry in Salesforce.
- **Switch off for everyone.** Part C: untick *Enabled*.

---

## Part I — Device tests

**What it is for.** Each milestone ends with a real phone test; the result is recorded in `IMPLEMENTATION-PLAN.md`.

**L2-7 — form opens (done 2026-10-29).** Add the OA (`https://line.me/R/ti/p/@939eyqft`) → tap **Log Activity** →
allow LINE's permission the first time → the page shows **Log activity** and "Hello, <LINE name>".

**L3-6 — one-time login (done 2026-10-29).**
1. Tap **Log Activity** → **Connect Salesforce** → **Log in to Salesforce**.
2. The phone's browser opens the Salesforce login → log in (MFA if asked).
3. **Connect LINE to Salesforce** — "Connect the LINE account "<LINE name>" to your Salesforce user <name>?" →
   **Connect** → **Open Sales Report in LINE**.
4. Back in LINE: "Hello, <LINE name>" and "Salesforce: <your name>". Reopening never asks to log in again.

**L4-4 — Account search (done 2026-10-29).**
1. Tap **Log Activity**. Under **Account**, type one letter: nothing happens. Type a second: after a short pause the
   list appears.
2. Keep typing: the list narrows; names that **start** with what you typed come first.
3. Tap an Account: it shows as selected with **Change**.
4. Type something that matches nothing: "No matching accounts".

If anything else appears: Setup → **Sales Report Logs** tab → "Errors today" / "All", and send Claude a screenshot.

---

## Day-to-day admin tasks

| Task | How |
|---|---|
| Give a new rep access | Assign **Sales Report User** (part D). The rep links on first use. |
| Disconnect a rep / lost phone | *Sales Report LINE Links* tab → the rep's link → Status = **Unlinked** (or delete). Next time the form asks to connect again. |
| Rep left the company | Deactivate the user as usual — the link ends automatically on the next attempt. |
| Something went wrong | *Sales Report Logs* tab → "Errors today". |
| Switch the forms off | Sales Report Settings → untick *Enabled*. |
| Yearly | Renew the certificate before it expires (part G) and upload it to the app. |
