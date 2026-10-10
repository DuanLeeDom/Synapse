; =============================================================================
; Synapse - Instalador Profissional para Windows x64
; Engine: Inno Setup 6.x
;
; SOLUÇÃO PARA ERRO DE DOWNLOAD:
;   O downloader nativo do Inno Setup NÃO segue redirecionamentos HTTPS
;   (GitHub → CDN, gyan.dev → Sourceforge, etc.) — causando o erro falso
;   de "conexão com a internet".
;
;   Solução: os downloads são feitos via PowerShell + curl.exe do Windows,
;   que segue redirects HTTPS explicitamente, com BITS/WebClient como fallback.
;
; Estrutura de ferramentas (compatível com udependencias.pas):
;   tools\ffmpeg\bin\ffmpeg.exe      (chave 'ffmpeg')
;   tools\ffmpeg\bin\ffprobe.exe     (chave 'qt')
;   tools\ytdlp\yt-dlp.exe           (chave 'ytdlp')
;   tools\imagemagick\magick.exe     (chave 'imagemagick')
;
; EXECUTAVEL DO SYNAPSE:
;   Este instalador EMBUTE o executavel (synapse.exe, na raiz do repositorio),
;   copiado pela secao [Files]. NAO ha consulta nem download da "ultima versao"
;   no GitHub aqui: a verificacao de atualizacoes fica a cargo do proprio
;   aplicativo. Por isso recompile este instalador a cada nova versao do exe.
; =============================================================================

[Setup]
AppName=Synapse
AppVersion=1.0.0
AppPublisher=Duan Lee
AppPublisherURL=https://github.com/DuanLeeDom/Synapse
AppSupportURL=https://github.com/DuanLeeDom/Synapse/issues
AppUpdatesURL=https://github.com/DuanLeeDom/Synapse/releases
DefaultDirName={autopf}\Synapse
DefaultGroupName=Synapse
DisableProgramGroupPage=yes
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
OutputDir=.\Output
OutputBaseFilename=synapse_setup_v1.0.0
SetupIconFile=C:\Users\domcat\Documents\dev\Synapse\img\ico\Synapse.ico
UninstallDisplayIcon={app}\synapse.exe
Compression=lzma2/ultra64
SolidCompression=yes
PrivilegesRequired=admin
WizardStyle=modern
CloseApplications=yes
RestartIfNeededByRun=no

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[CustomMessages]
brazilianportuguese.DepsAborted=Instalação cancelada pelo usuário.
brazilianportuguese.DepsFailed=Falha ao baixar ou instalar uma ou mais dependências.%n%nDetalhe: %1%n%nO Synapse pode funcionar parcialmente sem todas as dependências.%nVocê pode instalá-las manualmente depois.
brazilianportuguese.DepsInfo=O instalador vai baixar as seguintes ferramentas necessárias:%n%n%1%nIsso pode demorar alguns minutos dependendo de sua conexão.
brazilianportuguese.PSNotAvail=PowerShell não encontrado. Não foi possível instalar as dependências automaticamente.
brazilianportuguese.FFmpegFailed=Não foi possível baixar e instalar o FFmpeg e o ffprobe.%n%nVerifique sua conexão com a internet e execute o instalador novamente. O Synapse pode funcionar parcialmente sem essa dependência. Página do build essentials: https://www.gyan.dev/ffmpeg/builds/

[Files]
; Executavel do Synapse embutido (copiado junto com este instalador).
; Caminho relativo a este script (raiz do repositorio = ..\..\..).
Source: "..\..\..\synapse.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Synapse";                        Filename: "{app}\synapse.exe"
Name: "{group}\{cm:UninstallProgram,Synapse}";  Filename: "{uninstallexe}"
Name: "{autodesktop}\Synapse";                  Filename: "{app}\synapse.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Run]
Filename: "{app}\synapse.exe"; Description: "{cm:LaunchProgram,Synapse}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\tools"

; =============================================================================
; [Code]
; =============================================================================
[Code]

// ---------------------------------------------------------------------------
// URLs das dependências
// O PowerShell usa curl.exe com suporte explícito a redirecionamentos.
// ---------------------------------------------------------------------------
const
  // yt-dlp: binário único, sem extração necessária
  URL_YTDLP  = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';

  // FFmpeg: build essentials do gyan.dev (~110 MB), com ffmpeg.exe + ffprobe.exe
  URL_FFMPEG = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';

  // ImageMagick: portable Q16 x64 (7z) do GitHub Releases oficial
  // Versão fixada para consistência. Atualizar quando sair nova versão.
  URL_MAGICK = 'https://github.com/ImageMagick/ImageMagick/releases/download/7.1.2-32/ImageMagick-7.1.2-32-portable-Q16-x64.7z';

