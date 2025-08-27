; install_script.iss
; This script creates a Windows installer for the Predigt Uploader application.
; It bundles the Flutter application and the Python backend, and runs the backend setup script during installation.

#define MyAppName "Predigt Uploader"
#define MyAppVersion "1.0"
#define MyAppExeName "predigt_upload_v2.exe"
#define MyBackendDir "backend"
#define MyAppPublisher "Your Company Name"
#define MyAppURL "https://yourcompany.com"

[Setup]
; Basic application and installer settings
AppId={{B8E5F8C1-2A3D-4E5F-9B7C-1D2E3F4A5B6C}}
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
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
; Adds an option during installation to create a desktop icon
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; This section defines which files to include in the installer.
; It copies the compiled Flutter application and the backend folder.
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#MyBackendDir}\*"; DestDir: "{app}\backend"; Flags: ignoreversion recursesubdirs createallsubdirs
; Copy the setup script to the backend directory
Source: "setup_backend.ps1"; DestDir: "{app}\backend"; Flags: ignoreversion
; Copy a wrapper script for the main exe
Source: "app_wrapper.bat"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; Creates Start Menu and Desktop icons for the application.
; Use the wrapper script instead of direct exe
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\app_wrapper.bat"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\app_wrapper.bat"; Tasks: desktopicon

[Run]
; This section executes commands during or after the installation.
; It runs the PowerShell setup script silently and waits for it to complete.
Filename: "{win}\System32\WindowsPowerShell\v1.0\powershell.exe"; \
    Parameters: "-ExecutionPolicy Bypass -File ""{app}\backend\setup_backend.ps1"""; \
    WorkingDir: "{app}\backend"; \
    Flags: runhidden waituntilterminated; \
    StatusMsg: "Setting up Python backend environment..."

; This command gives the user the option to launch the application after the installation is finished.
Filename: "{app}\app_wrapper.bat"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Stop the backend when uninstalling
Filename: "{win}\System32\WindowsPowerShell\v1.0\powershell.exe"; \
    Parameters: "-ExecutionPolicy Bypass -File ""{app}\backend\stop_backend.ps1"""; \
    WorkingDir: "{app}\backend"; \
    Flags: runhidden