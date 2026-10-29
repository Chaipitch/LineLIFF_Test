# Questions for the BA — LINE Sales Reporting

**For:** the BA session (date: ________ · attendees: ________).
**How to use:** go through the sections in order; write the answer in the last column. Items marked **⚑ blocks L5**
must be answered before the forms are built; the rest can follow. Where we have a recommendation it is given, so the BA
can simply confirm. Context: `L0-SPEC.md`, `DECISIONS.md` (D-xx), `MOCKUP-REVIEW.md` (G-x, with the two mockup images).

Org facts quoted below come from the read-only check of sandbox `dev5` on 2026-10-28.

---

## 1. Scope and people

| # | Question | Context / options | Recommendation | Answer |
|---|---|---|---|---|
| Q-S1 ⚑ | Which reps will use the tool, and how many? | Every rep needs an active Salesforce user. **Opportunities need a full "Salesforce" licence**: the org has 9 active Salesforce and 18 "Salesforce Platform" users; Platform users can log activities but **cannot see or update Opportunities** (D-13). | List the users; confirm each has a Salesforce licence if they need Update Opportunity | |
| Q-S2 | Target go-live date and who signs off? | Plan is 20–26 working days after L1 values arrive. | | |
| Q-S3 | UI languages? | JA / EN / TH. Org default locale is ja_JP, users in Thailand. | All three, following the phone's LINE language | |
| Q-S4 | Internal only in this phase? | Built unpackaged but packaging-ready (D-06). | Yes, internal only | |
| Q-S5 | Confirm the 5 acceptance scenarios | Draft in `L0-SPEC.md` §9 (link once; search; log activity; VR error shown; unlink). | Confirm / add | |

## 2. Log Activity

| # | Question | Context / options | Recommendation | Answer |
|---|---|---|---|---|
| Q-A1 ⚑ | Record visits as **Task** or **Event**? (D-11, G1) | Mockup shows **Task**. Event fits time-bound meetings and triggers the org's Slack note + Opportunity meeting-count flows; Task fits "something done on a date". | **Task** (as in the mockup), Status `Completed` | |
| Q-A2 ⚑ | Which **Activity Type** values should reps choose from? | Task `Type` today has only call outcomes (Connected – Had Conversation, Busy / Call Back, Not Connected / Voicemail, Invalid Number / No Fit). "Customer Visit" doesn't exist. An admin must add the new values (they also appear for normal Task entry). | e.g. Customer Visit, Online Meeting, Phone Call, Demo, Other — BA to finalise | |
| Q-A3 ⚑ | Confirm the fields: Account*, Activity Type*, Date*, Comments | Mockup fields. Subject auto-built as "<Type> – <Account>". | Confirm; Comments required? | |
| Q-A4 | Date: past and today only, or future too (planned activities)? | Completed vs planned changes Status. | Past and today only (`Completed`) | |
| Q-A5 | Link the activity to the Account only, or also to an Opportunity / Contact? | Extra pickers add scope. | Account only in phase 1 | |
| Q-A6 | Photos / attachments? | Not in plan (adds scope). | Not in phase 1 | |
| Q-A7 | Who should own the Task? | With Option B the rep who submits is the owner (mockup "Assigned To Roj"). | The submitting rep | |

## 3. Update Opportunity

| # | Question | Context / options | Recommendation | Answer |
|---|---|---|---|---|
| Q-O1 ⚑ | Which fields can reps edit? (G3) | Mockup: Stage, Amount, Next Step. Other candidates: Close Date, Your Win Confidence, Next Step Due Date. Fields come from a field set, so admins can change this later without code (D-21). | Stage, Amount, Next Step, Close Date | |
| Q-O2 ⚑ | Which "Next Step" field do reps use? (D-12) | Two fields are labelled "Next Step": standard `NextStep` and custom `Next_Step_Custom__c` (+ `Next_Step_Due_Date__c`). Flows stamp "Next Step updated" dates. | Whichever the sales team uses in reports | |
| Q-O3 ⚑ | Which stages can be chosen? | Org stages: 01. Before 1st MTG, 02. Early Stage, 03. Final Proposal, 08.Closed Won, 08.Closed Lost. Closing needs extra fields (signed contract + win reason; lost reason + detail) by active validation rules. | Open stages 01–03 only; close in Salesforce | |
| Q-O4 ⚑ | Moving to Stage 02+ requires **PreSales Engineer** (active validation rule). Add it to the form? | Without it, reps will see the error and can't save. | Add PreSales Engineer to the form | |
| Q-O5 | Labels: the org calls `Amount` "Target TCV" and stages have numbers. OK to show the org's labels as-is? | Form shows Salesforce labels automatically. | Yes | |
| Q-O6 | Which Opportunities appear in the list? | Own only / all open on the Account / all visible. | All open on the Account that the rep can see | |
| Q-O7 | Create new Opportunities from LINE? | Not in plan (adds scope). | Not in phase 1 | |

