@echo off
rem Run an LC-3 program on the PC-1350 in the PokeComWin window.
rem   tools\demo_1350.bat [SOURCE.lc3]      (default: examples\ball_1350.lc3)
rem Builds build\lc3_1350.bin if it is missing (needs Git's sh and node), packs LC-3 + the source + a starter into
rem tools\demo\lc3demo-4030.bin (tools\make_demo_1350.py) and starts PokeComWin, which loads it at &4030 and types the
rem CALL of the starter: the source is compiled (CALL &4030) and run (CALL &4AE9) on the emulated machine.
rem Afterwards: CALL &4AE9 runs it again, CALL &4030 compiles again. The PokeComWin session is not saved.
rem Set POKECOM_EXE if PokeComWin.exe is somewhere else.
setlocal
set "REPO=%~dp0.."
if "%POKECOM_EXE%"=="" set "POKECOM_EXE=%USERPROFILE%\OneDrive\Documents\GitHub\PokeComWin\build\PokeComWin\PokeComWin.exe"
set "SRC=%~1"
if "%SRC%"=="" set "SRC=%REPO%\examples\ball_1350.lc3"

if not exist "%REPO%\build\lc3_1350.bin" (
  sh "%REPO%\tools\build_1350.sh" || goto :fail
)
set "ENTRY="
for /f %%e in ('python -I "%REPO%\tools\make_demo_1350.py" "%SRC%" "%REPO%\tools\demo\lc3demo-4030.bin"') do set "ENTRY=%%e"
if "%ENTRY%"=="" goto :fail
if not exist "%POKECOM_EXE%" (
  echo PokeComWin.exe not found: %POKECOM_EXE%
  goto :fail
)
echo Starting PokeComWin: LC-3 + %SRC%, starter at ^&%ENTRY%
start "" "%POKECOM_EXE%" --model 1350 --fresh --no-save --load "%REPO%\tools\demo\lc3demo-4030.bin" --addr 4030 --entry %ENTRY% --run
exit /b 0

:fail
echo Demo not started.
pause
exit /b 1
