@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ╔════════════════════════════════════════════════════════════╗
REM ║   DK DOWNLOADER - INSTALADOR INTELIGENTE PARA WINDOWS       ║
REM ║              Versión 2.0 - Auto-Setup                       ║
REM ╚════════════════════════════════════════════════════════════╝

title DK DOWNLOADER - WINDOWS (Instalador Inteligente)
color 0A

set "ZIP_URL_PRIMARY=https://raw.githubusercontent.com/carlosganzs/VPN-DF/main/midescargador.zip"
set "ZIP_URL_FALLBACK=https://github.com/carlosganzs/VPN-DF/raw/main/midescargador.zip"
set "PYTHON_URL_X64=https://www.python.org/ftp/python/3.11.8/python-3.11.8-amd64.exe"
set "PYTHON_URL_X86=https://www.python.org/ftp/python/3.11.8/python-3.11.8.exe"
set "BASE_DIR=%USERPROFILE%\VPN-DF"
set "ZIP_PATH=%BASE_DIR%\midescargador.zip"
set "SCRIPT_DIR=%~dp0"
set "PY_CMD="
set "FIRST_RUN=1"

goto :main

REM ╔════════════════════════════════════════════════════════════╗
REM ║            DETECCIÓN INTELIGENTE DE PYTHON                  ║
REM ╚════════════════════════════════════════════════════════════╝

:check_and_install_python_smartly
where py >nul 2>&1
if not errorlevel 1 (
    echo [+] Python ya detectado en PATH
    exit /b 0
)

where python >nul 2>&1
if not errorlevel 1 (
    echo [+] Python ya detectado en PATH
    exit /b 0
)

echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║  Python 3 no encontrado en tu sistema                      ║
echo ║  Se abrirá el navegador para descargar automáticamente    ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
echo [*] Detectando arquitectura del sistema...

REM Detectar si es 64 bits o 32 bits
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "ARCH=x64 (64 bits)"
    set "PYTHON_URL=!PYTHON_URL_X64!"
) else (
    set "ARCH=x86 (32 bits)"
    set "PYTHON_URL=!PYTHON_URL_X86!"
)

echo [+] Arquitectura detectada: !ARCH!
echo.
echo [*] Se abrirá el navegador para descargar Python...
echo [!] IMPORTANTE: Marca la opción "Add Python to PATH" durante la instalación
pause

REM Abre el navegador para descargar Python
start "" "https://www.python.org/downloads/windows/"

echo.
echo [+] Navegador abierto. Descarga e instala Python 3.
echo [!] RECUERDA: marca "Add Python to PATH" en el instalador
echo [*] Presiona ENTER cuando termines la instalación...
pause

REM Verifica si la instalación fue exitosa
where python >nul 2>&1
if errorlevel 1 (
    where py >nul 2>&1
    if errorlevel 1 (
        echo [-] Python aún no se detecta. Verifica la instalación.
        exit /b 1
    )
)

echo [+] Python instalado correctamente
exit /b 0

:detect_python
where py >nul 2>&1
if not errorlevel 1 (
    set "PY_CMD=py -3"
    exit /b 0
)

where python >nul 2>&1
if not errorlevel 1 (
    set "PY_CMD=python"
    exit /b 0
)

echo [-] No se encontro Python. Ejecutando instalador automático...
call :check_and_install_python_smartly
exit /b %ERRORLEVEL%

REM ╔════════════════════════════════════════════════════════════╗
REM ║           INSTALACIÓN DE DEPENDENCIAS                       ║
REM ╚════════════════════════════════════════════════════════════╝

:install_dependencies
echo.
echo [+] Instalando/Actualizando dependencias...
%PY_CMD% -m pip install --upgrade pip setuptools wheel >nul 2>&1

echo [*] Instalando dependencias Python (esto puede tomar 1-2 minutos)...
%PY_CMD% -m pip install --upgrade ^
    werkzeug flask flask-socketio requests beautifulsoup4 ^
    psutil cryptography flet aiofiles >nul 2>&1

if errorlevel 1 (
    echo [-] Fallo al instalar dependencias
    echo [!] Intenta ejecutar como administrador
    exit /b 1
)

echo [+] Dependencias instaladas correctamente
exit /b 0

REM ╔════════════════════════════════════════════════════════════╗
REM ║         DESCARGA Y EXTRACCIÓN DEL ZIP                       ║
REM ╚════════════════════════════════════════════════════════════╝

:download_and_extract
if not exist "%BASE_DIR%" mkdir "%BASE_DIR%"

