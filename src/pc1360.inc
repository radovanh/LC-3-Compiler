; ============================================================================
; pc1360.inc - platform equates for LC-3 on the SHARP PC-1360 (step 4 of the port)
; Everything that ties lc3_1360.asm to the PC-1360: memory plan, the BASIC entry/exit contract, ROM entry
; points, data and banks, BASIC tokens, the LCD geometry and the internal-RAM map.
; Counterpart of pc1350.inc (which stays as it is for the PC-1350 build).
;
; CODE_ORG is NOT defined here: tools/build_1360.sh writes a small top-level file per RAM card
; (src/lc3_1360_<n>k.asm) that defines CODE_ORG (= the card's BASIC start) and PASS1_GUARD, then INCLUDEs
; src/lc3_1360.asm. One source, one binary per card: 8 KB &E030, 16 KB &C030 (build/lc3_1360_16k.bin), 32 KB &8030.
; ============================================================================

CODE_PAGE       EQU CODE_ORG >> 8       ; high byte of the load address (statement-table handler encoding, below)

; ---- memory plan (inside the card's BASIC area, reserved by raising the BASIC start) ----------------
; CODE_ORG .. code end      LC-3 (compiler + runtime), CSAVEM range CODE_ORG..CODE_END-1
; WORK_BASE .. +&1CF        fixed work areas (below), page aligned, not saved by CSAVEM
; OBJ_START ..              object code, up to the BASIC start
; BASIC start .. &F9CF      the LC-3 source = the BASIC program (start raised with POKE &FFD7,lo,hi + NEW)
; WORK_BASE is checked by tools/check_layout_1360.py: it must lie at or above the end of the code.
WORK_BASE       EQU (CODE_PAGE << 8) + &C00
ARRAY_BASE      EQU WORK_BASE           ; run time: array sqrt0..sqrt255 (256 bytes, page aligned);
                                        ; compile time: label table (128 labels x 2 bytes)
RND_SEED_SAVE   EQU ARRAY_BASE + &5E    ; 2 bytes, array elements 94/95: RND seed kept between runs (as on the PC-1262)
DATA_STACK      EQU WORK_BASE + &100    ; 128-byte ring data stack (DIM / AREAD), page aligned, only the high byte is used
SHADOW_VARS     EQU WORK_BASE + &180    ; 27 shadow variables swapped by VAL; RUN clears 48 bytes from here
SHADOW_CLEAR_LEN EQU 48
SAVE_IRAM30     EQU WORK_BASE + &1B0    ; 16 bytes: BASIC's internal RAM &30-&3F, saved at entry, restored at every exit
SAVED_R         EQU WORK_BASE + &1C0    ; R at entry (BASIC CALL), restored by RUN / END, R+2 is the error return
ERR_POS_ADDR    EQU WORK_BASE + &1C1    ; 2 bytes: source position (X) of the last compile error (low, high)
KEY_WORK        EQU WORK_BASE + &1C3    ; 1 byte: spare (keyboard)
GLYPH_BUF       EQU WORK_BASE + &1C4    ; 5 bytes: the glyph of the character being printed, copied from the ROM font
OBJ_START       EQU WORK_BASE + &1D0    ; object code is generated from here

; ---- pass 1 (the compiler's measuring pass) ---------------------------------------------------
; Pass 1 emits into the external-ROM window &4000-&7FFF, where the writes are lost (the PC-1262 original used its
; BASIC ROM above &8000; on the PC-1360 that is the RAM card). Y starts at PASS1_HI:LB@OBJ_START; a label defined in
; pass 1 has a high byte >= PASS1_HI (0 = undefined), converted in pass 2 by + PASS1_DELTA. At the start of every
; line in pass 1, a high byte >= PASS1_GUARD gives error 4 at once (before Y can leave the window, and before the
; real object end, high byte + PASS1_DELTA, could pass &F9xx): PASS1_GUARD = min(&7C, &FA - PASS1_DELTA), set by the
; build per card. A line produces less than 1 KB of object code.
PASS1_HI        EQU &40
PASS1_DELTA     EQU (OBJ_START >> 8) - PASS1_HI

; ---- BASIC (PC-1360 ROM) -------------------------------------------------------------------------
BASIC_START_PTR EQU &FFD7   ; 2 bytes: start of the BASIC program = LC-3 source (points to the FF before the first line)
                            ; (&FFD9 = the end; BASIC's area ends at &F9CF, the standard variables start at &F9D0)

; ---- BASIC entry / exit contract (the only place that knows how LC-3 meets the BASIC CALL) ----------
; ENTRY.  "CALL CODE_ORG" (COMPILE) and "CALL RT_RUN_ENTRY" (run) are entered by the ROM's CALL statement handler
;   (bank 0 &7B00): it swaps X with &2AB4 (ROM &1212; BASIC keeps its text pointer there meanwhile), builds a JP at
;   &FF0D (or &8000) and CALLs it. R = the caller's level with the return address at (R,R+1) (&54 in the emulator,
;   from the prompt and from a program), J = 1, ROM bank 0 mapped. Both entries store R in SAVED_R and swap BASIC's
;   internal RAM &30-&3F into SAVE_IRAM30 (SAVE_IRAM30_SWAP).
; R.  RUN and END reload R from SAVED_R (RT_RUN, RT_END).
; SUCCESS EXIT.  Compile: "JPC RESTORE_IRAM30" (restore &30-&3F, RTN into the CALL handler, which does RC and
;   reloads X from &2AB4). Run: RT_END = R from SAVED_R, RND seed saved, RESTORE_IRAM30, RTN (also the BRK exit).
; ERROR EXIT (COMPILE_ERROR).  The PC-1360 statement-handler protocol, one level up (the same as on the PC-1350):
;     restore &30-&3F; (IR_ERR_CODE) = &34 = error number; X = source position; R = SAVED_R + 2; carry set; RTN.
;   (R+2, R+3) is the return into the interpreter's statement loop (bank 0: "CALL &FF0D / JRCP &5F52" at the
;   prompt, "CALL &FF0D / JPC &5FA2" in a program), which reports the error in (&34) on a carry, as for a ROM
;   statement handler that failed (the ROM's own error exits &10B9.. do "LP &34 / EXAM / SC / RTN").
;   X is also stored in ERR_POS_ADDR.
IR_SAVE_FIRST   EQU &30     ; BASIC's internal RAM that LC-3 must give back (16 bytes, &30-&3F)
ERR_R_OFFSET    EQU 2       ; R at the error return = SAVED_R + this (the CALL handler's own frame is skipped)

; ---- ROM entry points, data and banks (PC-1360) --------------------------------------------------
ROM_KEYSCAN     EQU &1E9C   ; key scan (internal ROM, "JP &00B5"): carry set and A = raw key code (&00-&45, &46 = BRK,
                            ; &47 = several keys) if a key is down; carry clear if none. Leaves IA and &3E00 at 0.
                            ; CALLed directly (platform_pc1360.asm: no PLAT_KEYSCAN stub).
BANK_PORT       EQU &3400   ; ROM bank select (bits 0-2) for &4000-&7FFF
BANK_BASIC      EQU 0       ; the bank mapped while LC-3 runs (the CALL handler runs in bank 0 and returns into it)
KEYTAB          EQU &4360   ; bank 0: raw key code -> INKEY$ code (no shift); KEYTAB + KEYTAB_SHIFT = the SHIFT table.
                            ; The table of BASIC's INKEY$ (bank 0 &7661 -> &480E, normal mode). It already holds LC-3's
                            ; codes: 1 several keys (&47) / no character, 2 CL, 4 up, 5 down, 13 ENTER, 14 right,
                            ; 15 left, 16 SHIFT, 18 DEF. (The other table the knowledgebase names, &46C0, is not the
                            ; INKEY$ one: it has 2 at raw code 9 and the arrows at 59-62.) Index <= &8F: no carry.
KEYTAB_BANK     EQU 0
KEYTAB_SHIFT    EQU &48     ; offset of the SHIFT table (&43A8)
KEY_RAW_SHIFT   EQU &15     ; raw key codes of the prefix keys (ROM_KEYSCAN), the same values as on the PC-1350
KEY_RAW_DEF     EQU &16
KEY_RAW_SML     EQU &17
KEY_PORT        EQU &3E00   ; keyboard line select: line number 1-7 (0 = none), read through port IA
FONT_ROM        EQU &418B   ; bank 1: 5 glyph bytes per character from &20, stored left to right, bit 0 = top dot
FONT_BANK       EQU 1
FONT_ROM_P1     EQU FONT_ROM + 1    ; (PLAT_GLYPH_PTR starts from here)

; ---- SIN / DMS tone timing ---------------------------------------------------------------------
; The PC-1360 runs at 768 kHz (its specification), as the PC-1262 and PC-1350: the cycle-counted SIN / DMS loops are
; unchanged and give the PC-1262's pitch and note lengths.

; ---- BASIC tokens / characters: the PC-1262 codes. The PC-1360 stores every keyword as &FE + its own code;
; RDTOK (lc3_1360.asm) translates them to these codes as the compiler reads them (table TBL_TOKENS).
TK_IF EQU &D4
TK_GOTO EQU &C6
TK_GOSUB EQU &E0
TK_RETURN EQU &E3
TK_END EQU &D8
TK_REM EQU &D7
TK_DATA EQU &DC
TK_DEG EQU &9B
TK_GRAD EQU &C3
TK_RESTORE EQU &E4
TK_DMS EQU &9C
TK_RUN EQU &B0
TK_WAIT EQU &C5
TK_STOP EQU &DA
TK_CLEAR EQU &C9
TK_DIM EQU &CB
TK_VAL EQU &A5
TK_CLS EQU &CE
TK_CURSOR EQU &CF
TK_PRINT EQU &DE
TK_LPRINT EQU &E2
TK_CHR EQU &A8
TK_POKE EQU &CD
TK_ON EQU &D3
TK_COS EQU &96
TK_TRON EQU &C7
TK_TROFF EQU &C8
TK_SIN EQU &95
TK_BEEP EQU &C4
TK_PAUSE EQU &DD
TK_ASN EQU &9D
CH_SQRT EQU &FC             ; square-root character = the array (PC-1360: the SQR keyword FE 94)
CH_QUOTE EQU &22
CH_EXCL EQU &21
CH_COLON EQU &3A
PC1360_KEYWORD EQU &FE      ; prefix of a keyword in a PC-1360 program line
PC1360_LINENUM EQU &1F      ; prefix of a binary line number (&1F hi lo, after GOTO / GOSUB / RESTORE / THEN)
TK_UNKNOWN      EQU &D5     ; what RDTOK returns for a keyword LC-3 does not know (the PC-1262 FOR: a syntax error)

; ---- statement table: flag bits and the handler encoding ----------------------------------------
; An entry is "token, flags | (handler high byte - CODE_PAGE), handler low byte". The relative high byte must stay
; below &20 (bits 7 and 5 are the flags): handlers lie in CODE_PAGE*256 .. +&1FFF (8 KB from LC-3's page; checked by
; tools/check_layout_1360.py). ST_GENERIC masks the flags off and adds CODE_PAGE.
ST_ARG1 EQU &80             ; statement has a first operand, stored by "LP &11 / EXAM"
ST_ARGA EQU &20             ; statement has an operand left in A

; ---- LCD geometry (PC-1360: 150 x 32 dots, 4 rows of 8-dot column bytes; the PC-1350 layout at &2800) ------------
; Column x (0-149) of row r (0-3) is at VRAM_BASE + (x / 30) * &200 + LCD_ROWOFF_r + x MOD 30.
; The 5 groups of 30 columns are &2800 &2A00 &2C00 &2E00 &3000; inside a group the rows are at +&00, +&40,
; +&1E, +&5E. Bit 0 of a byte is the top dot. The bytes between (&xx3C-&xx3F, &xx7C-&xxFF) are system RAM (&303C =
; the indicator byte, &2AB4 = BASIC's saved text pointer, &2E80 = the ROM bank trampolines' stack, ...) and are
; never written.
; Text: 25 cells of 6 columns per row (5 glyph columns + 1 blank), 100 cells; CURSOR n = row * 25 + cell,
; n >= 100 switches text output off (the cursor then points into the ROM, LCD_SINK_HI, where writes are lost).
VRAM_BASE       EQU &2800
LCD_GROUP_HI_STEP EQU 2     ; high-byte step from one 30-column group to the next
LCD_GROUP_COLS  EQU 30
LCD_LAST_GROUP_HI EQU &30
LCD_GROUP_LAST_LO0 EQU &1D  ; low 6 bits of the last column of a group: rows 0/1 (&1D / &5D)
LCD_GROUP_LAST_LO2 EQU &3B  ; ... rows 2/3 (&3B / &7B)
LCD_NEXT_GROUP  EQU &01E2   ; added to a "last column" address: same row, first column of the next group, minus 1
LCD_ROWOFF_1    EQU &40
LCD_ROWOFF_2    EQU &1E
LCD_ROWOFF_3    EQU &5E
LCD_COLS        EQU 150
LCD_ROWS_DOTS   EQU 32
LCD_CELLS       EQU 100
LCD_ROW_CELLS   EQU 25
LCD_SINK_HI     EQU &40     ; text / graphics "off": the pointer goes to &4000 (external ROM), where writes are lost;
                            ; every high byte >= &40 counts as "off" (the display is below &3200)
LCD_INDICATOR   EQU &303C   ; indicator byte (SHIFT bit 0, DEF bit 1, ...); not used by LC-3

; ---- Internal RAM (the SC61860 register file, addressed by P) ---------------------------
; As in pc1350.inc, plus RDTOK's scratch.
IR_SAVE_X       EQU &0C     ; C: saved X (0C,0D), swapped with X by H_SWAP_X_0C (also by RDTOK)
IR_DMS_LEN      EQU &0D     ; R: DMS note length
IR_GFX_COL      EQU &0C     ; R: GRAD / COS: address of the current column in row 0 (0C low, 0D high)
IR_GFX_Y        EQU &0E     ; R: graphic cursor Y, world coordinate 0-255, set by ON (0-31 visible, 249-255 = -7..-1)
IR_TOK_TMP      EQU &0E     ; C: RDTOK: the PC-1360 keyword code being looked up
IR_PASS_FLAG    EQU &0F     ; C: &00 in pass 1, &80 in pass 2
IR_TEXT_CUR     EQU &0F     ; R: text cursor = VRAM address of the next column - 1 (&0F low, &10 high)
IR_GFX_PTR      EQU &13     ; R: graphic cursor = VRAM address of column x in row 0 (&13 low, &14 high), set by ON
IR_GFX_ROWA     EQU &11     ; R: GRAD / COS: row offset of the low part (bit 7 = not visible)
IR_GFX_ROWB     EQU &12     ; R: GRAD / COS: row offset of the high part
IR_VAR_AT       EQU &15     ; R/C: variable @ ; A..Z follow at &16..&2F (27 variables)
IR_NVARS        EQU 27      ; number of variables (@, A-Z), also the size of the VAL shadow set
IR_RUN_CLEAR_FIRST EQU &11  ; RUN clears &11..&32
IR_RUN_CLEAR_LAST  EQU &32
IR_READ_PTR     EQU &30     ; R: READ pointer (&30 low, &31 high); swapped with the RESTORE operand
IR_DSTK_PTR     EQU &32     ; R: data-stack pointer, index into the 128-byte ring DATA_STACK
IR_RND_SEED     EQU &33     ; R: RND seed (&33 low, &34 high); kept in RND_SEED_SAVE between runs
IR_ERR_CODE     EQU &34     ; C: compile error number for the ROM's error report (same byte as the RND seed high)
IR_SAVE_X38     EQU &38     ; C: X saved by H_SAVE_X_38 / H_LOAD_X_38 (&38 low, &39 high)
IR_SAVE_Y3A     EQU &3A     ; C: Y saved next to it (&3A low, &3B high; H_SAVE_X_38 leaves P = &3A)
