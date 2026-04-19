#!/bin/bash
# =============================================================================
# ubuntu-setup.sh — Ubuntu 26.04 Resolute Raccoon Base Setup
# =============================================================================
# Ausgangslage: Minimale Ubuntu 26.04 Server-Installation (kein DE)
# Umfang: Snap-Purge, APT-Tuning, i386, Nvidia 595+ Open (CUDA 2404 Repo),
#         NTSYNC, Fish, Kitty, Starship, Fastfetch, Firefox (Mozilla PPA),
#         Steam, ProtonPlus, Faugus, Heroic, LACT, gaming.conf, nvidia.conf
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $*"; }
info() { echo -e "${CYAN}[→]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }

[[ $EUID -ne 0 ]] && err "Bitte als root ausführen: sudo bash ubuntu-setup.sh"

CURRENT_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$CURRENT_USER")

clear
echo -e "${BOLD}${CYAN}"
echo "  ██╗   ██╗██████╗ ██╗   ██╗███╗   ██╗████████╗██╗   ██╗"
echo "  ██║   ██║██╔══██╗██║   ██║████╗  ██║╚══██╔══╝██║   ██║"
echo "  ██║   ██║██████╔╝██║   ██║██╔██╗ ██║   ██║   ██║   ██║"
echo "  ██║   ██║██╔══██╗██║   ██║██║╚██╗██║   ██║   ██║   ██║"
echo "  ╚██████╔╝██████╔╝╚██████╔╝██║ ╚████║   ██║   ╚██████╔╝"
echo "   ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝   ╚═╝    ╚═════╝ "
echo -e "${NC}"
echo -e "  ${BOLD}Ubuntu 26.04 Resolute Raccoon — Base Setup${NC}"
echo -e "  Snap-Purge · Nvidia Open (CUDA 2404) · Fish · Kitty · Gaming ENV"
echo ""
echo -e "  ${YELLOW}Dieses Script richtet das System neu ein.${NC}"
echo -e "  ${YELLOW}Drücke ENTER zum Starten oder CTRL+C zum Abbrechen.${NC}"
read -r

# ── Snap purgen ────────────────────────────────────────────────────────────────
info "Snap entfernen..."
snap remove --purge snap-store firmware-updater desktop-security-alert \
    desktop-security-center prompting-client snapd-desktop-integration 2>/dev/null || true
snap remove --purge gtk-common-themes gnome-46-2404 mesa-2404 bare 2>/dev/null || true
snap remove --purge core24 snapd 2>/dev/null || true
apt purge -y snapd 2>/dev/null || true
apt-mark hold snapd

# nosnap.pref — verhindert Reinstall via apt
cat > /etc/apt/preferences.d/nosnap.pref << 'EOF'
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF
log "Snap entfernt und gesperrt"

# ── APT konfigurieren ──────────────────────────────────────────────────────────
info "APT konfigurieren..."
cat > /etc/apt/apt.conf.d/99custom << 'EOF'
APT::Get::Assume-Yes "true";
Acquire::Languages "none";
EOF
log "APT konfiguriert"

# ── System aktualisieren ───────────────────────────────────────────────────────
info "System aktualisieren..."
apt update
apt upgrade -y
apt full-upgrade -y
log "System aktuell"

# ── i386 Multiarch aktivieren ──────────────────────────────────────────────────
info "i386 Multiarch aktivieren..."
dpkg --add-architecture i386
apt update
log "i386 aktiviert"

# ── Basis-Pakete ───────────────────────────────────────────────────────────────
info "Basis-Pakete installieren..."
apt install -y \
    git \
    curl \
    wget \
    unzip \
    gpg \
    p7zip-full \
    btop \
    fastfetch \
    bash-completion \
    pciutils \
    usbutils \
    lshw \
    rsync \
    vim \
    nano \
    man-db \
    xdg-utils \
    xdg-user-dirs \
    pipewire \
    pipewire-pulse \
    wireplumber \
    power-profiles-daemon \
    hunspell \
    hunspell-de-de \
    hunspell-en-us \
    lsb-release
log "Basis-Pakete installiert"

# ── power-profiles-daemon ──────────────────────────────────────────────────────
info "power-profiles-daemon aktivieren..."
systemctl enable --now power-profiles-daemon
log "power-profiles-daemon aktiv"

# ── Restricted Codecs ──────────────────────────────────────────────────────────
info "Ubuntu Restricted Extras installieren..."
apt install -y ubuntu-restricted-addons ubuntu-restricted-extras
log "Restricted Extras installiert"

# ── Kernel Headers (vor Nvidia zwingend) ──────────────────────────────────────
info "Kernel Headers installieren..."
apt install -y \
    linux-headers-$(uname -r) \
    linux-headers-generic
log "Kernel Headers installiert"

# ── Nouveau blacklisten ────────────────────────────────────────────────────────
info "Nouveau blacklisten..."
cat > /etc/modprobe.d/blacklist-nouveau.conf << 'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
log "Nouveau geblockt"

# ── Nvidia (CUDA Repo ubuntu2404) ─────────────────────────────────────────────
# ubuntu2604-Repo ist noch Beta — 2404-Repo für stabile 595er Pakete verwenden
info "Nvidia CUDA Repo einrichten (ubuntu2404)..."
wget -P /tmp https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i /tmp/cuda-keyring_1.1-1_all.deb
rm /tmp/cuda-keyring_1.1-1_all.deb
apt update
log "CUDA Repo (2404) aktiviert"

info "Nvidia Open + i386 Libs + VAAPI + EGL-Wayland installieren..."
apt install -y \
    nvidia-open \
    nvidia-vaapi-driver \
    libnvidia-egl-wayland1 \
    libnvidia-compute:i386 \
    libnvidia-decode:i386 \
    libnvidia-fbc1:i386 \
    libnvidia-encode:i386 \
    libnvidia-gl:i386
log "Nvidia installiert"

# ── Nvidia Module — Early Loading (initramfs) ──────────────────────────────────
info "Nvidia Module in initramfs eintragen..."
cat > /etc/initramfs-tools/conf.d/nvidia-modules.conf << 'EOF'
# Nvidia Open — Early Loading
# Verhindert Blackscreen/Race Condition bei Wayland + GDM/SDDM
MODULES_INITRAMFS="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
EOF

for mod in nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
    grep -qxF "$mod" /etc/initramfs-tools/modules || echo "$mod" >> /etc/initramfs-tools/modules
done

update-initramfs -u -k all
log "Nvidia Early Loading konfiguriert"

# ── nvidia.conf (modprobe) ─────────────────────────────────────────────────────
info "nvidia.conf (modprobe) erstellen..."
cat > /etc/modprobe.d/nvidia.conf << 'EOF'
# Nvidia Open — Ubuntu 26.04
# modeset=1 ab Treiber 595 driver-seitig default — explizit zur Sicherheit
# fbdev=1 noch nicht default — nötig für stabilen simpledrm-Takeover (Linux 6.11+)
options nvidia_drm modeset=1
options nvidia_drm fbdev=1
EOF
log "nvidia.conf (modprobe) erstellt"

# ── NTSYNC ────────────────────────────────────────────────────────────────────
info "NTSYNC konfigurieren..."
echo "ntsync" | tee /etc/modules-load.d/ntsync.conf
log "NTSYNC aktiviert"

# ── Firefox (Mozilla PPA) ──────────────────────────────────────────────────────
info "Firefox via Mozilla PPA installieren..."
install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- \
    | gpg --dearmor | tee /etc/apt/keyrings/packages.mozilla.org.gpg > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.gpg] https://packages.mozilla.org/apt mozilla main" \
    | tee /etc/apt/sources.list.d/mozilla.list

