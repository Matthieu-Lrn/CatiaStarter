@echo off
REM ============================================================================
REM  start_catia.bat
REM
REM  Headless CATIA + ENOVIA V5 VPM launcher.
REM  Runs the real PLMStart env panel (V5StartInt17.tcl) invisibly via
REM  auto_plmstart.tcl and triggers its own Start button in-process, so the
REM  ENOVIA daemon login happens exactly like a normal GUI launch.
REM
REM  Level defaults to prd; pass another (vld/crt/trn) as the first arg.
REM ============================================================================

setlocal
cd /d "%~dp0"

set "LEVEL=%~1"
if "%LEVEL%"=="" set "LEVEL=prd"

REM V5StartApp17.tclsh reads env(V5START_PATH); the GUI normally sets it, but
REM set it here as a real env var so the child process reliably inherits it.
set "V5START_PATH=I:\V5Start\5.0.1"

REM Use the same wish the PLMStart chain uses. Adjust if not on PATH.
set "WISH=wish"

"%WISH%" auto_plmstart.tcl %LEVEL%

endlocal
