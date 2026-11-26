# LC-3 User Manual: commands and syntax

LC-3 is a two-pass compiler for a small BASIC-like language. You type the source with the pocket computer's own BASIC
editor and compile it on the machine into SC61860 machine code. The language has only one data type, the unsigned
byte (0-255), and a set of statements aimed at games: dot and sprite graphics, key scanning, sound, random numbers.

This manual is based on the English translation by PockEmul of the original documentation and of the explanation
thread by @poyokoma_danna ("LC-3 Compiler User Manual for SHARP PC-1261/PC-1262") and on the "LC-3 graphic engine for
PC-126x" text. The article itself is in [image/LC-3_jap2eng.pdf](image/LC-3_jap2eng.pdf) (see [README.md](README.md)).
Values for the PC-1350 and PC-1360 ports are taken from [README_1350.md](README_1350.md) and
[README_1360.md](README_1360.md).

Contents: [Installation](#1-installation-and-use) | [Errors](#2-errors) | [Source format](#3-source-format) |
[Expressions](#4-expressions) | [Functions](#5-functions) | [Memory and data](#6-memory-and-data-statements) |
[Control](#7-control-statements) | [Display](#8-display-statements) | [Graphics](#9-graphics-statements) |
[Sound](#10-sound-statements) | [Port differences](#11-differences-between-the-ports) | [Examples](#12-examples)

---

## 1. Installation and use

The addresses depend on the machine:

| Machine | Load LC-3 at | Compile | Run | Reserve memory |
|---|---|---|---|---|
| PC-1261 / PC-1262 | `&4000` | `CALL &4000` | `CALL &49BA` | `EQU#43` (PRO mode) |
| PC-1350 | `&4030` | `CALL &4030` | `CALL &4AE9` | `POKE &6F01,0,&5C` (RUN mode) |
| PC-1360, 8 KB card | `&E030` | `CALL &E030` | `CALL &EBD3` | `POKE &FFD7,0,&F4` (see README_1360.md) |
| PC-1360, 16 KB card | `&C030` | `CALL &C030` | `CALL &CBD3` | see README_1360.md |
| PC-1360, 32 KB card | `&8030` | `CALL &8030` | `CALL &8BD3` | `POKE &FFD7,0,&C0` |

The original `LC-3.bin` from the 1989 article runs at `CALL &4900` instead of `CALL &49BA`; the rebuilt binary in this
repository has a longer runtime. The PockEmul manual and the article both quote `&4900`.

Steps (PC-1262 shown; other machines see their own README):

1. In PRO mode: `NEW`, then `EQU#43`. This reserves 44 x 128 bytes below the BASIC area for LC-3 and the compiled
   program. A larger value leaves less room for the source but more for the object code; the ratio can be tuned with the
   `EQU#` value.
2. Load LC-3: `CLOADM &4000` (or `CLOADM` from tape; in an emulator, load the `.bin` at `&4000`).
3. Type the LC-3 source as ordinary numbered BASIC lines. It is never run as BASIC.
4. Compile with `CALL &4000`. If everything is fine, the prompt `>` comes back. On an error see [section 2](#2-errors).
5. Run with `CALL &49BA`. **Always run from PRO mode.**
6. `BRK` stops the program, but only while it waits in `WAIT`, `PAUSE`, `STOP`, `INKEY$`, `INPUT`, `INT`, `AREAD`,
   `SIN` or `DMS`. Put `WAIT 0` in every loop that must be breakable, otherwise only RESET helps.

On the Japanese PC-1262 the `¥` key is present; the compiler uses `¥` as the "not equal" operator, which export models
do not have.

PC-1262 memory map with `EQU#43`: LC-3 `&4000`-`&49B9`, compiled program `&49BC`-`&55FF`, source from `&5600`, data
stack `&6500`-`&657F`. Free area for source plus object is about 3,800 bytes on the original.

## 2. Errors

If the compiler finds an error it shows the error number. In PRO mode, press the up arrow to see the faulty line
(except for error 4).

| Error | Meaning |
|---|---|
| 0 | Syntax error, for example a missing operand; or a non-constant in a `DATA` statement |
| 1 | No data after `DMS`, `DEG` or `GRAD` (empty string) |
| 3 | Error in the `DMS` data |
| 4 | The object code does not fit in the object area: increase the `EQU#` value and compile again |
| 9 | `IF` without a condition |
| 10 | A label was defined twice, or a label inside an `IF` |
| `?` | A label was used but never defined |
| other | Common syntax error: unknown statement, bad label name, ... |

The error number is followed by `IN` and the line number.

**Do not press the up or down arrow, switch the power off instead,** if:

- anything other than the prompt `>` is shown and the machine stopped;
- the error was raised while running the program, not while compiling.

## 3. Source format

- Normal numbered BASIC lines. Several statements can share a line, separated by `:`. The colon is optional where the
  statements are unambiguous (`DIM A DIM B : GOTO ...`).
- You can also omit: the `=` in an assignment to a plain variable; the `,` after `PI`, `ON`, `COS`, `TRON`, `TROFF` and
  `SIN`; the quotes after `DMS`. This saves memory.
- There is **no `LET`**. After an `IF`, use a colon: `IF A<8 : A=A+1`.
- **A bare string is a print statement:** `10:"ABC"` shows ABC. There is no `PRINT "..."`.
- `REM text` comments the rest of the line. `END` stops the program and returns to BASIC (may be omitted at the end).
  A line holding only `.` (period) ends the source; everything after it is ignored.
- Special characters: `√` (square root key) is the array prefix, `π` switches to user-defined characters, `¥` is "not
  equal". See your machine README for how they are typed in an emulator text file.

## 4. Expressions

| Item | Description |
|---|---|
| Constant | 0-255. A larger value is taken modulo 256 |
| Character constant | `"A"` is the character code of A. In a longer string only the last character counts |
| Variables | `A`-`Z` and `@`: 27 byte variables, kept in internal RAM (small, fast code). `VAL` swaps them with 27 hidden variables |
| Array variable | `√expr`, 256 bytes `√0`-`√255`. `√A+1` is element A+1. `√96`-`√255` are also the user-defined character data |

Operators:

| Operator | Meaning |
|---|---|
| `+ - * /` | arithmetic. Overflow is dropped (low 8 bits); division rounds down; division by 0 gives 255 |
| `%` | remainder |
| `OR`, `AND` | logical (bitwise) |
| `= ¥ < >=` | comparison, only in `IF` |

**There is no operator precedence.** Evaluation is strictly left to right: `A=3+5*2` is 16, `A=3+(5*2)` is 13.

Functions do not need parentheses around their argument, but then the argument extends as far as possible:
`EXP 2 + 1` is 8, `EXP 2 ) + 1` is 5 (with an opening parenthesis before).

**Nesting limit:** keep the nesting of arrays, functions and parentheses to three levels. Deeper expressions can
overflow the stack and crash the program.

## 5. Functions

| Function | Description |
|---|---|
| `INKEY$` | Real-time key scan: the character code of the key, 0 if none. Several keys give 1. Special codes: 2 CL, 4 up, 5 down, 13 ENTER, 14 right, 15 left, 16 SHIFT, 18 DEF |
| `INPUT` | Waits for one key and returns its code (SHIFT and kana possible). Codes: 2 CL, 3 CA, 4 up, 5 down, 6 P<->NP, 8 mode, 10 OFF, 11 INS, 12 DEL, 13 ENTER, 14 right, 15 left, 20 HELP. Good for name entry and one-key adventures |
| `INT` | Simultaneous keys as bits: 1 SHIFT, 2 key 8, 4 key 2, 8 key 4, 16 DEF, 32 ENTER, 64 key 0, 128 key 6. 8 and 6 together give 130. For games with diagonal movement |
| `AREAD` | Pops a byte from the data stack (see `DIM`) |
| `READ` | Reads the next byte of the data selected with `RESTORE`. The first read also needs a `RESTORE`. Reading past the data gives undefined values |
| `RND n` | Random number 0 to n-1; `RND 0` gives 0-255 |
| `PEEK n` | Video RAM byte (PC-1262: n 0-239, top row 0-119, bottom row 120-239; 240 or more gives 0) |
| `PI x,y` | Tests a dot: 1 on, 0 off, 255 off screen. Cannot be used inside a larger expression |
| `LOG n` | log2 of n, truncated |
| `EXP n` | 2 to the power n (for bit masks) |
| `ABS n` | absolute value, n treated as signed |
| `SGN n` | sign: 1 positive, 255 negative, 0 zero |

## 6. Memory and data statements

| Statement | Description |
|---|---|
| `V=expr` | assign to a variable (`LET` does not exist) |
| `√n=expr[,c2,c3,...]` | assign to an array element, with consecutive constants for following elements: `√0=7,5,9` equals `√0=7:√1=5:√2=9` |
| `√n:hex...` | store consecutive bytes given as hex pairs, e.g. `√101:14555D7F551400140014`. Do not run past `√255` |
| `CLEAR n` | fill the whole array with n |
| `VAL` | swap the 27 variables with the 27 hidden ones (so you effectively have 54) |
| `DIM n` | push a byte on the data stack (128 entries, a ring) |
| `AREAD` | pop (function, see above). The stack survives program stops, so it can keep a high score; `CLEAR`+`ENTER` zeros it |
| `RESTORE label` | select the data for `READ` |
| `DATA c1[,c2...]` | write constants (or character constants) directly into the object code. They would be executed as machine code, so place them after `END` |
| `!hex` | write hex bytes directly into the object code. Sub-commands: `<` back one address, `>` forward one address, `+label` writes the label's address |

## 7. Control statements

**Labels** have two characters: first `#`, `$`, `&` or `%`, then `A`-`Z`, `@`, `;`, `<`, `=`, `>`, `?` (4 x 32 labels).
Letters after `#` are the most readable choice. A label is defined by writing it in front of a statement:
`20 #A:CURSOR A`.

| Statement | Description |
|---|---|
| `GOTO label` | jump. The label `^` means the start of the current line, so `10 GOTO ^` loops forever and needs no label |
| `GOSUB label` / `RETURN` | subroutine call and return. Using subroutines makes the program smaller |
| `ASN` | drop one level of subroutine nesting: leave a `GOSUB` routine with `GOTO` without a `RETURN` |
| `IF cond GOTO label` | jump if true |
| `IF cond : statements` | run the statements if true; the rest of the line is skipped when false |
| `IF cond GOTO label : statements` | jump if true, otherwise run the statements (an ELSE) |
| `RUN` | initialise and restart from the beginning: stack pointer, all variables and hidden variables cleared, data stack pointer reset |
| `WAIT n` | wait n x 0.004 s; BRK ends the program. `WAIT 0` only checks BRK |
| `PAUSE n` | wait n x 0.004 s unless a key is pressed |
| `STOP` | wait for a key (not SHIFT or DEF). Holding a key longer than a second may repeat once |
| `REM`, `END`, `.` | see [Source format](#3-source-format) |

Conditions are `=`, `¥` (not equal), `<` (left smaller) and `>=`. A bare expression is true when it is not 0. `IF` can
be nested without extra syntax: `IF K AND 128 IF X<115 : X=X+1`. There is no `>` or `<=`; swap the sides instead
(`IF "9"<K`).

## 8. Display statements

The PC-1261/62 LCD is 24 characters x 2 lines, 120 x 14 dots. Positions are given in **dots**. On the PC-1350/1360
the screen is 150 x 32 dots, 4 rows of 25 characters (see [section 11](#11-differences-between-the-ports)).

| Statement | Description |
|---|---|
| `"text"` | displays the text at the cursor. In the text a `π` switches to user-defined characters and back; the text always starts in normal mode |
| `CURSOR n` | text cursor (PC-1262: 0-239; 0 is top left, 120 bottom left; wraps around the ends; 240 or more hides all text output until it is set back) |
| `PRINT expr` | shows the value |
| `LPRINT expr` | shows the value with a leading zero for one digit |
| `CHR$ n` | shows the character with code n; 0-31 are the user-defined characters |
| `CLS n` | clears the quarters whose bit in n is 0: bit 0 top left, 1 top right, 2 bottom left, 3 bottom right. `CLS 0` clears everything |
| `DEG hex` | draws graphics at the text cursor from hex bytes, any number of columns, data from the left |
| `POKE n` | writes one byte of dot data at the text cursor and moves on one column. Useful for sprites entering from the screen edge, because `DEG`/text wrap round |

**User-defined characters:** the 32 characters `@ A-Z ; < = > ?` take their dot patterns from `√96`-`√255`, five bytes per
character, character 0 at `√96`-`√100`. The bytes are stored in the order of the ROM font, "from the right to the
lower index". Set them with `√101:14555D7F551400140014`, then show them with `"πAB"`. Typing the pattern into a
spreadsheet and flipping it horizontally helps with the hex values.

## 9. Graphics statements

Coordinates are "world coordinates" 0-255; points outside the screen are ignored silently (no error).

| Statement | Description |
|---|---|
| `TRON x,y` | set a dot |
| `TROFF x,y` | clear a dot |
| `ON x,y` | set the graphic cursor (only `ON` moves it). A PC-1262 x of 120 or more disables the following `GRAD` and `COS` |
| `GRAD hex` | draws the hex data at the graphic cursor, ORed into the screen; position in dots. x 0-119, the part beyond the right edge continues on the left; y only works inside the screen |
| `COS m,n` | erases: ANDs the screen with `m` over n+1 columns from the graphic cursor. `COS 248,4` ANDs 5 columns with `%11111000`, clearing bits 0-2 of each column. Neither `GRAD` nor `COS` changes the graphic cursor, so you can draw and erase at the same place |

Always put `WAIT 0` into loops (for example random dots) so that `BRK` still works.

## 10. Sound statements

| Statement | Description |
|---|---|
| `BEEP n` | 0 off, 1 write `&11` to port C, 2 beep at 2 kHz, 3 beep at 4 kHz. There is no length; use `WAIT` |
| `SIN f,t` | tone with frequency value `f` for duration `t`. The `f` values come from the `DMS` note table (for example `√0=70635751473E35332C26` for a scale, played with `SIN √(K-"0"),5`) |
| `DMS "mml"` | plays an MML-like string, e.g. `DMS "8ACEFEC9A6=8EFHJHF9E"`. Nothing else runs while it plays |

The SC61860 beeper can only sustain 2 kHz and 4 kHz by itself; other frequencies are produced by the CPU switching
the buzzer, so the program cannot do anything else meanwhile.

## 11. Differences between the ports

Sources for the PC-1262 compile unchanged on the PC-1350 and PC-1360. Only the screen statements differ because the
display is 150 x 32 dots with four 25-character rows:

| Statement | PC-1350 / PC-1360 |
|---|---|
| `CURSOR n` | text cell `n = row*25 + column`, rows 0-3, columns 0-24; `n >= 100` switches text off |
| `"text"`, `PRINT`, `CHR$` | a character is 6 dots wide |
| `POKE n`, `DEG hex` | 8-dot-high columns at the cursor, one column on each time |
| `PEEK n` | column n (0-149) of the cursor row; 150 or more gives 0 |
| `CLS n` | bits 0-3 are rows 0-3 |
| `ON x,y` | x 0-149, y 0-31 (249-255 = -7..-1 above the top) |
| `GRAD hex` | ORs 8-dot columns at the graphic cursor |
| `COS m,w` | clears where m has a 0 bit, w+1 columns wide (`COS 0,w` clears 8 dots high) |
| `TRON`, `TROFF`, `PI` | x 0-149, y 0-31 |

Programs that place text with PC-1262 `CURSOR` values (0-239) therefore show their text elsewhere. On the PC-1360
the kana and some other character codes show a space.

## 12. Examples

Moving text (PC-1262):

```
10 A=0
20 #A:CURSOR A:"(PC-1261/2)"
30 A=A+1%64:WAIT 5:GOTO #A
```

Title bouncing left and right, using `GOTO` with labels and `IF ... GOTO`:

```
10 A=0
20 $A: CURSOR A:"(PC-1261/2)"
30 A=A+1: WAIT 5: IF A<65 GOTO $A
40 $B: CURSOR A:"(PC-1261/2)"
50 A=A-1: WAIT 5: IF A¥0 GOTO $B
60 GOTO $A
```

The same with `GOSUB`/`ASN` (smaller code):

```
10 A=0
20 %A:GOSUB &A:A=A+1: WAIT 5: IF A<65 GOTO ^
30 GOSUB &A:A=A-1: WAIT 5: IF A¥0 GOTO ^
40 GOTO %A
50 &A: CURSOR A:"(PC-1261/2)":RETURN
```

A defined character: `10 √101:14555D7F551400140014:"πABBB":STOP`

Random dots: `10 CLS 0` / `20 WAIT 0:TRON RND 120,RND 14:GOTO ^`

A moving sprite that is drawn with `GRAD` and erased with `COS` (a sprite that crosses the screen while bouncing up and down):

```
10 CLS 0:X=0:Y=0:Z=1
20 %A:ON X,Y:GRAD 0106060202:WAIT 20:COS 248,4
30 X=X+1:IF X>=116:X=0
40 Y=Y+Z:IF Y=252:Y=253:Z=1
50 IF Y=14:Y=13:Z=255
60 GOTO %A
```

Keyboard dot mover with `INKEY$` (keys 4, 6, 2, 8):

```
10 CLS 0:X=0:Y=0
20 %A:TRON X,Y:WAIT 30
30 A=INKEY$:IF A="4":X=X-1:IF X=255:X=119
40 IF A="6":X=X+1:IF X=120:X=0
50 IF A="2":Y=Y+1:IF Y=14:Y=0
60 IF A="8":Y=Y-1:IF Y=255:Y=13
70 GOTO %A
```

Sprite moved by several simultaneous keys with `INT`:

```
10 CLS 0:X=0:Y=0
20 %A:ON X,Y:GRAD 0106060202:WAIT 10
30 %B:K=INT:I=0:IF K AND 128 IF X<115:X=X+1:I=1
40 IF K AND 8 IF X>=1:X=X-1:I=1
50 IF K AND 4 IF Y<11:Y=Y+1:I=1
60 IF K AND 2 IF Y>=1:Y=Y-1:I=1
70 IF I=0 GOTO %B:COS 248,4:GOTO %A
```

Sound: `10 BEEP 2:WAIT 100:BEEP 3:WAIT 100:BEEP 0`, and a small scale keyboard:

```
10 CLS 0:CURSOR 0:"PUSH 0-9 KEY"
20 √0:70635751473E35332C26
30 %A:K=INKEY$:IF K<"0" GOTO ^:IF "9"<K GOTO ^
40 SIN √(K-"0"),5:GOTO %A
```

More complete programs are in [examples/](examples/): `ball` (arrow-key controlled ball) and `breaker` (a block-breaking
game) for the PC-1350 and PC-1360, and the programs in the original article (LUMMY-BAHN, IMADOKI BLOCK 2) in
[lummy.txt](lummy.txt) and the PDF.

> The sample lines above are shown as printed in the translations; on a real machine `√` and `π` are keys and `¥`
> is SHIFT + `*`, and a few listings use a different spacing than your machine's BASIC editor produces.