# Mozilla PPA höher pinnen als ubuntu-repos (verhindert snap-Fallback)
cat > /etc/apt/preferences.d/mozilla.pref << 'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

apt update
apt install -y firefox firefox-l10n-de
log "Firefox installiert"

info "Firefox policies.json konfigurieren..."
FIREFOX_POLICIES_DIR="/usr/lib/firefox/distribution"
mkdir -p "$FIREFOX_POLICIES_DIR"
cat > "$FIREFOX_POLICIES_DIR/policies.json" << 'EOF'
{
  "policies": {
    "DisableTelemetry": true,
    "DisablePocket": true,
    "DisableFirefoxStudies": true,
    "DisableFormHistory": false,
    "Preferences": {
      "media.ffmpeg.vaapi.enabled":                  { "Value": true, "Status": "default" },
      "media.rdd-ffmpeg.enabled":                    { "Value": true, "Status": "default" },
      "media.hardware-video-decoding.force-enabled": { "Value": true, "Status": "default" },
      "widget.dmabuf.force-enabled":                 { "Value": true, "Status": "default" },
      "media.av1.enabled":                           { "Value": true, "Status": "default" },
      "gfx.webrender.all":                           { "Value": true, "Status": "default" }
    }
  }
}
EOF
log "Firefox konfiguriert"

