@echo off
setlocal

:: =============================================================================
:: install.bat  —  CfxLua CLI Installer (Windows)
:: =============================================================================

set "INSTALL_DIR=C:\Program Files\cfxlua"
set "SCRIPT_DIR=%~dp0"

echo Installing CfxLua CLI...

:: 1. Create installation directory
if not exist "%INSTALL_DIR%\bin" mkdir "%INSTALL_DIR%\bin"
if not exist "%INSTALL_DIR%\runtime" mkdir "%INSTALL_DIR%\runtime"
if not exist "%INSTALL_DIR%\vm\build" mkdir "%INSTALL_DIR%\vm\build"

:: 2. Copy files
echo Copying files to %INSTALL_DIR%...
copy /Y "%SCRIPT_DIR%bin\cfxlua.bat" "%INSTALL_DIR%\bin\"
xcopy /E /I /Y "%SCRIPT_DIR%runtime" "%INSTALL_DIR%\runtime"

:: Find the VM binary
if exist "%SCRIPT_DIR%cfxlua-vm.exe" (
    :: Release package mode
    copy /Y "%SCRIPT_DIR%cfxlua-vm.exe" "%INSTALL_DIR%\vm\build\"
) else if exist "%SCRIPT_DIR%core\lua.exe" (
    :: Source repo mode
    copy /Y "%SCRIPT_DIR%core\lua.exe" "%INSTALL_DIR%\vm\build\cfxlua-vm.exe"
) else if exist "%SCRIPT_DIR%build\lua.exe" (
    :: Source repo mode
    copy /Y "%SCRIPT_DIR%build\lua.exe" "%INSTALL_DIR%\vm\build\cfxlua-vm.exe"
)

:: 3. Update PATH (User level)
echo Adding to PATH...
setx PATH "%PATH%;%INSTALL_DIR%\bin"

echo -----------------------------------------------------------------------
echo Success! CfxLua CLI v1.1.1 installed.
echo NOTE: You may need to restart your terminal for PATH changes to take effect.
echo Usage: cfxlua ^<script.lua^>
echo -----------------------------------------------------------------------
pause
