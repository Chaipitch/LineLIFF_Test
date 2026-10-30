# Questions for the BA — LINE Sales Reporting

**For:** the BA session (date: ________ · attendees: ________).
**How to use:** go through the sections in order; write the answer in the last column. Items marked **⚑ blocks L5**
must be answered before the forms are built; the rest can follow. Where we have a recommendation it is given, so the BA
can simply confirm. Context: `L0-SPEC.md`, `DECISIONS.md` (D-xx), `MOCKUP-REVIEW.md` (G-x, with the two mockup images).

Org facts quoted below come from the read-only check of sandbox `dev5` on 2026-10-28.
**ภาษาไทย:** a Thai summary of all open questions, in priority order, is at the end of this file.

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
| Q-A1 ⚑ | Record visits as **Task** or **Event**? (D-11, G1) | Mockup shows **Task**. Event fits time-bound meetings and triggers the org's Slack note + Opportunity meeting-count flows; Task fits "something done on a date". | **Task** (as in the mockup), Status `Completed` | **Task** — answered 2026-10-30 (D-11) |
| Q-A2 ⚑ | Which **Activity Type** values should reps choose from? | Task `Type` today has only call outcomes (Connected – Had Conversation, Busy / Call Back, Not Connected / Voicemail, Invalid Number / No Fit). "Customer Visit" doesn't exist. An admin must add the new values (they also appear for normal Task entry). | e.g. Customer Visit, Online Meeting, Phone Call, Demo, Other — BA to finalise | |
| Q-A3 ⚑ | Confirm the fields: Account*, Activity Type*, Date*, Comments | Mockup fields. Subject auto-built as "<Type> – <Account>". | Confirm; Comments required? | Follow Salesforce: required = required on the rep's layout, in the database or in the field set; validation rules run on save (D-31) — 2026-10-30 |
| Q-A4 | Date: past and today only, or future too (planned activities)? | Completed vs planned changes Status. | Past and today only (`Completed`) | **Not restricted**: past, today and future; future → `Open`, otherwise `Completed` (D-32) — 2026-10-30 |
| Q-A5 | Link the activity to the Account only, or also to an Opportunity / Contact? | Extra pickers add scope. | Account only in phase 1 | **Account only** (D-33) — 2026-10-30 |
| Q-A6 | Photos / attachments? | Not in plan (adds scope). | Not in phase 1 | **Yes, attachments in scope** (D-34) — limits in Q-A6a — 2026-10-30 |
| Q-A6a | Attachment limits: how many files per activity, max size, which types? | Files are stored on the Task as Salesforce Files and count against file storage (sandbox `dev5`: 59 MB free of 200 MB). Photos are shrunk on the phone before upload. | 5 files, 4 MB each after resizing, photos (camera or gallery) + PDF | |
| Q-A7 | Who should own the Task? | With Option B the rep who submits is the owner (mockup "Assigned To Roj"). | The submitting rep | |

## 3. Update Opportunity

| # | Question | Context / options | Recommendation | Answer |
|---|---|---|---|---|
| Q-O1 ⚑ | Which fields can reps edit? (G3) | Mockup: Stage, Amount, Next Step. Other candidates: Close Date, Your Win Confidence, Next Step Due Date. Fields come from a field set, so admins can change this later without code (D-21). | Stage, Amount, Next Step, Close Date | BA will confirm later (2026-10-30) |
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

---

## ภาษาไทย — รายการที่ต้องยืนยันกับ BA (อัปเดต 2026-10-29)

สรุปคำถามที่ยังเปิดอยู่ เรียงตามความสำคัญ (ข้อที่ตอบแล้วตัดออก) พร้อมคำแนะนำของเรา BA ยืนยันได้เลย
ข้อ 1–14 ต้องตอบก่อนเริ่มทำฟอร์ม (L5)

### 🔴 ต้องตอบก่อนเริ่มทำฟอร์ม (L5)

**ผู้ใช้งาน**

1. Rep คนไหนบ้างที่จะใช้ระบบ? (ต้องมี Salesforce user ทุกคน)
   ⚠️ การ Update Opportunity ต้องใช้ license แบบ **Salesforce เต็ม** — ตอนนี้ใน org มี 9 คน ส่วนอีก 18 คนเป็น
   **Salesforce Platform** ซึ่ง**มองไม่เห็น Opportunity** (Q-S1, D-13)