# ── Fish Shell ─────────────────────────────────────────────────────────────────
info "Fish Shell installieren..."
apt install -y fish

chsh -s /usr/bin/fish "$CURRENT_USER"

mkdir -p "$USER_HOME/.config/fish"
cat > "$USER_HOME/.config/fish/config.fish" << 'EOF'
# Fish Config — Ubuntu 26.04
if status is-interactive
    # Starship prompt
    starship init fish | source

    # Fastfetch beim Start
    fastfetch

    # Aliase
    alias ls='ls --color=auto'
    alias ll='ls -lah --color=auto'
    alias grep='grep --color=auto'
    alias df='df -h'
    alias free='free -h'
    alias ..='cd ..'
    alias ...='cd ../..'

    # APT-Shortcuts
    alias update='sudo apt update && sudo apt full-upgrade -y'
    alias install='sudo apt install -y'
    alias remove='sudo apt remove -y'
    alias purge='sudo apt purge -y'
    alias search='apt search'

    # Cache leeren
    alias clean='sudo apt autoremove -y && sudo apt clean'

    # Systemd
    alias ss='sudo systemctl status'
    alias sr='sudo systemctl restart'
    alias se='sudo systemctl enable'

    # Git
    alias gs='git status'
    alias ga='git add .'
    alias gc='git commit -m'
    alias gp='git push'
end
EOF

chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.config/fish"
log "Fish Shell konfiguriert"

# ── Starship Prompt ────────────────────────────────────────────────────────────
info "Starship installieren..."
curl -sS https://starship.rs/install.sh | sh -s -- --yes

mkdir -p "$USER_HOME/.config"
cat > "$USER_HOME/.config/starship.toml" << 'EOF'
format = """
$directory\
$git_branch\
$git_status\
$cmd_duration\
$line_break\
$character"""

[directory]
style = "bold #7aa2f7"
truncation_length = 3
truncate_to_repo = true
format = "[$path]($style) "

[git_branch]
symbol = " "
style = "bold #bb9af7"
format = "[$symbol$branch]($style) "

[git_status]
style = "bold #f7768e"
format = "[$all_status$ahead_behind]($style) "
conflicted = "⚡"
ahead = "⇡${count}"
behind = "⇣${count}"
diverged = "⇕⇡${ahead_count}⇣${behind_count}"
untracked = "?"
modified = "!"
staged = "+"
deleted = "✘"

[cmd_duration]
min_time = 3_000
style = "bold #e0af68"
format = "[ $duration]($style) "

[character]
success_symbol = "[❯](bold #9ece6a)"
error_symbol = "[❯](bold #f7768e)"

[package]
disabled = true

[python]
disabled = true

[nodejs]
disabled = true

[rust]
disabled = true
EOF
chown "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.config/starship.toml"
log "Starship konfiguriert"

# ── Kitty Terminal ─────────────────────────────────────────────────────────────
info "Kitty installieren..."
apt install -y kitty

mkdir -p "$USER_HOME/.config/kitty"
cat > "$USER_HOME/.config/kitty/kitty.conf" << 'EOF'
# =============================================================================
# Kitty Terminal Configuration
# Theme: Tokyo Night
# =============================================================================

# Font
font_family      JetBrainsMono Nerd Font
bold_font        JetBrainsMono Nerd Font Bold
italic_font      JetBrainsMono Nerd Font Italic
bold_italic_font JetBrainsMono Nerd Font Bold Italic
font_size        13.0

# Tokyo Night Colors
foreground              #c0caf5
background              #1a1b26
selection_foreground    #1a1b26
selection_background    #c0caf5

cursor                  #c0caf5
cursor_text_color       #1a1b26
url_color               #73daca

color0  #15161e
color8  #414868
color1  #f7768e
color9  #f7768e
color2  #9ece6a
color10 #9ece6a
color3  #e0af68
color11 #e0af68
color4  #7aa2f7
color12 #7aa2f7
color5  #bb9af7
color13 #bb9af7
color6  #7dcfff
color14 #7dcfff
color7  #a9b1d6
color15 #c0caf5

