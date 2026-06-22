@echo off
setlocal EnableDelayedExpansion
title Portable AI USB - Server
chcp 65001 >nul 2>nul

REM ============================================================
REM Resolve install directory relative to THIS script.
REM This script lives in  AI_USB\scripts\startserver.bat
REM so  AI_USB  is one level up. Using relative paths means the
REM USB works no matter which drive letter it is assigned.
REM ============================================================
set "SCRIPTDIR=%~dp0"
set "SCRIPTDIR=%SCRIPTDIR:~0,-1%"
pushd "%SCRIPTDIR%\.." >nul 2>nul
set "AIDIR=%CD%"
popd >nul

set "MODELSDIR=%AIDIR%\models"
set "LLAMADIR=%AIDIR%\llama_cpp"
set "PORT=8080"

echo ============================================================
echo            PORTABLE AI USB - SERVER LAUNCHER
echo ============================================================
echo.
echo  Install dir : %AIDIR%
echo  Models dir  : %MODELSDIR%
echo  llama.cpp   : %LLAMADIR%
echo.

REM ============================================================
REM STEP 1: Locate llama-server.exe (and tell CUDA vs CPU build)
REM ============================================================
if not exist "%LLAMADIR%" (
    echo [ERROR] llama_cpp folder not found.
    echo          Run setup.bat first to prepare the USB drive.
    goto :END
)

set "CPU_EXE="
set "CUDA_EXE="
set "VULKAN_EXE="
REM for /r yields a phantom path for every folder, so we must
REM guard each iteration with "if exist" to skip non-matches.
for /r "%LLAMADIR%" %%F in (llama-server.exe server.exe) do (
    if exist "%%~fF" (
        set "FP=%%~dpF"
        set "FEXE=%%~fF"
        set "FNAME=%%~nxF"
        set "ISCUDA=0"
        set "ISVULKAN=0"
        for /f "delims=" %%D in ('dir /b "!FP!cudart64_*.dll" 2^>nul') do set "ISCUDA=1"
        for /f "delims=" %%D in ('dir /b "!FP!ggml-vulkan.dll" 2^>nul') do set "ISVULKAN=1"
        if "!ISCUDA!"=="1" (
            if not defined CUDA_EXE set "CUDA_EXE=!FEXE!"
            if "!FNAME!"=="llama-server.exe" set "CUDA_EXE=!FEXE!"
        ) else if "!ISVULKAN!"=="1" (
            if not defined VULKAN_EXE set "VULKAN_EXE=!FEXE!"
            if "!FNAME!"=="llama-server.exe" set "VULKAN_EXE=!FEXE!"
        ) else (
            if not defined CPU_EXE set "CPU_EXE=!FEXE!"
            if "!FNAME!"=="llama-server.exe" set "CPU_EXE=!FEXE!"
        )
    )
)

if not defined CUDA_EXE if not defined CPU_EXE if not defined VULKAN_EXE (
    echo [ERROR] llama-server.exe was not found under llama_cpp.
    echo          Run setup.bat again to download llama.cpp.
    goto :END
)

echo  Available engines:
if defined CPU_EXE    echo    - CPU    : !CPU_EXE!
if defined CUDA_EXE   echo    - CUDA   : !CUDA_EXE!
if defined VULKAN_EXE echo    - Vulkan : !VULKAN_EXE!
echo.

REM ============================================================
REM STEP 2: Scan models folder for .gguf files
REM ============================================================
if not exist "%MODELSDIR%" (
    echo [ERROR] models folder not found at:
    echo          %MODELSDIR%
    echo          Run setup.bat first.
    goto :END
)

set "MODELCOUNT=0"
for %%M in ("%MODELSDIR%\*.gguf") do (
    set /a MODELCOUNT+=1
    set "MODEL[!MODELCOUNT!]=%%~fM"
    set "MODELNAME[!MODELCOUNT!]=%%~nxM"
)

