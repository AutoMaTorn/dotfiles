#!/bin/bash

DOTFILES_DIR="$HOME/dotfiles"
REPO_URL="https://github.com/automatorn/dotfiles.git"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip"
FONT_DIR="$HOME/.local/share/fonts"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

get_section() {
    awk -v sec="$1" '
        $0 == "[" sec "]" { in_sec=1; next }
        /^\[/ { in_sec=0 }
        in_sec && NF && $0 !~ /^#/ { print }
    ' "$DOTFILES_DIR/packages.txt"
}

# Checks
if ! grep -qiE "debian|ubuntu" /etc/os-release 2>/dev/null; then
    warn "Only Debian/Ubuntu are supported."; exit 1
fi
if [ "$EUID" -eq 0 ]; then
    warn "Do not run as root."; exit 1
fi
if ! sudo -n true 2>/dev/null; then
    warn "Sudo required for apt."; sudo -v
fi

# Clone
if [ ! -d "$DOTFILES_DIR" ]; then
    info "Cloning dotfiles..."
    git clone "$REPO_URL" "$DOTFILES_DIR"
fi
cd "$DOTFILES_DIR"

# Non-free firmware repo
if ! grep -riq "non-free-firmware" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
    warn "Adding non-free-firmware repo..."
    echo "deb http://deb.debian.org/debian/ trixie main non-free-firmware" | \
        sudo tee /etc/apt/sources.list.d/debian-nonfree-firmware.list >/dev/null
fi

APT_PKGS=$(get_section "apt" | grep -v "^yandex-browser-stable$" | tr '\n' ' ')
if [ -n "$APT_PKGS" ]; then
    info "Installing apt packages..."
    sudo apt-get update
    sudo apt-get install -y $APT_PKGS
fi

# PipeWire -> PulseAudio
if get_section "apt" | grep -qx "pulseaudio"; then
    info "Switching to PulseAudio..."
    systemctl --user stop pipewire pipewire-pulse wireplumber pipewire.socket pipewire-pulse.socket 2>/dev/null || true
    systemctl --user disable pipewire pipewire-pulse wireplumber pipewire.socket pipewire-pulse.socket 2>/dev/null || true
    systemctl --user enable pulseaudio 2>/dev/null || true
    systemctl --user start pulseaudio 2>/dev/null || true
fi

# Flatpak
FLATPAK_PKGS=$(get_section "flatpak" | tr '\n' ' ')
if [ -n "$FLATPAK_PKGS" ]; then
    info "Installing flatpak apps..."
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    for app in $FLATPAK_PKGS; do
        sudo flatpak install -y --noninteractive flathub "$app" 2>/dev/null || warn "Failed: $app"
    done
fi

# Yandex Browser
if get_section "apt" | grep -qx "yandex-browser-stable"; then
    if ! command -v yandex-browser &>/dev/null && ! command -v yandex-browser-stable &>/dev/null; then
        info "Installing Yandex Browser..."
        wget -qO - https://repo.yandex.ru/yandex-browser/YANDEX-BROWSER-KEY.GPG | \
            sudo gpg --dearmor -o /usr/share/keyrings/yandex-browser.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/yandex-browser.gpg] https://repo.yandex.ru/yandex-browser/deb stable main" | \
            sudo tee /etc/apt/sources.list.d/yandex-browser.list >/dev/null
        sudo apt-get update || warn "Yandex repo update failed"
        sudo apt-get install -y yandex-browser-stable || warn "Yandex Browser install failed"
    fi
fi

# Wireless
sudo rfkill unblock wifi all 2>/dev/null || true
if rfkill list wifi 2>/dev/null | grep -q "Hard blocked: yes"; then
    warn "Wi-Fi hard blocked — unblock manually (Fn key or switch)."
fi

# NetworkManager cleanup
if [ -f /etc/network/interfaces ]; then
    sudo sed -i -e '/^[[:space:]]*auto[[:space:]]*wl/d' \
        -e '/^[[:space:]]*iface[[:space:]]*wl/d' \
        -e '/^[[:space:]]*allow-hotplug[[:space:]]*wl/d' /etc/network/interfaces
fi
for f in /etc/network/interfaces.d/*; do
    [ -f "$f" ] || continue
    if grep -qE '^[[:space:]]*(auto|iface|allow-hotplug)[[:space:]]+wl' "$f" 2>/dev/null; then
        sudo sed -i -e '/^[[:space:]]*auto[[:space:]]*wl/d' \
            -e '/^[[:space:]]*iface[[:space:]]*wl/d' \
            -e '/^[[:space:]]*allow-hotplug[[:space:]]*wl/d' "$f"
    fi
done

if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
    if grep -q '^\[ifupdown\]' /etc/NetworkManager/NetworkManager.conf; then
        sudo sed -i '/^\[ifupdown\]/,/^\[/ s/^managed=.*/managed=true/' /etc/NetworkManager/NetworkManager.conf
    else
        echo -e "\n[ifupdown]\nmanaged=true" | sudo tee -a /etc/NetworkManager/NetworkManager.conf >/dev/null
    fi
