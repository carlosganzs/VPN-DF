#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

log() {
  printf "\033[1;32m[+]\033[0m %s\n" "$1"
}

warn() {
  printf "\033[1;33m[!]\033[0m %s\n" "$1"
}

err() {
  printf "\033[1;31m[-]\033[0m %s\n" "$1" >&2
}

ZIP_URL_PRIMARY="https://raw.githubusercontent.com/carlosganzs/VPN-DF/main/midescargador.zip"
ZIP_URL_FALLBACK="https://github.com/carlosganzs/VPN-DF/raw/main/midescargador.zip"
BASE_DIR="$HOME/VPN-DF"
ZIP_PATH="$BASE_DIR/midescargador.zip"

mkdir -p "$BASE_DIR"

log "Actualizando repositorios de Termux"
pkg update -y

log "Instalando dependencias del sistema"
pkg install -y python python-pip curl unzip python-cryptography

log "Actualizando pip"
python -m pip install --upgrade pip

log "Instalando dependencias de Python"
pip install --upgrade werkzeug flask flask-socketio requests beautifulsoup4 flet psutil

if command -v termux-setup-storage >/dev/null 2>&1; then
  log "Solicitando permisos de almacenamiento"
  termux-setup-storage
  echo "Acepta el permiso en la ventana de Android y luego presiona ENTER para continuar."
  read -r
else
  warn "termux-setup-storage no está disponible. Continuando sin ese paso."
fi

log "Descargando código fuente"
if ! curl -fL --retry 3 --retry-delay 2 "$ZIP_URL_PRIMARY" -o "$ZIP_PATH"; then
  warn "Fallo en URL primaria, probando URL alterna"
  curl -fL --retry 3 --retry-delay 2 "$ZIP_URL_FALLBACK" -o "$ZIP_PATH"
fi

log "Extrayendo paquete"
unzip -o "$ZIP_PATH" -d "$BASE_DIR"

DK_PATH="$(find "$BASE_DIR" -type f -name dk.py | head -n 1 || true)"
if [[ -z "$DK_PATH" ]]; then
  err "No se encontró dk.py después de extraer el zip."
  exit 1
fi

DK_DIR="$(dirname "$DK_PATH")"
log "Iniciando dk.py desde: $DK_DIR"
cd "$DK_DIR"
exec python "$DK_PATH"
