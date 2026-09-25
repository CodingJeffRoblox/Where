@echo off
rem ==========================================================================
rem  Where - one-click setup and launch for Windows
rem
rem    start-where.bat           set up (if needed), build, and open Where
rem    start-where.bat update    get the latest code from GitHub first
rem    start-where.bat cli       open the command-line version instead
rem    start-where.bat help      show help
rem
rem  Anything missing is installed automatically:
rem    Git, Visual Studio C++ Build Tools, Rust, Flutter.
rem  Detailed output goes to %LOCALAPPDATA%\where-tools\setup-log.txt
rem ==========================================================================

setlocal EnableExtensions
cd /d "%~dp0"
title Where

rem ---- colours (Windows 10+ terminals understand these) --------------------
for /f %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"
set "C_OK=%ESC%[92m"
set "C_WARN=%ESC%[93m"
set "C_ERR=%ESC%[91m"
set "C_DIM=%ESC%[90m"
set "C_HEAD=%ESC%[1;97m"
set "C_ACC=%ESC%[96m"
set "C_END=%ESC%[0m"

rem ---- paths ----------------------------------------------------------------
set "ROOT=%~dp0"
set "APP=%ROOT%apps\where_flutter"
set "TOOLS=%LOCALAPPDATA%\where-tools"
set "FLUTTER_HOME=%TOOLS%\flutter"
set "LOG=%TOOLS%\setup-log.txt"
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "PATH=%USERPROFILE%\.cargo\bin;%FLUTTER_HOME%\bin;%ProgramFiles%\Git\cmd;%PATH%"
set "ARCH=x64"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH=arm64"
set "EXE_DIR=%APP%\build\windows\%ARCH%\runner\Release"
set "EXE=%EXE_DIR%\Where.exe"
set "MODE=%~1"

if not exist "%TOOLS%" mkdir "%TOOLS%" >nul 2>&1
echo ===== %DATE% %TIME% - start-where.bat %MODE% ===== >> "%LOG%"

cls
echo.
echo   %C_HEAD%W H E R E%C_END%   %C_DIM%find what you're looking for%C_END%
echo   %C_DIM%---------------------------------------------------%C_END%
echo.

if /i "%MODE%"=="help" goto :help
if /i "%MODE%"=="-h" goto :help
if /i "%MODE%"=="/?" goto :help

if not exist "%ROOT%Cargo.toml" (
  call :err "Put this file in the Where folder, next to Cargo.toml, and run it from there."
  goto :fail
)

rem ---- 1. tools ---------------------------------------------------------------
call :step 1 "Checking what's installed"
call :ensure_git || goto :fail
if /i "%MODE%"=="update" call :update_code
call :ensure_buildtools || goto :fail
call :ensure_rust || goto :fail
if /i "%MODE%"=="cli" goto :run_cli
call :ensure_flutter || goto :fail

rem ---- 2. windows settings -------------------------------------------------
call :step 2 "Checking Windows settings"
call :ensure_devmode

rem ---- 3. engine ---------------------------------------------------------------
call :step 3 "Building the search engine"
call :build_core || goto :fail

rem ---- 4. app ------------------------------------------------------------------
call :step 4 "Building the app"
call :build_app || goto :cli_fallback

rem ---- 5. launch ---------------------------------------------------------------
call :step 5 "Starting Where"
call :launch
goto :done


rem =============================================================== checks ====

:ensure_git
where git >nul 2>&1 && (call :ok "Git" & exit /b 0)
call :work "Installing Git..."
call :require_winget || exit /b 1
winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements >> "%LOG%" 2>&1
where git >nul 2>&1 || (call :err "Git was installed but Windows hasn't picked it up yet. Close this window and run start-where.bat again." & exit /b 1)
call :ok "Git installed"
exit /b 0

:ensure_buildtools
call :has_msvc && (call :ok "C++ build tools" & exit /b 0)
call :work "Installing Visual Studio C++ Build Tools..."
call :note "Large download - 2 to 5 GB - usually 10 to 30 minutes. Approve the admin prompt if one appears."
call :require_winget || exit /b 1
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --source winget --accept-package-agreements --accept-source-agreements --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended" >> "%LOG%" 2>&1
call :has_msvc && (call :ok "C++ build tools installed" & exit /b 0)
call :err "The C++ build tools are still missing."
call :note "If Visual Studio is already installed: open Visual Studio Installer, click Modify,"
call :note "tick 'Desktop development with C++', install, then run this file again."
exit /b 1

:has_msvc
if not exist "%VSWHERE%" exit /b 1
set "VSPATH="
for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSPATH=%%i"
if defined VSPATH exit /b 0
exit /b 1

