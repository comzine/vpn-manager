#!/bin/bash
# build.sh - Build-Script

set -e

echo "🔨 Building VPN Manager..."

# Go-Version prüfen
if ! command -v go &> /dev/null; then
    echo "❌ Go nicht installiert. Installieren Sie Go von https://golang.org/"
    exit 1
fi

# Dependencies laden
echo "📦 Loading dependencies..."
go mod tidy

# Build
echo "🔧 Compiling..."
go build -ldflags="-s -w" -o vpn-web .

# Validierung
if [[ -f "vpn-web" ]]; then
    echo "✅ Build erfolgreich: vpn-web"
    echo "📁 Dateigröße: $(du -h vpn-web | cut -f1)"
    echo ""
    echo "🚀 Nächste Schritte:"
    echo "  1. ./install-macos.sh"
    echo "  2. ./setup-autostart.sh"
else
    echo "❌ Build fehlgeschlagen"
    exit 1
fi
