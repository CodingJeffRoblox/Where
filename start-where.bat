@echo off
rem ==========================================================================
rem  Where - one-click setup and launch for Windows
rem
rem  Checks for everything Where needs, installs what is missing, builds the
rem  app, and starts it. Safe to run again at any time: steps that are already
rem  done are skipped.
rem
rem    start-where.bat         set up, build and open the desktop app
rem    start-where.bat cli     set up and open the command-line version only
rem    start-where.bat help    show this help
rem
rem  Installs if missing (with your approval where Windows asks):
rem    - Git                          via winget
rem    - Visual Studio C++ Build Tools via winget  (needed by Rust and Flutter)
rem    - Rust                         via rustup
rem    - Flutter SDK (stable)         into %LOCALAPPDATA%\where-tools\flutter
rem ==========================================================================

setlocal EnableExtensions
title Where - setup and launch
cd /d "%~dp0"

set "ROOT=%~dp0"
set "APP=%ROOT%apps\where_flutter"
set "FLUTTER_HOME=%LOCALAPPDATA%\where-tools\flutter"
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "PATH=%USERPROFILE%\.cargo\bin;%FLUTTER_HOME%\bin;%ProgramFiles%\Git\cmd;%PATH%"
set "MODE=%~1"
set "ARCH=x64"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH=arm64"

echo.
echo   WHERE - find what you're looking for
echo   ------------------------------------
echo.

if /i "%MODE%"=="help" goto :help
if /i "%MODE%"=="-h" goto :help
if /i "%MODE%"=="/?" goto :help

if not exist "%ROOT%Cargo.toml" (
  echo [x] Run this file from the Where folder - Cargo.toml was not found next to it.
  goto :fail
)

call :ensure_git || goto :fail
call :ensure_buildtools || goto :fail
call :ensure_rust || goto :fail

if /i "%MODE%"=="cli" goto :run_cli

call :ensure_flutter || goto :fail
call :ensure_devmode
call :build_core || goto :fail
call :build_app || goto :cli_fallback
call :launch
goto :done


rem ---------------------------------------------------------------- checks --

:ensure_git
where git >nul 2>&1 && (echo [ok] Git & exit /b 0)
echo [..] Git not found - installing...
call :require_winget || exit /b 1
winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
where git >nul 2>&1 || (echo [x] Git was installed but is not on PATH yet. Close this window and run start-where.bat again. & exit /b 1)
echo [ok] Git installed
exit /b 0

:ensure_buildtools
call :has_msvc && (echo [ok] C++ build tools & exit /b 0)
echo [..] C++ build tools not found - installing Visual Studio Build Tools.
echo      This is a large download - 2 to 5 GB - and can take a while.
echo      Approve the administrator prompt if Windows shows one.
call :require_winget || exit /b 1
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --source winget --accept-package-agreements --accept-source-agreements --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
call :has_msvc && (echo [ok] C++ build tools installed & exit /b 0)
echo [x] The C++ build tools are still missing.
echo     If Visual Studio or its Build Tools were already installed, open
echo     "Visual Studio Installer", click Modify, tick
echo     "Desktop development with C++", install, then run this file again.
exit /b 1

:has_msvc
if not exist "%VSWHERE%" exit /b 1
set "VSPATH="
for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSPATH=%%i"
if defined VSPATH exit /b 0
exit /b 1

:ensure_rust
where cargo >nul 2>&1 && (echo [ok] Rust & exit /b 0)
echo [..] Rust not found - installing via rustup...
set "RUSTUP_URL=https://win.rustup.rs/x86_64"
if /i "%ARCH%"=="arm64" set "RUSTUP_URL=https://win.rustup.rs/aarch64"
curl -sSfL -o "%TEMP%\rustup-init.exe" "%RUSTUP_URL%" || (echo [x] Could not download rustup. Check your internet connection. & exit /b 1)
"%TEMP%\rustup-init.exe" -y --default-toolchain stable --profile minimal || (echo [x] Rust install failed. & exit /b 1)
where cargo >nul 2>&1 || (echo [x] Rust was installed but cargo is not on PATH yet. Close this window and run again. & exit /b 1)
echo [ok] Rust installed
exit /b 0

