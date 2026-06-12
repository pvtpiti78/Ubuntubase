#!/bin/bash
# =============================================================================
# ubuntu-desktop-setup.sh — Ubuntu Desktop Setup
# =============================================================================
# Ausgangslage: Ubuntu Desktop (Standard-Install)
# Umfang: Snap-Purge, i386, Nvidia Open (CUDA Repo),
#         NTSYNC, Fish, Starship, Fastfetch, Firefox (Mozilla PPA),
#         Ubuntu Restricted Extras, Steam, ProtonPlus, Faugus,
#         Heroic, LACT, gaming.conf
# =============================================================================

set -uo pipefail

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

[[ $EUID -ne 0 ]] && err "Bitte als root ausführen: sudo bash ubuntu-desktop-setup.sh"

CURRENT_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$CURRENT_USER")

# Ubuntu-Version automatisch erkennen
UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "noble")
UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "26.04")

clear
echo -e "${BOLD}${CYAN}"
echo "  ██╗   ██╗██████╗ ██╗   ██╗███╗   ██╗████████╗██╗   ██╗"
echo "  ██║   ██║██╔══██╗██║   ██║████╗  ██║╚══██╔══╝██║   ██║"
echo "  ██║   ██║██████╔╝██║   ██║██╔██╗ ██║   ██║   ██║   ██║"
echo "  ██║   ██║██╔══██╗██║   ██║██║╚██╗██║   ██║   ██║   ██║"
echo "  ╚██████╔╝██████╔╝╚██████╔╝██║ ╚████║   ██║   ╚██████╔╝"
echo "   ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝   ╚═╝    ╚═════╝ "
echo -e "${NC}"
echo -e "  ${BOLD}Ubuntu ${UBUNTU_VERSION} — Desktop Setup${NC}"
echo -e "  Snap-Purge · Nvidia Open · Fish · Gaming ENV"
echo ""
echo -e "  ${YELLOW}Dieses Script richtet das System neu ein.${NC}"
echo -e "  ${YELLOW}Drücke ENTER zum Starten oder CTRL+C zum Abbrechen.${NC}"
read -r

# ── Snap purgen ────────────────────────────────────────────────────────────────
info "Snap entfernen..."
snap remove --purge firefox 2>/dev/null || true
snap remove --purge snap-store firmware-updater desktop-security-alert \
    desktop-security-center prompting-client snapd-desktop-integration 2>/dev/null || true
snap remove --purge gtk-common-themes gnome-46-2404 gnome-46-2410 mesa-2404 bare 2>/dev/null || true
snap remove --purge core24 snapd 2>/dev/null || true
apt purge -y snapd 2>/dev/null || true
apt-mark hold snapd

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
apt full-upgrade -y
log "System aktuell"

# ── Basis-Tools ───────────────────────────────────────────────────────────────
info "Basis-Tools installieren..."
apt install -y curl wget git unzip fastfetch lsb-release
log "Basis-Tools installiert"

# ── Fastfetch Config ──────────────────────────────────────────────────────────
info "Fastfetch config schreiben..."
mkdir -p "$USER_HOME/.config/fastfetch"
cat > "$USER_HOME/.config/fastfetch/config.jsonc" << 'EOF'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "type": "builtin",
        "source": "ubuntu"
    },
    "display": {
        "separator": "  "
    },
    "modules": [
        "title",
        "separator",
        { "type": "os",       "key": "OS"         },
        { "type": "kernel",   "key": "Kernel"      },
        { "type": "uptime",   "key": "Uptime"      },
        { "type": "packages", "key": "Packages"    },
        "separator",
        { "type": "shell",    "key": "Shell"       },
        { "type": "terminal", "key": "Terminal"    },
        { "type": "de",       "key": "DE/WM"       },
        "separator",
        { "type": "display",  "key": "Resolution"  },
        "separator",
        { "type": "cpu",      "key": "CPU"         },
        {
            "type": "gpu",
            "key": "GPU",
            "driverSpecific": true,
            "format": "{name} [{driver}]"
        },
        { "type": "memory",   "key": "RAM"         },
        { "type": "disk",     "key": "Disk", "folders": "/" },
        "separator",
        { "type": "localip",  "key": "Local IP"    }
    ]
}
EOF
chown "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.config/fastfetch/config.jsonc"
log "Fastfetch konfiguriert"

# ── i386 Multiarch aktivieren ──────────────────────────────────────────────────
info "i386 Multiarch aktivieren..."
dpkg --add-architecture i386
apt update
log "i386 aktiviert"

