#!/bin/bash
# setup-autostart.sh - Optimierte Version

set -e

APP_NAME="vpn-web"
INSTALL_DIR="/usr/local/bin"
WEB_INSTALL_DIR="/usr/local/share/vpn-web"
SERVICE_NAME="com.vpnweb"
PLIST_FILE="$HOME/Library/LaunchAgents/$SERVICE_NAME.plist"

log() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; exit 1; }

[[ "$OSTYPE" != "darwin"* ]] && error "Nur für macOS"
[[ ! -f "$INSTALL_DIR/$APP_NAME" ]] && error "Binary nicht gefunden. Führen Sie zuerst ./install-macos.sh aus"

echo "🔧 Setting up autostart..."

# Existierenden Service stoppen
if launchctl list | grep -q "$SERVICE_NAME" 2>/dev/null; then
    log "Stopping existing service..."
    launchctl stop "$SERVICE_NAME" 2>/dev/null || true
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    sleep 2
fi

# LaunchAgent erstellen
mkdir -p "$(dirname "$PLIST_FILE")"
cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$SERVICE_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/$APP_NAME</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$WEB_INSTALL_DIR</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/$APP_NAME.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/$APP_NAME.error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin</string>
    </dict>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>LimitLoadToSessionType</key>
    <array>
        <string>Aqua</string>
    </array>
</dict>
</plist>
EOF

# Service starten
mkdir -p "$HOME/Library/Logs"
launchctl load "$PLIST_FILE"
sleep 2
launchctl start "$SERVICE_NAME"
sleep 3

# Status prüfen
if launchctl list | grep -q "$SERVICE_NAME"; then
    success "🎉 Autostart configured!"
    success "Service is running: $(launchctl list | grep "$SERVICE_NAME")"
    success "Web interface: http://localhost:8080"
    
    # Test Web-Interface
    if curl -s -f http://localhost:8080 >/dev/null 2>&1; then
        success "Web interface is responding!"
    else
        echo "⚠️  Web interface may need a moment to start"
    fi
else
    error "Service setup failed. Check logs: tail -f $HOME/Library/Logs/$APP_NAME.error.log"
fi

cat << EOF

📋 Autostart details:
  • Service: $SERVICE_NAME
  • Config: $PLIST_FILE
  • Logs: $HOME/Library/Logs/$APP_NAME.log
  • Web: http://localhost:8080

🔧 Management:
  • Start:   launchctl start $SERVICE_NAME
  • Stop:    launchctl stop $SERVICE_NAME
  • Status:  launchctl list | grep $SERVICE_NAME
  • Remove:  ./remove-autostart.sh
EOF
