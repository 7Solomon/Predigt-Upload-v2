; install_script.iss
; This script creates a Windows installer for the Predigt Uploader application.
; It bundles the Flutter application and the Python backend, and runs the backend setup script during installation.

#define MyAppName "Predigt Uploader"
#define MyAppVersion "1.0"
#define MyAppExeName "predigt_upload_v2.exe"
#define MyBackendDir "backend"

[Setup]
; Basic application and installer settings
AppId={{AUTO}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
OutputDir=installers
OutputBaseFilename=predigt_uploader_setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
; Adds an option during installation to create a desktop icon
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; This section defines which files to include in the installer.
; It copies the compiled Flutter application and the backend folder.
Source: "build\windows\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#MyBackendDir}\*"; DestDir: "{app}\backend"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Creates Start Menu and Desktop icons for the application.
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; This section executes commands during or after the installation.
; It runs the PowerShell setup script silently and waits for it to complete.
Filename: "{win}\System32\WindowsPowerShell\v1.0\powershell.exe"; \
    Parameters: "-ExecutionPolicy Bypass -File ""{app}\backend\setup_backend.ps1"""; \
    WorkingDir: "{app}\backend"; \
    Flags: runhidden waituntilterminated

; This command gives the user the option to launch the application after the installation is finished.
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
