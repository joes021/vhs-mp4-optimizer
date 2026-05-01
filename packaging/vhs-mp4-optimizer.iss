#define MyAppName "VHS MP4 Optimizer"
#define MyAppPublisher "VHS MP4 Optimizer"
#define MyAppPublisherURL "https://github.com/joes021/vhs-mp4-optimizer"
#define MyAppSupportURL "https://github.com/joes021/vhs-mp4-optimizer/issues"
#define MyAppUpdatesURL "https://github.com/joes021/vhs-mp4-optimizer/releases/latest"

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0-dev"
#endif

#ifndef MyReleaseId
  #define MyReleaseId MyAppVersion
#endif

#ifndef MyVersionInfoVersion
  #define MyVersionInfoVersion "0.0.0.0"
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
; DefaultDirName={localappdata}\Programs\VHS MP4 Optimizer
; DefaultGroupName=VHS MP4 Optimizer
AppId={{8C1E6E58-BB6F-4D67-84AF-3B70D7A1A0B6}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppPublisherURL}
AppSupportURL={#MyAppSupportURL}
AppUpdatesURL={#MyAppUpdatesURL}
DefaultDirName={localappdata}\Programs\VHS MP4 Optimizer
DefaultGroupName=VHS MP4 Optimizer
DisableProgramGroupPage=yes
OutputDir={#MyOutputRoot}
OutputBaseFilename=VHS-MP4-Optimizer-Setup-{#MyReleaseId}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
SetupIconFile={#MyReleaseRoot}\assets\vhs-mp4-optimizer.ico
UninstallDisplayIcon={app}\assets\vhs-mp4-optimizer.ico
UninstallDisplayName=VHS MP4 Optimizer
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Video Converter for VHS, DV AVI, MPG and MP4 delivery workflows
VersionInfoProductName={#MyAppName}
VersionInfoVersion={#MyVersionInfoVersion}
VersionInfoProductVersion={#MyVersionInfoVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
; CreateDesktopIcon
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked

[Files]
Source: "{#MyReleaseRoot}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\VHS MP4 Optimizer"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\VHS MP4 Optimizer.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\assets\vhs-mp4-optimizer.ico"
Name: "{autodesktop}\VHS MP4 Optimizer"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\VHS MP4 Optimizer.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\assets\vhs-mp4-optimizer.ico"; Tasks: desktopicon
Name: "{autoprograms}\Uninstall VHS MP4 Optimizer"; Filename: "{uninstallexe}"
