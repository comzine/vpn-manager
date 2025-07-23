#!/bin/bash
# install-macos.sh - Optimierte Version mit Pfad-Fix

set -e

# Konfiguration
APP_NAME="vpn-web"
INSTALL_DIR="/usr/local/bin"
WEB_INSTALL_DIR="/usr/local/share/vpn-web"
VPNSLICE_DIR="$HOME/.bin/vpnslice_python"
VPNSLICE_SCRIPT="$HOME/.bin/vpnslice"
SUDOERS_FILE="/etc/sudoers.d/openconnect"

# Script-Verzeichnis ermitteln
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Validierung mit absoluten Pfaden
echo "🔍 Checking files in: $(pwd)"

[[ "$OSTYPE" != "darwin"* ]] && error "Nur für macOS"

# Prüfe ob Binary existiert
if [[ ! -f "$SCRIPT_DIR/$APP_NAME" ]]; then
    echo "❌ Binary '$APP_NAME' nicht gefunden in: $SCRIPT_DIR"
    echo "📁 Verfügbare Dateien:"
    ls -la "$SCRIPT_DIR" | head -10
    error "Kompilieren Sie zuerst: go build -o $APP_NAME ."
fi

# Prüfe ob Web-Verzeichnis existiert
if [[ ! -d "$SCRIPT_DIR/web" ]]; then
    echo "❌ Web-Verzeichnis nicht gefunden in: $SCRIPT_DIR"
    echo "📁 Verfügbare Verzeichnisse:"
    ls -la "$SCRIPT_DIR" | grep "^d"
    error "Web-Verzeichnis nicht gefunden"
fi

echo "✅ Files found:"
echo "  • Binary: $SCRIPT_DIR/$APP_NAME"
echo "  • Web dir: $SCRIPT_DIR/web"
echo ""

echo "🚀 Installing VPN Manager..."

# Homebrew installieren/prüfen
if ! command -v brew &>/dev/null; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Homebrew zu PATH hinzufügen
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    success "Homebrew installed"
else
    success "Homebrew already installed"
fi

# Pakete installieren
log "Installing packages..."
packages=("openconnect" "expect" "python3")
for pkg in "${packages[@]}"; do
    if brew list "$pkg" &>/dev/null; then
        success "$pkg already installed"
    else
        brew install "$pkg" && success "$pkg installed"
    fi
done

# Python Version prüfen
PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1-2)
log "Python version: $PYTHON_VERSION"

# vpn-slice installieren - verschiedene Methoden je nach Python-Version
log "Setting up vpn-slice..."
mkdir -p "$HOME/.bin" "$VPNSLICE_DIR"

# Aktuelles Verzeichnis merken
ORIGINAL_DIR="$(pwd)"
cd "$VPNSLICE_DIR"

# Methode 1: Versuche pipenv (falls erlaubt)
if command -v pipenv &>/dev/null || pip3 install --user pipenv &>/dev/null; then
    log "Using pipenv method..."
    
    if [[ ! -f "Pipfile" ]]; then
        cat > Pipfile << 'EOF'
[[source]]
url = "https://pypi.org/simple"
verify_ssl = true
name = "pypi"

[packages]
vpn-slice = "*"

[requires]
python_version = "3"
EOF
    fi
    
    if pipenv install &>/dev/null; then
        # Wrapper-Script für pipenv
        cat > "$VPNSLICE_SCRIPT" << 'EOF'
#!/bin/zsh
cd "$HOME/.bin/vpnslice_python"
pipenv run vpn-slice "$@"
EOF
        chmod +x "$VPNSLICE_SCRIPT"
        success "vpn-slice installed with pipenv"
    else
        warn "pipenv failed, trying alternative method..."
        PIPENV_FAILED=true
    fi
else
    PIPENV_FAILED=true
fi

# Methode 2: Virtual Environment (Fallback)
if [[ "$PIPENV_FAILED" == "true" ]]; then
    log "Using virtual environment method..."
    
    # Alte Installation aufräumen
    rm -rf "$VPNSLICE_DIR"
    mkdir -p "$VPNSLICE_DIR"
    cd "$VPNSLICE_DIR"
    
    # Virtual Environment erstellen
    python3 -m venv venv
    source venv/bin/activate
    
    # vpn-slice installieren
    pip install vpn-slice
    deactivate
    
    # Wrapper-Script für venv
    cat > "$VPNSLICE_SCRIPT" << 'EOF'
#!/bin/zsh
cd "$HOME/.bin/vpnslice_python"
source venv/bin/activate
vpn-slice "$@"
deactivate
EOF
    chmod +x "$VPNSLICE_SCRIPT"
    success "vpn-slice installed with virtual environment"