## 4. Account search

| # | Question | Context / options | Recommendation | Answer |
|---|---|---|---|---|
| Q-C1 | Search which fields? | Name only, or also English/Thai/Japanese names, customer code, phone. | Name (+ customer code if one exists). Built so admins can add fields without code (field set, `SETUP-GUIDE.md` part H); the sandbox has *Account Name (TH)* and *Account No.*, and duplicate names (e.g. "mo7 company" ×4) — showing a second field helps tell them apart | |
| Q-C2 | Show only the rep's own Accounts, or all they can see? | Security is the same either way (runs as the rep). | All visible | |
| Q-C3 | Roughly how many Accounts? | Affects search approach. | | |
| Q-C4 | Create an Account when none is found? | Not in plan (adds scope). | Not in phase 1 | |

## 5. Login, linking and security

| # | Question | Context / options | Recommendation | Answer |
|---|---|---|---|---|
| Q-L1 | How long does a link last? | Forever until unlinked, or re-confirm every N months. | Until unlinked or user deactivated | |
| Q-L2 | Who unlinks reps when they leave or change phones? | Admin list view + automatic unlink on deactivation are planned. | Salesforce admin | |
| Q-L3 | Should the one-time login happen **inside LINE** (as in the mockup) or in the phone's browser? (G4, D-15) | In-app: matches the mockup, rep returns to the form automatically. External browser: may reuse an existing Salesforce login. | **Tested 2026-10-29:** the phone's browser works well (plain page, back to LINE with one tap). Keep the browser unless the BA wants the in-app look | |
| Q-L4 | (Info) After linking, reps never log in again unless unlinked, deactivated or permission removed — there is no session expiry. OK? (G5) | Mockup says "re-authentication when session expires"; our design is stricter and simpler. | Confirm; update slide wording | |
| Q-L5 | What should the "connected" screen show? (G6) | Mockup shows the raw LINE User ID. | LINE display name ↔ Salesforce name | |
| Q-L8 | When a second LINE account logs in as the same rep: keep **latest wins** (old link ended automatically) or **first wins** (refuse until an admin unlinks)? Notify on replacement? | Explained in `BA-FAQ.md` §4. | Latest wins, no notification in phase 1 | |
| Q-L6 | Is MFA required for reps in **production**? Any SSO planned? | Sandbox has no SSO and no MFA permission; production must be checked before go-live. | | |
| Q-L7 | Any company policy on business data shown inside LINE? | Forms show Account and Opportunity names/amounts. | | |

## 6. Notifications (extra scope)

| # | Question | Context / options | Recommendation | Answer |
|---|---|---|---|---|
| Q-M1 | Send a LINE confirmation message after each submit? | Needs the Messaging API token and a webhook-free push; extra scope. | Not in phase 1 (success screen is enough) | |
| Q-M2 | Reminders / daily summaries? | Extra scope. | Later phase | |

## 7. LINE account and ownership

| # | Question | Context / options | Recommendation | Answer |
|---|---|---|---|---|
| Q-N1 | Official Account name: "Salesforce Reporting" (mockup) or "Sales Reporting"? (G7) | "Salesforce" in the name may need a trademark check. | "Sales Reporting" / 営業報告 | |
| Q-N2 | Who owns the company LINE Business ID / provider and will create the OA and channels? | Provider choice is irreversible (`LINE-SETUP.md` §0). | | |
| Q-N3 | Who designs the rich menu image? | Two buttons: Log Activity / 訪問報告, Update Opportunity / 商談更新. | | |
| Q-N4 | Verified (blue badge) account needed? | Not needed for internal use. | No | |
| Q-N5 | Welcome message text | Mockup: "Welcome to Salesforce Reporting! Please use the menu below to log your activity or update opportunity." | Use mockup text (with final OA name) | |

## 8. Testing

| # | Question | Context / options | Recommendation | Answer |
|---|---|---|---|---|
| Q-T1 | Test users: which reps (with full Salesforce licence) and LINE accounts for device QA? | Needed from L2; LINE testers must be added while the channel is "Developing". | 2 reps (1 iOS, 1 Android) | |
| Q-T2 | Who runs UAT and when? | L8. | | |

---

## After the session

1. Record each answer above, then update `DECISIONS.md` (D-11, D-12, D-13 → Decided; D-15 if Q-L3 changes it).
2. Apply `MOCKUP-REVIEW.md` gaps G1–G8 to `L0-SPEC.md` §7, `DATA-DICTIONARY.md` §3/§3a and the field sets.
3. Ask an admin to add the agreed Task `Type` values (Q-A2) in the sandbox first.