fi

# User groups
sudo usermod -aG netdev,video "$USER" 2>/dev/null || true

# Polkit: combine NetworkManager + power into one file
sudo mkdir -p /etc/polkit-1/rules.d
sudo tee /etc/polkit-1/rules.d/51-local.rules >/dev/null <<'EOF'
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.NetworkManager.") == 0 && subject.isInGroup("netdev")) {
        return polkit.Result.YES;
    }
});
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.reboot" ||
         action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
         action.id == "org.freedesktop.login1.power-off" ||
         action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
         action.id == "org.freedesktop.login1.suspend" ||
         action.id == "org.freedesktop.login1.hibernate") &&
        subject.isInGroup("netdev") && subject.local && subject.active) {
        return polkit.Result.YES;
    }
});
EOF

sudo systemctl restart NetworkManager 2>/dev/null || true
sudo nmcli general reload 2>/dev/null || true
nmcli radio wifi on 2>/dev/null || true

# Symlinks
mkdir -p "$HOME/.config"

backup_and_link() {
    local src="$1" dst="$2"
    if [ -L "$dst" ]; then rm "$dst"
    elif [ -e "$dst" ]; then mv "$dst" "$dst.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    ln -s "$src" "$dst"
}

for pair in \
    "$DOTFILES_DIR/.config/i3:$HOME/.config/i3" \
    "$DOTFILES_DIR/.config/polybar:$HOME/.config/polybar" \
    "$DOTFILES_DIR/.config/rofi:$HOME/.config/rofi" \
    "$DOTFILES_DIR/.config/kitty:$HOME/.config/kitty" \
    "$DOTFILES_DIR/.config/fastfetch:$HOME/.config/fastfetch" \
    "$DOTFILES_DIR/.config/wallpapers:$HOME/.config/wallpapers" \
    "$DOTFILES_DIR/zsh/.zshrc:$HOME/.zshrc" \
    "$DOTFILES_DIR/.xinitrc:$HOME/.xinitrc"; do
    IFS=':' read -r src dst <<< "$pair"
    backup_and_link "$src" "$dst"
done

if [ -f "$DOTFILES_DIR/.config/picom.conf" ]; then
    backup_and_link "$DOTFILES_DIR/.config/picom.conf" "$HOME/.config/picom.conf"
fi

# Oh My Zsh + autosuggestions
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" 2>/dev/null || true
fi

# Nerd Font
if ! fc-list | grep -qi "JetBrainsMono.*Nerd"; then
    info "Installing JetBrainsMono Nerd Font..."
    mkdir -p "$FONT_DIR"
    tmp=$(mktemp -d)
    wget -q "$FONT_URL" -O "$tmp/JetBrainsMono.zip"
    unzip -q "$tmp/JetBrainsMono.zip" -d "$FONT_DIR"
    rm -rf "$tmp"
    fc-cache -fv "$FONT_DIR" >/dev/null 2>&1
fi

# Shell
[ "$SHELL" != "$(which zsh)" ] && chsh -s "$(which zsh)"

# Services
sudo systemctl enable --now bluetooth 2>/dev/null || true
sudo systemctl enable --now NetworkManager 2>/dev/null || true

# Display manager (greetd + tuigreet)
if command -v greetd &>/dev/null || dpkg -l greetd &>/dev/null; then
    info "Configuring greetd..."

    if id -u _greetd &>/dev/null; then GREETD_USER="_greetd"
    elif id -u greeter &>/dev/null; then GREETD_USER="greeter"
    else GREETD_USER="_greetd"; fi

    sudo mkdir -p /var/cache/tuigreet
    sudo chown "${GREETD_USER}:${GREETD_USER}" /var/cache/tuigreet
    sudo chmod 0755 /var/cache/tuigreet

    sudo mkdir -p /etc/greetd
    sudo tee /etc/greetd/config.toml >/dev/null <<EOF
[terminal]
vt = 2

[default_session]
command = "tuigreet --time --remember --cmd startx --power-shutdown '/usr/bin/systemctl poweroff' --power-reboot '/usr/bin/systemctl reboot'"
user = "${GREETD_USER}"
EOF

    sudo systemctl disable lightdm 2>/dev/null || true
    sudo systemctl stop lightdm 2>/dev/null || true
    sudo systemctl disable getty@tty2.service 2>/dev/null || true
    sudo systemctl stop getty@tty2.service 2>/dev/null || true
    sudo systemctl set-default graphical.target 2>/dev/null || true
    sudo systemctl enable greetd.service 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Done! Reboot to enter greetd → i3.${NC}"
echo -e "${GREEN}============================================${NC}"
