; ============================================================================
; LC-3 compiler + runtime for the SHARP PC-1261/1262 (PJ magazine 1989)
; Rebuilt source (step 1), platform layer (step 2). Files: lc3_1262.asm (this), pc1262.inc (equates,
; BASIC entry/exit contract, iram map), helpers.asm (local copies of the internal-ROM helpers),
; platform_pc1262.asm (the remaining hardware routines, one stub each). Assembler: sc61860-asm.js,
; build with tools/build_1262.sh (it also runs tools/check_layout.py).
; STEP 2: no CAL into the internal ROM is left except the platform stubs, no jump into the BASIC ROM.
; The binary is therefore NOT byte-identical to LC-3.bin (2306 bytes) any more: it is 2492 bytes
; (&4000-&49BB), the object area starts at OBJ_START = &49BC (was &4902), run entry RT_RUN_ENTRY = &49BA
; (was &4900). Equivalence with the original is shown by tests/run_regression_1262.sh check-orig.
;
; Notation: "(P)" = internal-RAM byte addressed by P, "X/Y" = 16-bit registers at
; internal RAM &04/&05 and &06/&07, "K L M N" = &08..&0B, "(nn)" = internal RAM byte nn.
; Compile time: X = source pointer, Y = object pointer. Run time: Y = VRAM pointer.
;
; SIZE TRICKS that this source keeps byte for byte (do not "clean them up"):
;  * Hidden entry points inside other instructions. A one-byte opcode that swallows
;    the next 1-2 bytes (LIDP, LIQ, LIA ...) is written as ".db &xx" and the swallowed
;    bytes follow as real instructions under their own label, e.g.
;    GOTO_LABEL, ST_RETURN, RT_MOD, RT_RUN_ENTRY. Where the two paths straddle other
;    instructions the hidden entry is a "label+n" equate: RT_PEEK, RT_TRON, RT_PRINT_LT100.
;    Two of the original hidden entries swallowed a 2-byte "CAL rom"; as a 3-byte CALL cannot be
;    swallowed they became a JRP (RT_CURSOR_CALC -> RT_SQRT_ARRAY_1, RT_CHR -> FONT_ROM_GLYPH_DONE).
;  * MVMP (&54) is used as a ONE-byte instruction: it stores the next opcode byte
;    into (P) and that next instruction still executes. LDPC (&56) likewise loads
;    A with the next byte, which also executes (ST_ARRAY).
;  * Inline data after CALL EMIT_INL2 / EMIT_CALL_INL (bytes to emit) and in the
;    runtime after the string/array/hex/DEG/GRAD/DMS/RESTORE routines (read back
;    through H_RETADDR_TO_X / H_X_TO_RETADDR, which turn the return address into X).
;  * PTC/DTC dispatch table in STMT_NEXT; self-modifying ANID masks in RT_COS_CLEARBOX.
;  * The object code calls two local helpers (H_BA_TO_Y_B67 after "sqrt n =", H_RETADDR_TO_X for ASN),
;    where the original object code called the ROM (CAL &0240 = 2 bytes, CALL &1039). The first is 1 byte
;    longer per array assignment.
;
; PAGE CONSTRAINTS (relocation hazards, the assembler does not check them; tools/check_layout.py does):
;  * EMIT_CALL_FUNC emits the HIGH byte of RT_MUL for every routine named in TBL_RT_LO, so all 20 of
;    them (RT_USERFN_HOOK .. RT_RND, listed in TBL_RT_LO) must lie in the page of RT_MUL. The group is
;    kept in page &46 and RT_USERFN_HOOK at &4600 (the user-function hook address of the article), which
;    fixes the amount of code in front of it: the routines in the "behind the page-bound group" block
;    (RT_DIM, RT_VAL, RT_BEEP, RT_CLS, helpers, platform stubs) were moved behind the group for that.
;  * TBL_RT_LO and the tone table behind it (TBL_RT_END) must be in ONE page: EMIT_FUNC_LOBYTE adds the
;    index to the low byte only (the carry is dropped), for function calls and for DMS notes alike.
;    (Not in the original header; the original table at &44BD..&44FB just fitted.)
;  * TBL_OPERATORS and TBL_FUNCTIONS must share one page (high byte loaded once in
;    TABLE_LOOKUP); TBL_STATEMENTS is searched with the same style of address.
;  * COS_MASK1/COS_MASK2 (self-modified bytes) must be in one page (LIDP + LIDL).
;  * Statement-table handler addresses are stored as (flags | high byte), flags using
;    bits 7 and 5: a handler must be < &2000 or in &4000-&5FFF.
;  * RT_RUN falls through (hidden LIDP) into the object code: OBJ_START must follow RT_RUN_ENTRY directly.
; ============================================================================
        INCLUDE "pc1262.inc"
        ORG     CODE_ORG


COMPILE:
        LIB     HB@OBJ_START | &80   ; pass 1: bit 15 set, so every IYS hits ROM and is lost
        LP      IR_PASS_FLAG
        MVMP                        ; (P) <- &00: the next opcode byte is stored and ALSO executed
        LII     &FF
        LIDP    ARRAY_BASE
        FILD

PASS_START:
        CLRA
        LII     &0F
        LP      &10
        FILM
        LIA     LB@OBJ_START
        CALL    H_BA_TO_Y
        LIDP    BASIC_START_PTR     ; was CAL ROM_X_BASIC_START: X = (BASIC_START_PTR)
        LP      &04
        MVBD

LINE_END:
        LP      &14
        CPIM    &00
        JRZP    NEXT_LINE
        MVMP                        ; (P) <- &00: the next opcode byte is stored and ALSO executed
        LII     &03
        CALL    H_SWAP_BA_Y
        LIQ     &97
        LP      &04
        MVW
        CALL    H_SUB_BA_Y
        IYS
        JRP     STMT_START

NEXT_LINE:
        IXL
        INCA
        JRNZP   COMPILE_ERROR_1

SOURCE_END:
        CALL    ST_END
        LP      IR_PASS_FLAG
        ADIM    &80
        JPC     PLAT_FILL_INPBUF
        LIDP    BASIC_START_PTR
        LP      &07
        ANIM    &7F
        CALL    H_SUB_DP_Y
        LIB     HB@OBJ_START         ; pass 2: real object pointer
        JRNCM   PASS_START

COMPILE_ERROR:
        LDP
        LP      IR_ERR_CODE
        EXAM
        LP      IR_ERR_FLAG
        MVMP                        ; (P) <- &10: the next opcode byte is stored and ALSO executed
        LIDP    ERR_POS_ADDR
        LP      &04
        EXBD
        LIA     STACK_ON_ERROR
        STR
        SC
        RTN
COMPILE_ERROR_1:
        IX
        IX
        IY                          ; was CAL ROM_Y1_TO_1516: (15,16) = Y+1, Y unchanged
        LP      &15
        LIQ     &06
        MVB
        DY

STMT_START:
        LP      &13
        MVMP                        ; (P) <- &24: the next opcode byte is stored and ALSO executed

STMT_NEXT:
        IXL
        CPIA    &0D
        JRZM    LINE_END
        CPIA    &2E
        JRZM    SOURCE_END
        CALL    H_SWAP_X_0C
        LP      &08
        EXAM
        LIA     LB@TBL_STATEMENTS
        LIB     HB@TBL_STATEMENTS
        CALL    H_BA_TO_X
        LP      &08
