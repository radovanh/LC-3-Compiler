# LC-3 for the SHARP PC-1360

This is a port of the LC-3 compiler to the PC-1360. LC-3 was written for the PC-1261/1262 and published in Pocket
Computer Journal in 1989. It compiles a small BASIC-like language into fast machine code. You type the source with the
machine's own BASIC editor. The PC-1360 port behaves like the PC-1350 port (`README_1350.md`) wherever the two machines
allow it.

**Status:** works in the PokeComWin emulator, where all regression tests pass. **Not yet tested on a real PC-1360.**

## What you need

- A PC-1360 with a RAM card in slot 1: 8 KB (minimum, small programs only), 16 KB (recommended) or 32 KB.
- The LC-3 binary built for your card. All three binaries come from the same source. Each one must be loaded at its
  card's BASIC start:

| Card | Binary | Load at | Compile | Run | Room for compiled code + source |
|---|---|---|---|---|---|
| 8 KB | `build/lc3_1360_8k.bin` | `&E030` | `CALL &E030` (57392) | `CALL &EBD3` (60371) | 3,072 bytes (`&EDD0`-`&F9CF`) |
| **16 KB** | **`build/lc3_1360_16k.bin`** | **`&C030`** | **`CALL &C030` (49200)** | **`CALL &CBD3` (52179)** | 11,264 bytes (`&CDD0`-`&F9CF`) |
| 32 KB | `build/lc3_1360_32k.bin` | `&8030` | `CALL &8030` (32816) | `CALL &8BD3` (35795) | 27,648 bytes (`&8DD0`-`&F9CF`); the compiled code can be at most 15,152 bytes |

LC-3 itself is 3,011 bytes. To save it to tape, use the range `CODE_ORG` .. `CODE_ORG + &BC2`, for example
`&C030,&CBF2` for the 16 KB build. The PC-1360 manual gives the syntax (`CSAVE M`); it has not been tried here. The
run address can change when LC-3 is changed and rebuilt; `tools/build_1360.sh` prints the current addresses.

For comparison: the PC-1262 had about 7,000 bytes for compiled code and source together, and the PC-1350 port with an
8 KB card has 7,776. The 8 KB PC-1360 card is therefore small. LUMMY-BAHN, for example, needs about 3,450 bytes of
source and 2,350 bytes of compiled code, so it does not fit on the 8 KB card.

## Using it (16 KB card; for other cards use the addresses from the table)

1. Load LC-3 to `&C030` (on the machine `CLOAD M`; in PokeComWin File > Load, type BINARY, address `C030`).
2. Reserve memory: in RUN mode type `POKE &FFD7,0,&E0`. This moves the BASIC start to `&E000`.
3. Press MODE for PRO mode and type `NEW`.
4. Type the LC-3 source as BASIC lines. A line can have at most 79 characters, because the input buffer holds 80. In
   PokeComWin you can also load a `.bas` text file with File > Load, type BASIC.
5. Press MODE for RUN mode. `CALL &C030` compiles and `CALL &CBD3` runs.

You only need steps 1-3 once. The compiled code goes from `&CDD0` up to the BASIC start, and the source from the BASIC
start up to `&F9CF`.

If the compiler reports **error 4** (object too big), choose a higher BASIC start in step 2 and repeat step 3. Note that
`NEW` clears the source. For example, `POKE &FFD7,0,&F0` leaves 8,752 bytes for compiled code and 2,512 for the source.
Suggested BASIC starts for the other cards:

- 8 KB: `POKE &FFD7,0,&F4` leaves 1,584 bytes for compiled code and 1,488 for the source.
- 32 KB: `POKE &FFD7,0,&C0` leaves 12,848 bytes for compiled code and 14,800 for the source.

### Typing the source

- The PC-1360 stores keywords as 2 bytes (`&FE` + code). LC-3 reads them in that form, so you type the source exactly
  as on the PC-1262 or PC-1350.
- `√` (the array) is the keyword `SQR`. In PokeComWin `.bas` files, write it as `SQR` followed by a space (`SQR 96=...`)
  or as `\SQR`. Inside a string, use `\SQR` and `\PI`.
- The PC-1360 has no `(` and `)` keys. SHIFT + `/` gives `(` and SHIFT + `;` gives `)`. LC-3 writes `)` after some
  operands, for example `RND 6)+1` and `√1)`.