:ensure_flutter
where flutter >nul 2>&1 && goto :flutter_ready
if exist "%FLUTTER_HOME%\bin\flutter.bat" goto :flutter_add_path
echo [..] Flutter not found - downloading the stable SDK to
echo      %FLUTTER_HOME%
git clone --depth 1 -b stable https://github.com/flutter/flutter.git "%FLUTTER_HOME%" || (echo [x] Could not download Flutter. & exit /b 1)
:flutter_add_path
call :add_user_path "%FLUTTER_HOME%\bin"
:flutter_ready
echo [..] Preparing Flutter - the first run downloads extra tools and can take a few minutes...
call flutter config --no-analytics >nul 2>&1
call flutter config --enable-windows-desktop >nul 2>&1
call flutter --version >nul 2>&1 || (echo [x] Flutter is installed but failed to start. Run "flutter doctor" to see why. & exit /b 1)
echo [ok] Flutter
exit /b 0

:ensure_devmode
rem Flutter plugins on Windows need symlink support, which Developer Mode provides.
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense 2>nul | find "0x1" >nul && (echo [ok] Developer Mode & exit /b 0)
echo [!] Windows Developer Mode is off. The app build needs it.
echo     Settings is opening now: switch on "Developer Mode", then come back
echo     to this window and press any key.
start "" ms-settings:developers
pause >nul
exit /b 0


rem ----------------------------------------------------------------- build --

:build_core
echo [..] Building the Where core - first build takes a few minutes...
cargo build --release -p where_ffi -p where_cli || (echo [x] The Rust build failed - see the errors above. & exit /b 1)
echo [ok] Core built
exit /b 0

:build_app
pushd "%APP%"
if not exist "windows\runner" (
  echo [..] Creating Windows project files...
  call flutter create --platforms=windows --project-name where_flutter . >nul || goto :build_app_failed
)
echo [..] Fetching app packages...
call flutter pub get || goto :build_app_failed
echo [..] Building the desktop app...
call flutter build windows --release || goto :build_app_failed
popd
set "EXE_DIR=%APP%\build\windows\%ARCH%\runner\Release"
if not exist "%EXE_DIR%\where_flutter.exe" (
  echo [x] The app build finished but where_flutter.exe was not found.
  exit /b 1
)
copy /y "%ROOT%target\release\where_ffi.dll" "%EXE_DIR%\" >nul || (echo [x] Could not copy where_ffi.dll next to the app. & exit /b 1)
echo [ok] App built
exit /b 0

:build_app_failed
popd
exit /b 1


rem ---------------------------------------------------------------- launch --

:launch
echo [ok] Starting Where...
start "" "%EXE_DIR%\where_flutter.exe"
echo.
echo   Where is running. Next time, open it directly from:
echo   %EXE_DIR%\where_flutter.exe
echo   or run start-where.bat again to rebuild with the latest code.
timeout /t 8 >nul
exit /b 0

:cli_fallback
echo.
echo [!] The desktop app did not build - see the errors above.
echo     Opening the command-line version instead so you can still use Where.
echo.

:run_cli
if not exist "%ROOT%target\release\where-cli.exe" (
  echo [..] Building the command-line version...
  cargo build --release -p where_cli || goto :fail
)
set "PATH=%ROOT%target\release;%PATH%"
echo   Where command line is ready. Try:
echo     where-cli demo --db "%TEMP%\where-demo.db"
echo     where-cli add project Website
echo     where-cli index "%USERPROFILE%\Documents" -p Website
echo     where-cli search website
echo     where-cli --help
echo.
cmd /k
goto :done


rem --------------------------------------------------------------- helpers --

:require_winget
where winget >nul 2>&1 && exit /b 0
echo [x] winget is not available. Install "App Installer" from the Microsoft Store:
echo     https://apps.microsoft.com/detail/9NBLGGH4NNS1
echo     then run start-where.bat again.
start "" "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
exit /b 1

:add_user_path
rem Persist a folder on the user PATH without the 1024-character setx limit.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$d='%~1'; $p=[Environment]::GetEnvironmentVariable('Path','User'); if(-not $p){$p=''}; if(($p -split ';') -notcontains $d){[Environment]::SetEnvironmentVariable('Path',(($p.TrimEnd(';')+';'+$d).TrimStart(';')),'User')}" >nul 2>&1
exit /b 0

:help
echo   start-where.bat         set up, build and open the desktop app
echo   start-where.bat cli     set up and open the command-line version only
echo   start-where.bat help    show this help
echo.
echo   Missing tools - Git, C++ Build Tools, Rust, Flutter - are installed
echo   automatically. Run it again any time to rebuild with the latest code.
goto :done

:fail
echo.
echo   Setup stopped. Fix the problem above, then run start-where.bat again.
echo.
pause
endlocal
exit /b 1

:done
endlocal
exit /b 0
