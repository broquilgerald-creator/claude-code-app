# CDP Store 968 – Problems & Concerns Log (saved 2026-10-21)

Owner: Gerald (Training Coordinator). Files: 968_NOVEMBER_CDP_BINDER_FINAL_v2.xlsx, 968_OCTOBER_CDP_BINDER_10_5.xlsx, OCT_vs_NOV_CDP_comparison_v2.xlsx.

## A. Standing rules (must hold in every build)
1. TA for COB is 11 AM–5 PM.
2. Exposure (S1/S2/S3) of different crew must not collide; starts at least 2 h apart. Initial (IN) training is COMBINED across trainees.
3. 330 plan = 3 stations including RB.
4. Production crew: Batch Fried and EXPERT first (not "expeditor").
5. Budget must be within PHP 20,000 (hires plan: show the overrun).
6. Jonathan Garcia is NOT a trainer. BM = building maintenance (RB, Customer Area, Maintenance).
7. Trainees are placeholders (COB 1–4); trainers come from the November availability file.
8. John = NEW crew (not John Tero, who resigned).
9. Resigned/removed: Daniel Cestona Bauzon, Joana Mangrobang, Maryella R. Sanchez, John Tero. Gerald and Clariza (managers) = RESIGNED on SOC; their 12 FUSOC checks go to other managers on duty (SM preferred).
10. Roster total = 69 (+4 COB placeholders separate). Angelina Manaois = Angelina De Guzman. Ray, Rico, Janielle, Toffer, Cess = schedule names.
11. Richard is OFF on the cell that held Daniel's FUSOC check.

## B. OPEN problems / concerns (unresolved)
1. **Budget over cap**: Nov total PHP 36,919.99 = PHP 16,919.99 over 20,000 (COB alone ~15,780). Needs trimming decision.
2. **COB 1–4 are placeholders** – real names needed.
3. **Sarah's surname** unknown (TBC).
4. **Wilson Torio, Tiffany Cerdan** – need confirmation (roster).
5. **Stand-in trainers**: 3 COB sessions + 12 October-hire sessions use stand-ins because only Kate, Ash, Krystel, Angelo are free 11–5.
6. **Late-evening exposure slots** (10 PM–12 AM) in the October-hires plan – likely unacceptable; plan ends Nov 29.
7. **Fri/Sat 11 AM demand = 21** looks like a typo in the demand file.
8. **October budget hours still include sessions that did not proceed.**
9. **MESH trainer shows as RHIE.**
10. **Misc sheet eligible-pool sizes are blank.**
11. **OCT_vs_NOV_CDP_comparison_v2.xlsx is stale** (built before combined-IN change).
12. **Verification gap**: LibreOffice can't open xlsx here – binder checked only via openpyxl, never visually/in Excel. Open in Excel and check formulas, merged cells, images.
13. **Old sessions not archived** (permission denied); other-PC sessions unreachable (trusted-device).
14. App repo: PR #2 still a draft; test credentials hard-coded; auth hardening pending.

## C. Mistakes I made and you corrected (don't repeat)
- Kept Jonathan as a trainer; mapped "John" to Lejat; first October SOC edit left the Prepping B pair unchanged.
- Built a standalone workbook instead of using the CDP template.
- Wrongly matched Lester to John Rey De Vera; left October block 5 behind (last_row 151 vs 122).
- Both trainees in a pair got the same slot; COB placeholder rows cleared after writing new crew.
- Image/merged-cell/formula breakage from openpyxl (needs Pillow; MergedCell writes).

## D. Pipeline to rebuild November binder
build_template.py (WAIT=4) -> remove_daniel.py -> Impact F20 full names + Richard OFF (SOC AN27) -> rebuild_roster.py -> John fix (D61 DE VERA, F61 JOHN REY, I61 JOHN, I50 MICHAEL) -> hires_plan2.py (WAIT=1 MINH=2). Scripts live in the session scratchpad (ephemeral) – download the xlsx files.
