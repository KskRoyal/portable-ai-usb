@echo off
setlocal EnableDelayedExpansion
title Portable AI USB - Stop Server
chcp 65001 >nul 2>nul

echo ============================================================
echo            PORTABLE AI USB - STOP SERVER
echo ============================================================
echo.
echo  Looking for running llama-server processes...
echo.

REM Count running llama-server.exe instances
set "RUNNING=0"
for /f %%N in ('tasklist /fi "imagename eq llama-server.exe" 2^>nul ^| find /c "llama-server.exe"') do set "RUNNING=%%N"

if "!RUNNING!"=="0" (
    echo  No llama-server.exe process is currently running.
    echo.
    goto :CLOSE_LAUNCHER
)

echo  Found !RUNNING! running instance(s).
echo.

REM Step 1: Try a graceful termination first (lets the server
REM         flush files and close sockets cleanly).
echo  [1/2] Sending graceful stop request...
taskkill /im llama-server.exe >nul 2>nul

REM Give the process a few seconds to exit on its own.
timeout /t 3 /nobreak >nul

REM Step 2: Check if it is still alive and force-kill if needed.
set "STILL=0"
for /f %%N in ('tasklist /fi "imagename eq llama-server.exe" 2^>nul ^| find /c "llama-server.exe"') do set "STILL=%%N"

if "!STILL!"=="0" (
    echo        llama-server.exe stopped cleanly.
) else (
    echo        Process did not exit gracefully.
    echo  [2/2] Force stopping llama-server.exe...
    taskkill /f /im llama-server.exe >nul 2>nul
    timeout /t 1 /nobreak >nul
    set "STILL=0"
    for /f %%N in ('tasklist /fi "imagename eq llama-server.exe" 2^>nul ^| find /c "llama-server.exe"') do set "STILL=%%N"
    if "!STILL!"=="0" (
        echo        llama-server.exe has been force-stopped.
    ) else (
        echo        [WARNING] llama-server.exe could not be stopped.
        echo                  Close its window manually.
    )
)

:CLOSE_LAUNCHER
REM ============================================================
REM Step 3: Close the startserver.bat launcher window(s).
REM The launcher runs in a cmd.exe whose command line contains
REM "startserver.bat". Finding and stopping that cmd.exe closes
REM the launcher window. This does NOT affect this stopserver
REM window (its command line contains "stopserver.bat").
REM ============================================================
echo.
echo  Closing launcher window(s)...
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'cmd.exe' -and $_.CommandLine -like '*startserver.bat*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
echo        Launcher window(s) closed.

echo.
echo ============================================================
echo  Done. The local AI server has been stopped.
echo  You can safely remove the USB drive now.
echo ============================================================
echo.
pause
endlocal
exit /b 0
