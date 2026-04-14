#!/bin/bash
set -e

# ============================================
# Dotfiles Bootstrap Installer for Debian
# ============================================

DOTFILES_DIR="$HOME/dotfiles"
REPO_URL="https://github.com/GITHUB_USER/dotfiles.git"
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
