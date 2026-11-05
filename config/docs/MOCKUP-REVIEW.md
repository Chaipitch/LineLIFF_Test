# Mockup review — 2026-10-29

Review of the two concept images against the plan (2026-10-29). Each gap is recorded here and turned into a question in
`BA-QUESTIONS.md`. G4 and G6 were settled by the L3 build; G1–G2 by L5a and G3 by the BA's field list (D-46, 2026-11-03). Once the BA
answers, the spec, decisions log, data dictionary and field sets are updated together.

| Image | File |
|---|---|
| Overview: user flow, data in Salesforce, architecture, capabilities | `images/mockup-1-overview.webp` |
| One-time login and user mapping | `images/mockup-2-login-mapping.webp` |

## 1. Aligned with the plan

| Mockup | Plan |
|---|---|
| Rich menu with Log Activity / Update Opportunity, each opening a LIFF form | LIFF app with two forms (`L0-SPEC.md` §1, §3) |
| Welcome message on first open | Greeting message (`LINE-SETUP.md` §2) |
| Account auto-complete while typing, selection bound to Account ID | Debounced search, ≤ 10 results, Account ID stored (§4, L4) |
| LIFF → Apex REST → Salesforce, no middleware | Same architecture |
| "Assigned To Roj", "Last Modified By Roj" | Option B (D-02): records are written **as the rep** |
| One-time login, then no repeat logins | Link flow (L3), no further logins |
| User Mapping Table (LINE User ID ↔ Salesforce User) | `SalesReport_Line_Link__c` (D-08) |
| Opportunity dropdown filtered by the selected Account | `GET /opportunities?accountId=` (all the Account's Opportunities, open first, D-53) |
| Success screen with "Back to Menu" | **Built (L5a):** "Activity saved: <subject>" with *Log another activity* and *Close* (back to the chat) |
| Task subject "Customer Visit – Toyota Motor Thailand" | **Built (L5a):** Subject from Type label + Account name (`L0-SPEC.md` §7); needs the visit types in Task `Type` (Q-A2) |

## 2. Gaps (status 2026-11-02 — open items in `BA-QUESTIONS.md`)

| # | Gap | Mockup | Current plan | Org fact | Suggested resolution | Question |
|---|---|---|---|---|---|---|
| G1 | Activity object (D-11) | **Task**, Type "Customer Visit", Due Date, Comments | Leaning Event | Task `Type` has only call outcomes, no "Customer Visit"; Event `Type` has "On-site / Visit". The Task flow `Auto_Generate_Call_Subject` only runs for `TaskSubtype = Call`, so it won't overwrite our subject. | **Decided 2026-10-30: Task** (D-11), Subtype `Task`, Status from the date (D-32); admin adds visit types to Task `Type` | Q-A1, Q-A2 |
| G2 | Log Activity fields | Account, Activity Type, Date, Comments | Event fields incl. start time / duration | — | **Built (L5a):** Type, Date (`ActivityDate`, no time), Comments (`Description`) from field set `SalesReport_Activity_Form`; required flags follow Salesforce (D-31). Labels show as Salesforce's ("Due Date Only", "Description") until an admin renames them | Q-A3 |
| G3 | Update Opportunity fields | Stage, Amount, Next Step | + Win Confidence, Close Date, Next Step Due Date | Stage values are `01. Before 1st MTG`, `02. Early Stage`, `03. Final Proposal`, `08.Closed Won/Lost` (no "Proposal"); Stage ≥ 02 requires `PreSales_Engineer__c` (active VR); two "Next Step" fields (D-12) | Start the field set with Stage, Amount, Next Step; add PreSales Engineer (else reps hit the VR) and Close Date if agreed — **BA answered 2026-11-03: Stage, Amount, Main PreSales Engineer (searchable lookup), Next Step (custom), Next Step Due Date — built (D-46), always on (D-49)** | Q-O1 … Q-O4 |
| G4 | Where the login page opens (D-15) | Entirely inside LINE, ends on "Successfully connected!" | External browser first | — | **2026-11-02:** in-LINE login tried (D-40) but LINE's browser can't do passkeys (D-41) → login opens in the phone's browser right away, and Connect returns to the form in LINE (D-42) | Q-L3 |
| G5 | "OAuth" / "re-authentication when session expires" wording | Mockup implies an OAuth session that can expire | One normal Salesforce login to link; afterwards a fresh session is minted per request (JWT, D-16); nothing stored | — | Reword slide: re-login only if unlinked, deactivated or permission removed | Q-L4 (info) |
| G6 | "Connected" screen shows raw LINE User ID | `U1234567890 ↔ Roj` | — | — | **Built that way in L3:** the confirm page shows the LINE display name and the Salesforce name; the raw ID is never shown | Q-L5 |
| G7 | OA name | "Salesforce Reporting" | "Sales Reporting" (`LINE-SETUP.md`) | — | Pick one; "Salesforce" in an OA name may need a trademark check | Q-N1 |
| G8 | Stage example "Proposal", Amount label | "Proposal", "Amount" | Org labels: stage codes; `Amount` is labelled "Target TCV" | — | Form uses the org's labels automatically (field set + describe) | Q-O5 (info) |
