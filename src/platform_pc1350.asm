; ============================================================================
; platform_pc1350.asm - platform entry points of the hardware-bound routines (PC-1350)
; ============================================================================
; The PC-1350 counterpart of platform_pc1262.asm. Same PLAT_* names, same contracts where the routine exists
; on both machines (see the notes); the display, graphics and keyboard code itself is in lc3_1350.asm.
; Only two ROM routines are called: the key scan (&0436, internal ROM) and the glyph pointer (BASIC-ROM vector
; &8087); everything else is local. J must stay 1 (callers use MVB).
; ============================================================================

; Key scan.  ROM &0436 (one scan of the whole matrix, no wait).
; Out: carry set and A = raw key code (&00-&3F; &40 = several keys; BRK gives &3F) if a key is down; carry clear if none.
; Writes: A B K L M N, port IA (left 0), &7E00 (left 0), DP, P, Q.  X and Y survive.
PLAT_KEYSCAN:
        JP      ROM_KEYSCAN

; Wait for a key (STOP, the INPUT function).  Local code (the PC-1262 used ROM &1138).
; A key that is already down when this is called is taken again only after it has been held about 1 s (key repeat),
; otherwise the routine waits for a new key. SHIFT is a prefix (the next key is read from the SHIFT table); DEF and
; SML alone are ignored. BRK ends the program (RT_BRK_CHECK -> RT_END).
; Out: A = key code (BASROM_KEYTAB / its SHIFT table: 'A' = &41, 2 CL, 4 up, 5 down, 13 ENTER, 14 right, 15 left,
; 1 several keys), P = 3 (H_A_FROM_BA), I = 0.  Writes: A B I K L M N, DP, IA, &7E00.
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
        CALL    PLAT_KEYSCAN
        JRNCP   PLAT_GETKEY_3       ; released (or nothing was down)
        LOOP    PLAT_GETKEY_2
        JRP     PLAT_GETKEY_4       ; held for 1 s: repeat it (the counter is gone, A = raw code)
PLAT_GETKEY_3:
        POP                         ; drop the counter
PLAT_GETKEY_WAIT:
        CALL    RT_BRK_CHECK
        CALL    PLAT_KEYSCAN
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
        ADIA    LB@BASROM_KEYTAB    ; (raw code <= &40, offset <= &82: no carry out of the low byte)
        LIB     HB@BASROM_KEYTAB
        JP      H_A_FROM_BA

; Wait for the next 2 ms tick of the TEST register (bit 1). A copy of the PC-1262 ROM routine &08CF (it waits for the
; flag twice: the first TEST may see a tick that was latched earlier). Writes nothing but the flags.
PLAT_WAIT_TICK:
        TEST    &02
        JRZM    PLAT_WAIT_TICK
PLAT_WAIT_TICK_1:
        TEST    &02
        JRZM    PLAT_WAIT_TICK_1
        RTN

; Write A to the control port (OUTC): bit 0 display on, bits 4-5 buzzer (Xout high / 2 kHz / 4 kHz), bit 6 Xin off.
; The same code as ROM &04B3 (PC-1350) and &043D (PC-1262). The runtime JUMPs here (BEEP). Writes: A (EXAM with the
; port latch), P = Q = &5F.
PLAT_OUTC_A:
        LIP     &5F
        EXAM
        OUTC
        RTN

; Character A (code >= &20) -> X = address of its 5 glyph bytes + 5 (the caller reads them with DXL, right to left).
; BASIC-ROM vector &8087 (= JP &8EEF), the ROM's own glyph routine: codes < &20 and unused codes give a space, kana
; (&A0-&DF) only in Japanese mode, &F5-&FC (sqrt, pi, ...) always. In: A.  Out: X.  Writes: A B X N, P.
PLAT_GLYPH_PTR:
        JP      ROM_GLYPH_VEC

; User-defined character: X = font base (ARRAY_BASE + &60, set by the caller with H_BA_TO_X_B67 from A = &61: X = base),
; A = character code + &20 (&20-&3F)  ->  X = base + 5 * (code + 1), i.e. its 5 bytes + 5 (array elements stored
; right to left: sqrt96..sqrt100 = character 0, sqrt100 = its leftmost column). In: A, X.  Out: X.  Writes: A B X, P.
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

; RUN: clear the shadow variables (48 bytes from SHADOW_VARS) with A (= 0). Replaces the PC-1262's ROM &1B31 (which
; filled the BASIC display buffer that the shadow variables overlay there). Writes: I, DP.
PLAT_FILL_DISPLAY:
        LII     SHADOW_CLEAR_LEN - 1
        LIDP    SHADOW_VARS
        FILD
        RTN

; BASIC's internal RAM &30-&3F <-> SAVE_IRAM30. SWAP at the entries (BASIC's values go to SAVE_IRAM30; the old content
; of the save area comes into &30-&3F, LC-3 initialises what it uses), RESTORE (copy back) at every exit. A, B, X, Y and
; the flags survive; I = &0F, P = &40, DP = SAVE_IRAM30 + &0F afterwards. RESTORE_IRAM30 ends with the RTN of the exit.
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
