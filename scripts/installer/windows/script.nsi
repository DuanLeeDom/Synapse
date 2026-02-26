; ---------------------------------------------------------
; Synapse Installer - Full Native Downloader & Uninstaller
; ---------------------------------------------------------

!define APP_NAME "Synapse"
!define EXE_NAME "synapse.exe"
!define COMP_NAME "DuanLee_Dev"

; Incluir a interface moderna
!include "MUI2.nsh"

Name "${APP_NAME}"
OutFile "Instalador_Synapse_Completo.exe"
InstallDir "$PROGRAMFILES64\${APP_NAME}"
RequestExecutionLevel admin

; --- Configurações de Interface ---
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "PortugueseBR"

; ---------------------------------------------------------
; SEÇÃO DE INSTALAÇÃO
; ---------------------------------------------------------
Section "Instalar Synapse" SecMain
    SetOutPath "$INSTDIR"
    
    ; 1. Copia o seu executável (Certifique-se que ele está na mesma pasta do script)
    File "synapse.exe"

    ; 2. Baixar yt-dlp usando PowerShell (Com protocolo de segurança TLS 1.2)
    DetailPrint "Baixando yt-dlp.exe (Aguarde...)"
    nsExec::ExecToLog 'powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe -OutFile $\"$INSTDIR\yt-dlp.exe$\""'

    ; 3. Baixar e Extrair FFmpeg
    DetailPrint "Baixando pacote FFmpeg..."
    nsExec::ExecToLog 'powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip -OutFile $\"$INSTDIR\ffmpeg.zip$\""'
    
    DetailPrint "Extraindo FFmpeg..."
    nsExec::ExecToLog 'powershell -Command "Expand-Archive -Path $\"$INSTDIR\ffmpeg.zip$\" -DestinationPath $\"$INSTDIR\ffmpeg_temp$\" -Force"'
    
    ; Move o executável e limpa o lixo
    nsExec::ExecToLog 'cmd /c "move /y $\"$INSTDIR\ffmpeg_temp\ffmpeg-*\bin\ffmpeg.exe$\" $\"$INSTDIR\ffmpeg.exe$\""'
    Delete "$INSTDIR\ffmpeg.zip"
    RMDir /r "$INSTDIR\ffmpeg_temp"

    ; 4. Criar Atalhos e Desinstalador
    WriteUninstaller "$INSTDIR\uninstall.exe"
    CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${EXE_NAME}"
    CreateDirectory "$SMPROGRAMS\${APP_NAME}"
    CreateShortcut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${EXE_NAME}"
    CreateShortcut "$SMPROGRAMS\${APP_NAME}\Desinstalar.lnk" "$INSTDIR\uninstall.exe"

    ; 5. Registrar no Painel de Controle
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "DisplayName" "${APP_NAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "DisplayIcon" "$INSTDIR\${EXE_NAME}"
SectionEnd

; ---------------------------------------------------------
; SEÇÃO DE DESINSTALAÇÃO
; ---------------------------------------------------------
Section "Uninstall"
    ; Apagar arquivos físicos
    Delete "$INSTDIR\synapse.exe"
    Delete "$INSTDIR\yt-dlp.exe"
    Delete "$INSTDIR\ffmpeg.exe"
    Delete "$INSTDIR\uninstall.exe"
    
    ; Apagar atalhos
    Delete "$DESKTOP\${APP_NAME}.lnk"
    Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
    Delete "$SMPROGRAMS\${APP_NAME}\Desinstalar.lnk"
    RMDir "$SMPROGRAMS\${APP_NAME}"

    ; Remover pasta do programa
    RMDir "$INSTDIR"

    ; Remover do Registro
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"
SectionEnd