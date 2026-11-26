@echo off
rem Run an LC-3 program on the PC-1360 in the PokeComWin window.
rem   tools\demo_1360.bat [SOURCE.lc3]      (default: examples\ball_1360.lc3)
rem PokeComWin's PC-1360 has a 32 KB RAM card: the demo uses the 32 KB build (build\lc3_1360_32k.bin, built if it is
rem missing; needs Git's sh and node). It packs LC-3 + the source + a starter into tools\demo\lc3demo-8030.bin
rem (tools\make_demo_1360.py) and starts PokeComWin, which loads it at &8030 and types the CALL of the starter: the
rem source is compiled (CALL &8030) and run (CALL &8BD3, see tools\build_1360.sh) on the emulated machine.
rem Afterwards: CALL &8BD3 runs it again, CALL &8030 compiles again. The PokeComWin session is not saved.
rem Set POKECOM_EXE if PokeComWin.exe is somewhere else.
setlocal
set "REPO=%~dp0.."
if "%POKECOM_EXE%"=="" set "POKECOM_EXE=%USERPROFILE%\OneDrive\Documents\GitHub\PokeComWin\build\PokeComWin\PokeComWin.exe"
set "SRC=%~1"
if "%SRC%"=="" set "SRC=%REPO%\examples\ball_1360.lc3"

if not exist "%REPO%\build\lc3_1360_32k.bin" (
  sh "%REPO%\tools\build_1360.sh" 32 || goto :fail
)
set "ENTRY="
for /f %%e in ('python -I "%REPO%\tools\make_demo_1360.py" "%SRC%" "%REPO%\tools\demo\lc3demo-8030.bin"') do set "ENTRY=%%e"
if "%ENTRY%"=="" goto :fail
if not exist "%POKECOM_EXE%" (
  echo PokeComWin.exe not found: %POKECOM_EXE%
  goto :fail
)
echo Starting PokeComWin: LC-3 + %SRC%, starter at ^&%ENTRY%
start "" "%POKECOM_EXE%" --model 1360 --fresh --no-save --load "%REPO%\tools\demo\lc3demo-8030.bin" --addr 8030 --entry %ENTRY% --run
exit /b 0

:fail
echo Demo not started.
pause
exit /b 1