STMT_NEXT_1:
        IXL
        CPMA
        IX
        JRZP    ST_GENERIC
        IX
        INCA
        JRNCM   STMT_NEXT_1
        LDM
        CALL    H_SWAP_X_0C
        PTC
        .db 15                    ; 15 table entries; PTC pushes the return address ...
        .dw STMT_NEXT             ; ... so every handler just RTNs to STMT_NEXT
        DTC                       ; A = statement byte: find it in the table and jump to the entry address
                                  ; entry = token byte, handler address (big endian)
        .db TK_IF                 ; IF
        .dw ST_IF
        .db TK_GOTO               ; GOTO
        .dw ST_GOTO
        .db TK_GOSUB              ; GOSUB
        .dw ST_GOSUB
        .db TK_RETURN             ; RETURN
        .dw ST_RETURN
        .db TK_END                ; END
        .dw ST_END
        .db TK_REM                ; REM (BASIC ROM handler)
        .dw ST_REM
        .db CH_SQRT               ; sqrt char = array assignment
        .dw ST_ARRAY
        .db TK_DATA               ; DATA
        .dw ST_DATA
        .db CH_QUOTE              ; "string"
        .dw ST_STRING
        .db TK_DEG                ; DEG
        .dw ST_DEG
        .db TK_GRAD               ; GRAD
        .dw ST_GRAD
        .db TK_RESTORE            ; RESTORE
        .dw ST_RESTORE
        .db TK_DMS                ; DMS
        .dw ST_DMS
        .db CH_EXCL               ; ! hex data
        .dw ST_HEX
        .db CH_COLON              ; : separator
        .dw ST_COLON
        .dw ST_DEFAULT                 ; default case: label definition or variable assignment

ST_GENERIC:
        LP      &21
        MVBD
        CALL    H_SWAP_X_0C
        LP      &21
        TSIM    &80
        JRZP    ST_GENERIC_1
        CALL    EXPR
        CALL    EMIT_INL2
        .db &91,&DB                ; emits LP &11 / EXAM
        IXL
        CPIA    &2C
        JRZP    ST_GENERIC_1
        DX
ST_GENERIC_1:
        LP      &21
        TSIM    &A0
        JRZP    ST_GENERIC_2
        CALL    EXPR
ST_GENERIC_2:
        LIA     &78
        IYS
        LP      &21
        ANIM    &5F
        IY
        EXBD
        IY
        JRM     STMT_START

ST_GOTO:
        IXL
        CPIA    &5E
        JRNZP   GOTO_LABEL
        LIA     &2D

EMIT_JR_LINESTART:
        IYS
        LP      &08
        LIQ     &06                 ; was CAL ROM_STORE_Y_P: (P,P+1) = Y
        MVB
        LIQ     &95
        LP      &02
        MVB
        LP      &08
        SBB
        LP      &08
        LDM
        INCA
        IYS
        RTN

EMIT_JP_LABEL:
        LDM
        .db &10        ; LIDP: when entered from above it swallows the next 2 bytes (the LIA below)

GOTO_LABEL:
        LIA     &79
        DX
        JRP     ST_GOSUB_1

ST_GOSUB:
        LP      &13
        MVMP                        ; (P) <- &02: the next opcode byte is stored and ALSO executed
        LIA     &78
ST_GOSUB_1:
        IYS

EMIT_LABEL_ADDR:
        IXL
        CALL    PARSE_LABEL
        EXAB
        IXL
        CALL    H_SWAP_X_0C
        LP      IR_PASS_FLAG
        TSIM    &80
        JRZP    EMIT_LABEL_ADDR_1
        ANIA    &7F
        JRZM    COMPILE_ERROR
EMIT_LABEL_ADDR_1:
        IYS
        EXAB
        .db &10        ; LIDP: swallows the LIA below when entered from above

ST_RETURN:
        LIA     &37
        IYS
        RTN

PARSE_RELOP:
        LP      &09
        LIA     &7F
        EXAM
        IXL
        SBIA    &3C
        JRZP    PARSE_RELOP_1
        DECL
        DECA
        JRZP    PARSE_RELOP_1
        DECL
        DECA
        JRNZP   PARSE_RELOP_2
        IXL
        CPIA    &3D
        JRNZM   COMPILE_ERROR
PARSE_RELOP_1:
        RC
        RTN
PARSE_RELOP_2:
        DECL
        CPIA    &1E
        JRZM    PARSE_RELOP_1
        DX
PARSE_RELOP_3:
        SC
        RTN

ST_IF:
        CALL    H_SAVE_X_38
        CALL    GET_ELEMENT
        TSIM    &20
        JRZP    ST_IF_2
        LP      &11
        LDM
        LP      &12
        EXAM
        CALL    PARSE_RELOP
        JRCP    ST_IF_2
        CALL    H_SAVE_X_38
        CALL    GET_ELEMENT
        ANIM    &90
        CPIM    &90
        JRNZP   ST_IF_1
        CALL    EMIT_LP_CACHED
        LIA     &63
        JRP     ST_IF_4
ST_IF_1:
        CALL    H_LOAD_X_38
        CALL    EXPR
        CALL    EMIT_LP_CACHED
        LIA     &C7
        JRP     ST_IF_5
ST_IF_2:
        CALL    H_LOAD_X_38
        CALL    EXPR
        CALL    PARSE_RELOP
        JRNCP   ST_IF_3
        LIA     &43
        IYS
        LIA     &7D
        EXAM
        JRP     ST_IF_8
ST_IF_3:
        CALL    GET_ELEMENT
        TSIM    &80
        JRZP    ST_IF_7
        TSIM    &10
        JRZP    ST_IF_6
        LIA     &67
ST_IF_4:
        IYS
        LP      &11
        LDM
ST_IF_5:
        IYS
        JRP     ST_IF_8
ST_IF_6:
        TSIM    &20
        JRZP    ST_IF_7
        CALL    EMIT_LP_CACHED_11
        CALL    EMIT_INL2_KEEP_LP
        EXAM
        CPMA
        LIA     &DB
        JRM     ST_IF_5
ST_IF_7:
        CALL    EMIT_INL2
        .db &91,&DB                ; emits LP &11 / EXAM
        LP      &10
        CALL    EMIT_FIRST_LOADED
        CALL    EXPR_CONT
        CALL    EMIT_INL2
        .db &91,&C7                ; emits LP &11 / CPMA
ST_IF_8:
        LP      &09
        IXL
        CPIA    &C6
        JRNZP   ST_IF_10
        IXL
        CPIA    &5E
        JRNZM   EMIT_JP_LABEL
        LDM
        ADIA    &98
        SL
        CPIA    &2C
        JRCP    ST_IF_9
        ADIA    &0C
ST_IF_9:
        JRM     EMIT_JR_LINESTART
ST_IF_10:
        DX
        LDM
        SBIA    &60
        SL
        CPIA    &3C
        JRCP    ST_IF_11
        SBIA    &14
ST_IF_11:
        IYS
        LP      &14
        CPIM    &00
        JRNZP   ST_IF_12
        LII     &03
        MVMP                        ; (P) <- &13: the next opcode byte is stored and ALSO executed
        LIQ     &84
        LP      &17
        MVW