# Window
window_padding_width    12
background_opacity      0.95
hide_window_decorations no
remember_window_size    yes

# Cursor
cursor_shape            block
cursor_blink_interval   0

# Performance
sync_to_monitor         yes
confirm_os_window_close 0

# Tab bar
tab_bar_style           powerline
tab_powerline_style     slanted
EOF

chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.config/kitty"
log "Kitty konfiguriert"

# ── Fonts ──────────────────────────────────────────────────────────────────────
info "System-Fonts installieren..."
apt install -y \
    fonts-noto \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    fonts-liberation \
    fonts-dejavu
log "System-Fonts installiert"

info "JetBrainsMono Nerd Font installieren..."
FONT_DIR="/usr/share/fonts/JetBrainsMonoNF"
mkdir -p "$FONT_DIR"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
TMP_FONT=$(mktemp -d)
curl -fsSL "$FONT_URL" -o "$TMP_FONT/JetBrainsMono.zip"
unzip -q "$TMP_FONT/JetBrainsMono.zip" -d "$FONT_DIR"
rm -rf "$TMP_FONT"
fc-cache -fv > /dev/null
log "JetBrainsMono Nerd Font installiert"

# ── Gaming — Steam ─────────────────────────────────────────────────────────────
info "Steam installieren..."
apt install -y steam-installer
log "Steam installiert"

# ── protontricks ───────────────────────────────────────────────────────────────
info "protontricks installieren..."
apt install -y protontricks
log "protontricks installiert"

# ── Pacstall ───────────────────────────────────────────────────────────────────
info "Pacstall installieren..."
bash -c "$(wget -q https://pacstall.dev/q/install -O -)"
log "Pacstall installiert"

# ── ProtonPlus (via Pacstall) ──────────────────────────────────────────────────
info "ProtonPlus installieren..."
sudo -u "$CURRENT_USER" pacstall -I protonplus
log "ProtonPlus installiert"

