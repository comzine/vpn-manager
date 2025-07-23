#!/bin/bash
# check-files.sh

echo "🔍 Checking VPN Manager file structure..."

# Aktuelles Verzeichnis
echo "Current directory: $(pwd)"
echo ""

# Web-Verzeichnis prüfen
echo "📁 Checking web directory structure:"
if [[ -d "web" ]]; then
    echo "✅ web/ directory exists"
    
    if [[ -d "web/templates" ]]; then
        echo "✅ web/templates/ directory exists"
        if [[ -f "web/templates/index.html" ]]; then
            echo "✅ web/templates/index.html exists"
        else
            echo "❌ web/templates/index.html NOT found"
        fi
    else
        echo "❌ web/templates/ directory NOT found"
    fi
    
    if [[ -d "web/static" ]]; then
        echo "✅ web/static/ directory exists"
        if [[ -d "web/static/css" ]]; then
            echo "✅ web/static/css/ directory exists"
        fi
        if [[ -d "web/static/js" ]]; then
            echo "✅ web/static/js/ directory exists"
        fi
    else
        echo "❌ web/static/ directory NOT found"
    fi
else
    echo "❌ web/ directory NOT found"
fi

echo ""

# Binary prüfen
echo "📦 Checking binary:"
if [[ -f "vpn-web" ]]; then
    echo "✅ vpn-web binary exists"
else
    echo "❌ vpn-web binary NOT found"
    echo "   Run: go build -o vpn-web ."
fi

echo ""

# Installation prüfen
echo "🏗️  Checking installation:"
if [[ -f "/usr/local/bin/vpn-web" ]]; then
    echo "✅ /usr/local/bin/vpn-web exists"
else
    echo "❌ /usr/local/bin/vpn-web NOT found"
fi

if [[ -d "/usr/local/share/vpn-web/web" ]]; then
    echo "✅ /usr/local/share/vpn-web/web exists"
    if [[ -f "/usr/local/share/vpn-web/web/templates/index.html" ]]; then
        echo "✅ Installed template exists"
    else
        echo "❌ Installed template NOT found"
    fi
else
    echo "❌ /usr/local/share/vpn-web/web NOT found"
fi

echo ""

# LaunchAgent prüfen
echo "🚀 Checking autostart:"
LAUNCHAGENT_FILE="$HOME/Library/LaunchAgents/com.vpnweb.plist"
if [[ -f "$LAUNCHAGENT_FILE" ]]; then
    echo "✅ LaunchAgent exists"
    if launchctl list | grep -q "com.vpnweb"; then
        echo "✅ Service is loaded"
    else
        echo "❌ Service is NOT loaded"
    fi
else
    echo "❌ LaunchAgent NOT found"
fi

echo ""
echo "💡 If files are missing, run the appropriate script:"
echo "   • Missing web files: Check your project structure"
echo "   • Missing binary: go build -o vpn-web ."
echo "   • Missing installation: ./install-macos.sh"
echo "   • Missing autostart: ./setup-autostart.sh"