# ── Ubuntu Restricted Extras ───────────────────────────────────────────────────
info "Ubuntu Restricted Extras installieren..."
apt install -y ubuntu-restricted-addons ubuntu-restricted-extras || \
    warn "Restricted Extras fehlgeschlagen — möglicherweise noch nicht verfügbar"
log "Restricted Extras installiert"

# ── Kernel Headers ────────────────────────────────────────────────────────────
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

# ── Nvidia CUDA Repo ──────────────────────────────────────────────────────────
# ubuntu2604-Repo verwenden falls verfügbar, sonst 2404 als Fallback
info "Nvidia CUDA Repo einrichten..."
if apt-cache search nvidia-open 2>/dev/null | grep -q nvidia-open; then
    warn "Nvidia bereits in Repos verfügbar — CUDA Repo übersprungen"
else
    CUDA_REPO="ubuntu2404"
    wget -q -P /tmp "https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_REPO}/x86_64/cuda-keyring_1.1-1_all.deb" \
        && dpkg -i /tmp/cuda-keyring_1.1-1_all.deb \
        && rm /tmp/cuda-keyring_1.1-1_all.deb \
        && apt update \
        && log "CUDA Repo (${CUDA_REPO}) aktiviert" \
        || warn "CUDA Repo fehlgeschlagen"
fi

info "Nvidia Open + i386 Libs + VAAPI + EGL-Wayland installieren..."
apt install -y \
    nvidia-open \
    nvidia-vaapi-driver \
    libnvidia-egl-wayland1 \
    libnvidia-compute-570:i386 \
    libnvidia-decode-570:i386 \
    libnvidia-fbc1-570:i386 \
    libnvidia-encode-570:i386 \
    libnvidia-gl-570:i386 || \
warn "Einige i386 Nvidia Libs fehlgeschlagen — Versionsnummer prüfen"
log "Nvidia installiert"

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
    "DisableFeedbackCommands": true,
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
# Fish Config — Ubuntu Desktop
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
TMP_FONT=$(mktemp -d)
curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" \
    -o "$TMP_FONT/JetBrainsMono.zip"
unzip -q "$TMP_FONT/JetBrainsMono.zip" -d "$FONT_DIR"
rm -rf "$TMP_FONT"
fc-cache -fv > /dev/null
log "JetBrainsMono Nerd Font installiert"

# ── Steam ──────────────────────────────────────────────────────────────────────
info "Steam installieren..."
apt install -y steam-installer
log "Steam installiert"

# ── protontricks ───────────────────────────────────────────────────────────────
info "protontricks installieren..."
apt install -y protontricks
log "protontricks installiert"

# ── Flatpak + ProtonPlus ──────────────────────────────────────────────────────
info "Flatpak installieren..."
apt install -y flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
log "Flatpak installiert"

info "ProtonPlus installieren (Flatpak)..."
flatpak install -y flathub com.vysp3r.ProtonPlus
log "ProtonPlus installiert"

