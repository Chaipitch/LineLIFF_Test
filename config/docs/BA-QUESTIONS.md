# Questions for the BA — LINE Sales Reporting

**For:** the BA session (date: ________ · attendees: ________).
**How to use:** go through the sections in order; write the answer in the last column. Items marked **⚑ blocks L5**
must be answered before the forms are built; the rest can follow. Where we have a recommendation it is given, so the BA
can simply confirm. Context: `L0-SPEC.md`, `DECISIONS.md` (D-xx), `MOCKUP-REVIEW.md` (G-x, with the two mockup images).

Org facts quoted below come from the read-only check of sandbox `dev5` on 2026-10-28.
**ภาษาไทย:** a Thai checklist of the open questions, in priority order, is at the end of this file (updated 2026-11-04).

---

## 1. Scope and people

| # | Question | Context / options | Recommendation | Answer |
|---|---|---|---|---|
| Q-S1 ⚑ | Which reps will use the tool, and how many? | Every rep needs an active Salesforce user. **Opportunities need a full "Salesforce" licence**: the org has 9 active Salesforce and 18 "Salesforce Platform" users; Platform users can log activities but **cannot see or update Opportunities** (D-13). | List the users; confirm each has a Salesforce licence if they need Update Opportunity | |
| Q-S2 | Target go-live date and who signs off? | Plan is 20–26 working days after L1 values arrive. | | |
| Q-S3 | UI languages? | JA / EN / TH. Org default locale is ja_JP, users in Thailand. | All three, following the phone's LINE language | **Answered 2026-11-04 (user): English only** (D-47). |
| Q-S4 | Internal only in this phase? | Built unpackaged but packaging-ready (D-06). | Yes, internal only | |
| Q-S5 | Confirm the 5 acceptance scenarios | Draft in `L0-SPEC.md` §9 (link once; search; log activity; VR error shown; unlink). | Confirm / add | |

## 2. Log Activity

| # | Question | Context / options | Recommendation | Answer |
|---|---|---|---|---|
| Q-A1 ⚑ | Record visits as **Task** or **Event**? (D-11, G1) | Mockup shows **Task**. Event fits time-bound meetings and triggers the org's Slack note + Opportunity meeting-count flows; Task fits "something done on a date". | **Task** (as in the mockup), Status `Completed` | **Task** — answered 2026-10-30 (D-11) |
| Q-A2 ⚑ | Which **Activity Type** values should reps choose from? | Task `Type` today has only call outcomes (Connected – Had Conversation, Busy / Call Back, Not Connected / Voicemail, Invalid Number / No Fit). "Customer Visit" doesn't exist. An admin must add the new values (they also appear for normal Task entry). | e.g. Customer Visit, Online Meeting, Phone Call, Demo, Other — BA to finalise | |
| Q-A3 ⚑ | Confirm the fields: Account*, Activity Type*, Date*, Comments | Mockup fields. Subject auto-built as "<Type> – <Account>". | Confirm; Comments required? | Follow Salesforce: required = required on the rep's layout, in the database or in the field set; validation rules run on save (D-31) — 2026-10-30 |
| Q-A4 | Date: past and today only, or future too (planned activities)? | Completed vs planned changes Status. | Past and today only (`Completed`) | **Not restricted**: past, today and future; future → `Open`, otherwise `Completed` (D-32) — 2026-10-30 |
| Q-A5 | Link the activity to the Account only, or also to an Opportunity / Contact? | Extra pickers add scope. | Account only in phase 1 | **Account only** (D-33) — 2026-10-30 |
| Q-A6 | Photos / attachments? | Not in plan (adds scope). | Not in phase 1 | **Yes, attachments in scope** (D-34) — limits in Q-A6a — 2026-10-30. Built; switched off 2026-11-02, **on again 2026-11-04** until confirmed |
| Q-A6a | Attachment limits: how many files per activity, max size, which types? | Files are stored on the Task as Salesforce Files and count against file storage (sandbox `dev5`: 59 MB free of 200 MB). Photos are shrunk on the phone before upload. | 5 files, 4 MB each after resizing, photos (camera or gallery) + PDF | |
| Q-A7 | Who should own the Task? | With Option B the rep who submits is the owner (mockup "Assigned To Roj"). | The submitting rep | |

