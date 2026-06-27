#!/bin/sh
# shellcheck shell=dash

RELEASE_REPO="${RELEASE_REPO:-sentiox/HarpyNet-Router}"
REPO="https://api.github.com/repos/${RELEASE_REPO}/releases/latest"
RELEASE_PAGE="https://github.com/${RELEASE_REPO}/releases"
DOWNLOAD_DIR="/tmp/harpynet"
CONFIG_PATH="/etc/config/harpynet"
COUNT=3

CONFIG_BACKUP=""
PKG_IS_APK=0
command -v apk >/dev/null 2>&1 && PKG_IS_APK=1

msg() {
    printf "\033[32;1m%s\033[0m\n" "$1"
}

warn() {
    printf "\033[33;1m%s\033[0m\n" "$1"
}

backup_config() {
    if [ -n "$CONFIG_BACKUP" ]; then
        return
    fi

    if [ -f "$CONFIG_PATH" ]; then
        CONFIG_BACKUP="/tmp/harpynet-config-backup-$(date +%s)"
        cp -p "$CONFIG_PATH" "$CONFIG_BACKUP"
        msg "Existing HarpyNet config saved: $CONFIG_BACKUP"
    fi
}

restore_config() {
    if [ -n "$CONFIG_BACKUP" ] && [ -f "$CONFIG_BACKUP" ]; then
        cp -p "$CONFIG_BACKUP" "$CONFIG_PATH"
        msg "Existing HarpyNet config restored. Settings were not reset."
    fi
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

pkg_list_update() {
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk update
    else
        opkg update
    fi
}

pkg_install() {
    local pkg_file="$1"

    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk add --allow-untrusted "$pkg_file"
    else
        opkg install "$pkg_file"
    fi
}

download_packages() {
    local grep_url_pattern

    if [ "$PKG_IS_APK" -eq 1 ]; then
        grep_url_pattern='https://[^"[:space:]]*\.apk'
    else
        grep_url_pattern='https://[^"[:space:]]*\.ipk'
    fi

    wget -qO- "$REPO" | grep -o "$grep_url_pattern" | while read -r url; do
        filename=$(basename "$url")
        filepath="$DOWNLOAD_DIR/$filename"
        attempt=0

        while [ "$attempt" -lt "$COUNT" ]; do
            msg "Download $filename (count $((attempt + 1)))..."
            if wget -q -O "$filepath" "$url"; then
                if [ -s "$filepath" ]; then
                    msg "$filename successfully downloaded"
                    break
                fi
            fi
            warn "Download error for $filename. Retrying..."
            rm -f "$filepath"
            attempt=$((attempt + 1))
        done

        if [ "$attempt" -eq "$COUNT" ]; then
            warn "Failed to download $filename after $COUNT attempts"
        fi
    done

    if ! ls "$DOWNLOAD_DIR"/*harpynet* >/dev/null 2>&1; then
        warn "No packages were downloaded successfully"
        exit 1
    fi
}

install_core_packages() {
    local pkg
    local file
    local f

    for pkg in harpynet luci-app-harpynet; do
        file=""
        for f in "$DOWNLOAD_DIR"/"$pkg"*; do
            if [ -f "$f" ]; then
                file=$(basename "$f")
                break
            fi
        done

        if [ -n "$file" ]; then
            msg "Installing $file..."
            pkg_install "$DOWNLOAD_DIR/$file"
            sleep 3
        fi
    done
}

install_translation() {
    local ru
    local f
    local answer

    ru=""
    for f in "$DOWNLOAD_DIR"/luci-i18n-harpynet-ru*; do
        if [ -f "$f" ]; then
            ru=$(basename "$f")
            break
        fi
    done

    if [ -z "$ru" ]; then
        return
    fi

    if pkg_is_installed luci-i18n-harpynet-ru; then
        msg "Upgrading Russian translation..."
        pkg_remove luci-i18n-harpynet*
        pkg_install "$DOWNLOAD_DIR/$ru"
        return
    fi

    msg "Install Russian interface language? y/n"
    while true; do
        read -r -p '' answer
        case "$answer" in
            y|Y|yes|YES)
                pkg_remove luci-i18n-harpynet*
                pkg_install "$DOWNLOAD_DIR/$ru"
                break
                ;;
            n|N|no|NO)
                break
                ;;
            *)
                msg "Enter y or n"
                ;;
        esac
    done
}

check_system() {
    local model
    local openwrt_version
    local available_space
    local required_space
    local version
    local major
    local minor
    local patch

    model=$(cat /tmp/sysinfo/model)
    msg "Router model: $model"

    openwrt_version=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2 | cut -d'.' -f1)
    if [ "$openwrt_version" = "23" ]; then
        warn "OpenWrt 23.05 is not supported by current HarpyNet releases."
        warn "Use HarpyNet 0.4.11 for OpenWrt 23.05, or install dependencies manually."
        warn "Details: $RELEASE_PAGE"
        exit 1
    fi

    available_space=$(df /overlay | awk 'NR==2 {print $4}')
    required_space=15360
    if [ "$available_space" -lt "$required_space" ]; then
        warn "Error: Insufficient space in flash"
        warn "Available: $((available_space / 1024))MB"
        warn "Required: $((required_space / 1024))MB"
        exit 1
    fi

    if ! nslookup google.com >/dev/null 2>&1; then
        warn "DNS is not working."
        exit 1
    fi

    if command -v harpynet >/dev/null 2>&1; then
        version=$(/usr/bin/harpynet show_version 2>/dev/null | sed 's/^v//')
        if [ -n "$version" ]; then
            major=$(echo "$version" | cut -d. -f1)
            minor=$(echo "$version" | cut -d. -f2)
            patch=$(echo "$version" | cut -d. -f3)

            if [ "$major" -gt 0 ] ||
                { [ "$major" -eq 0 ] && [ "$minor" -gt 7 ]; } ||
                { [ "$major" -eq 0 ] && [ "$minor" -eq 7 ] && [ "$patch" -ge 0 ]; }; then
                msg "HarpyNet version >= 0.7.0"
            else
                warn "Old HarpyNet version detected. Settings will be preserved during upgrade."
                backup_config
            fi
        else
            warn "Unknown HarpyNet version. Settings will be preserved during upgrade."
            backup_config
        fi
    fi

    if pkg_is_installed https-dns-proxy; then
        warn "Conflicting package detected: https-dns-proxy. Remove? yes/no"
        while true; do
            read -r -p '' answer
            case "$answer" in
                yes|y|Y)
                    pkg_remove luci-app-https-dns-proxy
                    pkg_remove https-dns-proxy
                    pkg_remove luci-i18n-https-dns-proxy*
                    break
                    ;;
                *)
                    msg "Exit"
                    exit 1
                    ;;
            esac
        done
    fi
}

sing_box() {
    local sing_box_version
    local required_version

    if ! pkg_is_installed "^sing-box"; then
        return
    fi

    sing_box_version=$(sing-box version | head -n 1 | awk '{print $3}')
    required_version="1.12.4"

    if [ "$(printf '%s\n%s\n' "$sing_box_version" "$required_version" | sort -V | head -n 1)" != "$required_version" ]; then
        warn "sing-box version $sing_box_version is older than required $required_version."
        warn "Removing old version..."
        service harpynet stop
        pkg_remove sing-box
    fi
}

main() {
    rm -rf "$DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR"

    check_system
    sing_box

    /usr/sbin/ntpd -q -p 194.190.168.1 -p 216.239.35.0 -p 216.239.35.4 -p 162.159.200.1 -p 162.159.200.123

    pkg_list_update || { warn "Packages list update failed"; exit 1; }

    if [ -f "/etc/init.d/harpynet" ]; then
        msg "HarpyNet is already installed. Upgrading without resetting settings..."
        backup_config
        trap restore_config EXIT
    else
        msg "Installing HarpyNet..."
    fi

    if command -v curl >/dev/null 2>&1; then
        check_response=$(curl -s "$REPO")
        if echo "$check_response" | grep -q 'API rate limit '; then
            warn "GitHub API rate limit reached. Repeat in five minutes."
            exit 1
        fi
    fi

    download_packages
    install_core_packages
    restore_config
    install_translation

    find "$DOWNLOAD_DIR" -type f -name '*harpynet*' -exec rm {} \;
    msg "HarpyNet installation/update finished."
}

main
