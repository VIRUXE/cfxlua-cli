@echo off
setlocal

:: =============================================================================
:: bin/cfxlua.bat  —  CfxLua Standalone Interpreter Wrapper (Windows)
:: =============================================================================

:: ---------------------------------------------------------------------------
:: Resolve directories
:: ---------------------------------------------------------------------------
set "SCRIPT_DIR=%~dp0"
for %%i in ("%SCRIPT_DIR%..") do set "PROJECT_DIR=%%~fi"

:: ---------------------------------------------------------------------------
:: Locate the cfxlua-vm binary
:: ---------------------------------------------------------------------------
if defined CFXLUA_VM (
    set "VM_BIN=%CFXLUA_VM%"
) else if exist "%PROJECT_DIR%\core\lua.exe" (
    set "VM_BIN=%PROJECT_DIR%\core\lua.exe"
) else if exist "%PROJECT_DIR%\vm\build\cfxlua-vm.exe" (
    set "VM_BIN=%PROJECT_DIR%\vm\build\cfxlua-vm.exe"
) else if exist "%PROJECT_DIR%\vm\build\lua.exe" (
    set "VM_BIN=%PROJECT_DIR%\vm\build\lua.exe"
) else (
    where cfxlua-vm >nul 2>nul
    if %errorlevel% equ 0 (
        for /f "delims=" %%i in ('where cfxlua-vm') do set "VM_BIN=%%i"
    ) else (
        where lua5.4 >nul 2>nul
        if %errorlevel% equ 0 (
            for /f "delims=" %%i in ('where lua5.4') do set "VM_BIN=%%i"
            echo [cfxlua] WARNING: cfxlua-vm.exe not found; using system lua5.4 (no LuaGLM extensions) >&2
        ) else (
            where lua >nul 2>nul
            if %errorlevel% equ 0 (
                for /f "delims=" %%i in ('where lua') do set "VM_BIN=%%i"
                echo [cfxlua] WARNING: cfxlua-vm.exe not found; using system lua (no LuaGLM extensions) >&2
            ) else (
                echo [cfxlua] FATAL: no Lua interpreter found. >&2
                exit /b 1
            )
        )
    )
)

:: ---------------------------------------------------------------------------
:: Locate the runtime directory
:: ---------------------------------------------------------------------------
if defined CFXLUA_RUNTIME (
    set "RUNTIME_DIR=%CFXLUA_RUNTIME%"
) else (
    set "RUNTIME_DIR=%PROJECT_DIR%\runtime"
)

set "BOOTSTRAP=%RUNTIME_DIR%\bootstrap.lua"

if not exist "%BOOTSTRAP%" (
    echo [cfxlua] FATAL: bootstrap.lua not found at "%BOOTSTRAP%" >&2
    exit /b 1
)

:: ---------------------------------------------------------------------------
:: Handle special flags
:: ---------------------------------------------------------------------------
if "%~1"=="--version" (
    echo CfxLua 1.1.0  -  (c) 2026 Polaris Naz
    echo LuaGLM 5.4  -  Cfx.re
    exit /b 0
)
if "%~1"=="-v" (
    echo CfxLua 1.1.0  -  (c) 2026 Polaris Naz
    echo LuaGLM 5.4  -  Cfx.re
    exit /b 0
)

if "%~1"=="--help" goto :usage
if "%~1"=="-h" goto :usage
if "%~1"=="" goto :usage

:: ---------------------------------------------------------------------------
:: Execute the VM
:: ---------------------------------------------------------------------------
:: Set the bootstrap path for the VM
set "__cfx_bootstrapPath=%RUNTIME_DIR:\=/%"

"%VM_BIN%" "%BOOTSTRAP:\=/%" %*
exit /b %errorlevel%

:usage
echo Usage: cfxlua ^<script.lua^> [arg1 arg2 ...]
echo        cfxlua --version
echo        cfxlua --help
exit /b 0