// ---------------------------------------------------------------------------
// Variáveis de estado
// ---------------------------------------------------------------------------
var
  NeedsFFmpeg, NeedsYtDlp, NeedsMagick: Boolean;
  ProgressPage: TOutputProgressWizardPage;

// ---------------------------------------------------------------------------
// Helpers de verificação de PATH
// ---------------------------------------------------------------------------
function IsInAnyPath(const FileName: string): Boolean;
var
  SysPath, UserPath, Combined: string;
  Parts: TStringList;
  i: Integer;
  Dir: string;
begin
  Result := False;
  SysPath := ''; UserPath := '';
  RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', SysPath);
  RegQueryStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', UserPath);
  Combined := SysPath;
  if Combined <> '' then Combined := Combined + ';';
  Combined := Combined + UserPath;

  Parts := TStringList.Create;
  try
    Parts.Delimiter := ';';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := Combined;
    for i := 0 to Parts.Count - 1 do
    begin
      Dir := Trim(Parts[i]);
      if (Dir <> '') and FileExists(AddBackslash(Dir) + FileName) then
      begin
        Result := True; Exit;
      end;
    end;
  finally
    Parts.Free;
  end;
end;

function ToolExists(const SubFolder, ExeName: string): Boolean;
var
  Base: string;