fi

# Methode 3: Homebrew (letzter Ausweg)
if ! "$VPNSLICE_SCRIPT" --version >/dev/null 2>&1; then
    warn "Python methods failed, trying Homebrew..."
    
    if brew install vpn-slice &>/dev/null; then
        # Direkter Link zu Homebrew-Installation
        HOMEBREW_VPNSLICE="/opt/homebrew/bin/vpn-slice"
        if [[ ! -f "$HOMEBREW_VPNSLICE" ]]; then
            HOMEBREW_VPNSLICE="/usr/local/bin/vpn-slice"
        fi
        
        if [[ -f "$HOMEBREW_VPNSLICE" ]]; then
            ln -sf "$HOMEBREW_VPNSLICE" "$VPNSLICE_SCRIPT"
            success "vpn-slice installed via Homebrew"
        fi
    fi
fi

# Zurück zum ursprünglichen Verzeichnis
cd "$ORIGINAL_DIR"

# Finale Validierung
if "$VPNSLICE_SCRIPT" --version >/dev/null 2>&1; then
    success "vpn-slice setup successful"
    VPN_SLICE_VERSION=$("$VPNSLICE_SCRIPT" --version 2>&1 | head -n1)
    log "vpn-slice version: $VPN_SLICE_VERSION"
else
    error "vpn-slice installation failed. Please install manually: pip3 install --user vpn-slice"
fi

# Passwordless sudo konfigurieren
log "Configuring passwordless sudo..."
if [[ ! -f "$SUDOERS_FILE" ]]; then
    sudo tee "$SUDOERS_FILE" << EOF > /dev/null
# VPN Manager - passwordless sudo
$(whoami) ALL=(ALL) NOPASSWD: /opt/homebrew/bin/openconnect, /usr/local/bin/openconnect, /usr/bin/openconnect, /usr/sbin/openconnect
$(whoami) ALL=(ALL) NOPASSWD: /bin/kill, /usr/bin/kill
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/killall openconnect
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/pkill -f openconnect
$(whoami) ALL=(ALL) NOPASSWD: /bin/rm /tmp/openconnect.pid
$(whoami) ALL=(ALL) NOPASSWD: /bin/chmod /etc/hosts
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/tee /etc/hosts
$(whoami) ALL=(ALL) NOPASSWD: /sbin/route add *, /sbin/route delete *
EOF
    sudo chmod 440 "$SUDOERS_FILE"
    success "Passwordless sudo configured"
else
    success "Passwordless sudo already configured"
fi

# Binary und Web-Assets installieren mit absoluten Pfaden
log "Installing binary and web assets..."
log "Source binary: $SCRIPT_DIR/$APP_NAME"
log "Target binary: $INSTALL_DIR/$APP_NAME"
log "Source web: $SCRIPT_DIR/web"
log "Target web: $WEB_INSTALL_DIR"

# Binary kopieren
if [[ -f "$SCRIPT_DIR/$APP_NAME" ]]; then
    sudo cp "$SCRIPT_DIR/$APP_NAME" "$INSTALL_DIR/$APP_NAME"
    sudo chmod +x "$INSTALL_DIR/$APP_NAME"
    success "Binary installed"
else
    error "Binary not found: $SCRIPT_DIR/$APP_NAME"
fi

# Web-Assets kopieren
if [[ -d "$SCRIPT_DIR/web" ]]; then
    sudo mkdir -p "$WEB_INSTALL_DIR"
    sudo cp -r "$SCRIPT_DIR/web" "$WEB_INSTALL_DIR/"
    sudo chown -R "$(whoami):staff" "$WEB_INSTALL_DIR"
    success "Web assets installed"
else
    error "Web directory not found: $SCRIPT_DIR/web"
fi

success "🎉 Installation completed!"

# Zusammenfassung
cat << EOF

📋 Installed components:
  • Binary: $INSTALL_DIR/$APP_NAME
  • Web assets: $WEB_INSTALL_DIR/web
  • OpenConnect: $(which openconnect)
  • vpn-slice: $VPNSLICE_SCRIPT
  • Passwordless sudo: $SUDOERS_FILE

🚀 Usage:
  • Start: $INSTALL_DIR/$APP_NAME
  • Web interface: http://localhost:8080

🔧 Next steps:
  1. Test: $APP_NAME
  2. Setup autostart: ./setup-autostart.sh
  3. Configure VPN settings in web interface

💡 Troubleshooting:
  • Logs: Check terminal output
  • Permissions: Ensure passwordless sudo works
  • VPN-slice: Test with: $VPNSLICE_SCRIPT --version
EOF
