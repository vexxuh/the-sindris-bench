@echo off
setlocal
cd /d "%~dp0\.."
odin build cli -out:cli\tsb-cli.exe
