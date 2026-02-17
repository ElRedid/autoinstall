#!/bin/bash

SCRIPT_VERSION="1.0.3"

BASE_DIR="/usr/local/autoinstall"
INSTALLED_FLAG="$BASE_DIR/.installed"
VERSION_FILE="$BASE_DIR/version.txt"

REMOTE_VERSION_URL="https://raw.githubusercontent.com/ElRedid/autoinstall/main/version.txt"
REMOTE_PACKAGE_URL="https://raw.githubusercontent.com/ElRedid/autoinstall/main/autoinstall.tar.gz"

TMP_PACKAGE="/opt/autoinstall.tar.gz"
INSTALL_DIR="/opt"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Este script debe ejecutarse como root"
        exit 1
    fi
}

has_internet() {
    curl -s --max-time 2 https://raw.githubusercontent.com > /dev/null 2>&1
}

is_installed() {
    [ -f "$INSTALLED_FLAG" ]
}

ensure_dialog() {
    if ! command -v dialog > /dev/null 2>&1; then
        if has_internet; then
            echo -e "\n\e[36mInstalando dialog...\e[0m\n"
            dnf install -y dialog > /dev/null 2>&1
            command -v dialog > /dev/null 2>&1 || {
                echo "ERROR: no se pudo instalar dialog"
                exit 1
            }
        else
            echo "ERROR: dialog no instalado y sin internet"
            exit 1
        fi
    fi
}

msg_auto() {
    dialog --title "InfoInstall" --infobox "$1" 8 40
    sleep 2
}

ask_update() {
    dialog --title "InfoInstall" --defaultno --yesno "$1" 8 50
    return $?
}

ensure_local_version() {
    mkdir -p "$BASE_DIR"
    if [ ! -f "$VERSION_FILE" ]; then
        echo "$SCRIPT_VERSION" > "$VERSION_FILE"
    fi
}

get_local_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE" | tr -d ' \n\r'
    else
        echo "$SCRIPT_VERSION"
    fi
}

get_remote_version() {
    curl -s --max-time 5 "$REMOTE_VERSION_URL" | tr -d ' \n\r'
}

install_package() {
(
    echo 10
    curl -L -s "$REMOTE_PACKAGE_URL" -o "$TMP_PACKAGE"

    echo 40
    rm -rf "$INSTALL_DIR/install"

    echo 70
    tar -xzf "$TMP_PACKAGE" -C "$INSTALL_DIR"

    echo 90
    rm -f "$TMP_PACKAGE"

    echo 100
    sleep 1
) | dialog --title "InfoInstall" --gauge "Descargando e instalando autoinstall" 8 50 0
}

initial_install() {
(
    echo 10
    dnf install -y curl > /dev/null 2>&1

    echo 25
    dnf install -y tar > /dev/null 2>&1

    echo 40
    dnf install -y gzip > /dev/null 2>&1

    echo 55
    mkdir -p "$BASE_DIR"

    echo 70
    touch "$INSTALLED_FLAG"

    echo 85
    sleep 1
) | dialog --title "InfoInstall" --gauge "Instalando dependencias iniciales" 8 50 0

    ensure_local_version
    install_package
}

check_update() {
    ensure_local_version

    LOCAL_VERSION=$(get_local_version)
    REMOTE_VERSION=$(get_remote_version)

    if [ -z "$REMOTE_VERSION" ]; then
        return
    fi

    if [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
        ask_update "Nueva version disponible $REMOTE_VERSION\nVersion actual $LOCAL_VERSION\n\nDesea actualizar?"
        if [ $? -eq 0 ]; then
            msg_auto "Actualizando sistema"
            install_package
            echo "$REMOTE_VERSION" > "$VERSION_FILE"
        fi
    fi
}

main_menu() {
    if [ -d /opt/install ]; then
        cd /opt/install && ./autoinstall.sh
    else
        msg_auto "Menu no disponible"
    fi
}

main() {

    check_root
    ensure_dialog
    clear

    if is_installed; then
        if has_internet; then
            check_update
        fi
        main_menu
    else
        if has_internet; then
            initial_install
            main_menu
        else
            msg_auto "Se requiere internet en la primera ejecucion"
            exit 1
        fi
    fi

}

main
