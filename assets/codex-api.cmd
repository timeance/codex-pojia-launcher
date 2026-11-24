@echo off
setlocal
rem Use the Windows PowerShell module paths, even when called from PowerShell 7.
set "PSModulePath="
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0.codex-cli-launcher\codex-api.ps1" -WorkingDirectory "%~dp0." %*
set "codexExit=%errorlevel%"
if not "%codexExit%"=="0" pause
exit /b %codexExit%
