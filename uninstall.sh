#!/bin/sh
# shellcheck shell=dash

PKG_IS_APK=0
command -v apk >/dev/null 2>&1 && PKG_IS_APK=1

CONFIG_PATH="/etc/config/harpynet"
BACKUP_PATH="/etc/config/harpynet.backup-before-uninstall"

msg() {
    printf "\033[32;1m%s\033[0m\n" "$1"
}

warn() {
    printf "\033[33;1m%s\033[0m\n" "$1"
}

pkg_is_installed() {
    local pkg_name="$1"

    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk list --installed | grep -q "$pkg_name"
    else
        opkg list-installed | grep -q "$pkg_name"
    fi
}

pkg_remove() {
    local pkg_name="$1"

    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk del "$pkg_name"
    else
        opkg remove --force-depends "$pkg_name"
    fi
}

remove_if_installed() {
    local pkg_name="$1"

    if pkg_is_installed "$pkg_name"; then
        msg "Removing $pkg_name..."
        pkg_remove "$pkg_name"
    else
        msg "$pkg_name is not installed"
    fi
}

stop_service() {
    if [ -x /etc/init.d/harpynet ]; then
        msg "Stopping HarpyNet..."
        /etc/init.d/harpynet stop >/dev/null 2>&1 || true
        /etc/init.d/harpynet disable >/dev/null 2>&1 || true
    fi
}

handle_config() {
    local answer

    if [ ! -f "$CONFIG_PATH" ]; then
        return
    fi

    cp -p "$CONFIG_PATH" "$BACKUP_PATH"
    msg "Config backup saved: $BACKUP_PATH"
    warn "Remove HarpyNet config too? yes/no"

    while true; do
        read -r -p '' answer
        case "$answer" in
            yes|YES|y|Y)
                rm -f "$CONFIG_PATH"
                msg "Config removed"
                break
                ;;
            no|NO|n|N|'')
                msg "Config kept: $CONFIG_PATH"
                break
                ;;
            *)
                msg "Enter yes or no"
                ;;
        esac
    done
}

cleanup_luci_cache() {
    rm -f /tmp/luci-indexcache
    rm -rf /tmp/luci-modulecache/*

    if [ -x /etc/init.d/rpcd ]; then
        /etc/init.d/rpcd restart >/dev/null 2>&1 || true
    fi
}

main() {
    stop_service

    remove_if_installed luci-i18n-harpynet-ru
    remove_if_installed luci-app-harpynet
    remove_if_installed harpynet

    handle_config
    cleanup_luci_cache

    msg "HarpyNet uninstall finished."
}

main