ST_IF_12:
        IY
        LP      &13
        MVMP                        ; (P) <- &37: the next opcode byte is stored and ALSO executed
        RTN

GET_ELEMENT_OP:
        LP      &10
        ANIM    &08
        CALL    GET_OPERATOR
        DECB
        JRZM    PARSE_RELOP_3
        IX
        EXAB
        ORMA

GET_ELEMENT:
        LP      &10
        ANIM    &0F
        LP      &11
        MVMP                        ; (P) <- &00: the next opcode byte is stored and ALSO executed
        LII     &00
GET_ELEMENT_1:
        IXL
        SBIA    &3A
        JRNCP   GET_ELEMENT_3
        ADIA    &0A
        JRNCP   GET_ELEMENT_3
        LII     &09
        EXAM
GET_ELEMENT_2:
        ADM
        DECI
        JRNCM   GET_ELEMENT_2
        JRM     GET_ELEMENT_1
GET_ELEMENT_3:
        DECI
        JRCP    GET_OPERATOR_2
GET_ELEMENT_4:
        DX
GET_ELEMENT_5:
        LP      &10
        ORIM    &10

GET_OPERATOR:
        IXL
        LII     &07
        LIB     LB@TBL_OPERATORS
        CALL    TABLE_LOOKUP
        EXAB
        LP      &10
        JRNZP   GET_OPERATOR_1
        ORIM    &80
GET_OPERATOR_1:
        INCB
        DX
        RTN
GET_OPERATOR_2:
        CPIA    &F2
        JRNZP   GET_OPERATOR_4
GET_OPERATOR_3:
        MVMD
        IXL
        CPIA    &0D
        JRZM    GET_ELEMENT_4
        CPIA    &22
        JRNZM   GET_OPERATOR_3
        JRM     GET_ELEMENT_5
GET_OPERATOR_4:
        CPIA    &06
        JRCP    GET_OPERATOR_5
        CPIA    &21
        JRNCP   GET_OPERATOR_5
        ADIA    &8F
        EXAM
        LP      &10
        ORIM    &20
        JRM     GET_OPERATOR
GET_OPERATOR_5:
        LII     &0E
        LIB     LB@TBL_FUNCTIONS
        CALL    TABLE_LOOKUP
        JRZP    PARSE_LABEL_1
        LP      &08
        EXAM
        LP      &10
        RTN

TABLE_LOOKUP:
        LP      &08
        EXAM
        CALL    H_SWAP_X_0C
        LIA     HB@TBL_OPERATORS     ; same page for TBL_OPERATORS and TBL_FUNCTIONS
        EXAB
        CALL    H_BA_TO_X
        LP      &08
TABLE_LOOKUP_1:
        IXL
        CPMA
        JRZP    TABLE_LOOKUP_2
        DECI
        JRNZM   TABLE_LOOKUP_1
TABLE_LOOKUP_2:
        CALL    H_SWAP_X_0C
        LP      &00
        LDM
        CPIA    &00
        RTN

EMIT_FIRST:
        CALL    GET_ELEMENT

EMIT_FIRST_LOADED:
        TSIM    &10
        JRZP    EMIT_FIRST_LOADED_2
        LP      &11
        CPIM    &00
        JRNZP   EMIT_FIRST_LOADED_1
        LIA     &23
        IYS
        RTN
EMIT_FIRST_LOADED_1:
        LIA     &02
        IYS
        JRP     EMIT_FIRST_CONST
EMIT_FIRST_LOADED_2:
        TSIM    &20
        JRZP    EMIT_FUNCTION
        CALL    EMIT_LP_CACHED_11
        .db &02        ; LIA: swallows the LDM below when entered from above

EMIT_FIRST_CONST:
        LDM
        IYS
        RTN

EMIT_FUNCTION:
        LP      &08
        LDM
        ADIA    &06
        CPIA    &0C
        JRCP    EMIT_CALL_FUNC
        PUSH
        CALL    EXPR
        POP
        CPIA    &14
        JRNZP   EMIT_FUNCTION_2
        CALL    EMIT_INL2
        .db &92,&DB                ; emits LP &12 / EXAM
        IXL
        CPIA    &2C
        JRZP    EMIT_FUNCTION_1
        DX
EMIT_FUNCTION_1:
        CALL    EXPR_EMIT_CALL_INL
        .dw RT_PI_POINT            ; emits the address of the PI runtime routine (after the CALL opcode)
        JRP     EMIT_FUNCTION_3
EMIT_FUNCTION_2:
        CALL    EMIT_CALL_FUNC
EMIT_FUNCTION_3:
        IXL
        CPIA    &29
        JRZP    EMIT_FUNCTION_4
        DX
EMIT_FUNCTION_4:
        RTN

ST_END:
        LIA     &14

EMIT_CALL_FUNC:
        PUSH
        CALL    EMIT_INL2
        .db &78, HB@RT_MUL         ; emits CALL + page of all runtime routines (low byte comes from TBL_RT_LO)
        POP

EMIT_FUNC_LOBYTE:
        ADIA    (TBL_RT_LO-1) & 255  ; K+6+this = low byte of the table slot
        LIB     HB@TBL_RT_LO
        CALL    H_A_FROM_BA
        IYS
        RTN

EXPR_EMIT_CALL_INL:
        CALL    EXPR

EMIT_CALL_INL:
        LIA     &78
        IYS

EMIT_INL2:
        LP      &13
        MVMP                        ; (P) <- &F3: the next opcode byte is stored and ALSO executed

EMIT_INL2_KEEP_LP:
        CALL    H_SWAP_X_0C
        CALL    H_RETADDR_TO_X
        DX
        IXL
        IYS
        IXL
        IYS
        IX
        CALL    H_X_TO_RETADDR
        JP      H_SWAP_X_0C

EMIT_LP_CACHED:
        LP      &12
        .db &02        ; LIA: swallows the LP &11 below when entered from EMIT_LP_CACHED
EMIT_LP_CACHED_11:
        LP      &11
        LDM
        LP      &13
        CPMA
        JRZP    EMIT_LP_CACHED_11_1
        IYS
        EXAM
EMIT_LP_CACHED_11_1:
        RTN

PARSE_LABEL:
        LP      &1E
        SBIA    &27
PARSE_LABEL_1:
        JPNC    COMPILE_ERROR
        ADIA    &04
        JRNCM   PARSE_LABEL_1
        SWP
        RC
        SL
        EXAM
        IXL
        SBIA    &5B
        JRNCM   PARSE_LABEL_1
        ADIA    &20
        JRNCM   PARSE_LABEL_1
        ADM
        LDM
        SL
        CALL    H_SWAP_X_0C
        CALL    H_BA_TO_X_B67
        IXL
        RTN

LABEL_DEF:
        IY
        CALL    PARSE_LABEL
        IXL
        DX
        CALL    H_SWAP_X_0C
        LP      IR_PASS_FLAG
        CPIM    &00
        JRNZP   LABEL_DEF_1
        DECA
        LP      &0A
        JRNCM   PARSE_LABEL_1
        LP      IR_SAVE_X           ; was CAL ROM_SET_0C_Y_SWAP_DP: (0C,0D) = Y, then swap (0C,0D) <-> (DP)
        LIQ     &06
        MVB
        LP      IR_SAVE_X
        EXBD
