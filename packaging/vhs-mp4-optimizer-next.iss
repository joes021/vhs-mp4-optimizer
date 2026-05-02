#define MyAppName "VHS MP4 Optimizer Next"
#define MyAppPublisher "VHS MP4 Optimizer"
#define MyAppPublisherURL "https://github.com/joes021/vhs-mp4-optimizer/tree/codex/avalonia-migration"
#define MyAppSupportURL "https://github.com/joes021/vhs-mp4-optimizer/issues"
#define MyAppUpdatesURL "https://github.com/joes021/vhs-mp4-optimizer/tree/codex/avalonia-migration"

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
AppId={{4D660AB4-1A4E-4E7D-8A3B-DF7A7F6C8D90}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppPublisherURL}
AppSupportURL={#MyAppSupportURL}
AppUpdatesURL={#MyAppUpdatesURL}
DefaultDirName={localappdata}\Programs\VHS MP4 Optimizer Next
DefaultGroupName=VHS MP4 Optimizer Next
DisableProgramGroupPage=yes
OutputDir={#MyOutputRoot}
OutputBaseFilename=VHS-MP4-Optimizer-Next-Setup-{#MyReleaseId}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
SetupIconFile={#MyReleaseRoot}\app\avalonia-logo.ico
UninstallDisplayIcon={app}\app\avalonia-logo.ico
UninstallDisplayName=VHS MP4 Optimizer Next
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Cross-platform Avalonia migration build for VHS MP4 Optimizer
VersionInfoProductName={#MyAppName}
VersionInfoVersion={#MyVersionInfoVersion}
VersionInfoProductVersion={#MyVersionInfoVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked

[Files]
Source: "{#MyReleaseRoot}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\VHS MP4 Optimizer Next"; Filename: "{app}\app\VhsMp4Optimizer.App.exe"; WorkingDir: "{app}\app"; IconFilename: "{app}\app\avalonia-logo.ico"
Name: "{autodesktop}\VHS MP4 Optimizer Next"; Filename: "{app}\app\VhsMp4Optimizer.App.exe"; WorkingDir: "{app}\app"; IconFilename: "{app}\app\avalonia-logo.ico"; Tasks: desktopicon
Name: "{autoprograms}\Uninstall VHS MP4 Optimizer Next"; Filename: "{uninstallexe}"
