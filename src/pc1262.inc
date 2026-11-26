; ============================================================================
; pc1262.inc - platform equates for LC-3 on the SHARP PC-1261/1262
; Everything that ties lc3_1262.asm to the PC-1262: fixed RAM, the BASIC entry/exit contract, ROM data,
; the remaining internal-ROM routines (wrapped in platform_pc1262.asm), BASIC tokens, LCD geometry
; and the internal-RAM map. Step 3 (PC-1350) replaces this file and platform_pc1262.asm.
; ============================================================================

CODE_ORG        EQU &4000   ; load / entry address: CALL &4000 compiles

; ---- fixed RAM ------------------------------------------------------------
BASIC_START_PTR EQU &66E1   ; 2 bytes: start of the BASIC program = LC-3 source (EQU#43 -> &5600)
ARRAY_BASE      EQU &6700   ; run time: array sqrt0..sqrt255 (256 bytes); compile time: label table
                            ; (128 labels x 2 bytes)
ERR_POS_ADDR    EQU ARRAY_BASE ; (&6700,&6701) receive X (the source position) on a compile error
RND_SEED_SAVE   EQU &675E   ; 2 bytes, array elements 94/95: RND seed kept between runs
DATA_STACK      EQU &6500   ; 128-byte ring data stack (DIM / AREAD); only the high byte is used
SHADOW_VARS     EQU &6650   ; 27 shadow variables swapped in/out by VAL (overlays the display buffer)
VRAM_UPPER_L    EQU &2000   ; LCD memory, 4 blocks: &2000 &2040 (left), &2800 &2840 (right)
VRAM_UPPER_R    EQU &2800

; ---- BASIC entry / exit contract (the only place that knows how LC-3 meets the BASIC CALL) ----------
; ENTRY.  BASIC "CALL &4000" (compile) and "CALL &4900"-equivalent (run, RT_RUN_ENTRY) are entered by an
;   ordinary CALL from the interpreter: R = STACK_INIT with the BASIC return address at (R,R+1), and
;   J = 1 (the code relies on MVB / EXB moving 2 bytes). The code does not save R: it ASSUMES STACK_INIT.
; R.  STACK_INIT  is loaded into R by RUN and by END (RT_RUN, RT_END), which makes the following RTN return to
;   BASIC. The CPU stack (R, growing down) lives in internal RAM &35-&55 (IR_STACK_LOW .. STACK_INIT-1).
; ERROR EXIT (COMPILE_ERROR).  Compile error = return to BASIC with:
;     (IR_ERR_CODE) = error number   (it is the value of P when the error handler is reached: "LP &0A" before
;                                      the jump means error 10; &0F is shown as '?' etc.)
;     (IR_ERR_FLAG) = &10            (stored by an MVMP that takes the opcode byte of the next LIDP, so the
;                                      value is fixed by the instruction encoding)
;     (ERR_POS_ADDR) = X             (source position, shown by the BASIC editor)
;     R = STACK_ON_ERROR, carry set, RTN
;   The PC-1262 interpreter's CALL handler then reports the error. Step 3 replaces this exit by the PC-1350
;   protocol (error pointer + ROM ERROR entry, or a message and a normal return).
; SUCCESS EXIT.  Compile: "JPC PLAT_FILL_INPBUF" with carry set (the same RTN as the error exit, error code 0).
;   Run: RT_END = STACK_INIT into R, PLAT_FILL_INPBUF, RND seed saved to RND_SEED_SAVE, RTN.
; BASIC's own internal RAM &30-&3F is clobbered by LC-3 (READ pointer, data-stack pointer, RND seed, compile
;   scratch, deep CPU stack). On the PC-1262 nothing is saved or restored (as in the original); a port that
;   must keep BASIC alive has to save &30-&3F in COMPILE, RT_RUN_ENTRY (before use) and restore them in the exits:
;   COMPILE's two exits, RT_END and the BRK exit of RT_BRK_CHECK (JRNZP RT_END). See analysis/LC3_Analysis.md section 11.
STACK_INIT      EQU &56     ; R value on entry from BASIC CALL, restored by RUN/END
STACK_ON_ERROR  EQU &58     ; R value used when returning a compile error to BASIC

; ---- BASIC ROM data used (platform data, read through H_A_FROM_BA) ----------------
BASROM_KEYTAB   EQU &83A0   ; key code -> INKEY$ code table in the BASIC ROM

; ---- internal ROM routines that are still called (through platform_pc1262.asm only) ---
ROM_KEYSCAN     EQU &03C1   ; key scan: A = code, carry clear if none
ROM_OUTC_A      EQU &043D   ; A -> control port (OUTC)
ROM_WAIT_TICK   EQU &08CF   ; wait for the next 2 ms TEST tick
ROM_GETKEY      EQU &1138   ; wait for a key
ROM_GLYPH_PTR   EQU &135F   ; X = glyph address of character A (codes >= &20)
ROM_GLYPH_PTR_X EQU &1367   ; as above, X preset by the caller
ROM_KEYTIMER_INIT EQU &19EE ; key-input timer init
ROM_FILL_DISPLAY EQU &1B31  ; fill &6650-&667F with A
ROM_FILL_INPBUF EQU &1BA7   ; fill input buffer &67B0-&67FF with &0D
; The other 22 ROM routines of the original (BA->X/Y &022C/&022E/&0240/&0242, A=(BA) &0F30, Y+1->(15,16) &0F7A,
; return address <-> X &102E/&1039, copy &1047, X<->(38,39) &133B/&134E, (P)=Y &134A, DP=&203D &1353,
; X<->(0C,0D) &13A3, X=(BASIC start) &13BD, 16-bit sub/swap &1541-&156E, (P)<->(30,31) &15F2, POP/RTN &185E,
; (P)=(3A,3B) &1A1A) are now local code: src/helpers.asm or inline, see there.
; The BASIC-ROM REM handler (&C2CF, revision dependent, patch.txt) is now ST_REM in lc3_1262.asm.