LABEL_DEF_1:
        DY
        LP      &13
        MVMP                        ; (P) <- &37: the next opcode byte is stored and ALSO executed
        RTN

ST_DEFAULT:
        CPIA    &40
        JRCM    LABEL_DEF
        CPIA    &5B
        JRNCM   LABEL_DEF
        ADIA    &55
        LP      &12
        EXAM
        IXL
        CPIA    &3D
        JRZP    ST_DEFAULT_1
        DX
ST_DEFAULT_1:
        CALL    H_SAVE_X_38
        LIQ     &06                 ; was CAL ROM_STORE_Y_P: (P,P+1) = Y
        MVB
        CALL    GET_ELEMENT
        TSIM    &20
        JRZP    ST_DEFAULT_4
        LP      &12
        LDM
        LP      &11
        CPMA
        JRNZP   ST_DEFAULT_4
ST_DEFAULT_2:
        CALL    GET_ELEMENT_OP
        TSIM    &04
        JRZP    ST_DEFAULT_4
        TSIM    &10
        JRZP    ST_DEFAULT_4
        CALL    EMIT_LP_CACHED
        LP      &10
        LDM
        ANIA    &07
        ADIA    &6C
        CPIA    &72
        JRCP    ST_DEFAULT_3
        SBIA    &12
ST_DEFAULT_3:
        IYS
        TSIM    &80
        LP      &11
        LDM
        IYS
        JRZM    ST_DEFAULT_2
        RTN
ST_DEFAULT_4:
        LP      &13
        MVMP                        ; (P) <- &F3: the next opcode byte is stored and ALSO executed
        CALL    H_LOAD_X_38
        LP      &06
        LIQ     IR_SAVE_Y3A         ; was CAL ROM_P_FROM_3A: (P,P+1) = (3A,3B)
        MVB
        CALL    EXPR
        CALL    EMIT_LP_CACHED
        LIA     &DB
        IYS

ST_COLON:
        RTN

EXPR:
        CALL    EMIT_FIRST

EXPR_CONT:
        CALL    GET_ELEMENT_OP
        JRCM    ST_COLON
        LDM
        TSIM    &10
        JRZP    EXPR_CALL_RT_PLUS3_1
        TSIM    &04
        LP      &11
        JRZP    EXPR_CONT_5
        ANIA    &07
        CPIM    &01
        JRNZP   EXPR_CONT_3
        CPIA    &04
        JRZP    EXPR_CONT_1
        CPIA    &05
        JRNZP   EXPR_CONT_3
EXPR_CONT_1:
        ADIA    &3E
EXPR_CONT_2:
        IYS
        JRM     EXPR_CONT
EXPR_CONT_3:
        ADIA    &70
        CPIA    &76
        JRCP    EXPR_CONT_4
        SBIA    &12
EXPR_CONT_4:
        IYS
        LDM
        JRM     EXPR_CONT_2
EXPR_CONT_5:
        LIA     &03
        IYS
        LDM
        IYS
EXPR_CONT_6:
        LP      &10
        LDM
        .db &10        ; LIDP: swallows the ADIA &03 below when entered from above

EXPR_CALL_RT_PLUS3:
        ADIA    &03
        ANIA    &07
        CALL    EMIT_CALL_FUNC
        JRM     EXPR_CONT
EXPR_CALL_RT_PLUS3_1:
        TSIM    &20
        JRNZP   EXPR_CALL_RT_PLUS3_4
        PUSH
        LIA     &34
        IYS
        CALL    EMIT_FUNCTION
        POP
        LP      &10
        EXAM
        LIA     &5B
        IYS
        TSIM    &04
        JRZM    EXPR_CONT_6
        ANIM    &07
        CPIM    &05
        JRNZP   EXPR_CALL_RT_PLUS3_3
EXPR_CALL_RT_PLUS3_2:
        LIA     &DB
        IYS
EXPR_CALL_RT_PLUS3_3:
        LDM
        ADIA    &40
        IYS
        LIA     &DB
        JRM     EXPR_CONT_2
EXPR_CALL_RT_PLUS3_4:
        CALL    EMIT_LP_CACHED_11
        LP      &10
        TSIM    &04
        LDM
        JRZM    EXPR_CALL_RT_PLUS3
        ANIM    &07
        JRM     EXPR_CALL_RT_PLUS3_2
EXPR_CALL_RT_PLUS3_5:
        CALL    EMIT_LABEL_ADDR
        .db &13        ; LIQ: skips the IY below (the +label path)

HEX_FORWARD:
        IY
        .db &13        ; LIQ: skips the DY below

HEX_BACK:
        DY

ST_HEX:
        LP      &09
        LII     &01
ST_HEX_1:
        SWP
        EXAM
        IXL
        CPIA    &3C
        JRZM    HEX_BACK
        CPIA    &3E
        JRZM    HEX_FORWARD
        CPIA    &2B
        JRZM    EXPR_CALL_RT_PLUS3_5
        SBIA    &3A
        JRNCP   ST_HEX_2
        ADIA    &0A
        JRNCP   ST_ARRAY_2
        JRP     ST_HEX_3
ST_HEX_2:
        CPIA    &07
        JRCP    ST_ARRAY_2
        CPIA    &0D
        JRNCP   ST_ARRAY_2
        ADIA    &03
ST_HEX_3:
        ORMA
        DECI
        JRNCM   ST_HEX_1
        LDM
        IYS
        INCK
        JRM     ST_HEX

ST_ARRAY:
        CALL    EXPR
        IXL
        CPIA    &3D
        JRNZP   ST_ARRAY_3
        CALL    EMIT_CALL_INL
        .dw H_BA_TO_Y_B67          ; emits CALL H_BA_TO_Y_B67 (was CAL &0240 in the ROM)
ST_ARRAY_1:
        CALL    EXPR
        LDPC                        ; A <- &26: the next byte is loaded and ALSO executed
        IYS
        IXL
        CPIA    &2C
        JRZM    ST_ARRAY_1
ST_ARRAY_2:
        DX
        RTN
ST_ARRAY_3:
        CALL    EMIT_CALL_INL
        .dw RT_ARRAY_HEX
ST_ARRAY_4:
        CALL    EMIT_LEN_SLOT
        CALL    ST_HEX
        .db &13        ; LIQ: skips the DX below

STRING_END_DX:
        DX
STRING_END_DX_1:
        LP      &1F
        CALL    H_SWAP_P_Y
        DECK
        JRCP    ST_DMS_1
        LP      &08
        LDM
        IYS
        LP      &1F
        JP      H_SWAP_P_Y

EMIT_LEN_SLOT:
        LP      &08
        ANIM    &00
        LP      &1F
        LIQ     &06                 ; was CAL ROM_STORE_Y_P: (P,P+1) = Y
        MVB
        IY
        RTN

ST_DEG:
        CALL    EMIT_CALL_INL
        .dw RT_DEG
        JRM     ST_ARRAY_4

ST_GRAD:
        CALL    EMIT_CALL_INL
        .dw RT_GRAD
        JRM     ST_ARRAY_4

ST_STRING:
        CALL    EMIT_CALL_INL
        .dw RT_STRING
        CALL    EMIT_LEN_SLOT
        LIB     &00
