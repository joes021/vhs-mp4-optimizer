#define MyAppName "VHS MP4 Optimizer"
#define MyAppPublisher "joes021"

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0-dev"
#endif

#ifndef MyReleaseId
  #define MyReleaseId MyAppVersion
#endif

#ifndef MyReleaseRoot
  #error "MyReleaseRoot define is required."
#endif

#ifndef MyOutputRoot
  #error "MyOutputRoot define is required."
#endif

[Setup]
; Token hints for packaging checks:
; AppName=VHS MP4 Optimizer
; DefaultDirName={autopf}\VHS MP4 Optimizer
; DefaultGroupName=VHS MP4 Optimizer
AppId={{8C1E6E58-BB6F-4D67-84AF-3B70D7A1A0B6}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\VHS MP4 Optimizer
DefaultGroupName=VHS MP4 Optimizer
DisableProgramGroupPage=yes
OutputDir={#MyOutputRoot}
OutputBaseFilename=VHS-MP4-Optimizer-Setup-{#MyReleaseId}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
SetupIconFile={#MyReleaseRoot}\assets\vhs-mp4-optimizer.ico
UninstallDisplayIcon={app}\assets\vhs-mp4-optimizer.ico
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
; CreateDesktopIcon
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked

[Files]
Source: "{#MyReleaseRoot}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\VHS MP4 Optimizer"; Filename: "{app}\VHS MP4 Optimizer.bat"; WorkingDir: "{app}"; IconFilename: "{app}\assets\vhs-mp4-optimizer.ico"
Name: "{autodesktop}\VHS MP4 Optimizer"; Filename: "{app}\VHS MP4 Optimizer.bat"; WorkingDir: "{app}"; IconFilename: "{app}\assets\vhs-mp4-optimizer.ico"; Tasks: desktopicon
Name: "{autoprograms}\Uninstall VHS MP4 Optimizer"; Filename: "{uninstallexe}"
