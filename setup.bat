@echo off
setlocal EnableDelayedExpansion
title Portable AI USB - Setup
chcp 65001 >nul 2>nul

echo ============================================================
echo              PORTABLE AI USB - SETUP TOOL
echo ============================================================
echo.
echo This tool prepares a USB drive to run local AI models with
echo llama.cpp. Everything stays on the USB - nothing is installed
echo on the host computer.
echo.
echo ============================================================
echo.

REM ============================================================
REM STEP 1: Detect removable (USB) drives
REM ============================================================
echo [1/4] Detecting removable drives...
echo.

set "DRIVECOUNT=0"
for /f "delims=" %%D in ('powershell -NoProfile -Command "Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=2' | Select-Object -ExpandProperty DeviceID"') do (
    set /a DRIVECOUNT+=1
    set "DRIVE[!DRIVECOUNT!]=%%D"
)

if !DRIVECOUNT! equ 0 (
    echo [ERROR] No removable drives detected.
    echo Insert a USB drive and run this script again.
    goto :END
)

echo Available removable drives:
echo.
for /l %%i in (1,1,!DRIVECOUNT!) do (
    echo    %%i.  !DRIVE[%%i]!
)
echo.

:CHOOSE_DRIVE
set "CHOICE="
set /p "CHOICE=Select a drive by number (1-!DRIVECOUNT!): "
if "!CHOICE!"=="" goto :CHOOSE_DRIVE
if !CHOICE! lss 1 goto :CHOOSE_DRIVE
if !CHOICE! gtr !DRIVECOUNT! goto :CHOOSE_DRIVE

set "USBDRIVE=!DRIVE[%CHOICE%]!"
echo.
echo You selected: !USBDRIVE!
echo.

REM ============================================================
REM STEP 1b: Optional format
REM ============================================================
:FORMAT_PROMPT
set "FMT="
set /p "FMT=Format this drive first? ALL DATA WILL BE ERASED (y/N): "
if /i not "!FMT!"=="y" (
    echo Skipping format. Existing data will be kept.
    goto :AFTER_FORMAT
)
echo.
echo *** WARNING: This will erase EVERYTHING on !USBDRIVE! ***
set "CONFIRM="
set /p "CONFIRM=Type YES to confirm format: "
if /i not "!CONFIRM!"=="YES" (
    echo Format cancelled.
    goto :AFTER_FORMAT
)
echo.
echo Formatting !USBDRIVE! as exFAT (quick)...
echo.
format !USBDRIVE! /FS:exFAT /Q /Y
if errorlevel 1 (
    echo [WARNING] Format returned an error - continuing with the
    echo           existing filesystem. If the drive is in use, close
    echo           any open windows and try again.
)
echo.

:AFTER_FORMAT
REM ============================================================
REM STEP 2: Create folder structure
REM ============================================================
echo [2/4] Creating folder structure...
set "AIDIR=!USBDRIVE!\AI_USB"
set "MODELSDIR=!AIDIR!\models"
set "SCRIPTSDIR=!AIDIR!\scripts"
set "LLAMADIR=!AIDIR!\llama_cpp"

if not exist "!MODELSDIR!"    mkdir "!MODELSDIR!"
if not exist "!SCRIPTSDIR!"   mkdir "!SCRIPTSDIR!"
if not exist "!LLAMADIR!"     mkdir "!LLAMADIR!"
echo       !AIDIR!
echo         models\
echo         scripts\
echo         llama_cpp\
echo.

REM ============================================================
REM STEP 3: Download llama.cpp
REM ============================================================
echo [3/4] Download llama.cpp
echo.
echo Which build(s) do you want?
echo    1. CPU only       - smallest, works on every PC
echo    2. CUDA 12 only   - NVIDIA GPUs only
echo    3. Vulkan only    - Intel / AMD / NVIDIA GPUs
echo    4. All three      - RECOMMENDED, maximum compatibility
echo.
set "BUILDC="
set /p "BUILDC=Choose 1/2/3/4 [4]: "
if "!BUILDC!"=="" set "BUILDC=4"
if not "!BUILDC!"=="1" if not "!BUILDC!"=="2" if not "!BUILDC!"=="3" if not "!BUILDC!"=="4" (
    echo Invalid choice, defaulting to 4.
    set "BUILDC=4"
)
echo.

echo Extracting download helper...
set "PSHELPER=%TEMP%\llama_dl_!RANDOM!.ps1"
findstr /b "::PS::" "%~f0" > "%PSHELPER%"
powershell -NoProfile -Command "(Get-Content -LiteralPath '%PSHELPER%') -replace '^::PS::','' | Set-Content -LiteralPath '%PSHELPER%'"

echo Downloading from the official llama.cpp GitHub releases...
echo    (this can take a while - builds are several hundred MB)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PSHELPER%" -BuildChoice "!BUILDC!" -LlamaDir "!LLAMADIR!"
del "%PSHELPER%" >nul 2>nul
echo.

REM Verify llama-server.exe was downloaded
set "SERVERFOUND=0"
for /r "!LLAMADIR!" %%F in (llama-server.exe server.exe) do set "SERVERFOUND=1"
if "!SERVERFOUND!"=="0" (
    echo [ERROR] llama-server.exe was not found after download.
    echo          Check your internet connection and try again.
    goto :END
)
echo [OK] llama-server.exe is present.
echo.

