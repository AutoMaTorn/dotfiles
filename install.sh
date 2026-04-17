#!/bin/bash

DOTFILES_DIR="$HOME/dotfiles"
REPO_URL="https://github.com/automatorn/dotfiles.git"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip"
FONT_DIR="$HOME/.local/share/fonts"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; }

get_section() {
    awk -v sec="$1" '
        $0 == "[" sec "]" { in_sec=1; next }
        /^\[/ { in_sec=0 }
        in_sec && NF && $0 !~ /^#/ { print }
    ' "$DOTFILES_DIR/packages.txt"
}

# ───────────────────────────────
# Hardware detection
# ───────────────────────────────

detect_formfactor() {
    if [ -d /sys/class/power_supply ]; then
        for bat in /sys/class/power_supply/BAT*; do
            [ -e "$bat" ] && { echo "laptop"; return; }
        done
    fi
    echo "desktop"
}

detect_gpu() {
    local gpu_info
    gpu_info=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' || true)

    # Prefer discrete GPU if present
    if echo "$gpu_info" | grep -qi 'nvidia'; then
        echo "nvidia"
    elif echo "$gpu_info" | grep -qiE 'amd|ati'; then
        echo "amd"
    elif echo "$gpu_info" | grep -qi 'intel'; then
        echo "intel"
    else
        echo "unknown"
    fi
}

get_nvidia_driver_version() {
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1 | tr -d ' \t'
    else
        # Fallback: try to extract from installed package name
        dpkg -l 2>/dev/null | grep -oP 'nvidia-driver-\K[0-9]+' | head -n1
    fi
}

# ───────────────────────────────
# CLI argument parsing
# ───────────────────────────────

GPU_OVERRIDE=""
FORMFACTOR_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --gpu=*) GPU_OVERRIDE="${1#*=}"; shift ;;
        --formfactor=*) FORMFACTOR_OVERRIDE="${1#*=}"; shift ;;
        --help|-h)
            echo "Usage: $0 [--gpu=nvidia|amd|intel] [--formfactor=laptop|desktop]"
            exit 0
            ;;
        *) warn "Unknown argument: $1"; shift ;;
    esac
done

# ───────────────────────────────
# Pre-flight checks
# ───────────────────────────────

if ! grep -qiE "debian|ubuntu" /etc/os-release 2>/dev/null; then
    warn "Only Debian/Ubuntu are supported."; exit 1
fi
if [ "$EUID" -eq 0 ]; then
    warn "Do not run as root."; exit 1
fi
if ! sudo -n true 2>/dev/null; then
    warn "Sudo required for apt."; sudo -v
fi

# Clone repo
if [ ! -d "$DOTFILES_DIR" ]; then
    info "Cloning dotfiles..."
    git clone "$REPO_URL" "$DOTFILES_DIR"
fi
cd "$DOTFILES_DIR"

# Detect hardware
FORMFACTOR="${FORMFACTOR_OVERRIDE:-$(detect_formfactor)}"
GPU="${GPU_OVERRIDE:-$(detect_gpu)}"

info "Detected form factor: $FORMFACTOR"
info "Detected GPU vendor:  $GPU"

# Non-free firmware repo
REPO_FILE="/etc/apt/sources.list.d/debian-nonfree-firmware.list"
if [ ! -f "$REPO_FILE" ] || ! grep -q "non-free" "$REPO_FILE" 2>/dev/null; then
    warn "Adding non-free repo..."
    echo "deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware" | \
        sudo tee "$REPO_FILE" >/dev/null
fi

# ───────────────────────────────
# Apt packages
# ───────────────────────────────

APT_PKGS=$(get_section "apt" | grep -v "^yandex-browser-stable$" | tr '\n' ' ')
if [ -n "$APT_PKGS" ]; then
    info "Installing apt packages..."
    sudo apt-get update
    sudo apt-get install -y $APT_PKGS
fi

# ───────────────────────────────
# GPU driver setup (auto-detected)
# ───────────────────────────────

case "$GPU" in
    nvidia)
        info "Setting up NVIDIA drivers..."
        sudo apt-get install -y linux-headers-$(uname -r) build-essential nvidia-driver nvidia-settings
        sudo dkms autoinstall || warn "DKMS autoinstall failed — module may not load until reboot."

        if [ ! -f /etc/modprobe.d/blacklist-nouveau.conf ]; then
            echo "blacklist nouveau
options nouveau modeset=0" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf >/dev/null
        fi

        if ! grep -q "nouveau.modeset=0" /etc/default/grub; then
            sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="nouveau.modeset=0"/' /etc/default/grub
            sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nouveau.modeset=0"/' /etc/default/grub
        fi

        sudo update-grub
        sudo update-initramfs -u
        warn "Nouveau disabled. Reboot required to use NVIDIA drivers."
        ;;
    amd)
        info "Setting up AMD drivers..."
        sudo apt-get install -y firmware-amd-graphics mesa-vulkan-drivers xserver-xorg-video-amdgpu
        ;;
    intel)
        info "Setting up Intel drivers..."
        sudo apt-get install -y intel-media-va-driver-non-free firmware-intel-graphics
        ;;
    *)
        warn "Could not detect GPU. Skipping GPU driver setup."
        warn "Run with --gpu=nvidia|amd|intel to force."
        ;;