# ── Faugus Launcher ───────────────────────────────────────────────────────────
info "Faugus Launcher installieren (latest release)..."
FAUGUS_LATEST_TAG=$(curl -fsSL "https://api.github.com/repos/Faugus/faugus-launcher/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')
FAUGUS_LATEST="${FAUGUS_LATEST_TAG#v}"
FAUGUS_URL="https://github.com/Faugus/faugus-launcher/releases/download/${FAUGUS_LATEST_TAG}/faugus-launcher_${FAUGUS_LATEST}-1_all.deb"
if wget -q --show-progress -O /tmp/faugus.deb "$FAUGUS_URL"; then
    apt install -y /tmp/faugus.deb && log "Faugus Launcher ${FAUGUS_LATEST} installiert"
    rm -f /tmp/faugus.deb
else
    warn "Faugus Download fehlgeschlagen — übersprungen"
fi

# ── Heroic Games Launcher ─────────────────────────────────────────────────────
info "Heroic Games Launcher installieren (latest release)..."
HEROIC_LATEST_TAG=$(curl -fsSL "https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')
HEROIC_LATEST="${HEROIC_LATEST_TAG#v}"
HEROIC_URL="https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases/download/${HEROIC_LATEST_TAG}/Heroic-${HEROIC_LATEST}-linux-amd64.deb"
if wget -q --show-progress -O /tmp/heroic.deb "$HEROIC_URL"; then
    apt install -y /tmp/heroic.deb && log "Heroic Games Launcher ${HEROIC_LATEST} installiert"
    rm -f /tmp/heroic.deb
else
    warn "Heroic Download fehlgeschlagen — übersprungen"
fi

# ── LACT ──────────────────────────────────────────────────────────────────────
info "LACT installieren (latest release)..."
LACT_LATEST_TAG=$(curl -fsSL "https://api.github.com/repos/ilya-zlobintsev/LACT/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')
LACT_LATEST="${LACT_LATEST_TAG#v}"
LACT_URL="https://github.com/ilya-zlobintsev/LACT/releases/download/${LACT_LATEST_TAG}/lact-${LACT_LATEST}-0.amd64.ubuntu-2404.deb"
if wget -q --show-progress -O /tmp/lact.deb "$LACT_URL"; then
    apt install -y /tmp/lact.deb && log "LACT ${LACT_LATEST} installiert"
    rm -f /tmp/lact.deb
    systemctl enable --now lactd
else
    warn "LACT Download fehlgeschlagen — übersprungen"
fi

# ── gaming.conf ───────────────────────────────────────────────────────────────
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
PROTON_DLSS_UPGRADE=1
PROTON_ENABLE_NGX_UPDATER=1
PROTON_ENABLE_WAYLAND=1
PROTON_ENABLE_NVAPI=1
PROTON_USE_NTSYNC=1
DXVK_NVAPI_VKREFLEX=1
PROTON_PRIORITY_HIGH=1

### VKD3D Descriptor Heap (mainline seit vkd3d-proton 20260521)
VKD3D_CONFIG=descriptor_heap

### NTSYNC
WINEFSYNC=0
WINEESYNC=0

### DLSS SR
DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE=on
DXVK_NVAPI_DRS_NGX_DLSS_SR_MODE=custom
DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE_SCALING_RATIO=50
DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest

### DLSS RR
DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE=on
DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest

### Frame Generation (Dynamic MFG)
DXVK_NVAPI_DRS_NGX_DLSS_FG_OVERRIDE=on
DXVK_NVAPI_DRS_NGX_DLSS_FG_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest
DXVK_NVAPI_DRS_NGX_DLSSG_MODE=dynamic
DXVK_NVAPI_DRS_NGX_DLSSG_DYNAMIC_TARGET_FRAME_RATE=360
DXVK_NVAPI_DRS_NGX_DLSSG_DYNAMIC_MULTI_FRAME_COUNT_MAX=5

### Frame Rate Cap (355 für VRR Dropout-Schutz bei 360Hz)
DXVK_FRAME_RATE=355
VKD3D_FRAME_RATE=355

### HDR
DXVK_HDR=1
PROTON_ENABLE_HDR=1
ENABLE_HDR_WSI=1

### Debug (auskommentiert)
# DXVK_NVAPI_SET_NGX_DEBUG_OPTIONS="DLSSIndicator=1024,DLSSGIndicator=2"
EOF
log "gaming.conf erstellt"

# ── nvidia.conf ───────────────────────────────────────────────────────────────
info "nvidia.conf erstellen..."
cat > /etc/environment.d/nvidia.conf << 'EOF'
LIBVA_DRIVER_NAME=nvidia
NVD_BACKEND=direct
MOZ_DISABLE_RDD_SANDBOX=1
EOF
log "nvidia.conf erstellt"

# ── sysctl ────────────────────────────────────────────────────────────────────
info "sysctl konfigurieren..."
cat > /etc/sysctl.d/99-gaming.conf << 'EOF'
vm.max_map_count=2147483642
vm.swappiness=10
EOF
sysctl --system > /dev/null
log "sysctl konfiguriert"

# ── Vorlagen ──────────────────────────────────────────────────────────────────
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

# ── Berechtigungen ────────────────────────────────────────────────────────────
info "Berechtigungen Home-Verzeichnis setzen..."
chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME"
log "Berechtigungen gesetzt"

# ── Aufräumen ──────────────────────────────────────────────────────────────────
info "Aufräumen..."
apt autoremove -y
apt clean
log "Aufgeräumt"

# ── Abschluss ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  Desktop-Setup abgeschlossen!${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Nach dem Reboot prüfen:${NC}"
echo -e "  • Nvidia:   ${BOLD}nvidia-smi${NC}"
echo -e "  • NTSYNC:   ${BOLD}ls /dev/ntsync${NC}"
echo -e "  • Snap:     ${BOLD}snap list${NC}  → Fehler erwartet"
echo -e "  • Firefox:  ${BOLD}firefox --version${NC}  → kein Snap"
echo ""
echo -e "  ${YELLOW}Neustart empfohlen.${NC}"
echo ""
