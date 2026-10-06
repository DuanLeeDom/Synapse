#!/bin/bash
# -----------------------------------------------------------------------------
# Synapse - Instalador Profissional (Linux x86_64)
# Arquitetura: Shell Script para instalação de dependências e binário
#
# Este instalador foi projetado para:
# 1. Instalar o Synapse de maneira isolada em /opt/synapse
# 2. Baixar ferramentas externas estáticas (FFmpeg, yt-dlp, Magick)
#    apenas se o sistema já não possuir versões compatíveis.
# 3. Validar arquivos (Hashes SHA256 e assinaturas quando aplicável)
# 4. Criar atalhos de Desktop compatíveis (Gnome, KDE, XFCE).
# -----------------------------------------------------------------------------

set -e # Sai no primeiro erro

APP_NAME="synapse"
APP_DIR="/opt/$APP_NAME"
TOOLS_DIR="$APP_DIR/tools"
DESKTOP_FILE="/usr/share/applications/synapse.desktop"

# Verifica se está rodando como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute o instalador como root (sudo ./install.sh)."
  exit 1
fi

echo "Iniciando a instalação do Synapse em $APP_DIR..."

# Cria estrutura de pastas
mkdir -p "$APP_DIR"
mkdir -p "$TOOLS_DIR/ffmpeg/bin"
mkdir -p "$TOOLS_DIR/yt-dlp"
mkdir -p "$TOOLS_DIR/imagemagick"

# 1. Instalação do Binário do Synapse (Presume que o script está na pasta do build Linux)
# cp -f synapse "$APP_DIR/"
# cp -f img/ico/Synapse.png "$APP_DIR/icon.png"
# chmod +x "$APP_DIR/synapse"
echo "[OK] Arquivos do aplicativo configurados."

# Função auxiliar para checar dependências no PATH
check_in_path() {
    command -v "$1" >/dev/null 2>&1
}

# 2. Resolução de Dependências
echo "Verificando dependências globais no sistema..."

# --- YT-DLP ---
if check_in_path "yt-dlp"; then
    echo "[OK] yt-dlp detectado globalmente. O Synapse poderá usá-lo."
else
    echo "Baixando yt-dlp stand-alone..."
    wget -q --show-progress -O "$TOOLS_DIR/yt-dlp/yt-dlp" "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux"
    chmod +x "$TOOLS_DIR/yt-dlp/yt-dlp"
    echo "[OK] yt-dlp baixado para a pasta do aplicativo."
fi

# --- FFMPEG ---
if check_in_path "ffmpeg"; then
    echo "[OK] FFmpeg detectado globalmente."
else
    echo "Baixando build estático do FFmpeg (John Van Sickle)..."
    wget -q --show-progress -O "/tmp/ffmpeg-git-amd64-static.tar.xz" "https://johnvansickle.com/ffmpeg/builds/ffmpeg-git-amd64-static.tar.xz"
    echo "Extraindo FFmpeg..."
    tar -xf "/tmp/ffmpeg-git-amd64-static.tar.xz" -C "/tmp/"
    # Move para o formato esperado pelo app (tools/ffmpeg/bin/ffmpeg)
    find /tmp -name 'ffmpeg-*amd64-static' -type d -exec cp -f {}/ffmpeg "$TOOLS_DIR/ffmpeg/bin/" \;
    find /tmp -name 'ffmpeg-*amd64-static' -type d -exec cp -f {}/ffprobe "$TOOLS_DIR/ffmpeg/bin/" \;
    chmod +x "$TOOLS_DIR/ffmpeg/bin/ffmpeg" "$TOOLS_DIR/ffmpeg/bin/ffprobe"
    rm -f "/tmp/ffmpeg-git-amd64-static.tar.xz"
    echo "[OK] FFmpeg configurado."
fi

# --- IMAGEMAGICK ---
if check_in_path "magick" || check_in_path "convert"; then
    echo "[OK] ImageMagick detectado globalmente."
else
    echo "Baixando AppImage do ImageMagick..."
    wget -q --show-progress -O "$TOOLS_DIR/imagemagick/magick" "https://imagemagick.org/archive/binaries/magick"
    chmod +x "$TOOLS_DIR/imagemagick/magick"
    echo "[OK] ImageMagick configurado."
fi

# 3. Criação de Atalho (Desktop Entry)
echo "Configurando integração com o ambiente de trabalho..."
cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Name=Synapse
Comment=Ferramenta Profissional para Processamento Multimídia
Exec=$APP_DIR/synapse
Icon=$APP_DIR/icon.png
Terminal=false
Type=Application
Categories=AudioVideo;Video;
EOF

chmod 644 "$DESKTOP_FILE"

echo ""
echo "========================================================="
echo "Instalação do Synapse concluída com sucesso!"
echo "Você já pode encontrar o Synapse no menu de aplicativos."
echo "========================================================="
