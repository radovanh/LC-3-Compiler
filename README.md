# LC-3 Compiler for SHARP pocket computers

LC-3 is a two-pass compiler for a small BASIC-like language. The source is typed with the machine's own BASIC editor
and compiled on the pocket computer itself into fast SC61860 machine code. The program with compiler and runtime
library together is only 2.5-3 KB.

LC-3 was written for the SHARP PC-1261/PC-1262 and published in Pocket Computer Journal 1989/06 (original repository:
[hiroog/LC3_Compiler](https://github.com/hiroog/LC3_Compiler)). This repository holds a rebuilt, assemblable source
and ports to two more machines.

## Supported devices

| Device | Binary | Load address | Compile | Run | Memory needed | Details | Status |
|---|---|---|---|---|---|---|---|
| PC-1261 / PC-1262 | `build/lc3_1262.bin` | `&4000` | `CALL &4000` | `CALL &49BA` | built-in RAM | [README_1262.md](README_1262.md) | emulator |
| PC-1350 | `build/lc3_1350.bin` | `&4030` | `CALL &4030` | `CALL &4AE9` | 8 KB RAM card or larger | [README_1350.md](README_1350.md) | emulator |
| PC-1360 (8 KB card) | `build/lc3_1360_8k.bin` | `&E030` | `CALL &E030` | `CALL &EBD3` | 8 KB RAM card | [README_1360.md](README_1360.md) | emulator |
| PC-1360 (16 KB card) | `build/lc3_1360_16k.bin` | `&C030` | `CALL &C030` | `CALL &CBD3` | 16 KB RAM card | [README_1360.md](README_1360.md) | emulator |
| PC-1360 (32 KB card) | `build/lc3_1360_32k.bin` | `&8030` | `CALL &8030` | `CALL &8BD3` | 32 KB RAM card | [README_1360.md](README_1360.md) | emulator |

"Emulator" means: all regression tests pass in the PokeComWin emulator; the port has not been tested on a real machine
yet. LC-3 sources written for the PC-1262 compile unchanged on the other machines; only the screen statements
(`CURSOR`, `PEEK`/`POKE`, `CLS`, `GRAD`, ...) differ because the displays differ. See the device READMEs.

## Documentation

- [LC-3_User_Manual.md](LC-3_User_Manual.md): how to use the compiler, with all commands and syntax.
- [image/LC-3_jap2eng.pdf](image/LC-3_jap2eng.pdf): scans of the original magazine article with the source listings and
  the description of LC-3 (17 pages, Japanese text with an English translation laid over it). The pages show the
  *Pocket Computer Journal* ("PJ", ポケコンジャーナル, published by Kogakusha) logo. The article is the one from
  **PJ 1989/06**, "Compiler for PC-1261/62 LC-3"; it also contains the listing of IMADOKI BLOCK 2 (PJ 1990/06) and
  refers to LUMMY-BAHN (PJ 1988/02) and the "TY Compiler" (game "Reverse"). The issue dates come from the article
  list of the original repository and from the text of the scans; the exact page numbers are not stated here.

## Contents

| Folder / file | What it is |
|---|---|
| `src/` | assembler sources: `lc3_1262.asm`, `lc3_1350.asm`, `lc3_1360.asm`, one `pc*.inc` and `platform_pc*.asm` per device, `helpers.asm` (shared); the PC-1360 has one top file per RAM card: `lc3_1360_8k.asm`, `lc3_1360_16k.asm`, `lc3_1360_32k.asm` |
| `build/` | the finished binaries |
| `examples/` | example programs (`ball`, `breaker`) as `.lc3` sources and `.bas` text files, for the PC-1350 and PC-1360, and the `demo_*.bat` launchers for PokeComWin |

The assembler is `sc61860-asm.js` (SC61860 assembler for Node.js).
