; ---------------------------------------------------------
; Synapse Installer - Professional Edition
; ---------------------------------------------------------

!define APP_NAME "Synapse"
!define EXE_NAME "synapse.exe"
!define FFMPEG_DIR "ffmpeg-8.1-essentials_build"
!define COMP_NAME "Duan Lee"
!define WEB_SITE "https://github.com/duanleedom" ; Seu GitHub ou Site

; --- Configurações de Interface ---
!include "MUI2.nsh"
!include "LogicLib.nsh"

!define MUI_ABORTWARNING ; Avisa se o usuário tentar fechar o instalador
!define MUI_ICON "icon.ico" ; Ícone do Instalador
!define MUI_UNICON "icon.ico" ; Ícone do Desinstalador

; Imagens (Opcional: Comente as linhas abaixo se não tiver os arquivos .bmp ainda)
!define MUI_WELCOMEFINISHPAGE_BITMAP "welcome.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "header.bmp"

; --- Páginas do Instalador ---
!insertmacro MUI_PAGE_WELCOME ; Tela de Boas-vindas
!insertmacro MUI_PAGE_DIRECTORY ; Escolha da Pasta

; Página de Instalação (com barra de progresso)
!insertmacro MUI_PAGE_INSTFILES

; Página Final com opção de Executar o Synapse
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXE_NAME}"
!define MUI_FINISHPAGE_RUN_TEXT "Abrir o Synapse agora"
!define MUI_FINISHPAGE_LINK "Visitar repositório do projeto"
!define MUI_FINISHPAGE_LINK_LOCATION "${WEB_SITE}"
!insertmacro MUI_PAGE_FINISH

; --- Páginas do Desinstalador ---
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; --- Idioma ---
!insertmacro MUI_LANGUAGE "PortugueseBR"

; --- Informações de Versão e Nome ---
Name "${APP_NAME}"
OutFile "synapse_setup.exe"
InstallDir "$PROGRAMFILES64\${APP_NAME}"
RequestExecutionLevel admin

; ---------------------------------------------------------
; Seção de Instalação
; ---------------------------------------------------------
Section "Principal" SecMain
    SetOutPath "$INSTDIR"

    ; 1. Arquivos do Synapse
    DetailPrint "Instalando binários do Synapse..."
    File "synapse.exe"
    
    ; 2. FFmpeg (Pasta completa)
    DetailPrint "Alocando motor FFmpeg no sistema..."
    File /r "${FFMPEG_DIR}"

    ; 3. Configuração do PATH do Windows
    DetailPrint "Registrando dependências no PATH do Sistema..."
    ReadRegStr $1 HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path"
    
    ; Verificamos se já existe para evitar duplicidade
    ${Unless} ${FileExists} "$INSTDIR\${FFMPEG_DIR}\bin"
        WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path" "$1;$INSTDIR\${FFMPEG_DIR}\bin"
        SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
    ${EndUnless}

    ; 4. Criar o Desinstalador
    WriteUninstaller "$INSTDIR\uninstall.exe"

    ; 5. Atalhos Organizáveis
    DetailPrint "Criando atalhos..."
    CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${EXE_NAME}" "" "$INSTDIR\${EXE_NAME}" 0
    
    CreateDirectory "$SMPROGRAMS\${APP_NAME}"
    CreateShortcut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${EXE_NAME}"
    CreateShortcut "$SMPROGRAMS\${APP_NAME}\Desinstalar.lnk" "$INSTDIR\uninstall.exe"

    ; 6. Registro no Painel de Controle (Adicionar Ícone e Tamanho)
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "DisplayName" "${APP_NAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "DisplayIcon" "$INSTDIR\${EXE_NAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "Publisher" "${COMP_NAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
SectionEnd

; ---------------------------------------------------------
; Seção de Desinstalação
; ---------------------------------------------------------
Section "Uninstall"
    ; Remove arquivos e pastas
    RMDir /r "$INSTDIR"
    
    ; Remove Atalhos
    Delete "$DESKTOP\${APP_NAME}.lnk"
    RMDir /r "$SMPROGRAMS\${APP_NAME}"

    ; Remove do Registro
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"
SectionEnd