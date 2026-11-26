# LC-3 for the SHARP PC-1350

A port of the LC-3 compiler (PC-1261/1262, Pocket Computer Journal 1989) to the PC-1350. LC-3 compiles a small
BASIC-like language, typed with the machine's own BASIC editor, into fast machine code.

**Status:** works in the PokeComWin emulator (all regression tests pass). **Not yet tested on a real PC-1350.**

## What you need

- A PC-1350 with an **8 KB RAM card** or larger.
- `build/lc3_1350.bin`: LC-3 itself, 2,777 bytes, loaded at `&4030`.

## Addresses

| What | Address |
|---|---|
| Load LC-3 at | `&4030` (`CSAVEM "LC-3";&4030,&4B08`) |
| Compile | `CALL &4030` |
| Run the compiled program | `CALL &4AE9` |

These two CALL addresses are the same for every LC-3 program and every BASIC start. `&4AE9` can change when LC-3 itself
is changed and rebuilt: the build prints the current value (`tools/build_1350.sh`).

## Using it

1. Load LC-3 to `&4030` (on the machine `CLOADM`; in PokeComWin File > Load, type BINARY, address `4030`).
2. Reserve memory: in RUN mode `POKE &6F01,0,&5C` (moves the BASIC start to `&5C00`).
3. Press MODE for PRO mode, type `NEW`.
4. Type the LC-3 source as BASIC lines (in PokeComWin you can also load a `.bas` text file with File > Load, type BASIC).
5. Press MODE for RUN mode. `CALL &4030` compiles, `CALL &4AE9` runs.

Steps 1-3 are needed once. The space between `&4DD0` and the BASIC start holds the compiled code; the source lies from
the BASIC start up to `&6C2F`. If the compiler reports **error 4** (object too big), choose a higher BASIC start in
step 2 (`POKE &6F01,lo,hi`, then `NEW`: this clears the source).

In PokeComWin text files, write the array character `√` as `\SQR` and `π` as `\PI`.

### Compile errors

`CALL &4030` typed at the prompt shows `ERROR n` (the LC-3 error number; `:` = 10, `>` = general syntax error, `?` =
undefined label). To see **which line** is wrong, end the source with a line containing only `.` and put the CALL
behind it, e.g.

```
8000 .
8010 CALL &4030
```

then `RUN 8010`: the machine shows `ERROR ? IN 20`, and in PRO mode the up arrow shows line 20. (The source position
of the last error is also stored at `&4DC1`/`&4DC2`.)

### Stopping a program

`END` returns to BASIC. BRK (the ON key) stops a program while it waits (`WAIT`, `PAUSE`, `STOP`, `INKEY$`,
`INPUT`, `INT`, `SIN`, `DMS`); put `WAIT 0` in loops that should be breakable.

## The language on the PC-1350

LC-3 sources for the PC-1262 compile unchanged. Only the screen-related statements differ, because the PC-1350 has a
150 x 32 dot LCD (4 text rows of 25 characters) instead of 2 rows of 24:

| Statement | PC-1350 |
|---|---|
| `CURSOR n` | text cell `n = row*25 + column` (rows 0-3, columns 0-24); `n >= 100` switches text output off. Text wraps from row to row and from the last cell to the first. |
| `PRINT`, `LPRINT`, `CHR$`, `"text"` | a character is 6 dots wide (5 + 1 blank). `CHR$ 0`-`CHR$ 31` = user-defined characters in `√96`-`√255` as before. |
| `POKE n`, `DEG hex` | write 8-dot columns at the cursor, one column further each |
| `PEEK n` | the column `n` (0-149) of the row the cursor is in; `n >= 150` gives 0 |
| `CLS n` | bit 0-3 = row 0-3: a row whose bit is 0 is cleared; `CLS 0` clears everything |
| `ON x,y` | graphic cursor: x 0-149 (`x >= 150` switches `GRAD`/`COS` off), y 0-31 visible, 249-255 = -7..-1 (above the top) |
| `GRAD hex` | ORs 8-dot columns at the graphic cursor (bit 0 at y) |
| `COS m,w` | clears the dots where `m` has a 0 bit, `w+1` columns wide (`COS 0,w` = 8 dots high) |
| `TRON x,y` / `TROFF x,y` / `PI x,y` | set / clear / test a dot, x 0-149, y 0-31 (`PI` outside = 255) |
| `INKEY$` | the key held now: letters as ASCII, 1 several keys, 2 CL, 4 up, 5 down, 13 ENTER, 14 right, 15 left, 16 SHIFT, 18 DEF |
| `INPUT` | waits for a key (SHIFT = prefix for the shifted characters); a held key repeats after about 1 s |
| `INT` | the keys SHIFT 8 2 4 DEF ENTER 0 6 as bits 0-7 |