- The "not equal" character `¥` is `\` (SHIFT + `*`). In PokeComWin `.bas` files, put a space before it when it follows
  a keyword (`INKEY$ \13`).

### Compile errors

`CALL &C030` typed at the prompt shows `ERROR n`, where n is the LC-3 error number: `:` = 10, `>` = a general syntax
error, `?` = an undefined label, `4` = object too big.

To see **which line** is wrong, end the source with a line that holds only `.` and put the CALL behind it, e.g.

```
8000 .
8010 CALL &C030
```

then `RUN 8010`. The machine shows `ERROR ? IN 20`, and in PRO mode the up arrow shows line 20. The source position of
the last error is also stored at `&CDC1`/`&CDC2` (16 KB build; `WORK_BASE + &1C1` in general).

A PC-1360 keyword that LC-3 does not know, such as `FOR`, is a syntax error. So is a line number after `GOTO`/`GOSUB`
(LC-3 has labels only; the PC-1360 stores the number in binary).

### Stopping a program

`END` returns to BASIC. BRK (the ON key) stops a program only while it waits: in `WAIT`, `PAUSE`, `STOP`, `INKEY$`,
`INPUT`, `INT`, `SIN` and `DMS`. Put `WAIT 0` in loops that should be breakable.

## The language on the PC-1360

LC-3 sources for the PC-1262 compile unchanged; the compiled code is the same as the original's. The screen is the
PC-1350's (150 x 32 dots, 4 text rows of 25 characters), and so are the statements:

| Statement | PC-1360 (= PC-1350 port) |
|---|---|
| `CURSOR n` | Text cell `n = row*25 + column` (rows 0-3, columns 0-24). `n >= 100` switches text output off. Text wraps from row to row and from the last cell to the first. |
| `PRINT`, `LPRINT`, `CHR$`, `"text"` | A character is 6 dots wide (5 + 1 blank). `CHR$ 0`-`CHR$ 31` are the user-defined characters in `√96`-`√255`. Codes `&20`-`&7F` and `&F5`-`&FC` (`√`, `π`, ...) show the ROM's characters. Every other code, **including the kana**, shows a space. |
| `POKE n`, `DEG hex` | Write 8-dot columns at the cursor, moving one column further each time. |
| `PEEK n` | Column `n` (0-149) of the row the cursor is in; `n >= 150` gives 0. |
| `CLS n` | Bits 0-3 stand for rows 0-3: a row whose bit is 0 is cleared. `CLS 0` clears everything. |
| `ON x,y` | Graphic cursor: x 0-149 (`x >= 150` switches `GRAD`/`COS` off); y 0-31 is visible, and 249-255 are -7..-1 (above the top). |
| `GRAD hex` | ORs 8-dot columns in at the graphic cursor (bit 0 at y). |
| `COS m,w` | Clears the dots where `m` has a 0 bit, `w+1` columns wide (`COS 0,w` clears 8 dots high). |
| `TRON x,y` / `TROFF x,y` / `PI x,y` | Set / clear / test a dot, x 0-149, y 0-31 (`PI` outside the screen gives 255). |
| `INKEY$` | The key held now, from BASIC's own INKEY$ table: letters as ASCII, 1 several keys, 2 CL, 4 up, 5 down, 13 ENTER, 14 right, 15 left, 16 SHIFT, 18 DEF. |
| `INPUT` | Waits for a key. SHIFT is a prefix for the shifted characters (SHIFT + `/` = `(`). A held key repeats after about 1 s. |
| `INT` | The keys SHIFT 8 2 4 DEF ENTER 0 6 as bits 0-7. |

Everything else (expressions, variables, arrays, labels, `IF`, `GOSUB`, `DATA`, `BEEP`, `SIN`, `DMS`, ...) works as on
the PC-1262; see `analysis/LC3_Analysis.md` section 5. Some limits differ from the PC-1262:

- GOSUB nesting: the PC-1360 calls LC-3 with the stack 2 bytes lower than the PC-1262, so 15 levels are safe
  instead of 16.
- Long chains of nested functions in one expression (about 11 in a row, `ABS ABS ... 1`) overflow the compiler's stack,
  as they do on the original.

**Speed and tones.** The PC-1360 runs at 768 kHz (its specification), the clock PokeComWin also uses for the PC-1262,
so the cycle-counted `SIN` and `DMS` loops are unchanged: same pitch and note lengths as on the PC-1262 (the emulator
gives exactly the PC-1350 port's cycle counts). `WAIT`, `PAUSE` and the key repeat count the 2 ms timer, and `BEEP`
uses the hardware tone. Not checked on the machine.

### Adding statements (the `TBL_STATEMENTS` extension mechanism)

User statements are appended to `TBL_STATEMENTS` (`&C57E` in the 16 KB build), as in the original, but the entry format
is different. An entry is `token, flags | (handler high byte - LC-3's page), handler low byte`, where LC-3's page is
`&C0` / `&E0` / `&80`. The handler must lie in the 8 KB that start at LC-3's page. The flags are bit 7 = first operand
in `(&11)` and bit 5 = operand in A. The token is the PC-1262 code of the keyword; `RDTOK` translates the PC-1360
keywords that LC-3 knows (table `TBL_TOKENS`).

## Memory map (16 KB card; the 8 / 32 KB builds are the same plus &2000 / minus &4000)

| Range | Use |
|---|---|
| `&C030`-`&CBF2` | LC-3 (13 bytes are free before the work areas) |
| `&CC00`-`&CCFF` | Array `√0`-`√255` (and the label table while compiling); RND seed at `&CC5E` |
| `&CD00`-`&CD7F` | Data stack (`DIM`/`AREAD`) |
| `&CD80`-`&CDCF` | Shadow variables (`VAL`), BASIC's internal RAM `&30`-`&3F` while LC-3 runs (`&CDB0`), saved `R` (`&CDC0`), error position (`&CDC1`), glyph buffer (`&CDC4`) |
| `&CDD0` - BASIC start | Compiled program |
| BASIC start - `&F9CF` | The LC-3 source (the BASIC program) |
| `&F9D0`- | BASIC's variables and system area (not touched) |

While compiling, LC-3 also "writes" its first, measuring pass into the ROM window `&4000`-`&7FFF`, where the writes
are lost. While running, it writes only the 600 display bytes in `&2800`-`&307B`, never the PC-1360's system bytes
between them. It also writes the ROM bank register (bank 1 is mapped for a moment to read the font) and the keyboard
port.

## Examples and the demo in the emulator

| Example | What it shows |
|---|---|
| `examples/ball_1360.lc3` | A ball moved with the arrow keys (ENTER ends): `GRAD`, `COS`, `TRON`, `INKEY$`. |
| `examples/breaker_1360.lc3` | **LC-3 BREAKER**, the block-breaking game of the PC-1350 port. Its long title line is split in two so that every line can be typed. |

`tools\demo_1360.bat` starts PokeComWin with LC-3 and `examples/ball_1360.lc3`, already compiled and running.
`tools\demo_1360.bat examples\breaker_1360.lc3` does the same with another source. PokeComWin's PC-1360 has a 32 KB
card, so the demo uses the 32 KB build: `CALL &8BD3` runs the program again and `CALL &8030` compiles it again.

Each example also exists as a BASIC text file (`examples/*_1360.bas`) for PokeComWin's File > Load. The files have been
checked in two ways, and both give exactly the bytes the harness tokenizer gives for the `.lc3` sources
(`python -I tools/check_bas_1360.py --typed`):

- loaded with PokeComWin's own loader;
- typed key by key into the PC-1360 ROM.

## Building and testing

| Task | Command |
|---|---|
| Build the three binaries | `sh tools/build_1360.sh` (or `sh tools/build_1360.sh 16` for one card; needs node and python) |
| Compile suite (against the original PC-1262 results) + runtime suite, 16 KB | `sh tests/run_regression_1360.sh check` |
| The same for all cards (compile suite 16 / 32 KB, runtime suite 8 / 16 / 32 KB) | `sh tests/run_regression_1360.sh all-cards` |
| Runtime results against the PC-1350 port | `sh tests/run_regression_1360.sh vs1350` |
| BASIC protocol through the ROM (typed BASIC) | `python -I tests/protocol_1360.py` (`--bin build/lc3_1360_8k.bin --sym build/lc3_1360_8k.log` for another card) |
| Example `.bas` files vs the harness tokenizer | `python -I tools/check_bas_1360.py [--typed]` |
| Record a new runtime baseline (check the LCD output by eye) | `sh tests/run_regression_1360.sh record-run` |

Sources: `src/lc3_1360.asm` (a copy of `lc3_1350.asm` with the PC-1360 changes), `src/pc1360.inc`,
`src/platform_pc1360.asm`, and `src/helpers.asm` (shared). Details: `analysis/LC3_Analysis.md` section 13.

## Known limitations

- Not tested on real hardware. In particular, none of these has been checked on a machine:
  - the error report;
  - the key layout (it follows the ROM's INKEY$ table and PokeComWin's key matrix);
  - the `SIN`/`DMS` pitch;
  - the 8 KB and 16 KB cards (emulated as cards that repeat over `&8000`-`&FFFF`);
  - ROM versions other than the emulator's, since the font (`&418B`, bank 1) and the INKEY$ table (`&4360`, bank 0)
    are read directly.
- Kana are not printed (they show as spaces).
- `GRAD`/`COS` draw column by column; a moving sprite that is erased and redrawn can flicker.
- PC-1262 programs that place text with PC-1262 `CURSOR` values (dot columns 0-239) show their text elsewhere.
