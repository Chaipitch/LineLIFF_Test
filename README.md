# LINE Sales Reporting (LIFF → Salesforce)

Sales reps open a small form from a LINE Official Account's rich menu and record their work in Salesforce without
leaving LINE:

- **Log Activity** — a Task on the chosen Account (photos/files supported, switched off for now).
- **Update Opportunity** — waiting on the BA (L5c).

Reps log in to Salesforce once; after that every save runs **as the rep** (JWT bearer, "Option B"), so sharing,
field-level security, validation rules and "Created By" are Salesforce's own. No middleware: LINE app → LIFF page on a
public Salesforce Site → Apex REST → LINE ID-token verify + the org's REST API as the rep.

Status, 2026-11-02: L0–L5b and L7 done in sandbox `dev5`; L5c, L6 and L8 to come (`config/docs/IMPLEMENTATION-PLAN.md`).

## Folders

| Path | What |
|---|---|
| `sales-report/main/default/` | All Salesforce metadata of the feature (own package directory, packaging-ready — `COEXISTENCE.md` §3) |
| `liff-app/` | LIFF front-end source (`src/`), bundled with esbuild into the static resource `SalesReport_LiffApp` |
| `scripts/apex/` | One-off anonymous Apex: schedule the nightly cleanup, link-code benchmarks |
| `config/docs/` | Specification, decisions, guides (below) |

## Build, deploy, test

```bash
npm install
```

```bash
npm run build:liff
```

```bash
sf project deploy start -o lineliff-sbx --source-dir sales-report --test-level RunSpecifiedTests $(ls sales-report/main/default/classes/*Test.cls | xargs -n1 basename | sed 's/.cls$//' | sed 's/^/--tests /')
```

New org: deploy `sales-report/main/default/objects` first, follow `config/docs/SETUP-GUIDE.md` (Site, settings,
certificate, External Client App, LIFF app), then schedule the cleanup once:

```bash
sf apex run -o <alias> -f scripts/apex/schedule-cleanup.apex
```

## Documents (`config/docs/`)

| File | For | Contents |
|---|---|---|
| `SETUP-GUIDE.md` | Admins, BA | What each setup part is for, exact steps, device tests, day-to-day tasks |
| `L0-SPEC.md` | Developers | Scope, org findings, architecture, API, data model, classes, security |
| `REST-ENDPOINTS.md` | Developers, admins | How each REST endpoint works step by step; checklist for adding one |
| `DECISIONS.md` | Everyone | Decision log D-01 … D-38 and what is still open |
| `IMPLEMENTATION-PLAN.md` | Everyone | Milestones L0–L8, task status, dependencies |
| `DATA-DICTIONARY.md` | Admins, developers | Objects, fields, settings, labels, permissions, Site/ECA settings |
| `FILE-INVENTORY.md` | Developers | Every file and org component, with status |
| `BA-QUESTIONS.md` | BA | Open questions with recommendations; Thai checklist at the end |
| `BA-FAQ.md` | BA, non-technical readers | Plain-language answers (objects, linking, unlinking) |
| `COEXISTENCE.md` | Developers | No clash with the LINE Connect package; packaging rules |
| `LINE-SETUP.md` | Admins | LINE OA and channel setup (L1) |
| `ENVIRONMENTS.md` | Admins | Non-secret configuration values per org |
| `MOCKUP-REVIEW.md` | BA | Concept mockups vs what is built |
| `HANDOFF.md` | — | Original brief (historical; superseded by the documents above) |

No secrets are stored in this repository.
