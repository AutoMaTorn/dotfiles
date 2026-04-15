#!/bin/bash
set -e

DOTFILES_DIR="$HOME/dotfiles"
REPO_URL="https://github.com/automatorn/dotfiles.git"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip"
FONT_DIR="$HOME/.local/share/fonts"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Extract section from packages.txt
get_section() {
    local section="$1"
    local in_section=false
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        [[ "$line" == "[$section]" ]] && { in_section=true; continue; }
        [[ "$line" == \[*\] ]] && in_section=false
        $in_section && [[ -n "$line" && ! "$line" =~ ^# ]] && echo "$line"
    done < "$DOTFILES_DIR/packages.txt"
}

# OS / sudo checks
if ! grep -qiE "debian|ubuntu" /etc/os-release 2>/dev/null; then
    warn "This installer only supports Debian/Ubuntu."
    exit 1
fi

if [ "$EUID" -eq 0 ]; then
    warn "Do not run this script as root. Use a regular user with sudo access."
    exit 1
fi

if ! sudo -n true 2>/dev/null; then
    warn "This script requires sudo privileges for apt."
    sudo -v
fi

# Clone dotfiles if needed
if [ ! -d "$DOTFILES_DIR" ]; then
    info "Cloning dotfiles repository..."
    git clone "$REPO_URL" "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"

# Ensure non-free firmware repo is present
ensure_nonfree_firmware_repo() {
    if ! grep -riq "non-free-firmware" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
        warn "non-free-firmware apt component not found. Adding it..."
        echo "deb http://deb.debian.org/debian/ trixie main non-free-firmware" | sudo tee /etc/apt/sources.list.d/debian-nonfree-firmware.list >/dev/null
    fi
}
ensure_nonfree_firmware_repo

APT_PKGS=$(get_section "apt" | grep -v "^yandex-browser-stable$" | tr '\n' ' ')

# Install APT packages
if [ -n "$APT_PKGS" ]; then
    info "Updating package list..."
    sudo apt-get update
    info "Installing APT packages..."
    sudo apt-get install -y $APT_PKGS
fi

# Setup Flatpak & Flathub
FLATPAK_PKGS=$(get_section "flatpak" | tr '\n' ' ')
if [ -n "$FLATPAK_PKGS" ]; then
    info "Setting up Flatpak & Flathub..."
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    info "Installing Flatpak apps..."
    for app in $FLATPAK_PKGS; do
        sudo flatpak install -y --noninteractive flathub "$app" 2>/dev/null || warn "Failed to install flatpak: $app"
    done
fi

# Install Yandex Browser (3rd-party apt repo)
if get_section "apt" | grep -qx "yandex-browser-stable"; then
    if ! command -v yandex-browser &>/dev/null && ! command -v yandex-browser-stable &>/dev/null; then
        info "Installing Yandex Browser..."
        wget -qO - https://repo.yandex.ru/yandex-browser/YANDEX-BROWSER-KEY.GPG | sudo gpg --dearmor -o /usr/share/keyrings/yandex-browser.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/yandex-browser.gpg] https://repo.yandex.ru/yandex-browser/deb stable main" | sudo tee /etc/apt/sources.list.d/yandex-browser.list >/dev/null
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

# Unblock wireless devices
sudo rfkill unblock wifi 2>/dev/null || true
sudo rfkill unblock all 2>/dev/null || true
if rfkill list wifi 2>/dev/null | grep -q "Hard blocked: yes"; then
    warn "Wi-Fi is HARD BLOCKED (hardware switch / Fn key). Unblock it manually."
fi

# Ensure NetworkManager manages Wi-Fi interfaces
if [ -f /etc/network/interfaces ]; then
    sudo sed -i '/^[[:space:]]*auto[[:space:]]*wl/d' /etc/network/interfaces
    sudo sed -i '/^[[:space:]]*iface[[:space:]]*wl/d' /etc/network/interfaces
    sudo sed -i '/^[[:space:]]*allow-hotplug[[:space:]]*wl/d' /etc/network/interfaces
fi

# Clean wireless entries from interfaces.d as well
for f in /etc/network/interfaces.d/*; do
    [ -f "$f" ] || continue
    if grep -qE '^[[:space:]]*(auto|iface|allow-hotplug)[[:space:]]+wl' "$f" 2>/dev/null; then
        sudo sed -i '/^[[:space:]]*auto[[:space:]]*wl/d' "$f"
        sudo sed -i '/^[[:space:]]*iface[[:space:]]*wl/d' "$f"
        sudo sed -i '/^[[:space:]]*allow-hotplug[[:space:]]*wl/d' "$f"
    fi
done

# Force NetworkManager to manage interfaces even if they were in /etc/network/interfaces
if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
    if grep -q '^\[ifupdown\]' /etc/NetworkManager/NetworkManager.conf; then
        sudo sed -i '/^\[ifupdown\]/,/^\[/ s/^managed=.*/managed=true/' /etc/NetworkManager/NetworkManager.conf
    else
        echo -e "\n[ifupdown]\nmanaged=true" | sudo tee -a /etc/NetworkManager/NetworkManager.conf >/dev/null
    fi
fi

# Add user to netdev group for NetworkManager permissions
sudo usermod -aG netdev "$USER" 2>/dev/null || true

# Allow users in netdev group to manage networks without password
sudo mkdir -p /etc/polkit-1/rules.d
sudo tee /etc/polkit-1/rules.d/10-network-manager.rules >/dev/null <<'EOF'
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.NetworkManager.") == 0 && subject.isInGroup("netdev")) {
        return polkit.Result.YES;
    }
});
EOF

