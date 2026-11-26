"""Build a PokeComWin load image: LC-3 for the PC-1350 + an LC-3 source + a starter that compiles and runs it.

Usage: python -I tools/make_demo_1350.py [SOURCE.lc3] [OUT.bin]
       (defaults: examples/ball_1350.lc3, tools/demo/lc3demo-4030.bin)

The image is loaded at CODE_ORG (&4030) and contains:
  CODE_ORG ..   LC-3 (build/lc3_1350.bin, symbols build/lc3_1350.log)
  SRC_ADDR ..   the source tokenized as BASIC lines (analysis/tools/tok1262.py), i.e. the BASIC program
  after it      a starter: BASIC start / end pointers (&6F01 / &6F03) = the source, CALL COMPILE, JP RT_RUN_ENTRY
Prints the starter address: PokeComWin's --entry (hex) or "CALL <decimal>" on the emulated machine.
"""
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, 'tests'))
from regress import symbols  # noqa: E402

SRC_ADDR = 0x5C00


def main():
    os.makedirs(os.path.join(REPO, 'tools', 'demo'), exist_ok=True)
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, 'examples', 'ball_1350.lc3')
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(REPO, 'tools', 'demo', 'lc3demo-4030.bin')
    sym = symbols(os.path.join(REPO, 'build', 'lc3_1350.log'))
    lc3 = open(os.path.join(REPO, 'build', 'lc3_1350.bin'), 'rb').read()
    tok = out + '.prog'
    subprocess.run([sys.executable, '-I', os.path.join(REPO, 'analysis', 'tools', 'tok1262.py'), src, tok],
                   check=True, stdout=subprocess.DEVNULL)
    prog = open(tok, 'rb').read()
    os.unlink(tok)
    base = sym['CODE_ORG']
    end = SRC_ADDR + len(prog) - 1
    stub_at = (end + 16) & ~15
    if stub_at + 32 > 0x6C30:
        sys.exit('source too long')
    comp, run = sym['COMPILE'], sym['RT_RUN_ENTRY']
    stub = bytes([0x10, 0x6F, 0x01,                       # LIDP &6F01
                  0x02, SRC_ADDR & 255, 0x52,             # BASIC start
                  0x11, 0x02, 0x02, SRC_ADDR >> 8, 0x52,
                  0x11, 0x03, 0x02, end & 255, 0x52,      # BASIC end (the final FF)
                  0x11, 0x04, 0x02, end >> 8, 0x52,
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