esac

# ───────────────────────────────
# Laptop-specific packages
# ───────────────────────────────

if [ "$FORMFACTOR" = "laptop" ]; then
    info "Installing laptop-specific packages..."
    LAPTOP_PKGS=$(get_section "laptop" | tr '\n' ' ')
    if [ -n "$LAPTOP_PKGS" ]; then
        sudo apt-get install -y $LAPTOP_PKGS || warn "Some laptop packages failed to install."
    fi

    # Enable TLP if installed
    if command -v tlp &>/dev/null; then
        sudo systemctl enable --now tlp 2>/dev/null || true
    fi
fi

# ───────────────────────────────
# Audio: PipeWire → PulseAudio
# ───────────────────────────────

if get_section "apt" | grep -qx "pulseaudio"; then
    info "Switching to PulseAudio..."
    systemctl --user stop pipewire pipewire-pulse wireplumber pipewire.socket pipewire-pulse.socket 2>/dev/null || true
    systemctl --user disable pipewire pipewire-pulse wireplumber pipewire.socket pipewire-pulse.socket 2>/dev/null || true
    systemctl --user enable pulseaudio 2>/dev/null || true
    systemctl --user start pulseaudio 2>/dev/null || true
fi

# ───────────────────────────────
# Flatpak apps + NVIDIA runtime
# ───────────────────────────────

FLATPAK_PKGS=$(get_section "flatpak" | tr '\n' ' ')
if [ -n "$FLATPAK_PKGS" ]; then
    info "Installing flatpak apps..."
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    for app in $FLATPAK_PKGS; do
        sudo flatpak install -y --noninteractive flathub "$app" 2>/dev/null || warn "Failed: $app"
    done
fi

# Auto-install matching NVIDIA Flatpak runtime
if [ "$GPU" = "nvidia" ]; then
    NV_VER=$(get_nvidia_driver_version)
    if [ -n "$NV_VER" ]; then
        # Flatpak uses version without dots (e.g. 550-163-01)
        NV_VER_FLAT=$(echo "$NV_VER" | sed 's/\./-/g')
        info "Detected NVIDIA driver version: $NV_VER"
        info "Installing matching Flatpak runtime: $NV_VER_FLAT"

        sudo flatpak install -y --noninteractive flathub \
            "org.freedesktop.Platform.GL.nvidia-${NV_VER_FLAT}" 2>/dev/null || warn "Failed to install GL runtime"
        sudo flatpak install -y --noninteractive flathub \
            "org.freedesktop.Platform.GL32.nvidia-${NV_VER_FLAT}" 2>/dev/null || warn "Failed to install GL32 runtime"
    else
        warn "NVIDIA GPU detected but driver version could not be determined."
        warn "Install Flatpak runtime manually after reboot:"
        warn "  flatpak install flathub org.freedesktop.Platform.GL.nvidia-<version>"
    fi
fi

# ───────────────────────────────
# Yandex Browser
# ───────────────────────────────

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

# ───────────────────────────────
# VSCode
# ───────────────────────────────

if ! command -v code &>/dev/null; then
    info "Installing VSCode..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
        sudo gpg --dearmor -o /usr/share/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | \
        sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    sudo apt-get update || warn "VSCode repo update failed"
    sudo apt-get install -y code || warn "VSCode install failed"
fi

# ───────────────────────────────
# Network & Bluetooth
# ───────────────────────────────

sudo rfkill unblock wifi all 2>/dev/null || true
if rfkill list wifi 2>/dev/null | grep -q "Hard blocked: yes"; then
    warn "Wi-Fi hard blocked — unblock manually (Fn key or switch)."
fi

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

# ───────────────────────────────
# User groups
# ───────────────────────────────

sudo usermod -aG netdev,video "$USER" 2>/dev/null || true

# ───────────────────────────────
# Polkit rules
# ───────────────────────────────

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

# ───────────────────────────────
# Symlinks
# ───────────────────────────────

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

# ───────────────────────────────
# Oh My Zsh + autosuggestions
# ───────────────────────────────

