; ---------------------------------------------------------------------------
; Where - Windows installer (Inno Setup 6.3+)
;
; Built by .github/workflows/release.yml. To build by hand:
;   iscc /DAppVersion=0.4.0 /DSourceDir=<Release folder> /DOutDir=dist ^
;        /DIconFile=apps\where_flutter\windows\runner\resources\app_icon.ico ^
;        installer\windows\where.iss
;
; Installs for the current user (no admin prompt) into
; %LOCALAPPDATA%\Programs\Where, adds Start menu (and optional desktop)
; shortcuts, and registers an uninstaller. Your data in %APPDATA% is kept
; when Where is uninstalled.
; ---------------------------------------------------------------------------

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #error Pass /DSourceDir=<folder containing Where.exe>
#endif
#ifndef OutDir
  #define OutDir "dist"
#endif
#ifndef IconFile
  #define IconFile "..\..\apps\where_flutter\windows\runner\resources\app_icon.ico"
#endif

[Setup]
AppId={{8F3B2C71-5E2A-4C1B-9E4D-6A7B8C9D0E1F}
AppName=Where
AppVersion={#AppVersion}
AppVerName=Where {#AppVersion}
AppPublisher=CrownCore Studios
AppPublisherURL=https://github.com/CodingJeffRoblox/Where
AppSupportURL=https://github.com/CodingJeffRoblox/Where/blob/main/SUPPORT.md
AppUpdatesURL=https://github.com/CodingJeffRoblox/Where/releases
DefaultDirName={autopf}\Where
DefaultGroupName=Where
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutDir}
OutputBaseFilename=Where-Setup-{#AppVersion}-windows-x64
SetupIconFile={#IconFile}
UninstallDisplayIcon={app}\Where.exe
UninstallDisplayName=Where
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#AppVersion}
VersionInfoProductName=Where
VersionInfoCompany=CrownCore Studios

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Where"; Filename: "{app}\Where.exe"; Comment: "Find what you're looking for"
Name: "{autodesktop}\Where"; Filename: "{app}\Where.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Where.exe"; Description: "{cm:LaunchProgram,Where}"; Flags: nowait postinstall skipifsilent
