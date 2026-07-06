@echo off
setlocal
cd /d "%~dp0"

set "VENV_PYTHON=C:\Users\K1022108\langflow_venv\Scripts\python.exe"

if exist "%VENV_PYTHON%" (
    "%VENV_PYTHON%" launch_catia.py
) else (
    where py >nul 2>nul
    if %errorlevel%==0 (
        py -3 launch_catia.py
    ) else (
        python launch_catia.py
    )
)

if errorlevel 1 pause
