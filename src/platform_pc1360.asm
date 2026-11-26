; ============================================================================
; platform_pc1360.asm - platform entry points of the hardware-bound routines (PC-1360)
; ============================================================================
; The PC-1360 counterpart of platform_pc1350.asm. Same PLAT_* names, same contracts unless noted; the display,
; graphics and keyboard code itself is in lc3_1360.asm. One ROM routine is called: the key scan (&1E9C, internal
; ROM). ROM bank 0 is mapped whenever LC-3 runs: the ROM's CALL handler (bank 0 &7B00) runs in bank 0 and returns into
; it, so it is BASIC's bank at the entry and must be at the exit (BANK_BASIC). The key table (bank 0) is read as it
; is; the font (bank 1) is read with bank 1 mapped for the copy only (PLAT_GLYPH_PTR), as CHANGER mkII does. LC-3
; runs in the card RAM, so switching is safe. J must stay 1 (callers use MVB).
; ============================================================================

; Key scan: the callers CALL ROM_KEYSCAN (&1E9C = JP &00B5: one scan of the whole matrix, no wait) directly (the
; PC-1350's PLAT_KEYSCAN stub, a JP, is left out to save its 3 bytes).
; Out: carry set and A = raw key code (&00-&45; &46 = BRK, &47 = several keys) if a key is down; carry clear if none.
; Writes: A B K L M N, port IA (left 0), &3E00 (left 0), DP, P.  X and Y survive.

; Wait for a key (STOP, the INPUT function).  As on the PC-1350 (local code). It is RT_INPUT_STOP itself (an EQU in
; lc3_1360.asm): it ends in RT_INKEY_1 (A = the table byte, then RT_INKEY's EXAM / LDM and the BRK check).
; A key that is already down when this is called is taken again only after it has been held about 1 s (key repeat),
; otherwise the routine waits for a new key. SHIFT is a prefix (the next key is read from the SHIFT table); DEF and
; SML alone are ignored. BRK ends the program (RT_BRK_CHECK -> RT_END).
; Out: A = key code (KEYTAB / its SHIFT table: 'A' = &41, 2 CL, 4 up, 5 down, 13 ENTER, 14 right, 15 left,
; 1 several keys), P = 3, I = 0.  Writes: A B I K L M N, DP, IA, &3E00.
PLAT_GETKEY:
        CLRA
        PUSH                        ; key-table offset: 0, KEYTAB_SHIFT after SHIFT
PLAT_GETKEY_1:
        LIA     249                 ; 250 x 2 ticks (about 1 s): how long a held key must stay down to repeat
        PUSH
PLAT_GETKEY_2:
        CALL    PLAT_WAIT_TICK
        CALL    PLAT_WAIT_TICK
        CALL    RT_BRK_CHECK
        CALL    ROM_KEYSCAN
        JRNCP   PLAT_GETKEY_3       ; released (or nothing was down)
        LOOP    PLAT_GETKEY_2
        JRP     PLAT_GETKEY_4       ; held for 1 s: repeat it (the counter is gone, A = raw code)
PLAT_GETKEY_3:
        POP                         ; drop the counter
PLAT_GETKEY_WAIT:
        CALL    RT_BRK_CHECK
        CALL    ROM_KEYSCAN
        JRNCM   PLAT_GETKEY_WAIT
PLAT_GETKEY_4:
        CPIA    KEY_RAW_SHIFT
        JRNZP   PLAT_GETKEY_5
        POP
        LIA     KEYTAB_SHIFT
        PUSH
        JRM     PLAT_GETKEY_1       ; wait for the release of SHIFT, then the key
PLAT_GETKEY_5:
        CPIA    KEY_RAW_DEF
        JRZM    PLAT_GETKEY_1
        CPIA    KEY_RAW_SML
        JRZM    PLAT_GETKEY_1
        EXAB                        ; B = raw code
        POP                         ; A = table offset
        LP      &03
        ADM                         ; B = raw code + offset
        LDM
        ADIA    LB@KEYTAB           ; (raw code <= &47, offset <= &48: no carry out of the low byte)
        LIB     HB@KEYTAB           ; (bank 0, BASIC's bank: mapped)
        JP      RT_INKEY_1          ; A = (BA), back to the caller through RT_INKEY's end

; Wait for the next 2 ms tick of the TEST register (bit 1). As on the PC-1350 (it waits for the flag twice: the first
; TEST may see a tick that was latched earlier). Writes nothing but the flags.
PLAT_WAIT_TICK:
        TEST    &02
        JRZM    PLAT_WAIT_TICK
PLAT_WAIT_TICK_1:
        TEST    &02
        JRZM    PLAT_WAIT_TICK_1
        RTN

; Write A to the control port (OUTC): bit 0 display on, bits 4-5 buzzer (Xout high / 2 kHz / 4 kHz), bit 6 Xin off.
; As on the PC-1350 (the same bits on the PC-1360). The runtime JUMPs here (BEEP). Writes: A (EXAM with the
; port latch), P = Q = &5F.
PLAT_OUTC_A:
        LIP     &5F
        EXAM
        OUTC
        RTN

; Character A (code >= &20) -> X = GLYPH_BUF + 5, the 5 glyph bytes copied there from the ROM font (bank 1, FONT_ROM,
; stored left to right) in the order the caller reads them with DXL (GLYPH_BUF + 4 = the leftmost column, as the
; PC-1350's right-to-left ROM font and the user-defined characters). Bank 1 is mapped for the copy only, then BASIC's
; bank 0 again. The code -> glyph mapping is the ROM's (bank 1 &54CE) without the kana: &20-&7F = font entry
; code - &20, &F5-&FC (sqrt, pi, ...) = entry code - &50, every other code a space (the ROM shows the kana &A0-&DF
; in Japanese mode only; LC-3 does not).
; In: A.  Out: X.  Writes: A B X Y, P, Q, DP (I and K..N survive: RT_LPRINT keeps a flag in I).
PLAT_GLYPH_PTR:
        CPIA    &80
        JRCP    PLAT_GLYPH_PTR_2
        SBIA    &30                 ; &F5-&FC -> &C5-&CC: entry code - &50 below
        CPIA    &C5
        JRCP    PLAT_GLYPH_PTR_SP
        CPIA    &CD
        JRCP    PLAT_GLYPH_PTR_2
PLAT_GLYPH_PTR_SP:
        LIA     &20                 ; a space
PLAT_GLYPH_PTR_2:
        PUSH
        LIA     LB@FONT_ROM_P1
        LIB     HB@FONT_ROM_P1
        CALL    H_BA_TO_X           ; X = font
        POP
        CALL    PLAT_GLYPH_PTR_X    ; X += 5 * (A - &1F): X = the glyph + 5
        LIA     LB@GLYPH_BUF
        LIB     HB@GLYPH_BUF
        CALL    H_BA_TO_Y           ; Y = GLYPH_BUF - 1 (IYS stores at Y + 1)
        LIA     FONT_BANK
        LIDP    BANK_PORT
        STD
        LIA     &04
        PUSH
PLAT_GLYPH_PTR_1:                   ; the glyph's last column first: GLYPH_BUF + 4 = its first column
        DXL
        IYS
        LOOP    PLAT_GLYPH_PTR_1
        LIDP    BANK_PORT
        ANID    BANK_BASIC          ; (= 0: bank 0 again)
        LP      &04
        LIQ     &06
        MVB                         ; X = Y = GLYPH_BUF + 4
        IX                          ; X = GLYPH_BUF + 5
        RTN

; User-defined character: X = font base (ARRAY_BASE + &60, set by the caller with H_BA_TO_X_B67 from A = &61: X = base),
; A = character code + &20 (&20-&3F)  ->  X = base + 5 * (code + 1), i.e. its 5 bytes + 5 (array elements stored
; right to left: sqrt96..sqrt100 = character 0, sqrt100 = its leftmost column). As on the PC-1350.
; In: A, X.  Out: X.  Writes: A B X, P.
PLAT_GLYPH_PTR_X:
        SBIA    &1F                 ; code + 1 (1-32)
        LIB     &00
        LP      &04                 ; X += 5 * (code + 1)  (ADB keeps A and B)
        ADB
        LP      &04
        ADB
        LP      &04
        ADB
        LP      &04
        ADB
        LP      &04
        ADB
        RTN

; RUN: clear the shadow variables (48 bytes from SHADOW_VARS) with A (= 0). As on the PC-1350. Writes: I, DP.
PLAT_FILL_DISPLAY:
        LII     SHADOW_CLEAR_LEN - 1
        LIDP    SHADOW_VARS
        FILD
        RTN

; BASIC's internal RAM &30-&3F <-> SAVE_IRAM30. As on the PC-1350: SWAP at the entries, RESTORE (copy back) at every
; exit. A, B, X, Y and the flags survive; I = &0F, P = &40, DP = SAVE_IRAM30 + &0F afterwards. RESTORE_IRAM30 ends
; with the RTN of the exit.
SAVE_IRAM30_SWAP:
        LII     &0F
        LIDP    SAVE_IRAM30
        LP      IR_SAVE_FIRST
        EXWD
        RTN

RESTORE_IRAM30:
        LII     &0F
        LIDP    SAVE_IRAM30
        LP      IR_SAVE_FIRST
        MVWD
        RTN