begin
  Base := ExpandConstant('{app}\tools\') + SubFolder;
  Result := FileExists(Base + '\' + ExeName) or
            FileExists(Base + '\bin\' + ExeName);
end;

// ---------------------------------------------------------------------------
// VerificarDependencias
// ---------------------------------------------------------------------------
procedure VerificarDependencias;
begin
  NeedsFFmpeg := not ToolExists('ffmpeg', 'ffmpeg.exe')  and not IsInAnyPath('ffmpeg.exe');
  NeedsYtDlp  := not ToolExists('ytdlp',  'yt-dlp.exe') and not IsInAnyPath('yt-dlp.exe');
  NeedsMagick := not ToolExists('imagemagick', 'magick.exe') and not IsInAnyPath('magick.exe');
end;

// ---------------------------------------------------------------------------
// ExecPS: executa um script PowerShell e aguarda a conclusão.
// Retorna True se ExitCode = 0.
// ---------------------------------------------------------------------------
function ExecPS(const Script: string; out ExitCode: Integer): Boolean;
var
  TmpScript: string;
begin
  TmpScript := ExpandConstant('{tmp}\synapse_dep_script.ps1');
  SaveStringToFile(TmpScript, Script, False);

  Result := Exec(
    'powershell.exe',
    '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + TmpScript + '"',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ExitCode
  );
  Result := Result and (ExitCode = 0);
end;

// ---------------------------------------------------------------------------
// DownloadFile: segue redirects com o curl do Windows e usa BITS/WebClient
// como fallback para sistemas sem curl ou com falha transitória no download.
// ---------------------------------------------------------------------------
function DownloadFile(const Url, Dest: string): Boolean;
var
  Script: string;
  ExitCode: Integer;
begin
  Log('Iniciando download: ' + Url);
  Log('Destino: ' + Dest);

  Script :=
    'Set-StrictMode -Version Latest' + #13#10 +
    '$ErrorActionPreference = "Stop"' + #13#10 +
    'try {' + #13#10 +
    '  $dest = "' + Dest + '"' + #13#10 +
    '  $url  = "' + Url  + '"' + #13#10 +
    '  $destDir = Split-Path $dest -Parent' + #13#10 +
    '  if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }' + #13#10 +
    '  $curl = Join-Path $env:SystemRoot "System32\curl.exe"' + #13#10 +
    '  if (Test-Path -LiteralPath $curl) {' + #13#10 +
    '    Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue' + #13#10 +
    '    & $curl --fail --location --retry 3 --connect-timeout 30 --silent --show-error --output $dest $url' + #13#10 +
    '    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $dest) -and (Get-Item -LiteralPath $dest).Length -ge 1000) { exit 0 }' + #13#10 +
    '    Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue' + #13#10 +
    '  }' + #13#10 +
    '  # Fallback para BITS; se falhar, tenta WebClient.' + #13#10 +
    '  try {' + #13#10 +
    '    Import-Module BitsTransfer -ErrorAction Stop' + #13#10 +
    '    Start-BitsTransfer -Source $url -Destination $dest -TransferType Download -ErrorAction Stop' + #13#10 +
    '  } catch {' + #13#10 +
    '    Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue' + #13#10 +
    '    $wc = New-Object System.Net.WebClient' + #13#10 +
    '    $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")'  + #13#10 +
    '    $wc.DownloadFile($url, $dest)' + #13#10 +
    '  }' + #13#10 +
    '  if (-not (Test-Path -LiteralPath $dest) -or (Get-Item -LiteralPath $dest).Length -lt 1000) {' + #13#10 +
    '    Write-Error "Arquivo baixado invalido ou vazio."' + #13#10 +
    '    exit 2' + #13#10 +
    '  }' + #13#10 +
    '  exit 0' + #13#10 +
    '} catch {' + #13#10 +
    '  Write-Error $_.Exception.Message' + #13#10 +
    '  exit 1' + #13#10 +
    '}';

  Result := ExecPS(Script, ExitCode);
  if not Result then
    Log('ERRO no download. ExitCode=' + IntToStr(ExitCode) + ' URL=' + Url);
end;

// ---------------------------------------------------------------------------
// UnzipViaPowerShell: extrai um ZIP usando Expand-Archive do PowerShell
// ---------------------------------------------------------------------------
function UnzipViaPowerShell(const ZipFile, TargetFolder: string): Boolean;
var
  Script: string;
  ExitCode: Integer;
begin
  Log('Extraindo ZIP: ' + ZipFile + ' → ' + TargetFolder);
  Script :=
    '$ErrorActionPreference = "Stop"' + #13#10 +
    'try {' + #13#10 +
    '  $zip = "' + ZipFile + '"' + #13#10 +
    '  $dst = "' + TargetFolder + '"' + #13#10 +
    '  if (-not (Test-Path $dst)) { New-Item -ItemType Directory $dst -Force | Out-Null }' + #13#10 +
    '  Expand-Archive -LiteralPath $zip -DestinationPath $dst -Force' + #13#10 +
    '  exit 0' + #13#10 +
    '} catch { Write-Error $_; exit 1 }';

  Result := ExecPS(Script, ExitCode);
  if not Result then
    Log('ERRO ao extrair ZIP. ExitCode=' + IntToStr(ExitCode));
end;

// ---------------------------------------------------------------------------
// UnzipSevenZ: extrai um .7z usando o 7-Zip nativo do Windows (se disponível)
// ou via PowerShell com módulo SevenZipSharp como fallback.
// ---------------------------------------------------------------------------
function Unzip7z(const SevenZFile, TargetFolder: string): Boolean;
var
  Script: string;
  ExitCode: Integer;
begin
  Log('Extraindo 7z: ' + SevenZFile + ' → ' + TargetFolder);

  // Tenta usar 7z.exe ou 7za.exe instalados, ou o Shell (não suporta 7z nativo)
  // → Usamos PowerShell com .NET para ler o 7z via biblioteca nativa
  // O Windows 11 tem suporte nativo a tar e não a 7z, então baixamos o 7za.exe pequeno
  // via script separado ou usamos o método alternativo: baixar a versão .zip do ImageMagick

  // Abordagem: usar o 7za.exe (standalone, ~500KB) se ele estiver no tmp
  // Se não estiver, usa PowerShell para baixar e extrair via BITS

  Script :=
    '$ErrorActionPreference = "Stop"' + #13#10 +
    '$sevenZ = "' + SevenZFile + '"' + #13#10 +
    '$dst    = "' + TargetFolder + '"' + #13#10 +
    'if (-not (Test-Path $dst)) { New-Item -ItemType Directory $dst -Force | Out-Null }' + #13#10 +
    '' + #13#10 +
    '# Procura o 7za.exe em locais comuns' + #13#10 +
    '$7zaLocations = @(' + #13#10 +
    '  "' + ExpandConstant('{tmp}') + '\7za.exe",' + #13#10 +
    '  "C:\Program Files\7-Zip\7z.exe",' + #13#10 +
    '  "C:\Program Files (x86)\7-Zip\7z.exe"' + #13#10 +
    ')' + #13#10 +
    '$7zaExe = $null' + #13#10 +
    'foreach ($loc in $7zaLocations) { if (Test-Path $loc) { $7zaExe = $loc; break } }' + #13#10 +
    '' + #13#10 +
    'if ($7zaExe) {' + #13#10 +
    '  & $7zaExe x $sevenZ -o"$dst" -y | Out-Null' + #13#10 +
    '  if ($LASTEXITCODE -ne 0) { throw "7za falhou com codigo $LASTEXITCODE" }' + #13#10 +
    '} else {' + #13#10 +
    '  # Fallback: baixa o 7za.exe standalone (500KB) e extrai' + #13#10 +
    '  $7zaUrl = "https://github.com/nicowillis/7za/raw/main/7za.exe"' + #13#10 +
    '  $7zaPath = "' + ExpandConstant('{tmp}') + '\7za.exe"' + #13#10 +
    '  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13' + #13#10 +
    '  $wc = New-Object System.Net.WebClient' + #13#10 +
    '  $wc.Headers.Add("User-Agent", "Mozilla/5.0")' + #13#10 +
    '  $wc.DownloadFile($7zaUrl, $7zaPath)' + #13#10 +
    '  & $7zaPath x $sevenZ -o"$dst" -y | Out-Null' + #13#10 +
    '  if ($LASTEXITCODE -ne 0) { throw "7za (baixado) falhou com codigo $LASTEXITCODE" }' + #13#10 +
    '}' + #13#10 +
    'exit 0';

  Result := ExecPS(Script, ExitCode);
  if not Result then
    Log('ERRO ao extrair 7z. ExitCode=' + IntToStr(ExitCode));
end;

// ---------------------------------------------------------------------------
// EncontrarExeNaSubpasta: percorre subpastas procurando um executável.
// Retorna a pasta onde o arquivo foi encontrado, ou ''.
// ---------------------------------------------------------------------------
function EncontrarExeNaSubpasta(const Base, ExeName: string): string;
var
  FindRec: TFindRec;
  Sub: string;
begin
  Result := '';
  // Verifica direto na base
  if FileExists(Base + '\' + ExeName) then begin Result := Base; Exit; end;
  // Nível 1 de subpastas
  if FindFirst(Base + '\*', FindRec) then
  try
    repeat
      if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY <> 0) and
         (FindRec.Name <> '.') and (FindRec.Name <> '..') then
      begin
        Sub := Base + '\' + FindRec.Name;
        if FileExists(Sub + '\' + ExeName) then begin Result := Sub; Exit; end;
        if FileExists(Sub + '\bin\' + ExeName) then begin Result := Sub + '\bin'; Exit; end;
      end;
    until not FindNext(FindRec);
  finally
    FindClose(FindRec);
  end;
end;

// ---------------------------------------------------------------------------
// CurStepChanged: executa o pós-instalação
// ---------------------------------------------------------------------------
procedure CurStepChanged(CurStep: TSetupStep);
var
  TDir, TmpDir, ExtDir, BinDir: string;
  ExitCode: Integer;
begin
  if CurStep <> ssPostInstall then Exit;

  TDir   := ExpandConstant('{app}\tools');
  TmpDir := ExpandConstant('{tmp}');

  ProgressPage.SetText('Instalando dependências...', '');
  ProgressPage.Show;

  try
    // ── yt-dlp ──────────────────────────────────────────────────────────────
    if NeedsYtDlp then
    begin
      ProgressPage.SetText('Baixando yt-dlp...', URL_YTDLP);
      ProgressPage.SetProgress(1, 3);
      if DownloadFile(URL_YTDLP, TmpDir + '\yt-dlp.exe') then
      begin
        ForceDirectories(TDir + '\ytdlp');
        CopyFile(TmpDir + '\yt-dlp.exe', TDir + '\ytdlp\yt-dlp.exe', False);
        Log('yt-dlp instalado com sucesso.');
      end else
        Log('AVISO: falha ao baixar yt-dlp.');
    end;

    // ── FFmpeg ───────────────────────────────────────────────────────────────
    if NeedsFFmpeg then
    begin
      ProgressPage.SetText('Baixando FFmpeg essentials (~110 MB)...', URL_FFMPEG);
      ProgressPage.SetProgress(2, 3);
      if DownloadFile(URL_FFMPEG, TmpDir + '\ffmpeg.zip') then
      begin
        ProgressPage.SetText('Extraindo FFmpeg...', '');
        ExtDir := TmpDir + '\ffmpeg_ext';
        if UnzipViaPowerShell(TmpDir + '\ffmpeg.zip', ExtDir) then
        begin
          BinDir := EncontrarExeNaSubpasta(ExtDir, 'ffmpeg.exe');
          if (BinDir <> '') and
             FileExists(BinDir + '\ffprobe.exe') then
          begin
            ForceDirectories(TDir + '\ffmpeg\bin');
            if CopyFile(BinDir + '\ffmpeg.exe', TDir + '\ffmpeg\bin\ffmpeg.exe', False) and
               CopyFile(BinDir + '\ffprobe.exe', TDir + '\ffmpeg\bin\ffprobe.exe', False) and
               FileExists(TDir + '\ffmpeg\bin\ffmpeg.exe') and
               FileExists(TDir + '\ffmpeg\bin\ffprobe.exe') then
              Log('FFmpeg e ffprobe instalados com sucesso.')
            else
              Log('AVISO: falha ao copiar ffmpeg.exe e/ou ffprobe.exe.');
          end else
            Log('AVISO: ffmpeg.exe e/ou ffprobe.exe nao encontrados na estrutura do ZIP.');
        end else
          Log('AVISO: falha ao extrair ffmpeg.zip');
      end else
        Log('AVISO: falha ao baixar FFmpeg.');
    end;

    // ── ImageMagick (7z portátil) ────────────────────────────────────────────
    if NeedsMagick then
    begin
      ProgressPage.SetText('Baixando ImageMagick...', URL_MAGICK);
      ProgressPage.SetProgress(3, 3);
      if DownloadFile(URL_MAGICK, TmpDir + '\magick.7z') then
      begin
        ProgressPage.SetText('Extraindo ImageMagick...', '');
        ExtDir := TmpDir + '\magick_ext';
        if Unzip7z(TmpDir + '\magick.7z', ExtDir) then
        begin
          BinDir := EncontrarExeNaSubpasta(ExtDir, 'magick.exe');
          if BinDir <> '' then
          begin
            // Copia toda a pasta do ImageMagick (inclui DLLs e coders)
            ForceDirectories(TDir + '\imagemagick');
            Exec(ExpandConstant('{cmd}'),
              '/C xcopy /E /I /Q /Y "' + BinDir + '\*" "' + TDir + '\imagemagick\"',
              '', SW_HIDE, ewWaitUntilTerminated, ExitCode);
            Log('ImageMagick instalado com sucesso.');
          end else
            Log('AVISO: magick.exe nao encontrado na estrutura do 7z.');
        end else
          Log('AVISO: falha ao extrair magick.7z');
      end else
        Log('AVISO: falha ao baixar ImageMagick.');
    end;

    ProgressPage.SetProgress(3, 3);

  finally
    ProgressPage.Hide;
  end;

  if NeedsFFmpeg and
     (not FileExists(TDir + '\ffmpeg\bin\ffmpeg.exe') or
      not FileExists(TDir + '\ffmpeg\bin\ffprobe.exe')) then
    MsgBox(CustomMessage('FFmpegFailed'), mbError, MB_OK);
end;

// ---------------------------------------------------------------------------
// InitializeWizard
// ---------------------------------------------------------------------------
procedure InitializeWizard;
begin
  ProgressPage := CreateOutputProgressPage(
    'Instalando dependências',
    'Aguarde enquanto as ferramentas são baixadas e configuradas...'
  );
end;

// ---------------------------------------------------------------------------
// NextButtonClick: ao avançar da tela wpReady, verifica e informa o usuário
// ---------------------------------------------------------------------------
function NextButtonClick(CurPageID: Integer): Boolean;
var
  DepList: string;
begin
  Result := True;
  if CurPageID <> wpReady then Exit;

  VerificarDependencias;

  // Monta a lista do que será baixado para informar o usuário
  DepList := '';
  if NeedsYtDlp  then DepList := DepList + '  • yt-dlp' + #13#10;
  if NeedsFFmpeg then DepList := DepList + '  • FFmpeg essentials (ffmpeg + ffprobe, ~110 MB)' + #13#10;
  if NeedsMagick then DepList := DepList + '  • ImageMagick 7 Portable' + #13#10;

  if DepList <> '' then
  begin
    if MsgBox(
      FmtMessage(CustomMessage('DepsInfo'), [DepList]),
      mbInformation,
      MB_OKCANCEL
    ) = IDCANCEL then
    begin
      Result := False; // Usuário cancelou
    end;
  end;
end;
