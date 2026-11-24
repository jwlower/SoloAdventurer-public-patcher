@echo off
title Update Solo Adventurer
rem Put this file in your WoW folder (next to Wow.exe) and double-click it whenever Jacob says there's an update.
cd /d "%~dp0"
echo Checking for Solo Adventurer updates...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; $s=(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/jwlower/SoloAdventurer-public-patcher/main/update.ps1'); & ([ScriptBlock]::Create($s)) -GameDir '%~dp0.'"
echo.
pause