## 3. Update Opportunity

| # | Question | Context / options | Recommendation | Answer |
|---|---|---|---|---|
| Q-O1 ⚑ | Which fields can reps edit? (G3) | Mockup: Stage, Amount, Next Step. Other candidates: Close Date, Your Win Confidence, Next Step Due Date. Fields come from a field set, so admins can change this later without code (D-21). | Stage, Amount, Next Step, Close Date | **Answered 2026-11-03:** Account → Opportunity (choose), Stage, Amount, Main PreSales Engineer, Next Step (custom), Next Step Due Date. Built (D-46); Close Date no longer on the form. |
| Q-O2 ⚑ | Which "Next Step" field do reps use? (D-12) | Two fields are labelled "Next Step": standard `NextStep` and custom `Next_Step_Custom__c` (+ `Next_Step_Due_Date__c`). Flows stamp "Next Step updated" dates. | Whichever the sales team uses in reports | **Answered 2026-11-03:** custom `Next_Step_Custom__c` (+ `Next_Step_Due_Date__c`) (D-46). |
| Q-O3 ⚑ | Which stages can be chosen? | Org stages: 01. Before 1st MTG, 02. Early Stage, 03. Final Proposal, 08.Closed Won, 08.Closed Lost. Closing needs extra fields (signed contract + win reason; lost reason + detail) by active validation rules. | Open stages 01–03 only; close in Salesforce | **Answered 2026-11-05 (user): all active stages, incl. 04. Closed Won and 05. Closed Lost**; when a validation rule stops the save, its message is shown (D-52). |
| Q-O4 ⚑ | Moving to Stage 02+ requires **PreSales Engineer** (active validation rule). Add it to the form? | Without it, reps will see the error and can't save. | Add PreSales Engineer to the form | **Answered 2026-11-03:** yes — on the form as a search box of active Users (D-46). |
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
| Q-L2 | Who unlinks reps when they leave or change phones? | Built: **Revoke** button on the link in the *Sales Report LINE Links* tab, and automatic unlink when the user is deactivated (D-44). | Salesforce admin | **Answered** in the BA architecture document v1.0 (2026-11-03): an administrator revokes. |
| Q-L3 | Should the one-time login happen **inside LINE** (as in the mockup) or in the phone's browser? (G4, D-15) | In-app: matches the mockup, rep returns to the form automatically. External browser: may reuse an existing Salesforce login. | **Tested 2026-10-29:** the phone's browser works well (plain page, back to LINE with one tap). Keep the browser unless the BA wants the in-app look | **Phone's browser, opened right away; back to the form in LINE after Connect** — 2026-11-02 (D-42; in-LINE login dropped because of passkeys) |
| Q-L4 | (Info) After linking, reps never log in again unless unlinked, deactivated or permission removed — there is no session expiry. OK? (G5) | Mockup says "re-authentication when session expires"; our design is stricter and simpler. | Confirm; update slide wording | |
| Q-L5 | What should the "connected" screen show? (G6) | Mockup shows the raw LINE User ID. | LINE display name ↔ Salesforce name | |
| Q-L8 | When a second LINE account logs in as the same rep: keep **latest wins** (old link ended automatically) or **first wins** (refuse until an admin unlinks)? Notify on replacement? | Explained in `BA-FAQ.md` §4. | Latest wins, no notification in phase 1 | **Answered** in the BA architecture document v1.0 (2026-11-03): **first wins** — refuse, "contact your administrator", keep the existing link, log WARN. Built (D-44). |
| Q-L9 | Status of an ended link: **Revoked** = ended by an administrator, **Unlinked** = ended automatically (Salesforce user deactivated). OK? | Built this way (D-44); the BA document lists the three values but not the rule. | As built | |
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

---

## ภาษาไทย — Checklist สำหรับ BA (อัปเดต 2026-11-02)

**สถานะตอนนี้:** Log Activity ใช้งานได้แล้วบนมือถือ (บันทึก Task + แนบรูป/ไฟล์) ส่วนที่ยังรอคำตอบคือ
**Update Opportunity** และค่าบางอย่างที่เราใส่ค่าเริ่มต้นไว้ก่อน ช่วยติ๊ก ☐ หรือเขียนคำตอบต่อท้ายแต่ละข้อได้เลย
(รหัสในวงเล็บอ้างอิงตารางภาษาอังกฤษด้านบน)