echo.
echo [*] Descargando paquete (esto puede tomar unos momentos)...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { " ^
    "    $ProgressPreference = 'SilentlyContinue'; " ^
    "    Invoke-WebRequest -UseBasicParsing -Uri '%ZIP_URL_PRIMARY%' -OutFile '%ZIP_PATH%' -ErrorAction Stop; " ^
    "    Write-Host '[+] Descarga completada'; " ^
    "} catch { " ^
    "    Write-Host '[!] Usando URL alternativa...'; " ^
    "    $ProgressPreference = 'SilentlyContinue'; " ^
    "    Invoke-WebRequest -UseBasicParsing -Uri '%ZIP_URL_FALLBACK%' -OutFile '%ZIP_PATH%' -ErrorAction Stop; " ^
    "}" 2>nul

if errorlevel 1 (
    echo [-] Fallo al descargar el paquete
    exit /b 1
)

echo.
echo [*] Extrayendo archivos...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Expand-Archive -LiteralPath '%ZIP_PATH%' -DestinationPath '%BASE_DIR%' -Force" 2>nul

if errorlevel 1 (
    echo [-] Fallo al extraer el paquete
    exit /b 1
)

del /f /q "%ZIP_PATH%" >nul 2>&1

echo [+] Paquete extraído en: %BASE_DIR%
exit /b 0

REM ╔════════════════════════════════════════════════════════════╗
REM ║         INICIO DE LA APLICACIÓN                             ║
REM ╚════════════════════════════════════════════════════════════╝

:resolve_dk_path
set "DK_PATH="
if exist "%SCRIPT_DIR%dk.py" (
    set "DK_PATH=%SCRIPT_DIR%dk.py"
    exit /b 0
)

if exist "%BASE_DIR%\midescargador\dk.py" (
    set "DK_PATH=%BASE_DIR%\midescargador\dk.py"
    exit /b 0
)

for /f "delims=" %%F in ('dir /s /b "%BASE_DIR%\dk.py" 2^>nul') do (
    set "DK_PATH=%%F"
    exit /b 0
)

exit /b 1

:start_app
cls
call :resolve_dk_path
if errorlevel 1 (
    echo.
    echo [-] No se encontro dk.py
    echo [!] Usa la opcion 1 para instalar desde GitHub primero
    pause
    exit /b 1
)

for %%I in ("!DK_PATH!") do set "DK_DIR=%%~dpI"

echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║  Iniciando DK DOWNLOADER...                                ║
echo ║  La aplicación se abrirá en tu navegador (localhost:5000) ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
echo [+] Directorio: !DK_DIR!
echo [+] Python: !PY_CMD!
echo.

pushd "!DK_DIR!" >nul
if errorlevel 1 (
    echo [-] No se pudo entrar al directorio
    popd >nul
    exit /b 1
)

!PY_CMD! "!DK_PATH!"
set "RUN_EXIT=!ERRORLEVEL!"

popd >nul
exit /b !RUN_EXIT!

REM ╔════════════════════════════════════════════════════════════╗
REM ║         OPERACIONES AUTOMÁTICAS                             ║
REM ╚════════════════════════════════════════════════════════════╝

:auto_install
cls
echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║   INSTALACIÓN AUTOMÁTICA INTELIGENTE                       ║
echo ║        (Todo configurado para ti automáticamente)          ║
echo ╚════════════════════════════════════════════════════════════╝
echo.

echo [Paso 1/4] Verificando Python...
call :detect_python
if errorlevel 1 (
    echo [-] No se puede continuar sin Python
    pause
    exit /b 1
)
echo [✓] Python detectado: !PY_CMD!

echo.
echo [Paso 2/4] Instalando dependencias...
call :install_dependencies
if errorlevel 1 (
    echo [-] Fallo en la instalación de dependencias
    pause
    exit /b 1
)
echo [✓] Dependencias listas

echo.
echo [Paso 3/4] Descargando paquete...
call :download_and_extract
if errorlevel 1 (
    echo [-] Fallo al descargar/extraer
    pause
    exit /b 1
)
echo [✓] Paquete completo

echo.
echo [Paso 4/4] Iniciando aplicación...
call :start_app
exit /b %ERRORLEVEL%

REM ╔════════════════════════════════════════════════════════════╗
REM ║              MENÚ PRINCIPAL                                 ║
REM ╚════════════════════════════════════════════════════════════╝

:main
if %FIRST_RUN% equ 1 (
    set "FIRST_RUN=0"
    call :check_and_install_python_smartly
)

call :detect_python

:menu
cls
echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║        DK DOWNLOADER v2.0 - INSTALADOR WINDOWS            ║
echo ║                 (Versión Inteligente)                      ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
echo  Python: !PY_CMD!
echo.
echo  [1] Instalar desde GitHub (recomendado)
echo  [2] Iniciar (sin instalar)
echo  [3] Reparar Python
echo  [4] AUTO-INSTALAR (recomendado para principiantes)
echo  [0] Salir
echo.
echo ════════════════════════════════════════════════════════════
set /p option=Selecciona una opcion (0-4): 

if /I "%option%"=="1" (
    echo.
    echo [!] Limpiando instalación anterior...
    if exist "%BASE_DIR%" rmdir /s /q "%BASE_DIR%"
    
    call :install_dependencies
    if errorlevel 1 goto :menu
    
    call :download_and_extract
    if errorlevel 1 goto :menu
    
    call :start_app
    goto :menu
)

if /I "%option%"=="2" (
    call :start_app
    goto :menu
)

if /I "%option%"=="3" (
    echo [+] Reparando entorno Python...
    %PY_CMD% -m pip install --upgrade pip setuptools wheel
    call :install_dependencies
    pause
    goto :menu
)

if /I "%option%"=="4" (
    call :auto_install
    goto :menu
)

if /I "%option%"=="0" goto :end
if /I "%option%"=="q" goto :end

echo [!] Opcion invalida
timeout /t 2
goto :menu

:end
cls
echo.
echo [+] ¡Hasta luego!
echo.
timeout /t 2
exit /b 0
