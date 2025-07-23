#!/bin/bash
# remove-autostart.sh

set -e

SERVICE_NAME="com.vpnweb"
LAUNCHAGENT_FILE="$HOME/Library/LaunchAgents/com.vpnweb.plist"
APP_NAME="vpn-web"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo "🗑️  Removing VPN Manager autostart..."

# Service stoppen und entladen
if launchctl list | grep -q "$SERVICE_NAME" 2>/dev/null; then
    print_status "Stopping and unloading service..."
    launchctl stop "$SERVICE_NAME" 2>/dev/null || true
    sleep 2
    launchctl unload "$LAUNCHAGENT_FILE" 2>/dev/null || true
    print_success "Service stopped and unloaded"
else
    print_status "Service was not running"
fi

# LaunchAgent Datei löschen
if [[ -f "$LAUNCHAGENT_FILE" ]]; then
    rm "$LAUNCHAGENT_FILE"
    print_success "LaunchAgent configuration removed"
else
    print_status "LaunchAgent configuration not found"
fi

# Log-Dateien löschen (optional)
echo ""
read -p "Delete log files? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "$HOME/Library/Logs/$APP_NAME.log"
    rm -f "$HOME/Library/Logs/$APP_NAME.error.log"
    print_success "Log files removed"
else
    print_status "Log files kept"
fi

print_success "🎉 Autostart removed successfully!"
echo ""
echo "💡 The VPN Manager binary and web files are still installed."
echo "💡 You can still run the application manually: /usr/local/bin/$APP_NAME"
echo "💡 To completely uninstall, run: ./uninstall-macos.sh"
