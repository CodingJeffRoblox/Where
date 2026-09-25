@echo off
rem ==========================================================================
rem  Where - make a GitHub Release from files you've already built
rem
rem    make-release.bat              version from Cargo.toml
rem    make-release.bat 0.4.0        a specific version
rem    make-release.bat -Fetch       also add the Mac/Linux files GitHub built
rem    make-release.bat -Draft       publish as a draft you can review first
rem
rem  Put files built on other computers (Mac .dmg, Linux .AppImage/.deb/...)
rem  in the release-files folder and they are attached too.
rem  Notes come from docs\releases\v<version>.md (first "# line" = title).
rem ==========================================================================
setlocal
cd /d "%~dp0"
title Where - release
rem A first argument like 0.4.0 or v0.4.0 is the version.
set "ARGS=%*"
echo(%~1| findstr /r "^v*[0-9][0-9.]*$" >nul && set "ARGS=-Version %*"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\make-release.ps1" %ARGS%
echo.
pause