if !MODELCOUNT! equ 0 (
    echo [ERROR] No .gguf model files found in:
    echo          %MODELSDIR%
    echo.
    echo          Copy GGUF model files into that folder, for example:
    echo            Mistral-7B-Instruct.gguf
    echo            Gemma-3.gguf
    echo            Qwen3-8B.gguf
    echo.
    echo          Free models: https://huggingface.co/models?other=gguf
    goto :END
)

echo  Available models:
echo.
REM NOTE: must use for /l with %%i here. A goto loop with
REM !MODELNAME[!IDX!]! would break (nested delayed expansion
REM is not supported by cmd). %%i is substituted before
REM delayed expansion runs, so !MODELNAME[%%i]! works.
for /l %%i in (1,1,!MODELCOUNT!) do (
    echo    %%i. !MODELNAME[%%i]!
)
echo.

:CHOOSE_MODEL
set "MCHOICE="
set /p "MCHOICE=Select a model by number (1-!MODELCOUNT!): "
REM Trim leading/trailing spaces (defensive - tolerates stray input)
:TRIM_MCHOICE
if "!MCHOICE!"=="" goto :CHOOSE_MODEL
if "!MCHOICE:~-1!"==" " set "MCHOICE=!MCHOICE:~0,-1!" & goto :TRIM_MCHOICE
if "!MCHOICE:~0,1!"==" " set "MCHOICE=!MCHOICE:~1!" & goto :TRIM_MCHOICE
if "!MCHOICE!"=="" goto :CHOOSE_MODEL
if !MCHOICE! lss 1 goto :CHOOSE_MODEL
if !MCHOICE! gtr !MODELCOUNT! goto :CHOOSE_MODEL

set "SELECTEDMODEL=!MODEL[%MCHOICE%]!"
set "SELECTEDNAME=!MODELNAME[%MCHOICE%]!"
if "!SELECTEDMODEL!"=="" (
    echo  Invalid selection - please try again.
    goto :CHOOSE_MODEL
)
echo.
echo  Selected: !SELECTEDNAME!
echo.

REM ============================================================
REM STEP 3: Detect GPU
REM ============================================================
echo  Detecting GPU...
set "HAS_NVIDIA=0"
set "HAS_ANY_GPU=0"
set "GPUNAMES="
for /f "delims=" %%G in ('powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name }"') do (
    set "GPUNAMES=!GPUNAMES!%%G; "
    set "HAS_ANY_GPU=1"
    echo %%G | findstr /i /c:"NVIDIA" >nul && set "HAS_NVIDIA=1"
)
echo  GPUs: !GPUNAMES!
if "!HAS_NVIDIA!"=="1" (
    echo  -^> NVIDIA GPU detected.
) else if "!HAS_ANY_GPU!"=="1" (
    echo  -^> Non-NVIDIA GPU detected. Vulkan can accelerate it.
) else (
    echo  -^> No GPU detected.
)
echo.

REM ============================================================
REM STEP 4: Determine best GPU engine and ask user
REM ============================================================
set "USEGPU=0"
set "GPU_ENGINE="
set "GPU_LABEL="

REM Priority: NVIDIA+CUDA > Vulkan (any GPU) > none
if "!HAS_NVIDIA!"=="1" (
    if defined CUDA_EXE (
        set "GPU_ENGINE=!CUDA_EXE!"
        set "GPU_LABEL=NVIDIA CUDA"
    ) else if defined VULKAN_EXE (
        set "GPU_ENGINE=!VULKAN_EXE!"
        set "GPU_LABEL=Vulkan"
    )
) else if "!HAS_ANY_GPU!"=="1" (
    if defined VULKAN_EXE (
        set "GPU_ENGINE=!VULKAN_EXE!"
        set "GPU_LABEL=Vulkan"
    )
)