Everything else (expressions, variables, arrays, labels, `IF`, `GOSUB`, `DATA`, `BEEP`, `SIN`, `DMS`, ...) is as on the
PC-1262; see `analysis/LC3_Analysis.md` section 5.

## Memory map (8 KB card)

| Range | Use |
|---|---|
| `&4030`-`&4B08` | LC-3 |
| `&4C00`-`&4CFF` | array `√0`-`√255` (and the label table while compiling); RND seed at `&4C5E` |
| `&4D00`-`&4D7F` | data stack (`DIM`/`AREAD`) |
| `&4D80`-`&4DCF` | shadow variables (`VAL`), saved BASIC state, error position |
| `&4DD0` - BASIC start | compiled program |
| BASIC start - `&6C2F` | the LC-3 source (the BASIC program) |

## Examples and the demo in the emulator

| Example | What it shows |
|---|---|
| `examples/ball_1350.lc3` | a ball moved with the arrow keys (ENTER ends): `GRAD`, `COS`, `TRON`, `INKEY$` |
| `examples/breaker_1350.lc3` | **LC-3 BREAKER**, a block-breaking game: title screen and melody (`DMS`), 32 blocks drawn with `GRAD`, the ball with `TRON`/`TROFF`, block hits found with `PI` and cleared with `COS`, paddle on the arrow keys, sounds with `SIN`, score with `PRINT`, lives as a user-defined heart character (`√96=...`, `CHR$ 0`), `RND`, `GOSUB`/`RETURN`, `ASN`, `RUN` to restart. ENTER plays, Q quits (on the title and the GAME OVER screen). The ball speed is the frame delay `T` (`WAIT T`, line 60, 24 at the start, 3 less per cleared round down to 9; the paddle moves 4 dots per frame, the ball 1); PokeComWin's `WAIT` is about 3 times shorter than on a real PC-1350 (its 2 ms timer is counted in instructions), so on the real machine a smaller `T` may feel right. |

`tools\demo_1350.bat` starts PokeComWin with LC-3 and `examples/ball_1350.lc3` already compiled and running;
`tools\demo_1350.bat examples\breaker_1350.lc3` does the same with another source.

Each example also exists as a BASIC text file (`examples/*_1350.bas`) for PokeComWin's File > Load (steps above). In
these files the array character `√` is written `\SQR`, and the "not equal" character `¥` is written `\` with a space
before it when it follows a keyword (`INKEY$ \13`): PokeComWin's loader otherwise does not recognise the keyword.
`python -I tools/lc3_to_bas.py SOURCE.lc3` makes such a file from an `.lc3` source. Both `.bas` files load to the bytes
the `.lc3` sources give (checked with PokeComWin's own tokenizer; the only difference is the space after `REM` in
the breaker's comment line, which LC-3 skips). Every line has at most 79 characters, so the examples can also be typed
on the machine (its input buffer holds 80); the BREAKER title is split into lines 30 and 35 for that.

## Building and testing

| Task | Command |
|---|---|
| build `build/lc3_1350.bin` | `sh tools/build_1350.sh` (needs node and python) |
| compile suite (against the original PC-1262 results) + runtime suite | `sh tests/run_regression_1350.sh check` |
| BASIC protocol through the ROM (typed BASIC) | `python -I tests/protocol_1350.py` |
| record a new runtime baseline (check the LCD output by eye) | `sh tests/run_regression_1350.sh record-run` |

Sources: `src/lc3_1350.asm`, `src/pc1350.inc`, `src/platform_pc1350.asm`, `src/helpers.asm` (shared with the PC-1262).
Details: `analysis/LC3_Analysis.md` section 12.

## Known limitations

- Not tested on real hardware: the error report, the `INT` key wiring, the `SIN`/`DMS` pitch (it depends on the CPU
  clock) and PC-1350 ROM version 0.
- `GRAD`/`COS` draw column by column; a moving sprite that is erased and redrawn can flicker.
- PC-1262 programs that place text with PC-1262 `CURSOR` values (dot columns 0-239) show their text elsewhere.
