; ============================================================================
; helpers.asm - local replacements for the internal-ROM helper routines of the PC-1262
; ============================================================================
; The original LC-3 called 31 tiny routines in the PC-1260/61/62 internal ROM (CAL &xxxx).
; Every routine below is a byte-for-byte copy of the ROM code (disassembled from
; pc1261mem.bin), so registers, P/Q, I/J, DP and the flags on return are the same as
; before; several callers rely on those leftovers (see the notes per routine).
; "CALL H_xxx" is 3 bytes, the old "CAL &xxxx" was 2 bytes.
;
; Single-use and 3-byte helpers are expanded inline at the call site instead (the comment at
; the site says "was CAL ROM_xxx"):
;   ROM_STORE_Y_P   (&134A)  LIQ &06 / MVB                          (P,P+1) = Y
;   ROM_SWAP_P_3031 (&15F2)  LIQ &30 / EXB                          swap (P,P+1) <-> (30,31)
;   ROM_P_FROM_3A   (&1A1A)  LIQ &3A / MVB                          (P,P+1) = (3A,3B)
;   ROM_X_BASIC_START (&13BD) LIDP BASIC_START_PTR / LP &04 / MVBD  X = (BASIC start)
;   ROM_Y1_TO_1516  (&0F7A)  IY / LP &15 / LIQ &06 / MVB / DY       (15,16) = Y+1
;   ROM_SET_0C_Y_SWAP_DP (&156E)  LP &0C / LIQ &06 / MVB / LP &0C / EXBD
;   ROM_COPY_B      (&1047)  IXL / IYS / DECB / JRNZM               copy B bytes X+1.. -> Y+1..
;   ROM_DP_INDICATOR (&1353) LIDP LCD_INDICATOR
; MVB / EXB / MVBD move 2 bytes because J = 1 (the BASIC convention at CALL time); nothing in
; LC-3 changes J. MVB / EXB leave P and Q advanced by the 2 bytes moved (P = start+2).
; The exit values of P and Q, the written internal RAM and the flags of every helper were measured against
; the ROM routines on random states by tests/helper_diff.py; the only difference is that the ROM routines that
; CAL another ROM routine leave a return address in the dead stack slot below R (the flat local code does not).
; Callers that use the exit P: "LP &1F ... was ROM_STORE_Y_P" error numbers (P = start+2, e.g. &21), ST_DEFAULT
; (H_SAVE_X_38 leaves P = &3A), RT_INKEY / RT_INPUT_STOP (H_A_FROM_BA leaves P = &03, see there).
; ============================================================================

; ---- X <-> (0C,0D) ------------------------------------------------------------------------
; ROM &13A3.  Swap X with the saved-X slot (0C,0D).  Out: P = &06, Q = &0E.
; Writes: (0C,0D) and X (the swap).  A, B, Y and DP unchanged (DP is NOT reloaded from X).
H_SWAP_X_0C:
        LP      &04
        LIQ     IR_SAVE_X
        EXB
        RTN

; ---- X = BA - 1, DP = X --------------------------------------------------------------------
; ROM &022C (B = &67 first) and &022E.  In: BA.  Out: X = BA-1 and DP = X (DX loads DP), P = &06, Q = &05.
; Writes X, DP.  A unchanged; B = &67 for the _B67 entry, else unchanged.
H_BA_TO_X_B67:
        LIB     HB@ARRAY_BASE
H_BA_TO_X:
        LP      &04
        LIQ     &02
        MVB
        DX
        RTN

; ---- Y = BA - 1, DP = Y --------------------------------------------------------------------
; ROM &0240 (B = &67 first) and &0242.  In: BA.  Out: Y = BA-1 and DP = Y (DY loads DP), P = &08, Q = &07.
; Writes Y, DP.  A unchanged; B = &67 for the _B67 entry, else unchanged.
; The _B67 entry is also CALLed from the OBJECT code after "sqrt n =" (was CAL &0240).
H_BA_TO_Y_B67:
        LIB     HB@ARRAY_BASE