# ── Faugus Launcher — aktuelle Version von GitHub ─────────────────────────────
info "Faugus Launcher installieren (latest release)..."
FAUGUS_LATEST=$(curl -fsSL "https://api.github.com/repos/Faugus/faugus-launcher/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')
FAUGUS_URL="https://github.com/Faugus/faugus-launcher/releases/download/${FAUGUS_LATEST}/faugus-launcher_${FAUGUS_LATEST}-1_all.deb"
wget -O /tmp/faugus.deb "$FAUGUS_URL"
apt install -y /tmp/faugus.deb
rm /tmp/faugus.deb
log "Faugus Launcher ${FAUGUS_LATEST} installiert"

# ── Heroic Games Launcher — aktuelle Version von GitHub ───────────────────────
info "Heroic Games Launcher installieren (latest release)..."
HEROIC_LATEST=$(curl -fsSL "https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
HEROIC_URL="https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases/download/v${HEROIC_LATEST}/Heroic-${HEROIC_LATEST}-linux-amd64.deb"
wget -O /tmp/heroic.deb "$HEROIC_URL"
apt install -y /tmp/heroic.deb
rm /tmp/heroic.deb
log "Heroic Games Launcher ${HEROIC_LATEST} installiert"

# ── LACT — aktuelle Version von GitHub ────────────────────────────────────────
info "LACT installieren (latest release)..."
LACT_LATEST=$(curl -fsSL "https://api.github.com/repos/ilya-zlobintsev/LACT/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
LACT_URL="https://github.com/ilya-zlobintsev/LACT/releases/download/v${LACT_LATEST}/lact-${LACT_LATEST}-0.amd64.ubuntu-2404.deb"
wget -O /tmp/lact.deb "$LACT_URL"
apt install -y /tmp/lact.deb
rm /tmp/lact.deb
systemctl enable --now lactd
log "LACT ${LACT_LATEST} installiert"

# ── gaming.conf (Environment Variables) ───────────────────────────────────────
info "gaming.conf erstellen..."
mkdir -p /etc/environment.d
cat > /etc/environment.d/gaming.conf << 'EOF'
### OpenGL
__GL_SYNC_TO_VBLANK=0
__GL_MaxFramesAllowed=1
__GL_GSYNC_ALLOWED=1
__GL_VRR_ALLOWED=1
__GL_SHADER_DISK_CACHE_SIZE=12000000000

### Proton / Wayland
PROTON_ENABLE_NGX_UPDATER=1
PROTON_ENABLE_WAYLAND=1
PROTON_ENABLE_NVAPI=1
PROTON_USE_NTSYNC=1

### NTSYNC — kein esync/fsync
WINEFSYNC=0
WINEESYNC=0

### VKD3D — Descriptor Heap
# Nur mit CachyOS Proton / Proton-GE aktiv — Standard-Proton ignoriert das
PROTON_VKD3D_HEAP=1
VKD3D_CONFIG=descriptor_heap

### DLSS SR — Preset Latest, 50% Skalierung
DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE=on
DXVK_NVAPI_DRS_NGX_DLSS_SR_MODE=custom
DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE_SCALING_RATIO=50
DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest

### DLSS RR
DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE=on
DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest

### Frame Generation — Dynamic MFG
DXVK_NVAPI_DRS_NGX_DLSS_FG_OVERRIDE=on
DXVK_NVAPI_DRS_NGX_DLSS_FG_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest
DXVK_NVAPI_DRS_NGX_DLSSG_MODE=dynamic
DXVK_NVAPI_DRS_NGX_DLSSG_DYNAMIC_TARGET_FRAME_RATE=240
DXVK_NVAPI_DRS_NGX_DLSSG_DYNAMIC_MULTI_FRAME_COUNT_MAX=5

### Frame Rate Cap — 237 FPS (VRR-Dropout-Schutz bei 240Hz)
DXVK_FRAME_RATE=237
VKD3D_FRAME_RATE=237

### HDR
DXVK_HDR=1
PROTON_ENABLE_HDR=1
ENABLE_HDR_WSI=1

### Debug (DLSS + DLSSG Indicator) — bei Bedarf einkommentieren
# DXVK_NVAPI_SET_NGX_DEBUG_OPTIONS="DLSSIndicator=1024,DLSSGIndicator=2"
EOF
log "gaming.conf erstellt"

# ── nvidia.conf ENV (Wayland/Vulkan) ──────────────────────────────────────────
info "nvidia.conf ENV erstellen..."
cat > /etc/environment.d/nvidia.conf << 'EOF'
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
LIBVA_DRIVER_NAME=nvidia
NVD_BACKEND=direct
ELECTRON_OZONE_PLATFORM_HINT=auto

# Hardware-Decoding Firefox
MOZ_DISABLE_RDD_SANDBOX=1

# GNOME + Nvidia: Cursor/Mouse-Bug Workaround
# Bei Problemen (Cursor verschwindet, Freezes) diese Zeile aktivieren:
# MUTTER_DEBUG_DISABLE_HW_CURSORS=1
EOF
log "nvidia.conf ENV erstellt"

# ── ZRAM ──────────────────────────────────────────────────────────────────────
info "ZRAM konfigurieren..."
apt install -y zram-tools

cat > /etc/default/zramswap << 'EOF'
# ZRAM — 15% von 48GB RAM (~7GB)
ALGO=zstd
PERCENT=15
EOF

systemctl enable --now zramswap
log "ZRAM konfiguriert"

# ── GRUB konfigurieren ─────────────────────────────────────────────────────────
info "GRUB konfigurieren (Kernel-Parameter, Timeout)..."

# Kernel-Parameter:
# zswap.enabled=0      — kollidiert mit zram
# nvidia_drm.modeset=1 / fbdev=1 — Nvidia DRM früh laden
GRUB_PARAMS="zswap.enabled=0 nvidia_drm.modeset=1 nvidia_drm.fbdev=1"

# Bestehende GRUB_CMDLINE_LINUX_DEFAULT um Parameter erweitern (keine Duplikate)
CURRENT_PARAMS=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub \
    | sed 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/\1/')
NEW_PARAMS="$CURRENT_PARAMS"
for param in $GRUB_PARAMS; do
    KEY="${param%%=*}"
    if ! echo "$NEW_PARAMS" | grep -qE "(^| )${KEY}[= ]"; then
        NEW_PARAMS="$NEW_PARAMS $param"
    fi
done
NEW_PARAMS=$(echo "$NEW_PARAMS" | xargs)

sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"${NEW_PARAMS}\"|" \
    /etc/default/grub

# Timeout auf 5 Sekunden
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub

update-grub
log "GRUB konfiguriert (Timeout 5s, Nvidia DRM, zswap deaktiviert)"

# ── sysctl — vm.max_map_count (Steam/Wine) ────────────────────────────────────
info "sysctl vm.max_map_count setzen..."
cat > /etc/sysctl.d/99-gaming.conf << 'EOF'
vm.max_map_count=2147483642
vm.swappiness=10
EOF
sysctl --system > /dev/null
log "sysctl konfiguriert"

# ── Zeitzone setzen ───────────────────────────────────────────────────────────
info "Zeitzone auf Europe/Berlin setzen..."
timedatectl set-timezone Europe/Berlin
log "Zeitzone gesetzt"

# ── Systemsprache Deutsch ──────────────────────────────────────────────────────
info "Systemsprache Deutsch setzen..."
apt install -y locales language-pack-de language-pack-de-base
sed -i 's/# de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=de_DE.UTF-8 LANGUAGE=de_DE:de LC_ALL=de_DE.UTF-8
localectl set-locale LANG=de_DE.UTF-8 2>/dev/null || true
log "Systemsprache gesetzt"

# ── Tastatur auf Deutsch ───────────────────────────────────────────────────────
info "Tastaturlayout auf Deutsch setzen..."
cat > /etc/default/keyboard << 'EOF'
XKBMODEL="pc105"
XKBLAYOUT="de"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF
log "Tastaturlayout gesetzt"

# ── Vorlagen (Rechtsklick → Neu erstellen) ─────────────────────────────────────
info "Vorlagen-Verzeichnis anlegen..."
TEMPLATES_DIR="$USER_HOME/Vorlagen"
mkdir -p "$TEMPLATES_DIR"
touch "$TEMPLATES_DIR/Leere Textdatei.txt"
touch "$TEMPLATES_DIR/Dokument.md"
touch "$TEMPLATES_DIR/Skript.sh"
cat > "$TEMPLATES_DIR/Webseite.html" << 'EOF'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Titel</title>
</head>
<body>

</body>
</html>
EOF
chown -R "$CURRENT_USER:$CURRENT_USER" "$TEMPLATES_DIR"
log "Vorlagen angelegt"

# ── Berechtigungen Home-Verzeichnis ───────────────────────────────────────────
info "Berechtigungen Home-Verzeichnis setzen..."
chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME"
log "Berechtigungen gesetzt"

# ── NetworkManager — netplan + wait-online fix ─────────────────────────────────
# Ubuntu Server (subiquity) startet systemd-networkd-wait-online beim Boot.
# Der wartet auf networkd, aber NM managed den Adapter → Timeout → TTY statt DM.
# Lösung: NM als netplan renderer + wait-online deaktivieren.
info "netplan auf NetworkManager umstellen..."
apt install -y network-manager

# Subiquity-Config sichern, alle alten YAMLs deaktivieren
for f in /etc/netplan/*.yaml; do
    [ -f "$f" ] && mv "$f" "${f}.bak" 2>/dev/null || true
done

cat > /etc/netplan/01-networkmanager.yaml << 'EOF'
network:
  version: 2
  renderer: NetworkManager
EOF
chmod 600 /etc/netplan/01-networkmanager.yaml

# systemd-networkd-wait-online deaktivieren — sonst Boot-Timeout
systemctl disable systemd-networkd-wait-online 2>/dev/null || true
systemctl enable NetworkManager
log "netplan auf NetworkManager umgestellt, wait-online deaktiviert"

# ── Aufräumen ──────────────────────────────────────────────────────────────────
info "Aufräumen..."
apt autoremove -y
apt clean
log "Aufgeräumt"

# ── Abschluss ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  Base-Setup abgeschlossen!${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Nächste Schritte:${NC}"
echo -e "  1.  ${BOLD}sudo reboot${NC}"
echo -e "  2.  Nach Reboot DE-Script ausführen"
echo ""
echo -e "  ${CYAN}Nach dem Reboot prüfen:${NC}"
echo -e "  • Nvidia:   ${BOLD}nvidia-smi${NC}"
echo -e "  • DRM:      ${BOLD}cat /sys/module/nvidia_drm/parameters/modeset${NC}  → Y"
echo -e "  • NTSYNC:   ${BOLD}ls /dev/ntsync${NC}"
echo -e "  • Snap:     ${BOLD}snap list${NC}  → Fehler erwartet (kein snapd)"
echo ""
