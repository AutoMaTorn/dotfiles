#!/bin/bash
set -e

# ============================================
# Dotfiles Bootstrap Installer for Debian
# ============================================

DOTFILES_DIR="$HOME/dotfiles"
REPO_URL="https://github.com/automatorn/dotfiles.git"
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
# Helper: extract section from packages.txt
# ============================================
get_section() {
    local section="$1"
    local file="$DOTFILES_DIR/packages.txt"
    local in_section=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

        if [[ "$line" == "[$section]" ]]; then
            in_section=true
            continue
        fi

        if [[ "$line" == \[*\] ]]; then
            in_section=false
            continue
        fi

        if $in_section && [[ -n "$line" ]] && [[ ! "$line" =~ ^# ]]; then
            echo "$line"
        fi
    done < "$file"
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
# Install APT packages
# ============================================
APT_PKGS=$(get_section "apt" | grep -v "^yandex-browser-stable$" | tr '\n' ' ')
if [ -n "$APT_PKGS" ]; then
    info "Updating package list..."
    sudo apt-get update

    info "Installing APT packages..."
    sudo apt-get install -y $APT_PKGS
else
    warn "No APT packages found in packages.txt"
fi

# ============================================
# Setup Flatpak & Flathub
# ============================================
FLATPAK_PKGS=$(get_section "flatpak" | tr '\n' ' ')
if [ -n "$FLATPAK_PKGS" ]; then
    info "Setting up Flatpak & Flathub..."
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

    info "Installing Flatpak apps..."
    for app in $FLATPAK_PKGS; do
        sudo flatpak install -y --noninteractive flathub "$app" 2>/dev/null || warn "Failed to install flatpak: $app"
    done
else
    warn "No Flatpak apps found in packages.txt"
fi

# ============================================
# Install 3rd-party APT packages
# ============================================
APT_PKGS_LIST=$(get_section "apt" | tr '\n' ' ')

# Yandex Browser (fallback to Firefox)
if echo "$APT_PKGS_LIST" | grep -qw "yandex-browser-stable"; then
    if ! command -v yandex-browser &> /dev/null && ! command -v yandex-browser-stable &> /dev/null; then
        info "Installing Yandex Browser..."
        wget -qO - https://repo.yandex.ru/yandex-browser/YANDEX-BROWSER-KEY.GPG | sudo gpg --dearmor -o /usr/share/keyrings/yandex-browser.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/yandex-browser.gpg] https://repo.yandex.ru/yandex-browser/deb stable main" | sudo tee /etc/apt/sources.list.d/yandex-browser.list > /dev/null
        info "Updating apt for Yandex Browser repository..."
        sudo apt-get update || warn "apt-get update failed for Yandex repo"
        if sudo apt-get install -y yandex-browser-stable; then
            info "Yandex Browser installed successfully."
        else
            warn "Failed to install yandex-browser-stable. Installing Firefox as fallback..."
            sudo apt-get install -y firefox-esr || sudo apt-get install -y firefox || warn "Failed to install Firefox fallback."
        fi
    else
        info "Yandex Browser already installed."
    fi
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
backup_and_link "$DOTFILES_DIR/zsh/.zprofile" "$HOME/.zprofile"
backup_and_link "$DOTFILES_DIR/.xinitrc" "$HOME/.xinitrc"

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
echo "  2. i3 will start automatically when you log into tty1."
echo ""
echo "You can edit $DOTFILES_DIR/packages.txt and rerun this script to install additional packages."
