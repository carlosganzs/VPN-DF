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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

is_termux() {
  [[ -n "${TERMUX_VERSION:-}" ]]
}

pause_continue() {
  printf "\nPresiona ENTER para continuar..."
  read -r
}

print_banner() {
  clear || true
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║                   DK DOWNLOADER                     ║"
  echo "║                Launcher interactivo                 ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo
}

install_dependencies() {
  log "Actualizando repositorios de Termux"
  pkg update -y

  log "Instalando dependencias del sistema"
  pkg install -y python python-pip curl unzip python-cryptography

  log "Instalando dependencias de Python"
  pip install --upgrade pip setuptools wheel
  pip install --upgrade werkzeug flask flask-socketio requests beautifulsoup4 flet psutil

  apply_armv8l_pip_workaround
}

apply_armv8l_pip_workaround() {
  # Algunos builds de Android/Termux reportan la máquina como armv8l y ciertas
  # versiones de pip/packaging no la mapean, provocando KeyError: 'armv8l'.
  local machine
  machine="$(python - <<'PY'
import platform
print(platform.machine())
PY
)"

  if [[ "$machine" != "armv8l" ]]; then
    return 0
  fi

  warn "Detectado armv8l: aplicando compatibilidad de pip para Android"

  python - <<'PY'
from pathlib import Path
import inspect

import pip._vendor.packaging.tags as tags

path = Path(tags.__file__).resolve()
src = path.read_text(encoding="utf-8")

# Caso 1: diccionario indexado directamente -> KeyError
patched = src.replace(
    '}[machine]',
    '}.get(machine, "armeabi_v7a" if machine == "armv8l" else machine)'
)

# Caso 2: tabla con armv7l pero sin armv8l
if '"armv7l": "armeabi_v7a"' in patched and '"armv8l": "armeabi_v7a"' not in patched:
    patched = patched.replace(
        '"armv7l": "armeabi_v7a"',
        '"armv7l": "armeabi_v7a",\n        "armv8l": "armeabi_v7a"'
    )

if patched != src:
    backup = path.with_suffix(path.suffix + ".bak")
    backup.write_text(src, encoding="utf-8")
    path.write_text(patched, encoding="utf-8")
    print(f"Parche aplicado: {path}")
else:
    print("No fue necesario parchear tags.py")
PY
}

setup_storage_permission() {
  if command -v termux-setup-storage >/dev/null 2>&1; then
    log "Solicitando permisos de almacenamiento"
    termux-setup-storage
    echo "Acepta el permiso en la ventana de Android y luego presiona ENTER para continuar."
    read -r
  else
    warn "termux-setup-storage no está disponible. Continuando sin ese paso."
  fi
}

find_dk_in_base() {
  find "$BASE_DIR" -type f -name dk.py | head -n 1 || true
}

resolve_dk_path() {
  if [[ -f "$SCRIPT_DIR/dk.py" ]]; then
    printf "%s\n" "$SCRIPT_DIR/dk.py"
    return 0
  fi

  local dk_path
  dk_path="$(find_dk_in_base)"
  if [[ -n "$dk_path" ]]; then
    printf "%s\n" "$dk_path"
    return 0
  fi

  return 1
}

download_and_extract_from_github() {
  mkdir -p "$BASE_DIR"

  log "Descargando código fuente"
  if ! curl -fL --retry 3 --retry-delay 2 "$ZIP_URL_PRIMARY" -o "$ZIP_PATH"; then
    warn "Fallo en URL primaria, probando URL alterna"
    curl -fL --retry 3 --retry-delay 2 "$ZIP_URL_FALLBACK" -o "$ZIP_PATH"
  fi

  log "Extrayendo paquete"
  unzip -o "$ZIP_PATH" -d "$BASE_DIR"
  rm -f "$ZIP_PATH"
}

