#!/bin/bash
# =============================================================================
# kde-setup.sh — Ubuntu 26.04 KDE Plasma Setup
# =============================================================================
# Voraussetzung: ubuntu-setup.sh wurde ausgeführt + Reboot
# Umfang: Minimales KDE Plasma 6.6, plasma-login-manager, Wayland-only
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

[[ $EUID -ne 0 ]] && err "Bitte als root ausführen: sudo bash kde-setup.sh"

CURRENT_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$CURRENT_USER")

clear
echo -e "${BOLD}${CYAN}"
echo "  ██╗  ██╗██████╗ ███████╗"
echo "  ██║ ██╔╝██╔══██╗██╔════╝"
echo "  █████╔╝ ██║  ██║█████╗  "
echo "  ██╔═██╗ ██║  ██║██╔══╝  "
echo "  ██║  ██╗██████╔╝███████╗"
echo "  ╚═╝  ╚═╝╚═════╝ ╚══════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Ubuntu 26.04 — KDE Plasma Setup${NC}"
echo -e "  Minimal · plasma-login-manager · Wayland-only"
echo ""
echo -e "  ${YELLOW}ENTER zum Starten, CTRL+C zum Abbrechen.${NC}"
read -r

# ── Nvidia DRM Check ───────────────────────────────────────────────────────────
info "Nvidia DRM modeset prüfen..."
MODESET=$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || echo "N")
if [ "$MODESET" != "Y" ]; then
    warn "nvidia_drm.modeset ist nicht aktiv!"
    warn "Hast du nach ubuntu-setup.sh neu gestartet?"
    warn "Fortfahren auf eigene Gefahr — Blackscreen möglich."
    echo -ne "  ${YELLOW}Trotzdem fortfahren? [j/N]:${NC} "
    read -r FORCE
    [[ "$FORCE" != "j" && "$FORCE" != "J" ]] && err "Abgebrochen."
else
    log "nvidia_drm.modeset = Y — alles gut"
fi

# ── Unerwünschte KDE-Pakete vorab pinnen (vor dem Install!) ───────────────────
# Muss VOR apt install passieren — sonst zieht plasma-desktop sie via Recommends rein
info "Unerwünschte KDE-Pakete vorab pinnen..."
cat > /etc/apt/preferences.d/kde-unwanted.pref << 'EOF'
Package: plasma-discover plasma-discover-common plasma-discover-backend-fwupd plasma-discover-backend-snap plasma-discover-notifier kdeconnect kdeconnect-libs plasma-welcome plasma-firewall plasma-vault plasma-thunderbolt plasma-browser-integration plasma-disks partitionmanager kwalletmanager khelpcenter khelpcenter-data alacritty qrca spectacle
Pin: release *
Pin-Priority: -1
EOF
log "Unwanted-Pakete gepinnt"

# ── KDE Plasma — minimale Pakete ───────────────────────────────────────────────
info "KDE Plasma (minimal) installieren..."
apt install -y \
    plasma-desktop \
    plasma-nm \
    plasma-pa \
    kscreen \
    kde-config-gtk-style \
    libayatana-appindicator3-1 \
    qt6-wayland \
    dolphin \
    kate \
    ark \
    breeze \
    breeze-gtk-theme \
    breeze-icon-theme \
    xdg-desktop-portal-kde \
    gvfs \
    gvfs-backends \
    libnvidia-egl-wayland1 \
    plasma-systemmonitor
log "KDE Plasma installiert"

# ── plasma-login-manager ───────────────────────────────────────────────────────
# In Kubuntu 26.04 als Teil von Plasma 6.6 verfügbar (optional, nicht default)
# Falls nicht im Repo: Fallback auf SDDM mit Warnung
info "plasma-login-manager installieren..."
if apt-cache show plasma-login-manager &>/dev/null; then
    apt install -y plasma-login-manager
    systemctl enable plasmalogin
    systemctl set-default graphical.target

    # Wayland-Konfiguration
    mkdir -p /etc/plasmalogin.conf.d
    cat > /etc/plasmalogin.conf.d/wayland.conf << 'EOF'
[General]
DefaultSession=plasma.desktop
EOF
    log "plasma-login-manager installiert und aktiviert"
else
    warn "plasma-login-manager nicht im Repo gefunden — Fallback auf SDDM"
    apt install -y sddm
    systemctl enable sddm
    systemctl set-default graphical.target

    mkdir -p /etc/sddm.conf.d
    cat > /etc/sddm.conf.d/wayland.conf << 'EOF'
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=kwin_wayland --no-lockscreen
EOF
    log "SDDM (Fallback) installiert und konfiguriert"
fi

# ── Unerwünschte KDE-Pakete entfernen ─────────────────────────────────────────
# Purge was trotz Pin reingekommen sein könnte (z.B. bei erneutem Script-Run)
info "Unerwünschte KDE-Pakete entfernen..."
KDE_UNWANTED=(
    plasma-discover
    plasma-discover-common
    plasma-discover-backend-fwupd
    plasma-discover-backend-snap
    plasma-discover-notifier
    kdeconnect
    kdeconnect-libs
    plasma-welcome
    plasma-firewall
    plasma-vault
    plasma-thunderbolt
    plasma-browser-integration
    plasma-disks
    partitionmanager
    kwalletmanager
    khelpcenter
    khelpcenter-data
    alacritty
    qrca
    spectacle
)
apt-mark auto "${KDE_UNWANTED[@]}" 2>/dev/null || true
apt purge -y "${KDE_UNWANTED[@]}" 2>/dev/null || true
log "Unerwünschte KDE-Pakete entfernt"

# ── Fastfetch KDE-Variante ─────────────────────────────────────────────────────
info "Fastfetch für KDE konfigurieren..."
mkdir -p "$USER_HOME/.config/fastfetch"
cat > "$USER_HOME/.config/fastfetch/config.jsonc" << 'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "source": "ubuntu",
    "padding": { "right": 2 }
  },
  "modules": [
    "title", "separator",
    { "type": "os",      "key": "OS      " },
    { "type": "kernel",  "key": "Kernel  " },
    { "type": "de",      "key": "DE      " },
    { "type": "wm",      "key": "WM      " },
    { "type": "shell",   "key": "Shell   " },
    { "type": "cpu",     "key": "CPU     " },
    { "type": "gpu",     "key": "GPU     " },
    { "type": "memory",  "key": "RAM     " },
    { "type": "disk",    "key": "Disk    " },
    { "type": "uptime",  "key": "Uptime  " }
  ]
}
EOF
chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.config/fastfetch"
log "Fastfetch konfiguriert"

# ── Aufräumen ──────────────────────────────────────────────────────────────────
info "Aufräumen..."
apt autoremove -y
apt clean
log "Aufgeräumt"

# ── Abschluss ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  KDE Plasma Setup abgeschlossen!${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}System neu starten:${NC}  ${BOLD}sudo reboot${NC}"
echo ""
echo -e "  ${CYAN}Nach dem Reboot prüfen:${NC}"
echo -e "  • DRM:    ${BOLD}cat /sys/module/nvidia_drm/parameters/modeset${NC}  → Y"
echo -e "  • fbdev:  ${BOLD}cat /sys/module/nvidia_drm/parameters/fbdev${NC}     → Y"
echo ""
