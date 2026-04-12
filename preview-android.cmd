@echo off
setlocal

cd /d "%~dp0"

powershell.exe -NoLogo -ExecutionPolicy Bypass -File "%~dp0scripts\preview-android.ps1" %*
set "exit_code=%ERRORLEVEL%"

if not "%exit_code%"=="0" (
  echo.
  echo Preview launcher failed with exit code %exit_code%.
  pause
)

exit /b %exit_code%
