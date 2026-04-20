#!/bin/bash
# =============================================================================
# cosmic-setup.sh — Ubuntu 26.04 COSMIC Desktop Setup
# =============================================================================
# Voraussetzung: ubuntu-setup.sh wurde ausgeführt + Reboot
# Quelle: PPA ppa:hepp3n/cosmic-epoch (Community, nicht offiziell)
# Umfang: COSMIC Session + COSMIC Greeter, Wayland-only
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

[[ $EUID -ne 0 ]] && err "Bitte als root ausführen: sudo bash cosmic-setup.sh"

CURRENT_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$CURRENT_USER")

clear
echo -e "${BOLD}${CYAN}"
echo "   ██████╗ ██████╗ ███████╗███╗   ███╗██╗ ██████╗"
echo "  ██╔════╝██╔═══██╗██╔════╝████╗ ████║██║██╔════╝"
echo "  ██║     ██║   ██║███████╗██╔████╔██║██║██║     "
echo "  ██║     ██║   ██║╚════██║██║╚██╔╝██║██║██║     "
echo "  ╚██████╗╚██████╔╝███████║██║ ╚═╝ ██║██║╚██████╗"
echo "   ╚═════╝ ╚═════╝ ╚══════╝╚═╝     ╚═╝╚═╝ ╚═════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Ubuntu 26.04 — COSMIC Desktop Setup${NC}"
echo -e "  PPA: hepp3n/cosmic-epoch · COSMIC Greeter · Wayland-only"
echo ""
echo -e "  ${YELLOW}⚠  Inoffizielles Community-PPA — kann Systempakete upgraden!${NC}"
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

# ── COSMIC PPA hinzufügen ──────────────────────────────────────────────────────
info "COSMIC PPA hinzufügen (hepp3n/cosmic-epoch)..."
add-apt-repository -y ppa:hepp3n/cosmic-epoch
apt update
log "COSMIC PPA aktiviert"

# ── COSMIC Greeter vorab als DM setzen (non-interactive) ──────────────────────
info "COSMIC Greeter als Display Manager vorwählen..."
echo "cosmic-greeter shared/default-x-display-manager select cosmic-greeter" \
    | debconf-set-selections

# ── COSMIC Desktop installieren ───────────────────────────────────────────────
info "COSMIC Desktop installieren..."
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends cosmic-session
log "COSMIC Session installiert"

# ── COSMIC Greeter aktivieren ─────────────────────────────────────────────────
info "COSMIC Greeter aktivieren..."
systemctl disable gdm3 2>/dev/null || true
systemctl enable cosmic-greeter
systemctl set-default graphical.target
log "COSMIC Greeter aktiviert"

# ── Fastfetch COSMIC-Variante ──────────────────────────────────────────────────
info "Fastfetch für COSMIC konfigurieren..."
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
echo -e "${BOLD}${GREEN}  COSMIC Setup abgeschlossen!${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}System neu starten:${NC}  ${BOLD}sudo reboot${NC}"
echo ""
echo -e "  ${CYAN}Nach dem Reboot prüfen:${NC}"
echo -e "  • DRM:    ${BOLD}cat /sys/module/nvidia_drm/parameters/modeset${NC}  → Y"
echo -e "  • fbdev:  ${BOLD}cat /sys/module/nvidia_drm/parameters/fbdev${NC}     → Y"
echo ""
echo -e "  ${YELLOW}Rückgängig machen falls nötig:${NC}"
echo -e "  ${BOLD}sudo ppa-purge ppa:hepp3n/cosmic-epoch${NC}"
echo ""
