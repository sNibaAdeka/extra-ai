; Inno Setup script — builds ExtraAI-Setup-<version>.exe on the Windows CI
; runner (see .github/workflows/windows.yml). Produces a normal installer:
; Program Files, Start Menu, optional desktop icon, uninstaller.

[Setup]
AppName=Extra AI
AppVersion=1.0.0
AppPublisher=Extra AI
AppPublisherURL=https://extrai.org
DefaultDirName={autopf}\Extra AI
DefaultGroupName=Extra AI
OutputBaseFilename=ExtraAI-Setup-1.0.0
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\extra_ai.exe
WizardStyle=modern

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"

[Icons]
Name: "{autoprograms}\Extra AI"; Filename: "{app}\extra_ai.exe"
Name: "{autodesktop}\Extra AI"; Filename: "{app}\extra_ai.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\extra_ai.exe"; Description: "Launch Extra AI"; Flags: nowait postinstall skipifsilent
