@echo off
setlocal
cd /d "%~dp0"
odin build . -out:tsb.exe