ST_STRING_1:
        IXL
        CPIA    &20
        JRCM    STRING_END_DX
        CPIA    &22
        JRZM    STRING_END_DX_1
        CPIA    &FE
        JRZM    ST_STRING_1
        CPIA    &FB
        JRNZP   ST_STRING_2
        INCB
        JRM     ST_STRING_1
ST_STRING_2:
        LP      &03
        TSIM    &01
        JRZP    ST_STRING_3
        ANIA    &1F
ST_STRING_3:
        IYS
        INCK
        JRM     ST_STRING_1

ST_DMS:
        CALL    EMIT_CALL_INL
        .dw RT_DMS
        CALL    EMIT_LEN_SLOT
        IXL
        CPIA    &22
ST_DMS_1:
        JPNZ    COMPILE_ERROR
ST_DMS_2:
        IXL
        CPIA    &22
        JRZM    STRING_END_DX_1
        CPIA    &20
        JRCM    STRING_END_DX
        SBIA    &5B
        JRNCM   ST_DMS_1
        ADIA    &2B
        JRNCM   ST_DMS_1
        ADIA    &15
        CALL    EMIT_FUNC_LOBYTE
        INCK
        JRM     ST_DMS_2

ST_DATA:
        CALL    GET_ELEMENT
        TSIM    &10
        JPZ     COMPILE_ERROR
        LP      &11
        LDM
        IYS
        IXL
        CPIA    &2C
        JRZM    ST_DATA
        DX
        RTN

ST_RESTORE:
        CALL    EMIT_CALL_INL
        .dw RT_RESTORE
        JP      EMIT_LABEL_ADDR

ST_REM:                             ; REM: skip to the end of the line (was the BASIC-ROM handler BASROM_REM)
        IXL
        CPIA    &0D
        JRNZM   ST_REM
        DX
        RTN

TBL_OPERATORS:
        .db &A2                 ; operator #7: OR
        .db &A1                 ; operator #6: AND
        .db &2D                 ; operator #5: -
        .db &2B                 ; operator #4: +
        .db &25                 ; operator #3: %
        .db &2F                 ; operator #2: /
        .db &2A                 ; operator #1: *