REM ============================================================
REM STEP 4: Copy launcher scripts onto the USB
REM ============================================================
echo [4/4] Copying launcher scripts...
if exist "%~dp0startserver.bat" (
    copy /y "%~dp0startserver.bat" "!SCRIPTSDIR!\startserver.bat" >nul
) else (
    echo [WARNING] startserver.bat was not found next to setup.bat.
    echo            Place it in the same folder as setup.bat and re-run.
)
if exist "%~dp0stopserver.bat" (
    copy /y "%~dp0stopserver.bat" "!SCRIPTSDIR!\stopserver.bat" >nul
) else (
    echo [WARNING] stopserver.bat was not found next to setup.bat.
)
echo       scripts\startserver.bat
echo       scripts\stopserver.bat
echo.

REM ============================================================
REM Done
REM ============================================================
echo ============================================================
echo                    SETUP COMPLETE
echo ============================================================
echo.
echo  Your AI USB is ready at:  !AIDIR!
echo.
echo  NEXT STEPS:
echo   1. Copy .gguf model files into:
echo        !MODELSDIR!
echo   2. Run:
echo        !SCRIPTSDIR!\startserver.bat
echo   3. Your browser opens automatically at:
echo        http://localhost:8080
echo.
echo  Free GGUF models:
echo        https://huggingface.co/models?other=gguf
echo        (search for "Mistral", "Gemma", "Qwen" + "Instruct GGUF")
echo.
echo  To stop the server: run scripts\stopserver.bat
echo  or simply close the server window.
echo.
echo ============================================================

:END
echo.
pause
endlocal
exit /b 0

REM ============================================================
REM  Embedded PowerShell download helper.
REM  Each line below is prefixed with "::PS::" so cmd ignores it.
REM  setup.bat extracts these lines, strips the prefix and runs
REM  the resulting .ps1 to download + extract llama.cpp.
REM ============================================================
::PS::param([string]$BuildChoice, [string]$LlamaDir)
::PS::$ErrorActionPreference = 'Stop'
::PS::$ProgressPreference = 'SilentlyContinue'
::PS::[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
::PS::$api = 'https://api.github.com/repos/ggml-org/llama.cpp/releases/latest'
::PS::Write-Host "Fetching latest llama.cpp release info..."
::PS::$j = Invoke-RestMethod -Uri $api -UseBasicParsing
::PS::Write-Host ("Release tag: " + $j.tag_name)
::PS::$dl = Join-Path $env:TEMP 'llama_dl'
::PS::if (Test-Path $dl) { Remove-Item $dl -Recurse -Force }
::PS::New-Item -ItemType Directory -Path $dl -Force | Out-Null
::PS::function Get-Asset([string]$pattern) {
::PS::    $j.assets | Where-Object { $_.name -like $pattern } | Select-Object -First 1
::PS::}
::PS::function Download-Extract($asset, $dest) {
::PS::    if (-not $asset) { Write-Host "  [WARN] No matching asset found - skipped."; return $false }
::PS::    $zip = Join-Path $dl $asset.name
::PS::    Write-Host ("  Downloading: " + $asset.name)
::PS::    $progressPreference = 'SilentlyContinue'
::PS::    Invoke-WebRequest -Uri $asset.browser_download_url -UseBasicParsing -OutFile $zip
::PS::    Write-Host "  Extracting..."
::PS::    Expand-Archive -Path $zip -DestinationPath $dest -Force
::PS::    return $true
::PS::}
::PS::$cpuA = $null; $cudaMain = $null; $cudaRt = $null; $vulkanA = $null
::PS::if ($BuildChoice -eq '1' -or $BuildChoice -eq '4') {
::PS::    Write-Host "---- CPU build ----"
::PS::    $cpuA = Get-Asset 'llama-*-bin-win-cpu-x64.zip'
::PS::    $cpuDest = Join-Path $LlamaDir 'cpu'
::PS::    New-Item -ItemType Directory -Path $cpuDest -Force | Out-Null
::PS::    Download-Extract $cpuA $cpuDest | Out-Null
::PS::}
::PS::if ($BuildChoice -eq '2' -or $BuildChoice -eq '4') {
::PS::    Write-Host "---- CUDA 12 build (NVIDIA) ----"
::PS::    $cudaDest = Join-Path $LlamaDir 'cuda'
::PS::    New-Item -ItemType Directory -Path $cudaDest -Force | Out-Null
::PS::    $cudaMain = Get-Asset 'llama-*-bin-win-cuda-12*-x64.zip'
::PS::    Download-Extract $cudaMain $cudaDest | Out-Null
::PS::    Write-Host "---- CUDA 12 runtime DLLs (merged into cuda\) ----"
::PS::    $cudaRt = Get-Asset 'cudart-*-bin-win-cuda-12*-x64.zip'
::PS::    Download-Extract $cudaRt $cudaDest | Out-Null
::PS::}
::PS::if ($BuildChoice -eq '3' -or $BuildChoice -eq '4') {
::PS::    Write-Host "---- Vulkan build (Intel / AMD / NVIDIA) ----"
::PS::    $vulkanDest = Join-Path $LlamaDir 'vulkan'
::PS::    New-Item -ItemType Directory -Path $vulkanDest -Force | Out-Null
::PS::    $vulkanA = Get-Asset 'llama-*vulkan-x64.zip'
::PS::    Download-Extract $vulkanA $vulkanDest | Out-Null
::PS::}
::PS::Write-Host "Download step finished."
