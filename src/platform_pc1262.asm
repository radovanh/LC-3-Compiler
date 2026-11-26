; ============================================================================
; platform_pc1262.asm - platform entry points of the hardware-bound routines (PC-1262)
; ============================================================================
; Everything that still calls into the PC-1262 internal ROM goes through ONE of these stubs
; (a single tail "JP" each). Step 3 replaces this file and the platform equates in pc1262.inc with
; the PC-1350 code; the rest of lc3_1262.asm only does "CALL PLAT_xxx" / "JP PLAT_xxx" / "JPC PLAT_xxx".
; A stub is a tail jump, so the contract is exactly the contract of the ROM routine below.
; "Writes" lists the internal-RAM bytes the ROM routine changes (measured on random states, dead stack
; below R ignored); X, Y and everything not listed survive. J must stay 1 (callers use MVB).
; ============================================================================

; Key scan.  ROM &03C1.
; Out: carry set and A = key code if a key is down; carry clear if none (RT_PAUSE, RT_INKEY).
; Writes: A B K L M, P = Q = &5D.  (INKEY$ adds the code to BASROM_KEYTAB; PAUSE keeps its count on the stack.)
PLAT_KEYSCAN:
        JP      ROM_KEYSCAN

; Wait for a key (STOP / INPUT / the INPUT function).  ROM &1138.  Needs PLAT_KEYTIMER_INIT first.
; Out: A = key code (the caller masks the indicator byte first).
; Writes: I A B X Y K L M and more (it runs the BASIC key-input routine).
PLAT_GETKEY:
        JP      ROM_GETKEY

; Key-input timer initialisation.  ROM &19EE.  Called before PLAT_GETKEY.  Writes: A B.
PLAT_KEYTIMER_INIT:
        JP      ROM_KEYTIMER_INIT

; Wait for the next 2 ms tick of the TEST register (bit 1; the ROM loop waits for the flag twice).  ROM &08CF.
; Writes nothing but the flags.
PLAT_WAIT_TICK:
        JP      ROM_WAIT_TICK

; Write A to the control port (OUTC): bit 0 display on, bits 4-5 buzzer.  ROM &043D.
; The runtime JUMPs here (BEEP), so the routine's RTN returns to BEEP's caller.  Writes: A (EXAM with the
; port latch), P = Q = &5F.
PLAT_OUTC_A:
        JP      ROM_OUTC_A

; Character A (code >= &20, font in the BASIC ROM at &8045) -> X = pointer to its 5 glyph bytes, one below the
; first (the caller does DXL, IYS 5 times).  ROM &135F.  In: A.  Out: X.  Writes: A B X N.
PLAT_GLYPH_PTR:
        JP      ROM_GLYPH_PTR

; Same, but the font base is already in X (the user-defined characters at ARRAY_BASE + &60, set by the caller
; with H_BA_TO_X_B67).  ROM &1367 (the second entry of PLAT_GLYPH_PTR, which skips the base setup).
; In: A = character code + &20 (0-&1F = user character), X = font base.  Out: X.  Writes: A B XL N.
PLAT_GLYPH_PTR_X:
        JP      ROM_GLYPH_PTR_X

; Fill the BASIC display buffer (&6650-&667F) with A.  ROM &1B31.  Used by RUN.  Writes: I, DP.
PLAT_FILL_DISPLAY:
        JP      ROM_FILL_DISPLAY

; Fill the BASIC input buffer (&67B0-&67FF) with &0D.  ROM &1BA7.  Writes: I A, DP (left in page &67).
; JPC'd to at the end of a successful compile (carry set = return to BASIC) and CALLed by END.
PLAT_FILL_INPBUF:
        JP      ROM_FILL_INPBUF
