# BA FAQ — LINE Sales Reporting

Plain-language answers to questions from the BA. Technical detail: `DATA-DICTIONARY.md` (objects and fields),
`DECISIONS.md` (D-xx). Last updated 2026-10-29.

---

## 1. Where do we keep the LINE ↔ Salesforce user mapping — on User or in a custom object?

In a **custom object, `SalesReport_Line_Link__c` ("Sales Report LINE Link")**, not on the User object (D-08).

One record per LINE account holds: LINE User ID (from LINE's verified login, unique), Salesforce User, Status
(Active / Unlinked), LINE display name, and when/why it was linked or unlinked. Changes to User and Status are tracked
in field history.

Why not a field on User:

- **Security** — reps get no access to these records; only Sales Report's code writes them (D-19), so nobody can edit a
  mapping by hand to act as someone else. A User field is harder to lock down.
- **History** — a separate record keeps who was linked, when, and why it ended (new phone, admin, deactivated user).
- **Admin view** — its own tab, *Sales Report LINE Links*, with "Active links" / "All links". To disconnect a rep, set
  Status to Unlinked.
- **No changes to User** — the org already has a lot of automation (and LINE Connect); our own object keeps the feature
  separate and easy to remove or package later.
- **Rules enforced by the database** — one active LINE account per rep, one rep per LINE account.

Trade-off: the link isn't a field on the User record page. If wanted, add the "Sales Report LINE Links" related list
to the User page layout — no data change needed.

## 2. What is each Sales Report object for?

| Object | Simple description | Who uses it |
|---|---|---|
| **Sales Report LINE Link** | The **contact book**: "this LINE account belongs to this Salesforce user". Created once, the first time a rep logs in to Salesforce from LINE; checked every time the rep opens the form, so they never log in again. | System every request; admins to see or disconnect reps |
| **Sales Report Link Code** | The **one-time ticket** used during that first login to connect it to the rep's LINE account. Works once, expires after 5 minutes, stored only as a scrambled fingerprint. Old ones are cleaned up automatically. | System only, in the background |
| **Sales Report Log** | The **logbook** of errors and warnings, for when something goes wrong. Never stores passwords, tokens or full LINE IDs. Old entries are deleted after 30 days. | Admins when investigating a problem |

In one line: the **Link Code** proves who you are once, the **LINE Link** remembers you, the **Log** records problems.

## 3. Why can't we combine the LINE Link and the Link Code?

We could, but keeping them separate is simpler and safer: they hold different kinds of data with different lifetimes.

| | LINE Link | Link Code |
|---|---|---|
| What it is | A confirmed fact: "this LINE account = this rep" | A temporary ticket: "someone is trying to log in" |
| Created when | The rep has logged in to Salesforce and tapped **Connect** | The rep taps "Log in to Salesforce", before we know who they are in Salesforce |
| Lives | As long as the rep uses the tool | 5 minutes, then useless and deleted |
| How many | One per rep | Several per rep (every attempt, retry, expired try) |
| Trusted for | Every request: "who is this rep?" | Only the login page, once |

Problems if combined:

1. **Unverified data in the trusted table** — a code exists before the rep has proven who they are; every check would
   have to tell "pending" from "really linked", and a mistake there could let someone in.
2. **Changing phones** — the old phone's link stays active until the new login completes; one table would make those
   rules messier.
3. **Cleanup** — expired codes are deleted daily; links must never be deleted that way. Separate objects make the
   cleanup job impossible to get wrong.
4. **Admin view** — admins see only real links, not hundreds of expired login attempts.

Possible, yes (extra "pending" fields on LINE Link plus more rules in code), but it saves one object and adds
complexity and risk. Common login designs keep the short-lived "login attempt" apart from the permanent "account link".
**Recommendation: keep two objects.**

## 4. What if two LINE accounts try to log in as the same Salesforce user?

**Rule: one Salesforce user has one active LINE account. The latest confirmed login wins.**

| Step | What happens |
|---|---|
| Phone A links to Roj | Link A is active |
| Phone B logs in **as Roj** and taps **Connect** | Link B becomes active; Link A is set to **Unlinked**, reason "Replaced by new LINE account" |
| Phone A opens the form again | Sees **Connect Salesforce** again — it can no longer act as Roj |

- **At the same moment** — the database allows only one active link per user, so one goes first and the other replaces
  it. There are never two active links for one user.
- **It needs Roj's own login** — phone B must log in with Roj's Salesforce username, password and MFA, and tap Connect
  on a page that shows which LINE account is being connected. No one can take over without Roj's credentials.
- **Visible to admins** — the *Sales Report LINE Links* tab shows the old link as Unlinked with reason and time; field
  history records the change.
- **Reverse case** — one LINE account logging in as two different Salesforce users also follows "latest wins": the LINE
  account moves to the second user.
- **A different LINE Official Account** — only the Sales Reporting OA's LIFF app can start a login. A login token from
  any other OA or LINE channel (including LINE Connect's) fails our check, because LINE ties each token to our channel ID.

**Open choice for the BA:** "latest wins" suits reps who change phones (no admin needed). Alternative: "first wins" — a
second phone is refused until an admin unlinks the first. Small change either way. Optional extra: notify the rep/admin
when a link is replaced (extra scope).

## 5. Is the Sales Report Link Code a token?

**Yes — a one-time token**: the "login ticket" carried from LINE to Salesforce. A very limited one:

- Created when the rep taps "Log in to Salesforce"; it remembers which LINE account started the login.
- Travels in the link to the Salesforce login page; after the rep logs in and taps **Connect**, it's used once to
  connect that LINE account to that Salesforce user, then it's spent.
- **Can't access anything by itself** — only useful together with a real Salesforce login and a tap on Connect.
- **Single use, 5 minutes**, stored only as a scrambled fingerprint (SHA-256), so even an admin can't read a usable code.

Closest standard comparison: a one-time verification link, or the "state"/authorization code in an OAuth login.

The other tokens in the system, for comparison (neither is stored):

| Token | From | Purpose | Lifetime |
|---|---|---|---|
| **Link Code** (our object) | Sales Report | Connect a LINE account to a Salesforce user, once | 5 min, single use |
| **LINE ID token** | LINE | Proves "this request comes from LINE user X", on every request | 1 hour, refreshed by LINE |
| **Salesforce access token** | Salesforce (JWT flow) | Lets the system act **as the rep** for one request | Used and discarded within the request |

So the Link Code only matters at the very first connection. Day to day, the LINE ID token and the Salesforce access
token do the work, and the LINE Link record says which rep it is.