TBL_FUNCTIONS:                    ; (token - &3A) is looked up here, index K = 14..1
        .db &74                 ; K=14 PI
        .db &C2                 ; K=13 sqrt (array read)
        .db &6D                 ; K=12 PEEK
        .db &60                 ; K=11 SGN
        .db &5F                 ; K=10 ABS
        .db &59                 ; K= 9 EXP
        .db &58                 ; K= 8 LOG
        .db &66                 ; K= 7 RND
        .db &F8                 ; K= 6 ( (parenthesis)
        .db &A5                 ; K= 5 INPUT (user hook)
        .db &A7                 ; K= 4 AREAD
        .db &5E                 ; K= 3 INT
        .db &A1                 ; K= 2 READ
        .db &73                 ; K= 1 INKEY$
TBL_STATEMENTS:                   ; token, flags|handler-hi, handler-lo (ST_ARG1 = first operand -> (11), ST_ARGA = operand in A)
        .db TK_RUN, HB@RT_RUN, LB@RT_RUN   ; RUN
        .db TK_WAIT, HB@RT_WAIT | ST_ARGA, LB@RT_WAIT   ; WAIT
        .db TK_STOP, HB@RT_INPUT_STOP, LB@RT_INPUT_STOP   ; STOP
        .db TK_CLEAR, HB@RT_CLEAR | ST_ARGA, LB@RT_CLEAR   ; CLEAR
        .db TK_DIM, HB@RT_DIM | ST_ARGA, LB@RT_DIM   ; DIM
        .db TK_VAL, HB@RT_VAL, LB@RT_VAL   ; VAL
        .db TK_CLS, HB@RT_CLS | ST_ARGA, LB@RT_CLS   ; CLS
        .db TK_CURSOR, HB@RT_CURSOR | ST_ARGA, LB@RT_CURSOR   ; CURSOR
        .db TK_PRINT, HB@RT_PRINT | ST_ARGA, LB@RT_PRINT   ; PRINT
        .db TK_LPRINT, HB@RT_LPRINT | ST_ARGA, LB@RT_LPRINT   ; LPRINT
        .db TK_CHR, HB@RT_CHR | ST_ARGA, LB@RT_CHR   ; CHR$
        .db TK_POKE, HB@RT_POKE | ST_ARGA, LB@RT_POKE   ; POKE
        .db TK_ON, HB@RT_ON | ST_ARG1 | ST_ARGA, LB@RT_ON   ; ON
        .db TK_COS, HB@RT_COS_CLEARBOX | ST_ARG1 | ST_ARGA, LB@RT_COS_CLEARBOX   ; COS
        .db TK_TRON, HB@RT_TRON | ST_ARG1 | ST_ARGA, LB@RT_TRON   ; TRON
        .db TK_TROFF, HB@RT_TROFF | ST_ARG1 | ST_ARGA, LB@RT_TROFF   ; TROFF
        .db TK_SIN, HB@RT_SIN_TONE | ST_ARG1 | ST_ARGA, LB@RT_SIN_TONE   ; SIN
        .db TK_BEEP, HB@RT_BEEP | ST_ARGA, LB@RT_BEEP   ; BEEP
        .db TK_PAUSE, HB@RT_PAUSE | ST_ARGA, LB@RT_PAUSE   ; PAUSE
        .db TK_ASN, HB@H_RETADDR_TO_X, LB@H_RETADDR_TO_X   ; ASN (object code: CALL H_RETADDR_TO_X)
        .db &FF                   ; end of table: user-defined statements are appended HERE (before the &FF)
        .db &00,&00               ; two unused bytes (the original left them for statement extensions)

; Low bytes of the runtime routines, followed by the tone table that DMS looks up with the SAME
; page-wrapping index (EMIT_FUNC_LOBYTE adds to the low byte only): TBL_RT_LO .. TBL_RT_END-1 must lie in ONE page.
TBL_RT_LO:
        .db LB@RT_MUL           ; index 0
        .db LB@RT_DIV           ; index 1
        .db LB@RT_MOD           ; index 2
        .db LB@RT_MUL_VAR       ; index 3
        .db LB@RT_DIV_VAR       ; index 4
        .db LB@RT_MOD_VAR       ; index 5
        .db LB@RT_INKEY         ; index 6
        .db LB@RT_READ          ; index 7
        .db LB@RT_INT_KEYS      ; index 8
        .db LB@RT_AREAD         ; index 9
        .db LB@RT_USERFN_HOOK   ; index 10
        .db LB@RT_PAREN         ; index 11
        .db LB@RT_RND           ; index 12
        .db LB@RT_LOG2          ; index 13
        .db LB@RT_EXP2          ; index 14
        .db LB@RT_ABS           ; index 15
        .db LB@RT_SGN           ; index 16
        .db LB@RT_PEEK          ; index 17
        .db LB@RT_SQRT_ARRAY    ; index 18
        .db LB@RT_END           ; index 19
; Tone period / note tables for SIN and DMS (RT_SIN_TONE / RT_DMS); individual values not analysed.
        .db &01,&03,&05,&07,&0B,&0F,&17,&1F
        .db &2F,&3F,&5F,&7F,&80,&80,&80,&FF
        .db &F7,&F0,&E9,&E3,&DD,&D7,&D1,&CC
        .db &C7,&C3,&BE,&BA,&B7,&B3,&AF,&AC
        .db &A9,&A6,&A4,&A1,&9F,&9C,&9A,&98
        .db &96,&94,&93
TBL_RT_END:


RT_INPUT_STOP:
        CALL    PLAT_KEYTIMER_INIT
        CALL    PLAT_GETKEY
        LIDP    LCD_INDICATOR       ; was CAL ROM_DP_INDICATOR
        ANID    &8F
        LP      &03
        JRP     RT_INKEY_2

RT_CLEAR:
        LII     &FF
        LIDP    ARRAY_BASE
        FILD
        RTN

RT_RESTORE:
        CALL    H_RETADDR_TO_X
        DX
        IXL
        EXAB
        IXL
        CALL    H_BA_TO_Y
        LP      &06
        LIQ     IR_READ_PTR         ; was CAL ROM_SWAP_P_3031: swap (P,P+1) <-> (30,31)
        EXB
        JRP     RT_INL_RETURN

RT_DEG:
        CALL    H_RETADDR_TO_X
        DX
        IXL
        PUSH
RT_DEG_1:
        IXL
        CALL    RT_POKE
        LOOP    RT_DEG_1

RT_INL_RETURN:
        IX
        CALL    H_X_TO_RETADDR
        RTN

RT_ARRAY_HEX:
        CALL    H_BA_TO_Y_B67
        CALL    H_RETADDR_TO_X
        DX
        IXL
        EXAB
        INCB
RT_ARRAY_HEX_1:                      ; was CAL ROM_COPY_B: copy B bytes from X+1.. to Y+1..
        IXL
        IYS
        DECB
        JRNZM   RT_ARRAY_HEX_1
        JRM     RT_INL_RETURN

RT_STRING:
        CALL    H_RETADDR_TO_X
        DX
        IXL
        PUSH
RT_STRING_1:
        IXL
        CALL    H_SWAP_X_0C
        CALL    RT_CHR
        CALL    H_SWAP_X_0C
        LOOP    RT_STRING_1
        JRM     RT_INL_RETURN

RT_DMS:
        CALL    H_RETADDR_TO_X
        DX
        IXL
        PUSH
RT_DMS_1:
        IXL
        CPIA    &80
        JRNCP   RT_DMS_2
        SL
        LP      IR_DMS_LEN
        EXAM
        JRP     RT_DMS_3
RT_DMS_2:
        ANIA    &7F
        LP      &11
        EXAM
        LP      IR_DMS_LEN
        LDM
        CALL    RT_SIN_TONE
RT_DMS_3:
        LOOP    RT_DMS_1
        JRM     RT_INL_RETURN

RT_USERFN_HOOK:
        JP      RT_INPUT_STOP

RT_MUL_VAR:
        EXAB
        LDM
        EXAB

RT_MUL:
        LP      &08
        MVMP                        ; (P) <- &00: the next opcode byte is stored and ALSO executed
        LII     &07
RT_MUL_1:
        EXAB
        SR
        EXAB
        JRNCP   RT_MUL_2
        ADM
RT_MUL_2:
        SL
        DECI
        JRNCM   RT_MUL_1
        LDM
        RTN

RT_MOD_VAR:
        EXAB
        LDM
        .db &13        ; LIQ: swallows the EXAB below when entered from RT_MOD_VAR

RT_MOD:
        EXAB
        RC
        LP      &08
        EXAM
        LIA     &07
        PUSH
        CLRA
RT_MOD_1:
        EXAB
        SL
        EXAB
        SL
        EXAM
        CPMA
        JRCP    RT_MOD_2
        SBM
        INCB
RT_MOD_2:
        EXAM
        LOOP    RT_MOD_1
        RTN

RT_DIV_VAR:
        CALL    RT_MOD_VAR
        EXAB
        RTN

RT_DIV:
        CALL    RT_MOD
        EXAB
        RTN

RT_PAUSE:
        PUSH
RT_PAUSE_1:
        CALL    PLAT_WAIT_TICK
        CALL    PLAT_KEYSCAN
        JRNCP   RT_PAUSE_2
        LEAVE
RT_PAUSE_2:
        LOOP    RT_PAUSE_1
        JRP     RT_BRK_CHECK

RT_READ:
        LP      &04
        LIQ     IR_READ_PTR         ; was CAL ROM_SWAP_P_3031: swap (P,P+1) <-> (30,31)
        EXB
        IXL
        LP      &04
        LIQ     IR_READ_PTR         ; was CAL ROM_SWAP_P_3031: swap (P,P+1) <-> (30,31)
        EXB
        JRP     RT_PAREN

RT_INKEY:
        CALL    PLAT_KEYSCAN
        JRNCP   RT_INKEY_NONE
        ADIA    LB@BASROM_KEYTAB
        LIB     HB@BASROM_KEYTAB
RT_INKEY_1:
        CALL    H_A_FROM_BA
RT_INKEY_2:
        EXAM
        JRP     RT_INT_KEYS_1

RT_INT_KEYS:
        LIP     &5C
        ANIM    &00
        OUTA
        ORIM    &01
        INCP
        LIA     &02
        EXAM
        OUTB
        INA
        ANIA    &18
        SWP
        EXAB
        LDM
        ADM
        OUTB
        ANIM    &00
        INA
        ANIA    &16
        LP      &03
        ORMA
        OUTB
        OUTA
        INA
        ANIA    &08
        ORMA
        LIP     &5C
        ADIM    &7F
        OUTA
        INA
        ANIA    &60
        LP      &03
        ORMA
RT_INT_KEYS_1:
        LDM

RT_BRK_CHECK:
        TEST    &08
        JRNZP   RT_END
        RTN

RT_LOG2:
        LIB     &07
RT_LOG2_1:
        SL
        JRCP    RT_SGN_2
        DECB
        JRNCM   RT_LOG2_1
        JRP     RT_SGN_2

RT_EXP2:
        PUSH
        CLRA
        SC
RT_EXP2_1:
        SL
        LOOP    RT_EXP2_1
        JRP     RT_PAREN

RT_ABS:
        CPIA    &80
        JRCP    RT_PAREN
        LIB     &00
        LP      &03
        SBM
        LDM
        RTN

RT_AREAD:
        LP      IR_DSTK_PTR
        LDM
        SBIM    &01
        ANIM    &7F
        LIB     HB@DATA_STACK
        JRM     RT_INKEY_1

RT_SGN:
        CPIA    &00
        JRZP    RT_PAREN
        SL
        LIA     &01
        JRNCP   RT_PAREN
RT_SGN_1:
        LIB     &FF
RT_SGN_2:
        LP      &03
        LDM
        RTN

RT_CURSOR_CALC:
        LP      &06
RT_CURSOR_CALC_1:
        LII     &00
RT_PEEK EQU RT_CURSOR_CALC_1+1
        LIQ     &84
        EXAM
        LIA     HB@VRAM_UPPER_L - LCD_HALF_STEP
RT_CURSOR_CALC_2:
        ADIA    LCD_HALF_STEP
        SBIM    LCD_BLOCK_COLS
        JRNCM   RT_CURSOR_CALC_2
        ADIM    LCD_BLOCK_COLS
        TSIA    LCD_ROW_SEL
        JRZP    RT_CURSOR_CALC_3
        ADIM    LCD_ROW_STEP
RT_CURSOR_CALC_3:
        ANIA    LCD_HI_MASK
        INCP
        EXAM
        DECI
        JRCP    VRAM_PUT_NEXT_2
        DX
        JRP     RT_SQRT_ARRAY_1  ; (was a 1-byte LIDP that swallowed the 2-byte CAL below; CALL has 3 bytes)

RT_SQRT_ARRAY:
        CALL    H_BA_TO_X_B67
RT_SQRT_ARRAY_1:
        IXL

RT_PAREN:
        LP      &03
        EXAM
        LDM
        RTN

RT_END:
        LIA     STACK_INIT
        STR
        CALL    PLAT_FILL_INPBUF
        LIDP    RND_SEED_SAVE       ; (was LIDL &5E: relied on the DP that the ROM fill left in page &67)
        LP      IR_RND_SEED
        EXBD
        RTN

RT_RND:
        PUSH
        LIQ     &B3
        LP      &02
        MVB
        LP      &02
        ADB
        LP      IR_RND_SEED
        ADB
        LP      IR_RND_SEED
        LDM
        LP      IR_RND_SEED + 1
        ADM
        LIB     &00
        LIA     &81
        LP      IR_RND_SEED
        ADB
        POP
        EXAB
        LDM
        CALL    RT_MOD
        .db &13        ; LIQ: skips the CLRA below

RT_INKEY_NONE:
        CLRA
        JRM     RT_PAREN

RT_PI_POINT:
        LII     &FF
        LP      &12
        JRP     RT_PLOT

RT_TROFF:
        LII     &00
RT_TRON EQU RT_TROFF+1
        NOPW
        LP      &11

RT_PLOT:
        LIB     LCD_PLOT_HI
        CPIM    LCD_BLOCK_COLS
        JRCP    RT_PLOT_1
        SBIM    LCD_BLOCK_COLS
        CPIM    LCD_BLOCK_COLS
        JRNCM   RT_SGN_1
        INCB
RT_PLOT_1:
        CPIA    LCD_CELL_DOTS
        JRCP    RT_PLOT_2
        SBIA    LCD_CELL_DOTS
        ADIM    LCD_ROW_STEP
        CPIA    LCD_CELL_DOTS
        JRNCM   RT_SGN_1
RT_PLOT_2:
        PUSH
        LDM
        LP      &04
        EXAM
        CLRA
RT_PLOT_3:
        SL
        LOOP    RT_PLOT_3
        EXAB
        LP      &05
        EXAM
        LP      &03
        DX
        IXL
        INCI
        JRNCP   RT_PLOT_5
        TSMA
        LIB     &00
        JRZP    RT_PLOT_4
        INCB
RT_PLOT_4:
        LDM
        RTN
RT_PLOT_5:
        EXAM
        ORMA
        DECI
        JRNZP   RT_PLOT_6
        SBM
RT_PLOT_6:
        MVDM
        RTN

VRAM_PUT_NEXT:
        IYS
        LP      &06
        LDM
        ANIA    LCD_COL_MASK
        CPIA    LCD_BLOCK_LAST
        JRNZP   VRAM_PUT_NEXT_3
        LP      &07
        ADIM    LCD_HALF_STEP
        ANIM    LCD_HI_MASK
        CPIM    HB@VRAM_UPPER_L
        LP      &06
        JRNZP   VRAM_PUT_NEXT_1
        ADIM    LCD_ROW_STEP
VRAM_PUT_NEXT_1:
        ANIM    LCD_ROW_STEP
VRAM_PUT_NEXT_2:
        DY
VRAM_PUT_NEXT_3:
        RTN

RT_WAIT_POP:
        POP

RT_WAIT_TICK:
        CALL    PLAT_WAIT_TICK

RT_WAIT:
        CALL    RT_BRK_CHECK
        DECA
        JRNCM   RT_WAIT_TICK
        RTN

SIN_NOP_DELAY:
        NOPT
        JRP     RT_SIN_TONE_3

RT_SIN_TONE:
        PUSH
        LP      &11
        LDM
        LP      &00
        EXAM
        LDM
        DECI
        JRCM    RT_WAIT_POP
        ADIA    &0A
        JRNCP   RT_SIN_TONE_1
        LIA     &FF
RT_SIN_TONE_1:
        LIB     &FF
        EXAB
        CALL    RT_DIV
RT_SIN_TONE_2:
        PUSH
RT_SIN_TONE_3:
        LIP     &5F
        ORIM    &11
        OUTC
        ANIM    &01
        OUTC
        CUP
        LOOP    SIN_NOP_DELAY
        LOOP    RT_SIN_TONE_2
RT_SIN_TONE_4:
        RTN

RT_PRINT:
        CPIA    &64
RT_PRINT_1:
        JRCP    0
RT_PRINT_LT100 EQU RT_PRINT_1+1

RT_LPRINT:
        LII     &4D
        LIB     &FF
RT_LPRINT_1:
        INCB
        SBIA    &64
        JRNCM   RT_LPRINT_1
        PUSH
        CALL    RT_POKE_2
        POP
        LIB     &0A
RT_LPRINT_2:
        DECB
        ADIA    &0A
        JRNCM   RT_LPRINT_2
        PUSH
        CALL    RT_POKE_1
        POP
RT_LPRINT_3:
        ADIA    &30

RT_CHR:
        LIQ     IR_TEXT_CUR
        LP      &06
        MVB
        CPIA    &20
        JRNCP   FONT_ROM
        PUSH
        LIA     &61
        CALL    H_BA_TO_X_B67
        POP
        ADIA    &20
        CALL    PLAT_GLYPH_PTR_X
        JRP     FONT_ROM_GLYPH_DONE   ; (was a 1-byte LIDP that swallowed the 2-byte CAL below)

FONT_ROM:
        CALL    PLAT_GLYPH_PTR
FONT_ROM_GLYPH_DONE:
        LP      IR_TEXT_CUR
        ANIM    LCD_COL_MASK
        CPIM    LCD_BLOCK_COLS - LCD_CHAR_COLS
        JRNCP   RT_CURSOR_1
        DXL
        IYS
        DXL
        IYS
        DXL
        IYS
        DXL
        IYS
FONT_ROM_1:
        DXL
FONT_ROM_2:
        CALL    VRAM_PUT_NEXT
FONT_ROM_3:
        LP      IR_TEXT_CUR
        LIQ     &06                 ; was CAL ROM_STORE_Y_P: (P,P+1) = Y
        MVB
        RTN

RT_CURSOR:
        CALL    RT_CURSOR_CALC
        JRM     FONT_ROM_3
RT_CURSOR_1:
        LIA     &03
        PUSH
RT_CURSOR_2:
        DXL
        CALL    VRAM_PUT_NEXT
        LOOP    RT_CURSOR_2
        JRM     FONT_ROM_1

RT_POKE:
        LIQ     IR_TEXT_CUR
        LP      &06
        MVB
        JRM     FONT_ROM_2
RT_POKE_1:
        DECI
        JRNCP   RT_POKE_3
RT_POKE_2:
        INCB
        DECB
        JRZM    RT_SIN_TONE_4
RT_POKE_3:
        EXAB
        JRM     RT_LPRINT_3

RT_ON:
        LP      IR_GFX_Y
        EXAM
        LP      &11
        EXAM
        LP      &06
        EXAM
        LIA     LCD_GFX_HI_LEFT
        CPIM    LCD_BLOCK_COLS
        JRCP    RT_ON_1
        ADIA    LCD_HALF_STEP
        SBIM    LCD_BLOCK_COLS
        CPIM    LCD_BLOCK_COLS
        JRCP    RT_ON_1
        CLRA
RT_ON_1:
        LP      &07
        EXAM
        DY
        LIQ     &06
        LP      &13
        MVB
        RTN

RT_GRAD:
        LIQ     &93
        LP      &06
        MVB
        LDR
        STQ
        LP      &04
        MVB
        DX
        IXL
        PUSH
RT_GRAD_1:
        LP      IR_GFX_Y
        LDM
        LP      &08
        EXAM
        IXL
        CPIM    &07
        JRZP    RT_GRAD_5
        JRNCP   RT_GRAD_3
        CPIM    &00
        JRZP    RT_GRAD_8
        LIB     &00
        LP      &03
RT_GRAD_2:
        SL
        EXAM
        SL
        EXAM
        DECK
        JRNCM   RT_GRAD_2
        SR
        IY
        LP      &09
        MVMD
        ORMA
        MVDM
        LP      &06
        ADIM    LCD_ROW_STEP - 1
        IY
        LP      &09
        MVMD
        EXAB
        ORMA
        MVDM
        JRP     RT_GRAD_9
RT_GRAD_3:
        CPIM    &0E
        JRNCP   RT_GRAD_6
        SBIM    &07
RT_GRAD_4:
        SL
        DECK
        JRNZM   RT_GRAD_4
RT_GRAD_5:
        LP      &06
        ADIM    LCD_ROW_STEP
        JRP     RT_GRAD_8
RT_GRAD_6:
        CPIM    &F9
        JRCP    RT_GRAD_10
RT_GRAD_7:
        SR
        INCK
        JRNCM   RT_GRAD_7
RT_GRAD_8:
        IY
        LP      &09
        MVMD
        ORMA
        MVDM
RT_GRAD_9:
        LP      &06
        ANIM    LCD_COL_MASK
        CPIM    LCD_BLOCK_LAST
        JRNZP   RT_GRAD_10
        ANIM    &00
        LP      &07
        ADIM    LCD_HALF_STEP
        ANIM    LCD_GFX_HI_MASK
        DY
RT_GRAD_10:
        LOOP    RT_GRAD_1
        IX
        LDR
        STQ
        LP      &04
        EXB
        RTN

RT_COS_CLEARBOX:
        PUSH
        LIA     &FF
        LIDP    COS_MASK1
        STD
        LIDL    LB@COS_MASK2
        STD
        LP      IR_GFX_Y
        LDM
        LP      &08
        EXAM
        LP      &11
        LDM
        LIQ     &93
        LP      &06
        MVB
        CPIM    &07
        JRZP    RT_COS_CLEARBOX_4
        JRNCP   RT_COS_CLEARBOX_2
        CPIM    &00
        JRZP    RT_COS_CLEARBOX_7
        LIB     &FF
        LP      &03
RT_COS_CLEARBOX_1:
        SC
        SL
        EXAM
        SL
        EXAM
        DECK
        JRNCM   RT_COS_CLEARBOX_1
        SR
        MVDM
        JRP     RT_COS_CLEARBOX_7
RT_COS_CLEARBOX_2:
        CPIM    &0E
        JRNCP   RT_COS_CLEARBOX_5
        SBIM    &07
RT_COS_CLEARBOX_3:
        SC
        SL
        DECK
        JRNZM   RT_COS_CLEARBOX_3
RT_COS_CLEARBOX_4:
        STD
        JRP     RT_COS_CLEARBOX_8
RT_COS_CLEARBOX_5:
        CPIM    &F9
        JPC     H_POP_RTN
RT_COS_CLEARBOX_6:
        SC
        SR
        INCK
        JRNCM   RT_COS_CLEARBOX_6
RT_COS_CLEARBOX_7:
        LIDL    LB@COS_MASK1
        STD
RT_COS_CLEARBOX_8:
        IY
RT_COS_CLEARBOX_9:
        ANID    &FC
COS_MASK1 EQU RT_COS_CLEARBOX_9+1
        LP      &06
        ADIM    LCD_ROW_STEP - 1
        IY
RT_COS_CLEARBOX_10:
        ANID    &FF
COS_MASK2 EQU RT_COS_CLEARBOX_10+1
        ANIM    LCD_COL_MASK
        CPIM    LCD_BLOCK_LAST
        JRNZP   RT_COS_CLEARBOX_11
        ANIM    &00
        LP      &07
        ADIM    LCD_HALF_STEP
        ANIM    LCD_GFX_HI_MASK
        DY
RT_COS_CLEARBOX_11:
        LOOP    RT_COS_CLEARBOX_8
        RTN
; ---- routines that sit behind the page-bound group (see PAGE CONSTRAINTS) ----

RT_DIM:
        PUSH
        LP      IR_DSTK_PTR
        ADIM    &01
        ANIM    &7F
        LDM
        LIB     HB@DATA_STACK
        CALL    H_BA_TO_Y
        POP
        IYS
        RTN

RT_VAL:
        LII     IR_NVARS - 1
        LIDP    SHADOW_VARS
        LP      IR_VAR_AT
        EXWD
        RTN

RT_BEEP:
        SWP
        ANIA    &30
        INCA
        JP      PLAT_OUTC_A

RT_CLS:
        LP      &03
        EXAM
        CLRA
        LIDP    VRAM_UPPER_L
        LII     LCD_BLOCK_LAST
        TSIM    &01
        JRNZP   RT_CLS_1
        FILD
RT_CLS_1:
        TSIM    &04
        JRNZP   RT_CLS_2
        LIDL    LB@VRAM_LOWER_L
        FILD
RT_CLS_2:
        LIDP    VRAM_UPPER_R
        TSIM    &02
        JRNZP   RT_CLS_3
        FILD
RT_CLS_3:
        TSIM    &08
        JRNZP   RT_CLS_4
        LIDL    LB@VRAM_LOWER_R
        FILD
RT_CLS_4:
        RTN


        INCLUDE "helpers.asm"
        INCLUDE "platform_pc1262.asm"

RT_ENTRY_4900:
        LIDP    RND_SEED_SAVE
        LP      IR_RND_SEED
        EXBD

RT_RUN:
        LIA     STACK_INIT
        STR
        CLRA
        LII     IR_RUN_CLEAR_LAST - IR_RUN_CLEAR_FIRST
        LP      &11
        FILM
        CALL    PLAT_FILL_DISPLAY
        CALL    RT_CURSOR
        .db &10        ; LIDP: swallows the JRM below, execution continues in the object code at OBJ_START

RT_RUN_ENTRY:
        JRM     RT_ENTRY_4900

OBJ_START:   ; object code is generated from here (= &4902 in the original binary, &49BC now)
