@echo off
setlocal enabledelayedexpansion

REM Aime CPU miner — Windows wrapper for XMRig
REM
REM Address resolution order:
REM   1. Command-line argument %1
REM   2. AIME_ADDRESS environment variable
REM   3. %USERPROFILE%\.aime\last-wallet-address.txt
REM   4. .\aime-address.txt (per-folder override)
REM
REM Usage: aime-mine.bat [AIME_ADDRESS] [THREADS] [POOL]

set "ADDR="
set "ADDR_SOURCE="

REM Try command-line first
if not "%~1"=="" (
    set "ADDR=%~1"
    set "ADDR_SOURCE=command-line argument"
    goto :address_ok
)

REM Try environment variable
if defined AIME_ADDRESS (
    set "ADDR=%AIME_ADDRESS%"
    set "ADDR_SOURCE=AIME_ADDRESS env var"
    goto :address_ok
)

REM Try saved file in user profile
if exist "%USERPROFILE%\.aime\last-wallet-address.txt" (
    set /p ADDR=<"%USERPROFILE%\.aime\last-wallet-address.txt"
    set "ADDR_SOURCE=%USERPROFILE%\.aime\last-wallet-address.txt"
    goto :address_ok
)

REM Try per-folder override
if exist "aime-address.txt" (
    set /p ADDR=<"aime-address.txt"
    set "ADDR_SOURCE=.\aime-address.txt"
    goto :address_ok
)

REM No address found
goto :no_address

:address_ok
set "THREADS=%~2"
set "POOL=%~3"

if not defined THREADS set "THREADS=4"
if not defined POOL set "POOL=127.0.0.1:17081"

REM Detect daemon mode (Aime RPC ports)
set "DAEMON=false"
echo %POOL% | findstr /R ":17081$ :27081$ :37081$" >nul
if %errorlevel%==0 set "DAEMON=true"

REM Locate xmrig.exe
set "XMRIG="
if exist "xmrig.exe" set "XMRIG=xmrig.exe"
if "%XMRIG%"=="" if exist "xmrig\xmrig.exe" set "XMRIG=xmrig\xmrig.exe"
if "%XMRIG%"=="" goto :no_xmrig

REM Generate XMRig config
> config.json (
    echo {
    echo   "autosave": false,
    echo   "background": false,
    echo   "colors": true,
    echo   "title": false,
    echo   "randomx": {"init": -1, "mode": "auto", "1gb-pages": false, "rdmsr": true, "wrmsr": true, "numa": true},
    echo   "cpu": {"enabled": true, "huge-pages": true, "huge-pages-jit": true, "yield": true, "threads": %THREADS%},
    echo   "pools": [{
    echo     "url": "%POOL%",
    echo     "user": "%ADDR%",
    echo     "pass": "aime-worker",
    echo     "tls": false,
    echo     "keepalive": true,
    echo     "algo": "rx/0",
    echo     "daemon": %DAEMON%,
    echo     "submit-to-origin": true,
    echo     "nicehash": false
    echo   }],
    echo   "log-file": "aime-miner.log",
    echo   "print-time": 60
    echo }
)

echo ==========================================================
echo   Aime CPU Miner (Windows)
echo ==========================================================
if "%DAEMON%"=="true" (
    echo  Mode    : SOLO ^(via Aime daemon^)
) else (
    echo  Mode    : POOL ^(stratum^)
)
echo  Address : %ADDR%
echo  Source  : %ADDR_SOURCE%
echo  Threads : %THREADS%
echo  Pool    : %POOL%
echo  XMRig   : %XMRIG%
echo.
echo  Press Ctrl+C to stop, or close this window.
echo ==========================================================
echo.

"%XMRIG%" --config=config.json

if exist config.json del config.json
goto :eof

:no_address
echo Aime CPU Miner — Windows wrapper for XMRig
echo.
echo No address found. Set one of the following:
echo.
echo   1. Command line:    aime-mine.bat AQWWPyLG... 4
echo.
echo   2. Environment:     set AIME_ADDRESS=AQWWPyLG...
echo                       aime-mine.bat
echo.
echo   3. Saved file:      mkdir "%USERPROFILE%\.aime" 2^>nul
echo                       echo AQWWPyLG... ^> "%USERPROFILE%\.aime\last-wallet-address.txt"
echo                       aime-mine.bat
echo.
echo   4. Per-folder:      echo AQWWPyLG... ^> aime-address.txt
echo                       aime-mine.bat
echo.
echo Examples:
echo   aime-mine.bat AQWWPyLG4exW1QNg2HZnG... 4
echo   aime-mine.bat "" 8                          ^(auto-load address, 8 threads^)
echo.
echo Prerequisites:
echo   - xmrig.exe in current folder ^(or xmrig\xmrig.exe^)
echo     Download: https://github.com/xmrig/xmrig/releases
echo   - For SOLO mining: aimed daemon on RPC port ^(default 127.0.0.1:17081^)
echo.
exit /b 1

:no_xmrig
echo ==========================================================
echo   ERROR: xmrig.exe not found
echo ==========================================================
echo.
echo Download XMRig for Windows:
echo   https://github.com/xmrig/xmrig/releases/latest
echo.
echo Steps:
echo   1. Download "xmrig-X.X.X-msvc-win64.zip"
echo   2. Extract — find xmrig.exe inside
echo   3. Copy xmrig.exe next to aime-mine.bat
echo   4. Run again
echo.
exit /b 1