; ---- BASIC tokens / characters of the PC-1262 -------------------------------
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

; ---- LCD geometry (PC-1262: 2 rows x 24 cells x 5 columns, 7-bit columns) -----------
; STEP 2 ONLY NAMES THE VALUES; they are unchanged. Step 3 replaces them for the 150x32 LCD.
VRAM_LOWER_L    EQU &2040   ; lower row of the left half  (VRAM_UPPER_L + LCD_ROW_STEP)
VRAM_LOWER_R    EQU &2840   ; lower row of the right half (VRAM_UPPER_R + LCD_ROW_STEP)
LCD_BLOCK_COLS  EQU &3C     ; columns per VRAM block (12 cells x 5)
LCD_BLOCK_LAST  EQU &3B     ; index of the last column of a block (LII count for FILD)
LCD_COL_MASK    EQU &3F     ; low 6 bits of a VRAM address = column inside a 64-byte block
LCD_ROW_STEP    EQU &40     ; address distance upper row -> lower row block (&2000 -> &2040)
LCD_HALF_STEP   EQU &08     ; high-byte distance left half -> right half (&2000 -> &2800)
LCD_HI_MASK     EQU &28     ; valid bits of a VRAM high byte (&20 left / &28 right half)
LCD_ROW_SEL     EQU &10     ; bit of the cursor high byte (&30/&38) that selects the lower row
LCD_CELL_DOTS   EQU &07     ; dot rows per text row (a column byte holds 7 dots)
LCD_CHAR_COLS   EQU &05     ; glyph width in columns
LCD_GFX_HI_LEFT EQU &21     ; graphic cursor pointer high byte, left half (biased by +1: DY follows)
LCD_GFX_HI_MASK EQU &29     ; high-byte mask of the biased graphic cursor pointer
LCD_PLOT_HI     EQU &27     ; RT_PLOT high byte, left half (&28 = right half after INCB); value kept as is
LCD_INDICATOR   EQU &203D   ; LCD indicator byte (BUSY/DEG/RAD/GRAD ... segments)

; ---- Internal RAM (the SC61860 register file, addressed by P) ---------------------------
; Registers: &00 I, &01 J, &02 A, &03 B, &04/&05 X (XL/XH), &06/&07 Y (YL/YH), &08 K, &09 L, &0A M, &0B N.
; Only locations with ONE fixed meaning are named. The code generator's own scratch (&08-&14: K, L,
; &10 value flags, &11 operand / constant, &12 LP code, &13 last emitted LP, &14 "inside IF") and the
; run-time scratch stay literal in the code. Full table: analysis/LC3_Analysis.md section 3.2 and 11.
IR_SAVE_X       EQU &0C     ; C: saved X (0C,0D), swapped with X by H_SWAP_X_0C
IR_DMS_LEN      EQU &0D     ; R: DMS note length (same byte as the high half of IR_SAVE_X)
IR_GFX_Y        EQU &0E     ; R: graphic cursor Y, world coordinate 0-255, set by ON
IR_PASS_FLAG    EQU &0F     ; C: &00 in pass 1, &80 in pass 2
IR_TEXT_CUR     EQU &0F     ; R: text cursor VRAM address (&0F low, &10 high)
IR_VAR_AT       EQU &15     ; R/C: variable @ ; A..Z follow at &16..&2F (27 variables)
IR_NVARS        EQU 27      ; number of variables (@, A-Z), also the size of the VAL shadow set
IR_RUN_CLEAR_FIRST EQU &11  ; RUN clears &11..&32
IR_RUN_CLEAR_LAST  EQU &32
IR_READ_PTR     EQU &30     ; R: READ pointer (&30 low, &31 high); swapped with the RESTORE operand
IR_DSTK_PTR     EQU &32     ; R: data-stack pointer, index into the 128-byte ring DATA_STACK
IR_RND_SEED     EQU &33     ; R: RND seed (&33 low, &34 high); kept in RND_SEED_SAVE between runs
IR_ERR_CODE     EQU &34     ; C: compile error number returned to BASIC (0 = ok); same byte as the RND seed high
IR_ERR_FLAG     EQU &35     ; C: error flag, &10 on error (see the exit contract above)
IR_SAVE_X38     EQU &38     ; C: X saved by H_SAVE_X_38 / H_LOAD_X_38 (&38 low, &39 high)
IR_SAVE_Y3A     EQU &3A     ; C: Y saved next to it (&3A low, &3B high; H_SAVE_X_38 leaves P = &3A)
IR_STACK_LOW    EQU &35     ; lowest internal-RAM address of the CPU stack (R grows down from STACK_INIT)