:ensure_rust
where cargo >nul 2>&1 && (call :ok "Rust" & exit /b 0)
call :work "Installing Rust..."
set "RUSTUP_URL=https://win.rustup.rs/x86_64"
if /i "%ARCH%"=="arm64" set "RUSTUP_URL=https://win.rustup.rs/aarch64"
curl -sSfL -o "%TEMP%\rustup-init.exe" "%RUSTUP_URL%" >> "%LOG%" 2>&1 || (call :err "Could not download Rust. Check your internet connection." & exit /b 1)
"%TEMP%\rustup-init.exe" -y --default-toolchain stable --profile minimal >> "%LOG%" 2>&1 || (call :err "Rust install failed." & exit /b 1)
where cargo >nul 2>&1 || (call :err "Rust was installed but Windows hasn't picked it up yet. Close this window and run again." & exit /b 1)
call :ok "Rust installed"
exit /b 0

:ensure_flutter
where flutter >nul 2>&1 && goto :flutter_ready
if exist "%FLUTTER_HOME%\bin\flutter.bat" goto :flutter_add_path
call :work "Downloading Flutter..."
git clone --depth 1 -b stable https://github.com/flutter/flutter.git "%FLUTTER_HOME%" >> "%LOG%" 2>&1 || (call :err "Could not download Flutter." & exit /b 1)
:flutter_add_path
call :add_user_path "%FLUTTER_HOME%\bin"
:flutter_ready
if not exist "%TOOLS%\flutter-ready" (
  call :work "Preparing Flutter for first use - a few minutes..."
  call flutter config --no-analytics >> "%LOG%" 2>&1
  call flutter config --enable-windows-desktop >> "%LOG%" 2>&1
)
call flutter --version >> "%LOG%" 2>&1 || (call :err "Flutter is installed but failed to start. Run 'flutter doctor' to see why." & exit /b 1)
echo ready> "%TOOLS%\flutter-ready"
call :ok "Flutter"
exit /b 0

:ensure_devmode
rem Flutter plugins on Windows need symlink support, which Developer Mode provides.
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense 2>nul | find "0x1" >nul && (call :ok "Developer Mode is on" & exit /b 0)
call :warn "Windows Developer Mode is off - the app build needs it."
call :note "Settings is opening: switch on 'Developer Mode', then come back here and press any key."
start "" ms-settings:developers
pause >nul
exit /b 0

:update_code
if not exist "%ROOT%.git" (
  call :warn "This folder isn't a git clone, so it can't update itself. Skipping."
  exit /b 0
)
call :work "Getting the latest code..."
git -C "%ROOT%." pull --ff-only >> "%LOG%" 2>&1 && (call :ok "Code is up to date" & exit /b 0)
call :warn "Couldn't update automatically - you may have local changes. Continuing with the current code."
exit /b 0


rem ================================================================ build ====

:build_core
call :work "Compiling - the first build takes a few minutes, later ones seconds..."
cargo build --release -p where_ffi -p where_cli >> "%LOG%" 2>&1 || (call :err "The engine didn't build." & exit /b 1)
call :ok "Search engine ready"
exit /b 0

:build_app
pushd "%APP%"
if not exist "windows\runner" (
  call :work "Creating Windows project files..."
  call flutter create --platforms=windows --project-name where_flutter . >> "%LOG%" 2>&1 || goto :build_app_failed
)
call :work "Getting app packages..."
call flutter pub get >> "%LOG%" 2>&1 || goto :build_app_failed
rem A build cache from an older version of the app can point at files that
rem no longer exist - e.g. after the program was renamed. Clear it if so.
set "CMAKE_CACHE=build\windows\%ARCH%\CMakeCache.txt"
if exist "%CMAKE_CACHE%" (
  findstr /c:"TARGET_FILE_DIR:Where>" "%CMAKE_CACHE%" >nul 2>&1 || (
    call :work "Clearing an out-of-date build..."
    rmdir /s /q "build\windows" >nul 2>&1
  )
)
call :work "Compiling the app - a few minutes the first time..."
call flutter build windows --release >> "%LOG%" 2>&1 && goto :build_app_done
rem One automatic retry from a clean slate fixes most stale-cache problems.
call :warn "First attempt failed - clearing the build folder and trying once more..."
rmdir /s /q "build\windows" >nul 2>&1
call flutter build windows --release >> "%LOG%" 2>&1 || goto :build_app_failed
:build_app_done
popd
if not exist "%EXE%" (
  call :err "The app built but Where.exe wasn't where it should be."
  exit /b 1
)
copy /y "%ROOT%target\release\where_ffi.dll" "%EXE_DIR%\" >nul || (call :err "Couldn't place where_ffi.dll next to the app." & exit /b 1)
call :ok "App ready"
exit /b 0

