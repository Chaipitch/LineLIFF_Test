# Environments — configuration values

Non-secret identifiers per environment. **No secrets here** (channel secrets, access tokens, consumer secrets, private
keys, passwords). Values marked *pending* are filled in as each milestone delivers them.
Settings values are entered into `SalesReport_Settings__c` by an admin ([HUMAN]); this file is the reference.

## Sandbox `dev5` (development)

| Item | Value | Source / where used | Received |
|---|---|---|---|
| Salesforce org | TerraSky (Thailand) Co., Ltd. — sandbox `dev5`, Enterprise Edition | CLI alias `lineliff-sbx` | 2026-10-28 |
| My Domain | `https://terraskyth--dev5.sandbox.my.salesforce.com` | Link page, JWT token endpoint (build from `URL.getOrgDomainUrl()`) | 2026-10-28 |
| LINE Connect installed | `tsthlineoa` 0.1.0.10 "MVP" | `COEXISTENCE.md` | 2026-10-28 |
| LINE provider | Terrasky Sales Report | OA and LINE Login channel share it (`LINE-SETUP.md` §0) | 2026-10-29 |
| Messaging API channel ID | 2012272508 | Not used until OA messages are added (out of scope) | 2026-10-29 |
| LINE Login channel ID | 2012273127 | `SalesReport_Settings__c.Line_Login_Channel_Id__c`; ID-token verify `client_id` and expected `aud` | 2026-10-29 |
| OA basic ID | @939eyqft | Friend link `https://line.me/R/ti/p/@939eyqft` for reps/testers | 2026-10-29 |
| OA settings | Webhook off, auto-response off, linked to the LINE Login channel — confirmed by user. Not registered in LINE Connect — confirmed by user and by query (0 `tsthlineoa__LINE_OA_Configuration__c` records with these channel IDs / basic ID, 2026-10-29) | `LINE-SETUP.md` §2, §5 | 2026-10-29 |
| LINE Login channel status | Developing | Switch to Published in L8 | 2026-10-29 |
| LINE testers (Tester role) | TerraskyDev (the user) | Device QA | 2026-10-29 |
| Sales Report Settings (org default) | LINE Login Channel ID = 2012273127, Enabled = true, Log Level = WARN; LIFF ID *pending* | Set by Claude via CLI | 2026-10-29 |
| Code deployed | L2 shell (Apex REST `/me`, VF `SalesReport_Liff`, LIFF bundle, log object, labels, permission sets, remote site) | `sf project deploy start --source-dir sales-report` | 2026-10-29 |
| Site | `SalesReport_Site` (label "Sales Report"), active, `https://terraskyth--dev5.sandbox.my.salesforce-sites.com/salesreport/`, home page `SalesReport_Liff`, guest default record owner = the admin. Guest profile "Sales Report Profile": Apex `SalesReportMeController` only, VF `SalesReport_Liff` + default Site pages, no object access (checked by query). Lightning features for guests off, redirect to custom domain off. Public checks (2026-10-29): `/me` → 401 `TOKEN_MISSING` / `TOKEN_INVALID` (real LINE verify), page 200 with `apiBase` `/salesreport/services/apexrest/salesreport/v1`, guest `/services/data` → 401, guest log entries written (owner = default record owner). | Created by user, checked by Claude | 2026-10-29 |
| LIFF ID | *pending* | `SalesReport_Settings__c.Liff_Id__c`, rich menu URLs; LIFF endpoint `https://terraskyth--dev5.sandbox.my.salesforce-sites.com/salesreport/SalesReport_Liff` (L2) | |
| External Client App consumer key | *pending* | `SalesReport_Settings__c.Eca_Consumer_Key__c` (L3) | |
| JWT certificate | `SalesReport_JWT_Signing` — *pending* | L3 | |

## Production

Not set up. Before go-live, record the production values here (a separate LIFF app / LINE Login channel endpoint
pointing at the production Site may be needed — decide in L8).
