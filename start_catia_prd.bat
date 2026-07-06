@echo off
REM ============================================================================
REM  start_catia_prd.bat
REM
REM  Launches CATIA V5 (PRD) headlessly by calling the real backend launcher
REM  V5StartApp17.tclsh directly with the exact 16 arguments the PLMStart GUI
REM  would have passed. No GUI, no button clicking.
REM
REM  These args were captured from a real GUI launch (V5StartApp.CATIA.<user>.debug).
REM  If IT bumps the service pack / config / customization, update the values
REM  below (they mirror what you pick in the CATStart environment panel).
REM ============================================================================

setlocal

set "TCLSH=tclsh"
set "APP=I:\prd\cecc\bin\V5StartApp17.tclsh"

REM --- the 16 args, in order (argv0..argv15) ---
set "A0=V5R21"          & REM Catia version
set "A1=sp2f"           & REM service pack
set "A2=prd"            & REM level
set "A3=M170"           & REM customization (CAT_CUST_VERS)
set "A4=ENOM6PRD"       & REM Enovia database
set "A5=user"           & REM mode
set "A6=CATIA"          & REM product
set "A7=mtl"            & REM site
set "A8=I:\prd"         & REM root_data
set "A9=NOSL3"          & REM license
set "A10=I:\prd\Standard" & REM standard path
set "A11=win_b64"       & REM OS
set "A12=iCFGv50r00"    & REM plugin config
set "A13=ON"            & REM custo schema
set "A14=ON"            & REM custo interface
set "A15=ON"            & REM custo user-exit

REM --- env vars the PLMStart GUI normally exports before calling the backend ---
REM V5StartApp17.tclsh READS these from the environment instead of computing them.
set "USER_V5_PROFILE=DESIGN"       & REM your CATIA profile (DESIGN is the default; change if yours differs)
set "V5START_USERID=%USERNAME%"
set "V5START_LOCID=%A7%"
set "CUSTONAME=%A12%"              & REM plugin/customization name (iCFGv50r00)
set "CUSTO_LOCAL_DEST=c:\temp\ba"  & REM local ba custo cache root
set "CompanyIdentity=BOMBARDIER"

if not exist "%APP%" (
    echo ERROR: cannot find %APP%
    echo Make sure the I: drive is mapped.
    pause
    exit /b 1
)

echo Launching CATIA V5R21 PRD (%A3% / %A4% / %A12%) ...
"%TCLSH%" "%APP%" %A0% %A1% %A2% %A3% %A4% %A5% %A6% %A7% %A8% %A9% %A10% %A11% %A12% %A13% %A14% %A15% > "%TEMP%\start_catia_prd.%USERNAME%.out" 2>&1

if errorlevel 1 (
    echo V5StartApp17.tclsh returned an error - see "%TEMP%\start_catia_prd.%USERNAME%.out"
    pause
    exit /b 1
)

endlocal