### 🔴 Update Opportunity — สร้างแล้วตามค่าที่เสนอ (2 พ.ย.) ข้อ 1–7 เปลี่ยนได้ใน Setup โดยไม่ต้องแก้โค้ด

> ตอนนี้ฟอร์มใช้: Stage, Amount (Target TCV), Next Step (`NextStep` มาตรฐาน), Close Date — เลือก Stage ได้เฉพาะ 01–03
> แสดงดีลที่ยังเปิดอยู่ของ Account ที่ Rep มองเห็น — PreSales Engineer เป็นฟิลด์ lookup ยังแสดงในฟอร์มไม่ได้
> ถ้าไม่กรอก ระบบจะแสดงข้อความ validation rule แทน

1. ☐ **Rep คนไหนบ้างที่จะใช้?** ขอรายชื่อ — ⚠️ การดู/แก้ Opportunity ต้องใช้ license **Salesforce เต็ม**
   ซึ่งตอนนี้ใช้ครบทั้ง 9 license แล้ว คนที่เป็น **Salesforce Platform** บันทึกกิจกรรมได้ แต่**มองไม่เห็น Opportunity** (Q-S1, D-13)
2. ✅ ตอบแล้ว (3 พ.ย.): ฟิลด์ที่แก้ได้ = Stage, Amount (Target TCV), Main PreSales Engineer, Next Step, Next Step Due Date (Q-O1, D-46)
3. ✅ ตอบแล้ว (3 พ.ย.): ใช้ `Next_Step_Custom__c` และ `Next_Step_Due_Date__c` (Q-O2, D-46)
4. ✅ ตอบแล้ว (5 พ.ย.): **เลือกได้ทุก Stage** รวม 04. Closed Won / 05. Closed Lost — ถ้าติด validation rule ระบบแสดงข้อความของ Salesforce (Q-O3, D-52)
5. ✅ ตอบแล้ว (3 พ.ย.): **เพิ่ม Main PreSales Engineer** ในฟอร์ม (ค้นหาชื่อ user) (Q-O4, D-46)
6. ☐ **แสดง Opportunity ไหนบ้าง?** เสนอ: ดีลที่ยังเปิดอยู่ของ Account ที่เลือก และ Rep มีสิทธิ์มองเห็น (Q-O6)
7. ☐ **แสดงชื่อฟิลด์ตาม Salesforce ได้ไหม?** เช่น Amount แสดงเป็น "Target TCV", Stage มีเลขนำหน้า → เสนอ: ได้ (Q-O5)

### 🟠 ต้องการเร็ว ๆ นี้ (กระทบสิ่งที่ใช้งานอยู่)

8. ☐ **Activity Type ให้เลือกค่าอะไรบ้าง?** ตอนนี้มีแต่ผลการโทร (เช่น "Connected - Busy / Call Back")
   ทำให้หัวเรื่อง Task ออกมาเป็น "Connected - Busy / Call Back – ชื่อลูกค้า"
   → เสนอ: Customer Visit, Online Meeting, Phone Call, Demo, Other — admin เพิ่มค่าใน Salesforce (Q-A2)
9. ☐ (เปิดใช้งานแล้ว 4 พ.ย.) **แนบไฟล์:** ตอนนี้ตั้งไว้ **ไม่เกิน 5 ไฟล์ ไฟล์ละไม่เกิน 4 MB** (รูปถูกย่อบนมือถือก่อนส่ง) รองรับ jpg / png / pdf
   → ใช้ตามนี้ได้ไหม? (ตอนนี้กำหนดตายตัวในโค้ด D-48 — ถ้าต้องการเปลี่ยนต้องแก้โค้ด; 4 MB คือค่าสูงสุดที่ระบบรองรับ) (Q-A6a)
10. ☐ **ชื่อฟิลด์ในฟอร์ม:** ตอนนี้แสดงตาม Salesforce คือ "Due Date Only" และ "Description"
    → ให้ admin เปลี่ยนชื่อเป็น "Date" / "Comments" ไหม? และ**เพิ่มฟิลด์ Activity Purpose** (มีอยู่แล้วใน org) ในฟอร์มไหม?
