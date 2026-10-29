# L1 — LINE setup guide ([HUMAN])

**For:** the person who owns the company's LINE Business ID / LINE Developers provider.
**Time:** ~1 hour of clicking, plus any internal approval for a new Official Account.
**Result:** a "Sales Reporting" LINE Official Account (OA) with a Messaging API channel, and a LINE Login channel
under the **same provider**, linked to each other. The LIFF app and rich menu are added in **L2**, because they need the
Salesforce Site URL that L2 creates.

Related: `IMPLEMENTATION-PLAN.md` (L1, L2), `DECISIONS.md`, `HANDOFF.md` §2a rule 4 and §9.
Console menus are named as of 2026-10; if a label has moved, look for the same setting nearby.

> **Never send secrets back.** Channel secret, channel access token and any LINE Login channel secret stay in the LINE
> console. This build does not need them for L1–L3 (ID-token verification only needs the LINE Login **channel ID**).
> If a later step needs one, it will ask you to enter it directly into Salesforce, not into chat, email or the repo.

---

## 0. Before you start — one irreversible choice

**Pick the provider.** The OA and the LINE Login channel must be under the **same provider**, because LINE gives each user
a different user ID per provider. The rep's LINE user ID seen by the LIFF app (LINE Login channel) must be the same one
the OA sees.

- Once an OA is assigned to a provider, **it can't be moved or unassigned**. Channels can't be moved between providers either.
- Use the company's existing provider (the "LINE umbrella" from the requirements) unless you decide otherwise.
  **Do not** pick the provider used for LINE Connect test channels unless that is the company provider.
- You need the **Admin** role on that provider. Only providers where you are Admin appear in the selection list.

Write down: provider name → __________________

## 1. Create the "Sales Reporting" Official Account

1. Go to LINE Official Account Manager (`https://manager.line.biz`) and log in with the company's LINE Business ID.
2. **Create** a new LINE Official Account (entry form):
   - Account name: e.g. `Sales Reporting` / `営業報告` (shown to reps as the friend name). The final name is still a BA
     question (`BA-QUESTIONS.md` Q-N1 — the mockup says "Salesforce Reporting"). For an unverified account the name can be
     changed later in OA Manager settings, so this doesn't block setup; the basic ID (`@xxxxxxx`) can't be changed.
   - Company / industry details as for the company's other OAs.
3. Open the new account in LINE Official Account Manager and confirm it appears.

A verified (blue badge) account is **not** needed for an internal tool. [BA confirms]

## 2. Turn off chat features we don't use

In LINE Official Account Manager → the new OA → **Settings → Response settings**:

| Setting | Value | Why |
|---|---|---|
| Chat | Off (or on only if someone will read messages) | Reps should use the rich menu, not chat. |
| Greeting message | On. Proposed text (mockup, BA Q-N5): "Welcome to Sales Reporting! Please use the menu below to log your activity or update opportunity." | First-time guidance. |
| Auto-response messages | **Off** | HANDOFF §2a rule 4. |
| Webhooks | **Off** | No webhook is needed in this phase. |

**Do not** register this OA in LINE Connect: no `LINE_OA_Configuration__c` record in Salesforce and no LINE Connect
webhook URL on it. Otherwise reps' messages would be stored as customer chats.

## 3. Enable the Messaging API (creates the Messaging API channel)

Messaging API channels can no longer be created directly in the LINE Developers Console; they are created from the OA.

1. LINE Official Account Manager → the new OA → **Settings → Messaging API** → **Enable Messaging API**.
2. **Select the provider** from step 0. Double-check — this cannot be changed later.
3. Accept the terms. Privacy policy / terms URLs can be left empty for an internal tool.
4. Log in to the LINE Developers Console (`https://developers.line.biz/console/`) with the **same account**, open the
   provider and confirm the new Messaging API channel is listed.
5. Open the channel → **Basic settings** → copy the **Channel ID** (a number). → send it back (table in §7).

Do **not** issue a channel access token now; it is not needed until OA push messages are added (out of scope).