**Log Activity (บันทึกกิจกรรม)**

2. ✅ ตอบแล้ว (30 ต.ค.): บันทึกเป็น **Task** (Q-A1, D-11)
3. Activity Type ให้ Rep เลือกได้มีค่าอะไรบ้าง? ตอนนี้ Task Type มีแต่ค่าผลการโทร ยังไม่มี "Customer Visit" → admin
   ต้องเพิ่มค่าใหม่ → เสนอ: Customer Visit, Online Meeting, Phone Call, Demo, Other (Q-A2)
4. ✅ ตอบแล้ว (30 ต.ค.): ฟิลด์บังคับกรอกให้ **ตาม Salesforce** (page layout ของ Rep / ฐานข้อมูล / field set)
   validation rule ทำงานตอนกดบันทึก (Q-A3, D-31)
5. ✅ ตอบแล้ว (30 ต.ค.): วันที่ **ไม่จำกัด** (ย้อนหลัง/วันนี้/อนาคต) — วันในอนาคตจะเป็นสถานะ Open (Q-A4, D-32)
6. ✅ ตอบแล้ว (30 ต.ค.): ผูกกับ **Account อย่างเดียว** (Q-A5, D-33)
7. ✅ ตอบแล้ว (30 ต.ค.): **ทำ** แนบไฟล์ได้ (Q-A6, D-34) — เหลือยืนยัน: แนบได้กี่ไฟล์ ขนาดเท่าไร ประเภทอะไร?
   → แนะนำ: 5 ไฟล์ ไฟล์ละไม่เกิน 4 MB (ย่อรูปบนมือถือก่อนส่ง) รูปถ่าย/รูปในเครื่อง + PDF (Q-A6a)

**Update Opportunity (อัปเดตดีล)**

8. Rep แก้ไขฟิลด์ไหนได้บ้าง? mockup มี: Stage, Amount, Next Step / ตัวเลือกเพิ่ม: Close Date, Your Win Confidence,
   Next Step Due Date → แนะนำ: Stage, Amount, Next Step, Close Date (Q-O1)
   ⏳ BA จะยืนยันฟิลด์ของ Update Opportunity ทีหลัง (30 ต.ค.)
9. ใช้ฟิลด์ "Next Step" ตัวไหน? ใน org มี 2 ตัวชื่อเหมือนกัน: `NextStep` (มาตรฐาน) และ `Next_Step_Custom__c`
   → ใช้ตัวที่ทีม sales ใช้ใน report (Q-O2, D-12)
10. ให้เลือก Stage ได้ถึงไหน? Stage ที่มี: 01. Before 1st MTG / 02. Early Stage / 03. Final Proposal / 08. Closed Won /
    08. Closed Lost (ปิดดีลต้องกรอกเอกสารสัญญา/เหตุผลเพิ่มตาม validation rule) → แนะนำ: เปิดให้เลือกแค่ 01–03
    ส่วนการปิดดีลทำใน Salesforce (Q-O3)
11. Stage 02 ขึ้นไป ระบบบังคับกรอก **PreSales Engineer** (validation rule) → เพิ่มฟิลด์นี้ในฟอร์มไหม?
    → แนะนำ: เพิ่ม ไม่งั้น Rep จะบันทึกไม่ผ่าน (Q-O4)
12. ใน org ฟิลด์ Amount ใช้ชื่อว่า "Target TCV" และ Stage มีเลขนำหน้า → แสดงตามชื่อใน Salesforce ได้ไหม?
    → แนะนำ: ได้ (Q-O5)
13. แสดง Opportunity ไหนบ้าง: ของตัวเอง / ที่ยังเปิดอยู่ทั้งหมดของ Account / ทั้งหมดที่มองเห็น?
    → แนะนำ: ดีลที่ยังเปิดอยู่ของ Account ที่ Rep มองเห็น (Q-O6)
14. ต้องสร้าง Opportunity ใหม่จาก LINE ได้ไหม? → แนะนำ: ไม่ทำในเฟสแรก (Q-O7)

