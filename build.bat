@echo off
setlocal
cd /d "%~dp0"
odin build gui -out:tsb.exe
