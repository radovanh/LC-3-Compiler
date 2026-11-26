# LC-3 for the SHARP PC-1261 / PC-1262

LC-3 is a compiler for a small BASIC-like language, published in Pocket Computer Journal (PJ) 1989/06. You type the
source with the machine's own BASIC editor; LC-3 compiles it into fast SC61860 machine code. This is the original
platform. The source here is a readable, symbolic rebuild of the article's `LC-3.bin`; compiled programs are
identical to the original's, and the binary is a little larger (2,492 instead of 2,306 bytes) because the routines it
used to call in the internal ROM are now local code (`src/helpers.asm`, `src/platform_pc1262.asm`).

**Status:** works in the PokeComWin emulator (all regression tests pass). The original `LC-3.bin` is known to work on
real machines.

## What you need

- A PC-1261 or PC-1262.
- `build/lc3_1262.bin`: LC-3 itself, 2,492 bytes, loaded at `&4000`.

## Addresses

| What | Address |
|---|---|
| Load LC-3 at | `&4000` (`CSAVEM "LC-3";&4000,&49BB`) |
| Compile | `CALL &4000` |
| Run the compiled program | `CALL &49BA` |
| Compiled code | `&49BC`-`&55FF` (3,140 bytes with `EQU#43`) |

The original binary runs at `CALL &4900` instead; the rebuilt one has a longer runtime, so use `&49BA`.

## Using it

1. In PRO mode: `NEW`, then `EQU#43` (moves the BASIC start to `&5600`).
2. Load `lc3_1262.bin` to `&4000` (`CLOADM`).
3. Type the LC-3 source as BASIC lines. It is never run as BASIC.
4. `CALL &4000` compiles. On an error the error number is shown; in PRO mode the up arrow shows the faulty line.
   Error 4 = the object area is too small (use a smaller `EQU#` value).
5. `CALL &49BA` runs the program. Always run it from PRO mode.

BRK works only while the program waits (`STOP`, `WAIT`, `PAUSE`, `INKEY$`, `INPUT`, `INT`, `AREAD`, `SIN`, `DMS`);
put `WAIT 0` in loops that should be breakable.

## Memory map (`EQU#43`)

| Range | Use |
|---|---|
| `&4000`-`&49B9` | LC-3 (compiler + runtime) |
| `&49BA` | run entry |
| `&49BC`-`&55FF` | compiled program |
| `&5600`-`&64FF` | the LC-3 source (the BASIC program) |
| `&6500`-`&657F` | data stack (`DIM`/`AREAD`) |

## The language

The language is that of the original article (statements, functions, labels, arrays, `GOSUB`, `DATA`, `BEEP`, `SIN`,
`DMS`, graphics on the 24 x 2 character LCD). The ports for the PC-1350 and PC-1360 compile the same sources; only
the screen statements differ (see `README_1350.md` and `README_1360.md`).

## Sources

`src/lc3_1262.asm` (top level), `src/pc1262.inc`, `src/platform_pc1262.asm`, `src/helpers.asm` (shared with the other
ports). Assembler: `sc61860-asm.js`.