11. ☐ **ฟิลด์ไหนบังคับกรอก?** ตอนนี้ฟอร์มบังคับตาม Salesforce (page layout ของ Task) ซึ่งยังไม่บังคับ Type / Date / Comments
    → ต้องการให้บังคับฟิลด์ไหน admin ตั้งที่ page layout ได้เลย (Q-A3)
12. ☐ **Go-live วันไหน ใครเซ็นรับ และใครทำ UAT เมื่อไร?** (Q-S2, Q-T2)

### 🟡 ยืนยันค่าที่เราตั้งไว้ (ถ้าโอเคตอบ "ได้" ได้เลย)

13. ✅ ตอบแล้ว (2 พ.ย.): ล็อกอิน Salesforce ครั้งแรก**เปิดใน browser ของมือถือทันที** (ไม่ต้องกดปุ่มก่อน) เพราะหน้าล็อกอินใน LINE ใช้ passkey/Face ID ไม่ได้ — กด Connect แล้วกลับมาที่ฟอร์มใน LINE อัตโนมัติ (Q-L3, D-42)
14. ☐ ผูกบัญชีแล้ว**ไม่หมดอายุ** Rep ไม่ต้องล็อกอินซ้ำ จนกว่า admin จะยกเลิกการผูก หรือ user ถูก deactivate — โอเคไหม? (Q-L1, Q-L4)
15. ✅ ตอบแล้ว (เอกสาร architecture ของ BA, 3 พ.ย.): ถ้า Rep ผูก LINE บัญชีที่สองกับ user เดิม → **ปฏิเสธ** ให้ติดต่อ admin บัญชีเดิมยังใช้ได้ (Q-L8, D-44)
    ☐ **ยืนยันความหมายสถานะ:** Revoked = admin ยกเลิก, Unlinked = ระบบยกเลิกอัตโนมัติเพราะ user ถูก deactivate — โอเคไหม? (Q-L9)
16. ✅ ตอบแล้ว (3 พ.ย.): **admin เป็นคนยกเลิกการผูก** ด้วยปุ่ม **Revoke** ในแท็บ Sales Report LINE Links (Q-L2, D-44)
17. ☐ ค้นหา Account ด้วย**ชื่อเท่านั้น** และแสดงทุก Account ที่ Rep มีสิทธิ์เห็น — ต้องค้นด้วยชื่อภาษาไทย/รหัสลูกค้าด้วยไหม? (Q-C1, Q-C2)
18. ✅ ตอบแล้ว (4 พ.ย.): ภาษาหน้าจอ **อังกฤษอย่างเดียว** (Q-S3, D-47)

### 🔵 Security / นโยบาย (ตอบก่อนขึ้น production)

19. ☐ Production บังคับ **MFA** สำหรับ Rep ไหม? ใช้วิธียืนยันตัวตนแบบไหน (passkey/Face ID, Salesforce Authenticator, รหัสทางอีเมล)? มีแผนใช้ **SSO** ไหม? (Q-L6)
    (ล็อกอินเปิดใน browser ของมือถือ จึงใช้ passkey/Face ID ได้ — D-42)
20. ☐ มีนโยบายบริษัทเรื่องการแสดงข้อมูลลูกค้า/ดีลใน LINE ไหม? (Q-L7)

### ⚪ ทำทีหลังได้ (เฟสถัดไป)

21. ☐ ส่งข้อความยืนยันใน LINE หลังบันทึก / แจ้งเตือนรายวัน? (Q-M1, Q-M2)
22. ☐ สร้าง Opportunity หรือ Account ใหม่จาก LINE? (Q-O7, Q-C4)
23. ☐ ชื่อ OA, รูป rich menu, ข้อความต้อนรับ, blue badge (Q-N1, Q-N3–N5)

**ปิดแล้ว (ไม่ต้องตอบ):** บันทึกเป็น Task ✓ · วันที่ไม่จำกัด ✓ · ผูกกับ Account อย่างเดียว ✓ · แนบไฟล์ได้ ✓ ·
เจ้าของ Task = Rep ที่บันทึก ✓ · ใช้ภายในบริษัทเท่านั้น ✓