if defined GPU_ENGINE (
    :GPU_PROMPT
    set "GYES="
    set /p "GYES=Use GPU acceleration (!GPU_LABEL!)? (Y/n): "
    if /i "!GYES!"=="n" (
        set "USEGPU=0"
    ) else if /i "!GYES!"=="y" (
        set "USEGPU=1"
    ) else if "!GYES!"=="" (
        set "USEGPU=1"
    ) else (
        goto :GPU_PROMPT
    )
) else (
    if "!HAS_ANY_GPU!"=="1" (
        echo  No GPU-accelerated build available for your GPU.
        echo  Re-run setup.bat and choose Vulkan ^(option 3^) or All ^(option 4^).
    )
)

REM ============================================================
REM STEP 5: Choose the engine and parameters
REM ============================================================
set "USESERVER="
set "ENGINE_LABEL="

if "!USEGPU!"=="1" (
    set "USESERVER=!GPU_ENGINE!"
    set "ENGINE_LABEL=!GPU_LABEL!"
)

if not defined USESERVER (
    if defined CPU_EXE (
        set "USESERVER=!CPU_EXE!"
        set "ENGINE_LABEL=CPU"
    ) else if defined VULKAN_EXE (
        REM Vulkan build can fall back to CPU internally if no Vulkan device
        set "USESERVER=!VULKAN_EXE!"
        set "ENGINE_LABEL=Vulkan (CPU fallback)"
        set "USEGPU=0"
    ) else (
        echo [ERROR] No compatible engine found for this computer.
        echo          The CUDA build cannot run without an NVIDIA GPU,
        echo          and no CPU or Vulkan build is available.
        echo.
        echo          Re-run setup.bat and choose:
        echo            - CPU only ^(option 1^), or
        echo            - Vulkan ^(option 3^), or
        echo            - All three ^(option 4^)
        goto :END
    )
)

REM Detect CPU threads (physical cores, fallback to logical)
set "CORES=4"
for /f "delims=" %%T in ('powershell -NoProfile -Command "$p=(Get-CimInstance Win32_Processor | Measure-Object NumberOfCores -Sum).Sum; if($p){$p}else{(Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors}"') do set "CORES=%%T"
if "!CORES!"=="" set "CORES=4"

set /a USETHREADS=CORES
if !USEGPU! equ 0 (
    REM CPU mode: leave one core free for the system
    set /a USETHREADS=CORES - 1
    if !USETHREADS! lss 1 set "USETHREADS=1"
)

REM Context size (safe default; edit this line to change it)
set "CTX=4096"

REM Build the command line (inner quotes are preserved by set "...")
set "PARAMS=-m "!SELECTEDMODEL!" --host 127.0.0.1 --port !PORT!"
if !USEGPU! equ 1 (
    set "PARAMS=!PARAMS! -ngl 99"
) else (
    set "PARAMS=!PARAMS! -ngl 0 -t !USETHREADS!"
)
set "PARAMS=!PARAMS! -c !CTX!"
set "PARAMS=!PARAMS! --jinja"
set "PARAMS=!PARAMS! --flash-attn on"

REM ============================================================
REM STEP 6: Launch
REM ============================================================
echo ============================================================
echo  Starting llama-server...
echo    Model      : !SELECTEDNAME!
echo    Engine     : !ENGINE_LABEL!
if !USEGPU! equ 1 (
    echo    GPU layers : 99 (all layers on GPU^)
) else (
    echo    Threads    : !USETHREADS!
    echo    GPU layers : 0  (CPU only^)
)
echo    Context    : !CTX! tokens
echo    Server URL : http://localhost:!PORT!
echo ============================================================
echo.
echo  A browser window will open automatically in a few seconds.
echo  To stop the server: close this window OR run stopserver.bat
echo.

REM Open the browser after the server has had time to start.
REM Done in a hidden detached process so it does not block launch.
start "" /b powershell -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Seconds 6; Start-Process 'http://localhost:!PORT!'"

REM Run the server from its own folder so DLLs resolve correctly.
pushd "!USESERVER!\.." >nul 2>nul
"!USESERVER!" !PARAMS!
popd >nul

:END
echo.
pause
endlocal
exit /b 0
