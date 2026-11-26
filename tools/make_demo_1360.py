"""Build a PokeComWin load image: LC-3 for the PC-1360 + an LC-3 source + a starter that compiles and runs it.

Usage: python -I tools/make_demo_1360.py [SOURCE.lc3] [OUT.bin]
       (defaults: examples/ball_1360.lc3, tools/demo/lc3demo-8030.bin)

PokeComWin's PC-1360 has a 32 KB RAM card, so the image uses the 32 KB build. It is loaded at CODE_ORG (&8030) and
contains:
  CODE_ORG ..   LC-3 (build/lc3_1360_32k.bin, symbols build/lc3_1360_32k.log)
  SRC_ADDR ..   the source tokenized as PC-1360 BASIC lines (analysis/tools/tok1360.py), i.e. the BASIC program
  after it      a starter: BASIC start / end pointers (&FFD7 / &FFD9) = the source, CALL COMPILE, JP RT_RUN_ENTRY
Prints the starter address: PokeComWin's --entry (hex) or "CALL <decimal>" on the emulated machine.
"""
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, 'tests'))
from regress import symbols  # noqa: E402

SRC_ADDR = 0xB000


def main():
    os.makedirs(os.path.join(REPO, 'tools', 'demo'), exist_ok=True)
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, 'examples', 'ball_1360.lc3')
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(REPO, 'tools', 'demo', 'lc3demo-8030.bin')
    sym = symbols(os.path.join(REPO, 'build', 'lc3_1360_32k.log'))
    lc3 = open(os.path.join(REPO, 'build', 'lc3_1360_32k.bin'), 'rb').read()
    tok = out + '.prog'
    subprocess.run([sys.executable, '-I', os.path.join(REPO, 'analysis', 'tools', 'tok1360.py'), src, tok],
                   check=True, stdout=subprocess.DEVNULL)
    prog = open(tok, 'rb').read()
    os.unlink(tok)
    base = sym['CODE_ORG']
    end = SRC_ADDR + len(prog) - 1
    stub_at = (end + 16) & ~15
    if stub_at + 32 > 0xF9D0:
        sys.exit('source too long')
    comp, run = sym['COMPILE'], sym['RT_RUN_ENTRY']
    stub = bytes([0x10, 0xFF, 0xD7,                       # LIDP &FFD7
                  0x02, SRC_ADDR & 255, 0x52,             # BASIC start
                  0x11, 0xD8, 0x02, SRC_ADDR >> 8, 0x52,
                  0x11, 0xD9, 0x02, end & 255, 0x52,      # BASIC end (the final FF)
                  0x11, 0xDA, 0x02, end >> 8, 0x52,
                  0x78, comp >> 8, comp & 255,            # CALL COMPILE
                  0x79, run >> 8, run & 255])             # JP RT_RUN_ENTRY
    img = bytearray(stub_at + len(stub) - base)
    img[0:len(lc3)] = lc3
    img[SRC_ADDR - base:SRC_ADDR - base + len(prog)] = prog
    img[stub_at - base:] = stub
    open(out, 'wb').write(img)
    print('%X' % stub_at)


if __name__ == '__main__':
    main()