### 🟡 ตอบได้ระหว่างทำ

**การค้นหา Account** (ใช้งานได้แล้ว ค้นจากชื่อ Account)

15. ต้องค้นจากฟิลด์อื่นด้วยไหม เช่น Account Name (TH), Account No.? (admin เพิ่มเองได้โดยไม่ต้องแก้โค้ด)
    ⚠️ ใน sandbox มีชื่อ Account ซ้ำกัน (เช่น "mo7 company" 4 รายการ) → ถ้าแสดง Account No. ใต้ชื่อ จะช่วยแยกได้ (Q-C1)
16. ค้นเฉพาะ Account ของตัวเอง หรือทั้งหมดที่มีสิทธิ์เห็น? → แนะนำ: ทั้งหมดที่มีสิทธิ์เห็น (Q-C2)
17. จำนวน Account ใน production ประมาณเท่าไร? (Q-C3)
18. ต้องสร้าง Account ใหม่จาก LINE ไหม? → แนะนำ: ไม่ทำในเฟสแรก (Q-C4)

**การเชื่อม LINE กับ Salesforce** (รายละเอียด: `BA-FAQ.md`)

19. ถ้ามี LINE อีกบัญชีมา login เป็น user เดียวกัน → ใช้แบบ **latest wins** (บัญชีเก่าถูก unlink อัตโนมัติ) หรือ
    **first wins** (ต้องให้ admin unlink ก่อน)? → แนะนำ: latest wins (คุยเบื้องต้นแล้ว รอทดสอบ) (Q-L8)
20. ต้องแจ้งเตือนเมื่อบัญชีเก่าถูกแทนที่ไหม? → แนะนำ: ไม่ทำในเฟสแรก (Q-L8)
21. การเชื่อมต่อมีอายุไหม หรือใช้ได้จนกว่าจะ unlink/ปิด user? → แนะนำ: จนกว่าจะ unlink หรือปิด user (Q-L1)
22. ใครเป็นคน unlink เวลา Rep ลาออกหรือเปลี่ยนมือถือ? → แนะนำ: Salesforce admin (Q-L2)
23. production บังคับ **MFA** สำหรับ Rep ไหม? มีแผนใช้ SSO ไหม? (Q-L6)
24. ตอน login ครั้งแรก ตอนนี้เปิดใน **browser ของมือถือ** (ทดสอบแล้วใช้ได้ดี) → OK ไหม หรืออยากให้เปิดใน LINE
    แบบใน mockup? (Q-L3)
25. นโยบายบริษัทเรื่องแสดงข้อมูลธุรกิจ (ชื่อลูกค้า, ยอดเงิน) ใน LINE มีข้อจำกัดไหม? (Q-L7)

**ภาษาและ LINE OA**

26. ภาษาที่ใช้ในฟอร์ม: ไทย / อังกฤษ / ญี่ปุ่น? → แนะนำ: ทั้ง 3 ภาษา ตามภาษาของ LINE ในมือถือ (Q-S3)
27. ชื่อ OA: "Sales Reporting" หรือ "Salesforce Reporting" (ตาม mockup)? ⚠️ การใช้คำว่า "Salesforce" อาจต้องเช็คเรื่อง
    trademark (Q-N1)
28. ข้อความต้อนรับ (Greeting) ใช้ตาม mockup ได้ไหม? (Q-N5)
29. ใครออกแบบรูป Rich menu? (Q-N3)
30. ต้องส่งข้อความยืนยันใน LINE หลังบันทึกสำเร็จไหม? → แนะนำ: ไม่ทำในเฟสแรก (หน้าจอแสดงผลสำเร็จพอแล้ว) (Q-M1)

**ทดสอบและ Go-live**

31. ขอ **test user ที่ไม่ใช่ admin** อย่างน้อย 1 คน (มี Salesforce license เต็ม) สำหรับทดสอบว่ามองเห็นเฉพาะข้อมูลที่มีสิทธิ์
    → แนะนำ: 2 คน (iOS 1, Android 1) (Q-T1)
32. ใครทำ UAT และวันไหน? Go-live เมื่อไร และใครเป็นคน sign-off? (Q-T2, Q-S2)