start_app() {
  local dk_path
  dk_path="$(resolve_dk_path || true)"
  if [[ -z "$dk_path" ]]; then
    err "No se encontró dk.py. Usa la opción 1 para instalar desde GitHub."
    return 1
  fi

  local dk_dir
  dk_dir="$(dirname "$dk_path")"
  log "Iniciando dk.py desde: $dk_dir"
  cd "$dk_dir"
  exec python "$dk_path"
}

install_from_github() {
  warn "Borrando instalación actual en: $BASE_DIR"
  rm -rf "$BASE_DIR"
  mkdir -p "$BASE_DIR"

  install_dependencies
  setup_storage_permission
  download_and_extract_from_github

  log "Instalación completada. Iniciando aplicación..."
  start_app
}

repair_termux_repos_and_libs() {
  if ! is_termux; then
    warn "Esta reparación está pensada para Termux. Saltando..."
    return 0
  fi

  if command -v termux-change-repo >/dev/null 2>&1; then
    log "Abriendo termux-change-repo (elige mirror estable y confirma)"
    if ! termux-change-repo; then
      warn "termux-change-repo no se completó. Continuando con actualización igualmente."
    fi
  else
    warn "termux-change-repo no está disponible en este entorno."
  fi

  log "Ejecutando: apt update && apt full-upgrade"
  apt update
  apt full-upgrade -y

  log "Reparación de repositorios/librerías completada"
}

auto_fix_termux_if_needed() {
  if ! is_termux; then
    return 0
  fi

  local need_fix=0

  if [[ ! -d "$HOME/storage" ]]; then
    warn "No se detecta acceso de almacenamiento de Termux."
    need_fix=1
  fi

  if ! command -v python >/dev/null 2>&1; then
    warn "Python no está disponible en Termux."
    need_fix=1
  fi

  if ! command -v pkg >/dev/null 2>&1; then
    warn "No se encontró 'pkg'. Tu entorno de Termux parece incompleto."
    need_fix=1
  fi

  if [[ "$need_fix" -eq 1 ]]; then
    warn "Se detectaron problemas base. Ejecutando auto-reparación (equivalente a opción 3)."
    repair_termux_repos_and_libs
    if [[ ! -d "$HOME/storage" ]]; then
      setup_storage_permission
    fi
  fi
}

show_menu() {
  print_banner
  if is_termux; then
    echo "Entorno detectado: Termux (${TERMUX_VERSION})"
  else
    echo "Entorno detectado: Bash estándar (no Termux)"
  fi
  echo
  echo
  echo "==================== DK DOWNLOADER ===================="
  echo "1) Instalar desde GitHub (borra instalación actual y reinstala)"
  echo "2) Iniciar (sin instalar)"
  echo "3) Reparar Termux (repos/librerías/permisos)"
  echo "4) Auto diagnosticar y corregir (recomendado)"
  echo "0) Salir"
  echo "======================================================="
}

auto_doctor() {
  log "Ejecutando diagnóstico automático..."
  auto_fix_termux_if_needed
  if ! resolve_dk_path >/dev/null 2>&1; then
    warn "No se encontró dk.py. Instalando desde GitHub..."
    install_from_github
    return 0
  fi
  log "Diagnóstico completo. Intentando iniciar aplicación..."
  start_app
}

main() {
  auto_fix_termux_if_needed

  while true; do
    show_menu
    read -rp "Selecciona una opción: " option

    case "$option" in
      1)
        install_from_github
        ;;
      2)
        if ! start_app; then
          warn "No se pudo iniciar. Instala primero con la opción 1."
          pause_continue
        fi
        ;;
      3)
        repair_termux_repos_and_libs
        pause_continue
        ;;
      4)
        auto_doctor
        ;;
      0|q|Q|salir|SALIR)
        log "Saliendo."
        exit 0
        ;;
      *)
        warn "Opción inválida. Usa 1, 2, 3, 4 o 0."
        pause_continue
        ;;
    esac
  done
}

main
