#!/bin/bash
# install-macos.sh - Optimierte Version

set -e

# Konfiguration
APP_NAME="vpn-web"
INSTALL_DIR="/usr/local/bin"
WEB_INSTALL_DIR="/usr/local/share/vpn-web"
VPNSLICE_DIR="$HOME/.bin/vpnslice_python"
VPNSLICE_SCRIPT="$HOME/.bin/vpnslice"
SUDOERS_FILE="/etc/sudoers.d/openconnect"

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

# Validierung
[[ "$OSTYPE" != "darwin"* ]] && error "Nur für macOS"
[[ ! -f "$APP_NAME" ]] && error "Binary '$APP_NAME' nicht gefunden. Kompilieren Sie zuerst: go build -o $APP_NAME ."
[[ ! -d "web" ]] && error "Web-Verzeichnis nicht gefunden"

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

# pipenv installieren
if ! command -v pipenv &>/dev/null; then
    log "Installing pipenv..."
    pip3 install --user pipenv
    export PATH="$HOME/.local/bin:$PATH"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
    success "pipenv installed"
fi

# vpn-slice mit pipenv installieren
log "Setting up vpn-slice..."
mkdir -p "$HOME/.bin" "$VPNSLICE_DIR"
cd "$VPNSLICE_DIR"

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

pipenv install

# Wrapper-Script erstellen
cat > "$VPNSLICE_SCRIPT" << 'EOF'
#!/bin/zsh
cd "$HOME/.bin/vpnslice_python"
pipenv run vpn-slice "$@"
EOF

chmod +x "$VPNSLICE_SCRIPT"

if "$VPNSLICE_SCRIPT" --version >/dev/null 2>&1; then
    success "vpn-slice setup successful"
else
    warn "vpn-slice setup may have issues"
fi

cd - >/dev/null

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

# Binary und Web-Assets installieren
log "Installing binary and web assets..."
sudo cp "$APP_NAME" "$INSTALL_DIR/$APP_NAME"
sudo chmod +x "$INSTALL_DIR/$APP_NAME"
sudo mkdir -p "$WEB_INSTALL_DIR"
sudo cp -r web "$WEB_INSTALL_DIR/"
sudo chown -R "$(whoami):staff" "$WEB_INSTALL_DIR"

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
