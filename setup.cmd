@echo off
setlocal
for /f "usebackq" %%i in (`where ruby.exe`) do set RUBY_EXE_PATH=%%i
for %%i in ("%RUBY_EXE_PATH%") do set RUBY_EXE_DIR=%%~dpi

set WSL_SETUP_DIR=%~dp0
set WSL_SETUP_RAKEFILE=%WSL_SETUP_DIR%Rakefile

"%RUBY_EXE_PATH%" "%RUBY_EXE_DIR%rake" -f "%WSL_SETUP_RAKEFILE%" %*
endlocal
