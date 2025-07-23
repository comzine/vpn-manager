#!/bin/bash
# uninstall-macos.sh - Optimierte Version

set -e

APP_NAME="vpn-web"
INSTALL_DIR="/usr/local/bin"
WEB_INSTALL_DIR="/usr/local/share/vpn-web"
SERVICE_NAME="com.vpnweb"
PLIST_FILE="$HOME/Library/LaunchAgents/$SERVICE_NAME.plist"

warn() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log() { echo -e "\033[0;34m[INFO]\033[0m $1"; }

echo "🗑️  VPN Manager Uninstaller"
echo ""
warn "This will remove:"
echo "  • Binary: $INSTALL_DIR/$APP_NAME"
echo "  • Web assets: $WEB_INSTALL_DIR"
echo "  • LaunchAgent: $PLIST_FILE"
echo "  • Configuration files (optional)"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo ""
[[ ! $REPLY =~ ^[Yy]$ ]] && { log "Cancelled."; exit 0; }

# Service stoppen
if launchctl list | grep -q "$SERVICE_NAME" 2>/dev/null; then
    log "Stopping service..."
    launchctl stop "$SERVICE_NAME" 2>/dev/null || true
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    success "Service stopped"
fi

# Dateien entfernen
[[ -f "$PLIST_FILE" ]] && { rm "$PLIST_FILE"; success "LaunchAgent removed"; }
[[ -f "$INSTALL_DIR/$APP_NAME" ]] && { sudo rm "$INSTALL_DIR/$APP_NAME"; success "Binary removed"; }
[[ -d "$WEB_INSTALL_DIR" ]] && { sudo rm -rf "$WEB_INSTALL_DIR"; success "Web assets removed"; }

# Konfiguration (optional)
config_files=("$HOME/.vpn_web_settings.json" "$HOME/.vpn_certificates")
found_config=false
for file in "${config_files[@]}"; do
    [[ -e "$file" ]] && { echo "  • $file"; found_config=true; }
done

if $found_config; then
    echo ""
    read -p "Delete configuration files? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for file in "${config_files[@]}"; do
            [[ -e "$file" ]] && { rm -rf "$file"; success "Removed: $file"; }
        done
    fi
fi

# Logs (optional)
log_files=("$HOME/Library/Logs/$APP_NAME.log" "$HOME/Library/Logs/$APP_NAME.error.log")
if [[ -f "${log_files[0]}" ]] || [[ -f "${log_files[1]}" ]]; then
    read -p "Delete log files? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "${log_files[@]}"
        success "Log files removed"
    fi
fi

success "🎉 VPN Manager uninstalled!"
echo ""
log "Dependencies (not removed automatically):"
echo "  • OpenConnect: brew uninstall openconnect"
echo "  • vpn-slice: pip3 uninstall vpn-slice"
echo "  • Homebrew: see https://brew.sh/"