# Restart NetworkManager and reload configuration
sudo systemctl restart NetworkManager 2>/dev/null || true
sleep 1
sudo nmcli general reload 2>/dev/null || true
nmcli radio wifi on 2>/dev/null || true

# Symlink configs
info "Creating symlinks for dotfiles..."

backup_and_link() {
    local src="$1" dst="$2"
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        mv "$dst" "$dst.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    ln -s "$src" "$dst"
}

mkdir -p "$HOME/.config"

links=(
    "$DOTFILES_DIR/.config/i3:$HOME/.config/i3"
    "$DOTFILES_DIR/.config/polybar:$HOME/.config/polybar"
    "$DOTFILES_DIR/.config/rofi:$HOME/.config/rofi"
    "$DOTFILES_DIR/.config/kitty:$HOME/.config/kitty"
    "$DOTFILES_DIR/.config/fastfetch:$HOME/.config/fastfetch"
    "$DOTFILES_DIR/.config/wallpapers:$HOME/.config/wallpapers"
    "$DOTFILES_DIR/zsh/.zshrc:$HOME/.zshrc"
)

for pair in "${links[@]}"; do
    IFS=':' read -r src dst <<< "$pair"
    backup_and_link "$src" "$dst"
done

if [ -f "$DOTFILES_DIR/.config/picom.conf" ]; then
    backup_and_link "$DOTFILES_DIR/.config/picom.conf" "$HOME/.config/picom.conf"
fi

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    info "Oh My Zsh already installed."
fi

# Install Nerd Font
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

# Set Zsh as default shell
if [ "$SHELL" != "$(which zsh)" ]; then
    info "Changing default shell to zsh..."
    chsh -s "$(which zsh)"
else
    info "Zsh is already the default shell."
fi

# Enable services
sudo systemctl enable --now bluetooth 2>/dev/null || true
sudo systemctl enable --now NetworkManager 2>/dev/null || true
sudo systemctl enable lightdm 2>/dev/null || true

# Done
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Reboot your system."
echo "  2. LightDM login screen will appear — choose i3 and log in."
echo ""
echo "You can edit $DOTFILES_DIR/packages.txt and rerun this script to install additional packages."