:build_app_failed
popd
call :err "The app didn't build."
call :show_log_tail
exit /b 1


rem =============================================================== launch ====

:launch
start "" "%EXE%"
call :ok "Where is open"
call :make_shortcuts
echo.
echo   %C_DIM%Next time, open Where from your desktop or Start menu.%C_END%
echo   %C_DIM%Run start-where.bat again after updating the code.%C_END%
echo.
timeout /t 6 >nul
exit /b 0

:make_shortcuts
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$w=New-Object -ComObject WScript.Shell; $made=$false;" ^
  "foreach($d in @([Environment]::GetFolderPath('Desktop'),[Environment]::GetFolderPath('Programs'))){" ^
  "  $p=Join-Path $d 'Where.lnk'; if(-not (Test-Path $p)){" ^
  "    $s=$w.CreateShortcut($p); $s.TargetPath=$env:EXE; $s.WorkingDirectory=$env:EXE_DIR;" ^
  "    $s.Description='Where - find what you are looking for'; $s.Save(); $made=$true } };" ^
  "if($made){exit 10}" >> "%LOG%" 2>&1
if errorlevel 10 call :ok "Added Where to your desktop and Start menu"
exit /b 0

:cli_fallback
echo.
call :warn "Opening the command-line version instead, so you can still use Where."
call :note "Copy the error above and send it over so the app can be fixed."
echo.

:run_cli
if not exist "%ROOT%target\release\where-cli.exe" (
  call :work "Building the command-line version..."
  cargo build --release -p where_cli >> "%LOG%" 2>&1 || goto :fail
)
set "PATH=%ROOT%target\release;%PATH%"
echo.
echo   %C_HEAD%Where command line is ready.%C_END% Try:
echo     %C_ACC%where-cli demo --db "%TEMP%\where-demo.db"%C_END%
echo     %C_ACC%where-cli add project Website%C_END%
echo     %C_ACC%where-cli index "%USERPROFILE%\Documents" -p Website%C_END%
echo     %C_ACC%where-cli search website%C_END%
echo     %C_ACC%where-cli --help%C_END%
echo.
cmd /k
goto :done


rem ============================================================== helpers ====

:step
echo.
echo   %C_HEAD%[%~1/5] %~2%C_END%
exit /b 0

:ok
echo     %C_OK%OK%C_END%  %~1
exit /b 0

:work
echo     %C_ACC%..%C_END%  %~1
exit /b 0

:warn
echo     %C_WARN%!!%C_END%  %~1
exit /b 0

:err
echo     %C_ERR%XX  %~1%C_END%
exit /b 0

:note
echo         %C_DIM%%~1%C_END%
exit /b 0

:show_log_tail
echo.
echo   %C_DIM%Last lines of the log:%C_END%
echo   %C_DIM%---------------------------------------------------%C_END%
powershell -NoProfile -Command "Get-Content -LiteralPath $env:LOG -Tail 25 | ForEach-Object { '    ' + $_ }"
echo   %C_DIM%---------------------------------------------------%C_END%
exit /b 0

:require_winget
where winget >nul 2>&1 && exit /b 0
call :err "winget is missing. Install 'App Installer' from the Microsoft Store, then run this again."
start "" "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
exit /b 1

:add_user_path
rem Persist a folder on the user PATH without the 1024-character setx limit.
set "ADD_DIR=%~1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=$env:ADD_DIR; $p=[Environment]::GetEnvironmentVariable('Path','User'); if(-not $p){$p=''}; if(($p -split ';') -notcontains $d){[Environment]::SetEnvironmentVariable('Path',(($p.TrimEnd(';')+';'+$d).TrimStart(';')),'User')}" >> "%LOG%" 2>&1
exit /b 0

:help
echo   %C_HEAD%start-where.bat%C_END%           set up if needed, build, and open Where
echo   %C_HEAD%start-where.bat update%C_END%    get the latest code first, then build and open
echo   %C_HEAD%start-where.bat cli%C_END%       open the command-line version
echo.
echo   Missing tools - Git, C++ Build Tools, Rust, Flutter - install automatically.
echo   Details are logged to %LOG%
goto :done

:fail
echo.
echo   %C_ERR%Setup stopped.%C_END% Fix the problem above, then run start-where.bat again.
echo   %C_DIM%Full log: %LOG%%C_END%
echo.
echo   Press any key to open the log, or close this window.
pause >nul
start "" notepad "%LOG%"
endlocal
exit /b 1

:done
endlocal
exit /b 0
