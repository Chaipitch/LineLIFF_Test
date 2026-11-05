# Sales Report in LINE — user guide for sales reps

Log your customer activities and update your opportunities from LINE, without opening Salesforce. Everything you save
goes straight into Salesforce under **your own name**, exactly as if you had entered it there.

Last updated 2026-11-04. Screen texts below are the real ones (English).

---

## Before you start

You need:

- the **LINE app** on your phone, and the company's **Sales Reporting** LINE Official Account added as a friend;
- your normal **Salesforce login** (the same username, password and verification you use today);
- the **Sales Report User** access in Salesforce — your administrator gives it. Without it you will see *"Your
  Salesforce user is not set up for Sales Report. Please ask your administrator."*

## The menu

Open the Sales Reporting chat in LINE. At the bottom you see two buttons:

| Button | What it does |
|---|---|
| **Log Activity** | Records a visit, call or meeting as a Salesforce activity on a customer Account |
| **Update Opportunity** | Updates the stage, amount, PreSales engineer and next step of one of an Account's open deals |

---

## 1. First time only — connect your Salesforce login

The first time you tap a button, Sales Report needs to know who you are in Salesforce.

1. Tap **Log Activity** (or **Update Opportunity**).
2. Your phone's **browser** (Safari or Chrome) opens the Salesforce login page. LINE shows *"Finish logging in to
   Salesforce in your browser, then come back here."*
3. Log in to Salesforce as usual — password, authenticator app, passkey or Face ID all work.
4. A page **Connect LINE to Salesforce** asks: *Connect the LINE account "<your LINE name>" to your Salesforce user
   <your name>?* Check that both names are yours, then tap **Connect**.
5. LINE opens again on the form you chose. Done.

You **never need to log in again** after this — not even when you restart your phone. Only if your administrator
disconnects you, or your Salesforce user changes, will LINE ask you to log in once more.

**Good to know**

- If the browser didn't open, or you closed it, tap **Log in to Salesforce** in LINE to open it again.
- The login link is valid for **5 minutes**. If it expired you see *"This link has expired or was already used. Open
  the form in LINE and try again."* — just tap the menu button again.
- Only tap **Connect** on a page **you opened yourself** from the LINE menu. Never on a link someone sent you.
- Your Salesforce password is typed only on Salesforce's own page. Sales Report never sees or stores it.

**If you see "already linked"**

*"This Salesforce user is already linked to another LINE account. Please contact your administrator…"* — your
Salesforce user is still connected to another LINE account (for example on your old phone). Ask your administrator to
**revoke** the old connection, then try again. The same applies to *"This LINE account is already linked to another
Salesforce user."*

---

## 2. Log an activity

1. Tap **Log Activity**. The top of the form shows *Salesforce: <your name>* — check it's you.
2. **Account**: type at least **2 letters** of the customer's name, then tap the right Account in the list. Only
   Accounts you can see in Salesforce appear. Tapped the wrong one? Tap **Change**.
3. Fill in the fields — for example **Type**, **Date** and **Comments**. Fields marked **\*** are required.
   - The date can be today, in the past or in the future. A past or today's date is saved as **Completed**; a future
     date is saved as a planned (**Open**) activity.
4. Tap **Save**. You see *"Activity saved: <Type> – <Account>"* and, below it, everything you saved (Account and each
   field) so you can check it.
5. Tap **Log another activity** or **Close**.

The activity appears in Salesforce on the Account's activity timeline, with you as the creator. Its subject is the
type plus the Account name, e.g. *"Customer Visit – Toyota Motor Thailand"*.

> **Photos and files**: after filling in the form, tap **Add photo or file**. The red line under *Photos and files*
> shows the limits — up to 5 files, 4 MB each, JPG, PNG or PDF. Photos are shrunk automatically. If a file fails after the activity was
> saved, tap **Try again**; the activity itself is already safe.

---

## 3. Update an opportunity

1. Tap **Update Opportunity**.
2. **Account**: type at least 2 letters and choose the customer.
3. **Opportunity**: tap one of the Account's **open** deals (shown with its stage and close date). If you see *"No open
   opportunities for this account."*, there is nothing to update for that customer.
4. The form shows the deal's **current values**. Change what you need:

| Field | Notes |
|---|---|
| **Stage** | All stages, including **04. Closed Won** and **05. Closed Lost** |
| **Target TCV** (Amount) | Numbers only |
| **Main PreSales Engineer** | Type 2+ letters of a name and pick the person. **Change** clears it |
| **Next Step** | What happens next |
| **Next Step Due Date** | When it is due |

5. Tap **Save**. You see *"Opportunity updated: <deal name>"* and, below it, the values now in Salesforce (Account,
   Opportunity and each field).

Salesforce's own rules still apply. For example, moving a deal to **Stage 02 or later** needs a **Main PreSales
Engineer**, and closing it as **Won** or **Lost** needs details such as the signed contract or the lost reason. If
something is missing you see *"Salesforce couldn't save your changes:"* followed by Salesforce's message — complete it in
Salesforce if the field isn't on this form.
Fix the field and tap **Save** again — nothing was changed.

---

## 4. Messages and what to do

| You see | What it means | What to do |
|---|---|---|
| *Please check the highlighted fields.* | A required field is empty or a value is wrong | Fix the fields marked in red, then **Save** |
| *Choose an Account first.* / *Choose an opportunity first.* | Nothing chosen yet | Choose one, then **Save** |
| *No matching accounts* / *No matches* | Nothing you can see matches what you typed | Try fewer or different letters |
| *Salesforce couldn't save your changes:* … | A Salesforce rule stopped the save | Read Salesforce's message, fix the field, **Save** again |
| *A Salesforce rule couldn't run, so nothing was saved…* | A problem in Salesforce itself, not your input | Send the message to your administrator |
| *Your Salesforce user can't open this data.* | Your Salesforce licence or access doesn't include this (e.g. Opportunities) | Ask your administrator |
| *Your Salesforce user is not set up for Sales Report.* | You don't have the Sales Report User access | Ask your administrator |
| *Too many requests. Please wait a minute and try again.* | Very many taps in one minute | Wait a minute |
| *Your session expired. Reopening…* | LINE refreshes your sign-in | Nothing — the form reopens by itself |
| *Something went wrong. Please try again.* **Reference: …** | Unexpected error | Try again. If it keeps happening, send the **Reference** to your administrator — it lets them find exactly what happened |
| *Can't reach Salesforce. Check your internet connection and try again.* | No signal, or Salesforce didn't answer in time | Check your connection and tap **Save** again — what you typed is kept. If you were saving, check in Salesforce first that it wasn't saved already |
| *The service is temporarily unavailable.* | Sales Report is not reachable right now | Try again later |
| *Please open this page from the Sales Reporting menu in LINE.* | The page was opened outside LINE | Use the menu in the LINE chat |

## 5. New phone, new LINE account, or leaving

- **New phone, same LINE account** (LINE transferred): nothing to do.
- **New LINE account**: ask your administrator to **revoke** your old connection, then connect again (section 1).
- **Lost phone**: tell your administrator straight away so they revoke the connection.
- **Leaving the company**: your access ends automatically when your Salesforce user is deactivated.

## 6. Privacy

- Sales Report knows your LINE display name and LINE ID only to connect you to your Salesforce user.
- It never stores your Salesforce password or session.
- What you save is visible in Salesforce exactly like anything else you enter there, to the same people.