## 4. Create the LINE Login channel

LINE Developers Console → the **same provider** → **Create a new channel** → **LINE Login**:

| Field | Value |
|---|---|
| Region to provide the service | Thailand and/or Japan — choose where the reps are (affects nothing else in this build) |
| Company or owner's country or region | Company's country |
| Channel name | e.g. `Sales Reporting Login` (must not contain "LINE") |
| Channel description | `Internal sales reporting form for employees` |
| App types | **Web app** only |
| Email address | Technical contact for LINE notices |
| Privacy policy / Terms of use URL | Optional for an internal tool |

Then open the new channel → **Basic settings** → copy the **Channel ID** → send it back.
Leave **OpenID Connect → Email address permission** unapplied (we only use `openid profile`).

> **LINE MINI App note.** LINE now recommends creating new LIFF apps as LINE MINI Apps. This build keeps a LIFF app on
> a LINE Login channel (HANDOFF §3), which LINE still supports, because a MINI App adds a review step and policies aimed
> at public services. Recorded as D-17 in `DECISIONS.md`; change only if the user decides so.

## 5. Link the OA to the LINE Login channel

Lets the LIFF consent screen offer "add Sales Reporting as a friend", and makes the friendship visible to the app.

1. LINE Developers Console → the LINE Login channel → **Basic settings** → **Linked LINE Official Account** → **Edit**.
2. Select the Sales Reporting OA → **Update**.

Requirements: same provider (step 0) and you are Admin on both the LINE Login channel and the OA. Only one OA can be
linked per LINE Login channel.

## 6. Roles while the channel is in "Developing"

A new LINE Login channel starts in **Developing** status. In that status only users with the **Admin** or **Tester** role
on the channel can use it — normal reps will get an error when they open the LIFF app.

- For development and device QA (L2–L8): LINE Login channel → **Roles** → invite each tester's LINE Developers account
  as **Tester**.
- Switching the channel to **Published** happens at rollout (L8), not now. [BA/user decides who approves that]

## 7. Send back these values

Reply in the Claude session (or the issue/PR) with:

| # | Value | Where to find it | Example format |
|---|---|---|---|
| 1 | Provider name | LINE Developers Console, provider list | text |
| 2 | Messaging API **channel ID** | Messaging API channel → Basic settings | 10-digit number |
| 3 | LINE Login **channel ID** | LINE Login channel → Basic settings | 10-digit number |
| 4 | OA basic ID | LINE Official Account Manager → account header | `@123abcde` |
| 5 | Confirmation | Webhook off, auto-response off, OA linked to the LINE Login channel, not registered in LINE Connect | yes / no |
| 6 | Testers | LINE accounts added as Tester (names only) | list |

Do **not** send: channel secrets, channel access tokens, Business ID passwords.

## 8. What happened next (L2 — done 2026-10-29)

The LIFF app and the rich menu were added in L2. Their steps, values and the reasons behind them are now in
`SETUP-GUIDE.md` part F (LIFF ID 2012273127-wBh0Giwq, endpoint
`https://terraskyth--dev5.sandbox.my.salesforce-sites.com/salesreport/SalesReport_Liff`).

## Sources

- Messaging API getting started — <https://developers.line.biz/en/docs/messaging-api/getting-started/>
- Get user IDs (user IDs differ per provider) — <https://developers.line.biz/en/docs/messaging-api/getting-user-ids/>
- Getting started with LINE Login — <https://developers.line.biz/en/docs/line-login/getting-started/>
- Linking an OA to a LINE Login channel — <https://developers.line.biz/en/docs/line-login/link-a-bot/>
- Managing roles (Developing status: Admin/Tester only) — <https://developers.line.biz/en/docs/line-developers-console/managing-roles/>
- Adding a LIFF app — <https://developers.line.biz/en/docs/liff/registering-liff-apps/>
- OA Manager rich menus — <https://linebiz.com/jp-en/manual/OfficialAccountManager/rich-menus>
