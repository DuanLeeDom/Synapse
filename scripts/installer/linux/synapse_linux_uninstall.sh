#!/bin/bash
# -----------------------------------------------------------------------------
# Synapse - Desinstalador Seguro (Linux x86_64)
# 
# Remove as dependências próprias e o binário do Synapse.
# Não altera ferramentas globais.
# -----------------------------------------------------------------------------

APP_NAME="synapse"
APP_DIR="/opt/$APP_NAME"
DESKTOP_FILE="/usr/share/applications/synapse.desktop"

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute o desinstalador como root (sudo ./uninstall.sh)."
  exit 1
fi

echo "Removendo Synapse e suas dependências internas..."

# Remover atalho
if [ -f "$DESKTOP_FILE" ]; then
    rm -f "$DESKTOP_FILE"
    echo "Atalho removido."
fi

# Remover diretório de instalação (Incluindo tools)
if [ -d "$APP_DIR" ]; then
    rm -rf "$APP_DIR"
    echo "Arquivos do aplicativo e ferramentas isoladas removidos."
fi

echo "Synapse desinstalado com sucesso."
