@echo off
setlocal enabledelayedexpansion

REM aime-set-address.bat — Manage saved Aime wallet address for auto-loading
REM
REM Usage:
REM   aime-set-address.bat                       Interactive prompt
REM   aime-set-address.bat AQWWPy...             Save address directly
REM   aime-set-address.bat show                  Show currently saved address
REM   aime-set-address.bat clear                 Remove saved address
REM
REM The address is saved to %USERPROFILE%\.aime\last-wallet-address.txt
REM and is automatically loaded by aime-mine.bat when no address arg is given.

set "ADDRESS_FILE=%USERPROFILE%\.aime\last-wallet-address.txt"

if "%~1"=="" goto :interactive
if /I "%~1"=="show" goto :show
if /I "%~1"=="status" goto :show
if /I "%~1"=="current" goto :show
if /I "%~1"=="clear" goto :clear
if /I "%~1"=="remove" goto :clear
if /I "%~1"=="delete" goto :clear
if /I "%~1"=="unset" goto :clear
if /I "%~1"=="help" goto :help
if /I "%~1"=="-h" goto :help
if /I "%~1"=="--help" goto :help
goto :save

:show
if exist "%ADDRESS_FILE%" (
    set /p CURRENT=<"%ADDRESS_FILE%"
    if defined CURRENT (
        echo Current saved address:
        echo   !CURRENT!
        echo.
        echo   File: %ADDRESS_FILE%
        exit /b 0
    )
)
echo No address currently saved.
echo   Expected file: %ADDRESS_FILE% ^(does not exist or empty^)
exit /b 1

:clear
if exist "%ADDRESS_FILE%" (
    del "%ADDRESS_FILE%"
    echo [OK] Saved address cleared.
    echo   Removed: %ADDRESS_FILE%
) else (
    echo Nothing to clear ^(no saved address^).
)
exit /b 0

:interactive
echo Aime Address Setup
echo ==================
if exist "%ADDRESS_FILE%" (
    set /p OLD_ADDR=<"%ADDRESS_FILE%"
    if defined OLD_ADDR (
        echo Current saved address:
        echo   !OLD_ADDR!
        echo.
    )
)
set /p NEW_ADDR="Paste your AIME address (or 'q' to cancel): "
if "!NEW_ADDR!"=="" goto :cancelled
if /I "!NEW_ADDR!"=="q" goto :cancelled
set "ARG_ADDR=!NEW_ADDR!"
goto :save_inner

:cancelled
echo Cancelled.
exit /b 0

:save
set "ARG_ADDR=%~1"

:save_inner
REM Basic validation: starts with A
echo !ARG_ADDR! | findstr /B "A" >nul
if errorlevel 1 (
    echo [ERROR] Invalid address format - must start with 'A'
    echo   Got: !ARG_ADDR!
    exit /b 1
)

REM Length check: must be 95 chars
set "LEN=0"
call :strlen "!ARG_ADDR!" LEN
if not "!LEN!"=="95" (
    echo [ERROR] Invalid address length - must be 95 characters
    echo   Got: !LEN! chars
    echo   Address: !ARG_ADDR!
    exit /b 1
)

if not exist "%USERPROFILE%\.aime" mkdir "%USERPROFILE%\.aime"

if exist "%ADDRESS_FILE%" (
    set /p OLD=<"%ADDRESS_FILE%"
    if defined OLD (
        echo Replacing previous address:
        echo   OLD: !OLD!
    )
)

echo !ARG_ADDR!> "%ADDRESS_FILE%"
echo   NEW: !ARG_ADDR!
echo.
echo [OK] Address saved to %ADDRESS_FILE%
echo   Run: aime-mine.bat    ^(no args needed^)
exit /b 0

:help
echo aime-set-address.bat - Manage saved Aime wallet address
echo.
echo Usage:
echo   aime-set-address.bat                  Interactive prompt
echo   aime-set-address.bat AQWWPy...        Save address directly
echo   aime-set-address.bat show             Show current saved
echo   aime-set-address.bat clear            Remove saved
echo.
echo File location: %ADDRESS_FILE%
echo The miner ^(aime-mine.bat^) auto-loads this file.
exit /b 0

REM ===== Helper: string length =====
:strlen <string> <result_var>
setlocal enabledelayedexpansion
set "s=%~1"
set "len=0"
:strlen_loop
if defined s (
    set "s=!s:~1!"
    set /a "len+=1"
    goto :strlen_loop
)
endlocal & set "%~2=%len%"
exit /b 0
