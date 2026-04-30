@echo off
setlocal enabledelayedexpansion

REM Aime CPU miner — Windows wrapper for XMRig
REM Usage: aime-mine.bat <YOUR_AIME_ADDRESS> [THREADS] [POOL]

if "%~1"=="" goto :usage

set "ADDR=%~1"
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

REM Sanity check on address
echo %ADDR% | findstr /B "A" >nul
if %errorlevel% neq 0 (
    echo [WARN] Address does not start with 'A' - is this an Aime address?
    timeout /t 2 >nul
)

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

:usage
echo Aime CPU Miner — Windows wrapper for XMRig
echo.
echo Usage: aime-mine.bat ^<AIME_ADDRESS^> [THREADS] [POOL]
echo.
echo Arguments:
echo   AIME_ADDRESS  Your wallet address ^(95 chars, starts with "A"^)
echo   THREADS       Number of CPU threads ^(default: 4^)
echo   POOL          Pool URL ^(default: 127.0.0.1:17081 — solo via local node^)
echo.
echo Examples:
echo   aime-mine.bat AQWWPyLG4exW1QNg2HZnGBgoXxkKCPf2WetZCd3n4k7nPusWGoC73nKRcUuEvCkZ1d26kNGgbuXGf7DcaJADpN484v1XjDr 4
echo   aime-mine.bat AQWWPyLG4... 4 pool.aime.network:3333
echo.
echo Prerequisites:
echo   1. xmrig.exe in current folder ^(or xmrig\xmrig.exe^)
echo      Download: https://github.com/xmrig/xmrig/releases
echo      File name: xmrig-X.X.X-msvc-win64.zip
echo.
echo   2. For SOLO mining: an Aime daemon ^(aimed^) running on the
echo      specified RPC port ^(default 127.0.0.1:17081^).
echo.
echo Press Ctrl+C or close the window to stop mining.
exit /b 1

:no_xmrig
echo ==========================================================
echo   ERROR: xmrig.exe not found in current folder
echo ==========================================================
echo.
echo Download XMRig for Windows:
echo   https://github.com/xmrig/xmrig/releases/latest
echo.
echo Steps:
echo   1. Download "xmrig-X.X.X-msvc-win64.zip"
echo   2. Extract — find xmrig.exe inside
echo   3. Copy xmrig.exe to this folder ^(next to aime-mine.bat^)
echo   4. Run aime-mine.bat again
echo.
exit /b 1