H_BA_TO_Y:
        LP      &06
        LIQ     &02
        MVB
        DY
        RTN

; ---- A = (BA) ----------------------------------------------------------------------------
; ROM &0F30.  Uses the DATA instruction, which reads any address on the PC-1262 (the original
; LC-3 uses it for RAM tables, the BASIC key table and the data stack).
; Out: A = (BA), I = 0, P = &03 (the DATA instruction post-increments P), Q unchanged, B unchanged.
; The callers depend on P = &03: RT_INKEY then does "EXAM" (A <-> (3) = B), RT_AREAD likewise, and the
; compile error code of a bad DMS note is P (error 3, tests/lc3/e_dms_char.lc3).
; NOTE for step 3: the DATA instruction must be re-checked on the PC-1350/60 (RAM / BASIC-ROM addresses).
H_A_FROM_BA:
        LII     &00
        LP      &02
        DATA
        RTN

; ---- inline-data helpers: return address <-> X ---------------------------------------------
; ROM &1039 / &102E.  A routine F that was CALLed with inline data behind the CALL
; (CALL F / .db data ...) does "CALL H_RETADDR_TO_X": X = address of the inline data - 1, and
; F's own return address is removed from the CPU stack.  "CALL H_X_TO_RETADDR" pushes X back
; as the return address of F and returns there (so F continues behind the data).
; H_RETADDR_TO_X is also the ASN statement (object code CALL H_RETADDR_TO_X: drops one GOSUB level).
; They work on the R stack layout (return addresses are 2 bytes at (R,R+1)...); A and B are clobbered
; (H_RETADDR_TO_X also X, H_X_TO_RETADDR only A and the stack). Exit P/Q: &5A/&58 resp. &58/&56.
H_RETADDR_TO_X:
        LDR
        INCA
        INCA
        LP      &04
        STQ
        MVB
        STP
        EXAB
        LDR
        STQ
        MVB
        EXAB
        STR
        RTN

H_X_TO_RETADDR:
        LDR
        DECA
        DECA
        STP
        LIQ     &04
        MVB
        STQ
        EXB
        STR
        RTN

; ---- X <-> (38,39) -------------------------------------------------------------------------
; ROM &133B / &134E.  Out of LOAD: P = &06, Q = &3A.  Out of SAVE: P = &3A, Q = &06.  The compiler relies on this: the
; "LIQ &06 / MVB" that follows (was ROM_STORE_Y_P, in ST_DEFAULT) stores Y at (3A,3B), and the
; "LIQ &3A / MVB" (was ROM_P_FROM_3A) later reads it back.
H_LOAD_X_38:
        LP      &04
        LIQ     IR_SAVE_X38
        MVB
        RTN

H_SAVE_X_38:
        LP      IR_SAVE_X38
        LIQ     &04
        MVB
        RTN

; ---- 16-bit subtract / swap with Y, one chain of entry points (ROM &1541-&154D) ------------
; Exit of all four: P = &04, Q = &08 (SWAP_P_Y: P = the entry P + 2, Q = &08).
; H_SUB_DP_Y  : BA = (DP,DP+1); then falls into H_SUB_BA_Y
; H_SUB_BA_Y  : BA = BA - Y, carry = borrow (swap BA<->Y, Y = Y - BA, swap back)
; H_SWAP_BA_Y : swap BA <-> Y
; H_SWAP_P_Y  : swap (P,P+1) <-> Y
H_SUB_DP_Y:
        LP      &02
        MVBD
H_SUB_BA_Y:
        LP      &02
        LIQ     &06
        EXB
        LP      &06
        SBB
H_SWAP_BA_Y:
        LP      &02
H_SWAP_P_Y:
        LIQ     &06
        EXB
        RTN

; ---- POP / RTN (ROM &185E) -----------------------------------------------------------------
; Target of the conditional "JPC" in RT_COS_CLEARBOX.
H_POP_RTN:
        POP
        RTN
