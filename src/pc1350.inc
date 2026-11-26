; ============================================================================
; pc1350.inc - platform equates for LC-3 on the SHARP PC-1350 (step 3 of the port)
; Everything that ties lc3_1350.asm to the PC-1350: memory plan, the BASIC entry/exit contract, ROM entry
; points and data, BASIC tokens, the LCD geometry and the internal-RAM map.
; Counterpart of pc1262.inc (which stays as it is for the PC-1262 build).
; Minimum machine: PC-1350 with an 8 KB RAM card (RAM &4000-&5FFF + the internal &6000-&6FFF).
; ============================================================================

CODE_ORG        EQU &4030   ; load / entry address: CALL &4030 compiles (the BASIC start of an 8 KB card)

; ---- memory plan -------------------------------------------------------------
; &4030 .. code end        LC-3 (compiler + runtime), CSAVEM range CODE_ORG..CODE_END-1
; WORK_BASE .. +&1CF       fixed work areas (below), page aligned, not saved by CSAVEM
; OBJ_START ..             object code, up to the BASIC start
; BASIC start .. &6C2F     the LC-3 source = the BASIC program (start raised with POKE &6F01,lo,hi + NEW)
; WORK_BASE is checked by tools/check_layout_1350.py: it must lie at or above the end of the code.
WORK_BASE       EQU &4C00
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
OBJ_START       EQU WORK_BASE + &1D0    ; object code is generated from here

; ---- BASIC (PC-1350 ROM, both versions) ------------------------------------------
BASIC_START_PTR EQU &6F01   ; 2 bytes: start of the BASIC program = LC-3 source (points to the FF before the first line)

; ---- BASIC entry / exit contract (the only place that knows how LC-3 meets the BASIC CALL) ----------
; ENTRY.  "CALL &4030" (COMPILE) and "CALL RT_RUN_ENTRY" (run) are entered by the ROM's CALL statement handler
;   (&C342): R = the caller's level with the return address at (R,R+1) (&56 in the emulator, from the prompt and
;   from a program), J = 1. X = the previous content of &6F20 (BASIC keeps its text pointer in &6F20 meanwhile).
;   Both entries store R in SAVED_R and swap BASIC's internal RAM &30-&3F into SAVE_IRAM30 (SAVE_IRAM30_SWAP).
; R.  RUN and END reload R from SAVED_R (RT_RUN, RT_END).
; SUCCESS EXIT.  Compile: "JPC RESTORE_IRAM30" (restore &30-&3F, RTN into the CALL handler, which does RC and
;   reloads X from &6F20). Run: RT_END = R from SAVED_R, RND seed saved, RESTORE_IRAM30, RTN (also the BRK exit).
; ERROR EXIT (COMPILE_ERROR).  The PC-1350 statement-handler protocol, one level up:
;     restore &30-&3F; (IR_ERR_CODE) = &34 = error number; X = source position; R = SAVED_R + 2; carry set; RTN.
;   This returns past the CALL handler straight into the interpreter's statement loop (&AF5A: "JRCP" -> error),
;   as a ROM statement handler that failed would. The ROM then prints "ERROR n" ((&34) AND &0F + '0': 10 = ':',
;   14 = '>', 15 = '?', as on the PC-1262). When the CALL was in a program line, the ROM takes X as the error
;   address: "ERROR n IN line" names the LC-3 source line, and PRO mode + up arrow shows it (checked in
;   PokeComWin). A CALL typed at the prompt gives "ERROR n" only. X is also stored in ERR_POS_ADDR.
IR_SAVE_FIRST   EQU &30     ; BASIC's internal RAM that LC-3 must give back (16 bytes, &30-&3F)
ERR_R_OFFSET    EQU 2       ; R at the error return = SAVED_R + this (the CALL handler's own frame is skipped)

; ---- ROM entry points and data (PC-1350, the same in ROM versions 0 and 1) ------------
ROM_KEYSCAN     EQU &0436   ; key scan: carry set and A = raw key code (&00-&3F, &40 = several keys), carry clear if none
ROM_GLYPH_VEC   EQU &8087   ; BASIC-ROM vector "JP &8EEF": A = character -> X = its 5 glyph bytes + 5 (font &808A,
                            ; stored right to left; codes < &20 give a space; kana only in Japanese mode)
BASROM_KEYTAB   EQU &8403   ; raw key code -> INKEY$ code (no shift); BASROM_KEYTAB + KEYTAB_SHIFT = the SHIFT table
KEYTAB_SHIFT    EQU &82     ; offset of the SHIFT table (&8485)
KEY_RAW_SHIFT   EQU &15     ; raw key codes of the prefix keys (ROM_KEYSCAN)
KEY_RAW_DEF     EQU &16
KEY_RAW_SML     EQU &17
KEY_PORT        EQU &7E00   ; keyboard row select (bits 0-5), with port IA (rows 7-11 of PokeComWin's matrix)

; ---- BASIC tokens / characters (identical to the PC-1262 for every keyword LC-3 uses: checked against the ROM table) ----
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
CH_SQRT EQU &FC             ; square-root character = the array
CH_QUOTE EQU &22
CH_EXCL EQU &21
CH_COLON EQU &3A

; ---- statement table flag bits (high byte of a TBL_STATEMENTS entry) ----------
ST_ARG1 EQU &80             ; statement has a first operand, stored by "LP &11 / EXAM"
ST_ARGA EQU &20             ; statement has an operand left in A

; ---- LCD geometry (PC-1350: 150 x 32 dots, 4 rows of 8-dot column bytes) --------------------
; Column x (0-149) of row r (0-3) is at VRAM_BASE + (x / 30) * &200 + LCD_ROWOFF_r + x MOD 30.
; The 5 groups of 30 columns are &7000 &7200 &7400 &7600 &7800; inside a group the rows are at +&00, +&40,
; +&1E, +&5E (line order 1, 3, 2, 4 in memory). Bit 0 of a byte is the top dot. The bytes between (&xx3C-&xx3F,
; &xx7C-&xxFF) are system RAM (&783C = the indicator byte) and are never written.
; Text: 25 cells of 6 columns per row (5 glyph columns + 1 blank), 100 cells; CURSOR n = row * 25 + cell,
; n >= 100 switches text output off (the cursor then points into the ROM, LCD_SINK, where writes are lost).
VRAM_BASE       EQU &7000
LCD_GROUP_HI_STEP EQU 2     ; high-byte step from one 30-column group to the next
LCD_GROUP_COLS  EQU 30
LCD_LAST_GROUP_HI EQU &78
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
LCD_SINK_HI     EQU &80     ; text / graphics "off": the pointer goes to &8000 (ROM), where writes are lost
LCD_INDICATOR   EQU &783C   ; indicator byte (SHIFT bit 0, DEF bit 1, ...); not used by LC-3

; ---- Internal RAM (the SC61860 register file, addressed by P) ---------------------------
; As on the PC-1262 (pc1262.inc), plus the graphics scratch of the PC-1350 runtime.
IR_SAVE_X       EQU &0C     ; C: saved X (0C,0D), swapped with X by H_SWAP_X_0C
IR_DMS_LEN      EQU &0D     ; R: DMS note length
IR_GFX_COL      EQU &0C     ; R: GRAD / COS: address of the current column in row 0 (0C low, 0D high)
IR_GFX_Y        EQU &0E     ; R: graphic cursor Y, world coordinate 0-255, set by ON (0-31 visible, 249-255 = -7..-1)
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