if [ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
    rm -rf "$HOME/.oh-my-zsh"
    info "Installing Oh My Zsh..."
    if git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" 2>/dev/null; then
        info "Oh My Zsh installed."
    else
        warn "Oh My Zsh install failed — check internet connection."
    fi
fi

if [ -d "$HOME/.oh-my-zsh" ]; then
    ZSH_AUTOSUGGESTIONS_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    if [ ! -f "$ZSH_AUTOSUGGESTIONS_DIR/zsh-autosuggestions.zsh" ]; then
        rm -rf "$ZSH_AUTOSUGGESTIONS_DIR"
        info "Installing zsh-autosuggestions..."
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUGGESTIONS_DIR" 2>/dev/null || warn "zsh-autosuggestions install failed"
    fi
fi

backup_and_link "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"

# ───────────────────────────────
# Nerd Font
# ───────────────────────────────

if ! fc-list | grep -qi "JetBrainsMono.*Nerd"; then
    info "Installing JetBrainsMono Nerd Font..."
    mkdir -p "$FONT_DIR"
    tmp=$(mktemp -d)
    wget -q "$FONT_URL" -O "$tmp/JetBrainsMono.zip"
    unzip -q "$tmp/JetBrainsMono.zip" -d "$FONT_DIR"
    rm -rf "$tmp"
    fc-cache -fv "$FONT_DIR" >/dev/null 2>&1
fi

# ───────────────────────────────
# Xwrapper config
# ───────────────────────────────

if [ -f /etc/X11/Xwrapper.config ]; then
    sudo sed -i 's/^allowed_users=.*/allowed_users=anybody/' /etc/X11/Xwrapper.config
    if ! grep -q '^needs_root_rights' /etc/X11/Xwrapper.config; then
        echo "needs_root_rights=no" | sudo tee -a /etc/X11/Xwrapper.config >/dev/null
    else
        sudo sed -i 's/^needs_root_rights=.*/needs_root_rights=no/' /etc/X11/Xwrapper.config
    fi
else
    info "Creating /etc/X11/Xwrapper.config..."
    echo -e "allowed_users=anybody\nneeds_root_rights=no" | sudo tee /etc/X11/Xwrapper.config >/dev/null
fi

chmod +x "$HOME/.xinitrc"

# ───────────────────────────────
# Shell
# ───────────────────────────────

ZSH_BIN=$(which zsh 2>/dev/null || true)
if [ -n "$ZSH_BIN" ] && [ -x "$ZSH_BIN" ]; then
    if [ "$SHELL" != "$ZSH_BIN" ]; then
        info "Changing default shell to zsh..."
        chsh -s "$ZSH_BIN" || warn "chsh failed — run manually: chsh -s $(which zsh)"
    fi
else
    warn "zsh not found — skipping chsh."
fi

# ───────────────────────────────
# Services
# ───────────────────────────────

sudo systemctl enable --now bluetooth 2>/dev/null || true
sudo systemctl enable --now NetworkManager 2>/dev/null || true

# ───────────────────────────────
# Display manager (greetd + tuigreet)
# ───────────────────────────────

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
command = "tuigreet --time --remember --cmd /usr/bin/startx --power-shutdown '/usr/bin/systemctl poweroff' --power-reboot '/usr/bin/systemctl reboot'"
user = "${GREETD_USER}"
EOF

    sudo systemctl disable lightdm 2>/dev/null || true
    sudo systemctl stop lightdm 2>/dev/null || true
    sudo systemctl disable getty@tty2.service 2>/dev/null || true
    sudo systemctl stop getty@tty2.service 2>/dev/null || true
    sudo systemctl set-default graphical.target 2>/dev/null || true
    sudo systemctl enable greetd.service 2>/dev/null || true
    sudo systemctl start greetd.service 2>/dev/null || warn "Failed to start greetd — check logs with: journalctl -u greetd"

    if ! grep -q "enable_autosuspend=0" /etc/modprobe.d/btusb.conf 2>/dev/null; then
        info "Fixing Bluetooth autosuspend for AX210..."
        echo "options btusb enable_autosuspend=0" | sudo tee /etc/modprobe.d/btusb.conf >/dev/null
        sudo update-initramfs -u 2>/dev/null || warn "update-initramfs failed — reboot required for BT fix."
    fi

    info "Hiding kernel messages from greetd console..."
    sudo tee /etc/systemd/system/greetd-quiet-console.service >/dev/null <<'EOF'
[Unit]
Description=Disable kernel messages on console before greetd
Before=greetd.service

[Service]
Type=oneshot
ExecStart=/bin/dmesg --console-off
RemainAfterExit=yes

[Install]
RequiredBy=greetd.service
EOF
    sudo systemctl daemon-reload 2>/dev/null || true
    sudo systemctl enable greetd-quiet-console.service 2>/dev/null || true
fi

# ───────────────────────────────
# Summary
# ───────────────────────────────

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Done!${NC}"
echo -e "  Form factor: ${GREEN}$FORMFACTOR${NC}"
echo -e "  GPU vendor:  ${GREEN}$GPU${NC}"
if [ "$GPU" = "nvidia" ]; then
    echo -e "  NVIDIA driver: ${GREEN}$(get_nvidia_driver_version)${NC}"
fi
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Reboot to enter greetd → i3.${NC}"
if [ "$GPU" = "nvidia" ]; then
    echo -e "${YELLOW}NVIDIA: nouveau is blacklisted, reboot required.${NC}"
fi
echo -e "${GREEN}============================================${NC}"
