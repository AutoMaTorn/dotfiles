#!/bin/bash
set -e

# ============================================
# Dotfiles Bootstrap Installer for Debian
# ============================================

DOTFILES_DIR="$HOME/dotfiles"
REPO_URL="https://github.com/automatorn/dotfiles"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip"
FONT_DIR="$HOME/.local/share/fonts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================
# OS Check
# ============================================
if ! grep -qiE "debian|ubuntu" /etc/os-release 2>/dev/null; then
    error "This installer only supports Debian/Ubuntu."
    exit 1
fi

# ============================================
# Sudo check
# ============================================
if [ "$EUID" -eq 0 ]; then
    error "Do not run this script as root. Use a regular user with sudo access."
    exit 1
fi

if ! sudo -n true 2>/dev/null; then
    warn "This script requires sudo privileges for apt."
    sudo -v
fi

# ============================================
# Clone dotfiles if running via curl
# ============================================
if [ ! -d "$DOTFILES_DIR" ]; then
    info "Cloning dotfiles repository..."
    git clone "$REPO_URL" "$DOTFILES_DIR"
else
    info "Dotfiles directory already exists."
fi

cd "$DOTFILES_DIR"

# ============================================
# Install packages from packages.txt
# ============================================
if [ -f "$DOTFILES_DIR/packages.txt" ]; then
    info "Updating package list..."
    sudo apt-get update

    info "Installing packages from packages.txt..."
    PKGS=$(grep -v '^#' "$DOTFILES_DIR/packages.txt" | grep -v '^$' | tr '\n' ' ')
    if [ -n "$PKGS" ]; then
        sudo apt-get install -y $PKGS
    fi
else
    warn "packages.txt not found. Skipping package installation."
fi

# ============================================
# Setup Flatpak & Flathub
# ============================================
info "Setting up Flatpak..."
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

# ============================================
# Install Flatpak apps
# ============================================
info "Installing Flatpak apps..."
flatpak install -y flathub com.spotify.Client 2>/dev/null || warn "Spotify installation failed"
flatpak install -y flathub org.telegram.desktop 2>/dev/null || warn "Telegram installation failed"

# ============================================
# Install Discord
# ============================================
if ! command -v discord &> /dev/null; then
    info "Installing Discord..."
    wget -q "https://discord.com/api/download?platform=linux&format=deb" -O /tmp/discord.deb
    sudo apt-get install -y /tmp/discord.deb
    rm -f /tmp/discord.deb
else
    info "Discord already installed."
fi

# ============================================
# Install Yandex Browser
# ============================================
if ! command -v yandex-browser &> /dev/null && ! command -v yandex-browser-stable &> /dev/null; then
    info "Installing Yandex Browser..."
    wget -qO - https://repo.yandex.ru/yandex-browser/YANDEX-BROWSER-KEY.GPG | sudo gpg --dearmor -o /usr/share/keyrings/yandex-browser.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/yandex-browser.gpg] https://repo.yandex.ru/yandex-browser/deb stable main" | sudo tee /etc/apt/sources.list.d/yandex-browser.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y yandex-browser-stable
else
    info "Yandex Browser already installed."
fi

# ============================================
# Install v2rayN
# ============================================
if [ ! -d "$HOME/Apps/v2rayN" ]; then
    info "Installing v2rayN..."
    mkdir -p "$HOME/Apps"
    V2RAY_URL=$(curl -sL https://api.github.com/repos/2dust/v2rayN/releases/latest | grep -oP '"browser_download_url": "\K[^"]*linux-x64\.zip' | head -n 1)
    if [ -n "$V2RAY_URL" ]; then
        wget -q "$V2RAY_URL" -O /tmp/v2rayN.zip
        unzip -q /tmp/v2rayN.zip -d "$HOME/Apps/v2rayN"
        rm -f /tmp/v2rayN.zip
        # Create simple launcher
        mkdir -p "$HOME/.local/share/applications"
        cat > "$HOME/.local/share/applications/v2rayN.desktop" << 'EOF'
[Desktop Entry]
Name=v2rayN
Exec=/bin/bash -c "cd $HOME/Apps/v2rayN && ./v2rayN"
Icon=applications-internet
Type=Application
Categories=Network;
EOF
    else
        warn "Could not find v2rayN Linux release. Please install manually."
    fi
else
    info "v2rayN already installed."
fi

# ============================================
# Create symlinks for configs
# ============================================
info "Creating symlinks for dotfiles..."

backup_and_link() {
    local src="$1"
    local dst="$2"

    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        mv "$dst" "$dst.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    ln -s "$src" "$dst"
}

mkdir -p "$HOME/.config"

backup_and_link "$DOTFILES_DIR/.config/i3" "$HOME/.config/i3"
backup_and_link "$DOTFILES_DIR/.config/polybar" "$HOME/.config/polybar"
backup_and_link "$DOTFILES_DIR/.config/rofi" "$HOME/.config/rofi"
backup_and_link "$DOTFILES_DIR/.config/kitty" "$HOME/.config/kitty"
backup_and_link "$DOTFILES_DIR/.config/fastfetch" "$HOME/.config/fastfetch"
backup_and_link "$DOTFILES_DIR/.config/wallpapers" "$HOME/.config/wallpapers"

# picom.conf (if exists in dotfiles)
if [ -f "$DOTFILES_DIR/.config/picom.conf" ]; then
    backup_and_link "$DOTFILES_DIR/.config/picom.conf" "$HOME/.config/picom.conf"
fi

backup_and_link "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"

# ============================================
# Install Oh My Zsh
# ============================================
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    info "Oh My Zsh already installed."
fi

# ============================================
# Install Nerd Font
# ============================================
if ! fc-list | grep -qi "JetBrainsMono.*Nerd"; then
    info "Installing JetBrainsMono Nerd Font..."
    mkdir -p "$FONT_DIR"
    TMP_FONT=$(mktemp -d)
    wget -q "$FONT_URL" -O "$TMP_FONT/JetBrainsMono.zip"
    unzip -q "$TMP_FONT/JetBrainsMono.zip" -d "$FONT_DIR"
    rm -rf "$TMP_FONT"
    fc-cache -fv "$FONT_DIR" >/dev/null 2>&1
    info "Font installed."
else
    info "JetBrainsMono Nerd Font already installed."
fi

# ============================================
# Set Zsh as default shell
# ============================================
if [ "$SHELL" != "$(which zsh)" ]; then
    info "Changing default shell to zsh..."
    chsh -s "$(which zsh)"
else
    info "Zsh is already the default shell."
fi

# ============================================
# Enable services
# ============================================
sudo systemctl enable --now bluetooth 2>/dev/null || true
sudo systemctl enable --now NetworkManager 2>/dev/null || true

# ============================================
# Done
# ============================================
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Log out and log back in (or reboot)."
echo "  2. Run 'startx' to launch i3, or select i3 from your display manager."
echo ""
echo "You can edit $DOTFILES_DIR/packages.txt and rerun this script to install additional packages."
