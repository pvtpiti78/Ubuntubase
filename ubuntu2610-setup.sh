#!/bin/bash
# =============================================================================
# ubuntu2610-setup.sh — Ubuntu 26.10 (Stonking Stingray) Post-Install
# =============================================================================
# Hardware : Ryzen 7 9800X3D | RX 9070 XT | MSI X870E (AMD only, kein DKMS)
# Umfang   : Snap-Purge, Mozilla-Repo, Chrome, Codecs, Mesa 32/64 bit, Steam,
#            Protontricks, ProtonPlus, Heroic, Faugus, LACT, zram, sysctl,
#            Gaming-ENV, ufw, Fish (+ optional Kitty Tokyo Night)
# Aufruf   : sudo bash ubuntu2610-setup.sh
# =============================================================================

set -uo pipefail

# ── Schalter ──────────────────────────────────────────────────────────────────
WITH_KITTY=1          # Kitty + Tokyo Night + JetBrainsMono Nerd Font
WITH_PROTONPLUS=1     # ProtonPlus als Flatpak (einzige Flatpak-Ausnahme)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $*"; }
info() { echo -e "${CYAN}[→]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }

[[ $EUID -ne 0 ]] && err "Bitte als root ausführen: sudo bash ubuntu2610-setup.sh"

CURRENT_USER=${SUDO_USER:-}
[[ -z "$CURRENT_USER" || "$CURRENT_USER" == "root" ]] && err "Bitte per sudo als normaler User starten (SUDO_USER fehlt)."
USER_HOME=$(getent passwd "$CURRENT_USER" | cut -d: -f6)

# shellcheck disable=SC1091
. /etc/os-release
export DEBIAN_FRONTEND=noninteractive

echo -e "${BOLD}${CYAN}  Ubuntu ${VERSION_ID:-?} (${VERSION_CODENAME:-?}) — Post-Install${NC}"
[[ "${VERSION_ID:-}" == "26.10" ]] || warn "Erwartet 26.10, gefunden: ${VERSION_ID:-?} — Script läuft trotzdem weiter."
ping -c1 -W3 archive.ubuntu.com >/dev/null 2>&1 || err "Keine Internetverbindung."
echo -e "  ${YELLOW}ENTER zum Starten, CTRL+C zum Abbrechen.${NC}"
read -r

# ── Helfer ────────────────────────────────────────────────────────────────────
apt_try() { apt-get install -y "$@" || warn "Fehlgeschlagen: $*"; }

# Neuestes Asset eines GitHub-Latest-Releases per Regex finden (höchste Version)
gh_asset() {
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
        | grep -oP '"browser_download_url":\s*"\K[^"]+' \
        | grep -E "$2" | sort -V | tail -n1
}

# .deb von GitHub holen und installieren: gh_deb <Name> <repo> <regex>
gh_deb() {
    local name="$1" repo="$2" rx="$3" url tmp="/tmp/gh-$1.deb"
    url=$(gh_asset "$repo" "$rx" || true)
    if [[ -z "$url" ]]; then
        warn "$name: kein passendes .deb-Asset gefunden — übersprungen"
        return 1
    fi
    info "$name: $url"
    if wget -q --show-progress -O "$tmp" "$url" && chmod 644 "$tmp" && apt-get install -y "$tmp"; then
        log "$name installiert"
    else
        warn "$name: Download/Installation fehlgeschlagen"
        rm -f "$tmp"; return 1
    fi
    rm -f "$tmp"
}

# ── APT konfigurieren ─────────────────────────────────────────────────────────
info "APT konfigurieren..."
cat > /etc/apt/apt.conf.d/99custom << 'EOF'
APT::Get::Assume-Yes "true";
Acquire::Languages "none";
EOF
add-apt-repository -y multiverse >/dev/null 2>&1 || warn "multiverse konnte nicht aktiviert werden — prüfen!"
log "APT konfiguriert"

# ── Pins VOR allem anderen (Mozilla gewinnt gegen das Snap-Transitional) ─────
info "APT-Pins setzen (Mozilla bevorzugt, snapd gesperrt)..."
cat > /etc/apt/preferences.d/mozilla.pref << 'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
cat > /etc/apt/preferences.d/nosnap.pref << 'EOF'
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF
log "Pins gesetzt"

# ── Snap purgen ───────────────────────────────────────────────────────────────
info "Snap entfernen..."
# Metapakete festnageln, damit autoremove nach dem snapd-Purge nichts mitreißt
for p in ubuntu-desktop ubuntu-desktop-minimal ubuntu-session gnome-shell gdm3; do
    dpkg -s "$p" >/dev/null 2>&1 && apt-mark manual "$p" >/dev/null
done

if command -v snap >/dev/null 2>&1; then
    # Mehrere Durchgänge: Bases/Runtimes lassen sich erst entfernen, wenn die
    # abhängigen Snaps weg sind. snapd selbst kommt zuletzt.
    for pass in 1 2 3 4 5 6; do
        mapfile -t SNAPS < <(snap list 2>/dev/null | awk 'NR>1 && $1!="snapd" {print $1}')
        [[ ${#SNAPS[@]} -eq 0 ]] && break
        info "Snap-Durchgang $pass: ${SNAPS[*]}"
        for s in "${SNAPS[@]}"; do
            snap remove --purge "$s" >/dev/null 2>&1 && log "  $s entfernt"
        done
    done
    snap remove --purge snapd >/dev/null 2>&1 || true
fi
systemctl disable --now snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
apt-get purge -y snapd 2>/dev/null || true
rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd "$USER_HOME/snap"
hash -r
command -v snap >/dev/null 2>&1 && warn "snap ist noch da — manuell prüfen" || log "Snap entfernt und gesperrt"

# ── System aktualisieren ──────────────────────────────────────────────────────
info "System aktualisieren (Beta: bis 15.10. regelmäßig wiederholen)..."
dpkg --add-architecture i386
apt-get update
apt-get full-upgrade -y
log "System aktuell"

# ── Basis ─────────────────────────────────────────────────────────────────────
info "Basis-Tools installieren..."
apt_try curl wget git unzip zip p7zip-full unrar btop fastfetch fwupd locales \
        language-pack-de language-pack-gnome-de
# Steam-Runtime braucht en_US, sonst pv-locale-gen-Fehler beim ersten Proton-Start
locale-gen en_US.UTF-8 de_DE.UTF-8 >/dev/null
log "Basis-Tools installiert"

# ── Swapfile weg, zram an ─────────────────────────────────────────────────────
info "Swapfile entfernen, zram (15 % / zstd) einrichten..."
swapoff -a 2>/dev/null || true
sed -i '/[[:space:]]swap[[:space:]]/ s/^/#/' /etc/fstab
rm -f /swap.img /swapfile
apt_try systemd-zram-generator
cat > /etc/systemd/zram-generator.conf << 'EOF'
[zram0]
zram-size = ram * 0.15
compression-algorithm = zstd
EOF
log "zram konfiguriert (aktiv nach Reboot)"

# ── Codecs + Mesa/Vulkan (AMD, 64+32 bit) ─────────────────────────────────────
info "Codecs installieren (explizit, ohne ubuntu-restricted-extras)..."
apt_try ffmpeg libavcodec-extra gstreamer1.0-libav gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly ubuntu-restricted-addons
log "Codecs installiert"

info "Mesa/Vulkan/VA-API installieren..."
apt_try mesa-vulkan-drivers mesa-vulkan-drivers:i386 libvulkan1 libvulkan1:i386 \
        libgl1-mesa-dri:i386 mesa-va-drivers mesa-va-drivers:i386 \
        vulkan-tools mesa-utils vainfo
log "RADV 64/32-bit bereit"

# ── NTSYNC ────────────────────────────────────────────────────────────────────
info "NTSYNC konfigurieren..."
echo "ntsync" > /etc/modules-load.d/ntsync.conf
modprobe ntsync 2>/dev/null || warn "ntsync-Modul nicht ladbar — nach Reboot /dev/ntsync prüfen"
log "NTSYNC aktiviert"

# ── Firefox (Mozilla-Repo, deb822) ────────────────────────────────────────────
info "Firefox via Mozilla-Repo installieren..."
install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O /etc/apt/keyrings/packages.mozilla.org.asc
cat > /etc/apt/sources.list.d/mozilla.sources << 'EOF'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
apt-get update
apt_try firefox firefox-l10n-de

mkdir -p /usr/lib/firefox/distribution
cat > /usr/lib/firefox/distribution/policies.json << 'EOF'
{
  "policies": {
    "DisableTelemetry": true,
    "DisablePocket": true,
    "DisableFirefoxStudies": true,
    "DisableFeedbackCommands": true
  }
}
EOF
log "Firefox installiert"

# AppArmor: Ubuntu blockt unprivilegierte User-Namespaces für Apps ohne Profil
# (apparmor_restrict_unprivileged_userns). Das Mozilla-deb hat keins, dann
# meldet Firefox "CanCreateUserNamespace() ... EPERM" und der Sandbox fehlt
# etwas. Profil nach Mozillas Anleitung: nur "userns" erlauben, sonst unconfined.
info "AppArmor-Profil für Firefox (userns) schreiben..."
cat > /etc/apparmor.d/firefox-local << 'EOF'
# Gibt dem Mozilla-Firefox ein Profil mit userns-Recht (sonst EPERM im Sandbox-Setup)
abi <abi/4.0>,
include <tunables/global>

profile firefox-local /{usr/lib,opt}/firefox/{firefox,firefox-bin,updater} flags=(unconfined) {
  userns,

  # Site-specific additions and overrides.
  include if exists <local/firefox>
}
EOF
apparmor_parser -r /etc/apparmor.d/firefox-local 2>/dev/null \
    && log "AppArmor-Profil geladen" \
    || warn "AppArmor-Profil nicht ladbar — nach Reboot prüfen (aa-status)"

# ── Google Chrome ─────────────────────────────────────────────────────────────
info "Google Chrome installieren..."
wget -q --show-progress -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && chmod 644 /tmp/chrome.deb \
    && apt-get install -y /tmp/chrome.deb \
    && log "Chrome installiert (Repo für Updates wird vom Paket angelegt)" \
    || warn "Chrome fehlgeschlagen"
rm -f /tmp/chrome.deb

# ── Gaming: Steam, Protontricks, ProtonPlus ───────────────────────────────────
info "Steam + Protontricks installieren..."
apt_try steam-installer steam-devices
# Hinweis: winetricks hat wine als harte Dependency (~1,2 GB), das ist auch mit
# --no-install-recommends nicht vermeidbar. Proton nutzt trotzdem sein eigenes Wine.
apt-get install -y --no-install-recommends protontricks winetricks || warn "protontricks fehlgeschlagen"
log "Steam + Protontricks installiert"

if [[ $WITH_PROTONPLUS -eq 1 ]]; then
    info "ProtonPlus (Flatpak) installieren..."
    apt_try flatpak
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub com.vysp3r.ProtonPlus || warn "ProtonPlus fehlgeschlagen"
    log "ProtonPlus installiert"
fi

# ── Heroic, Faugus, LACT (GitHub-.deb, Asset per API aufgelöst) ───────────────
info "Heroic / Faugus / LACT installieren..."
apt_try libglvnd0 libgles2   # GLES für Faugus/GTK
gh_deb heroic Heroic-Games-Launcher/HeroicGamesLauncher 'Heroic-[0-9.]+-linux-amd64\.deb$'
gh_deb faugus Faugus/faugus-launcher 'faugus-launcher_[^/]*_all\.deb$'
# LACT: höchste verfügbare ubuntu-XXXX-Variante (2404/2604/...)
if gh_deb lact ilya-zlobintsev/LACT 'lact-[0-9.]+-[0-9]+\.amd64\.ubuntu-[0-9]+\.deb$'; then
    systemctl enable --now lactd 2>/dev/null || warn "lactd nicht aktivierbar — nach Reboot prüfen"
fi

# ── Tuning: sysctl + Gaming-ENV ───────────────────────────────────────────────
info "sysctl + Gaming-ENV schreiben..."
cat > /etc/sysctl.d/99-gaming.conf << 'EOF'
kernel.split_lock_mitigate=0
vm.max_map_count=2147483642
EOF
sysctl --system >/dev/null

mkdir -p /etc/environment.d
cat > /etc/environment.d/90-gaming.conf << 'EOF'
MESA_SHADER_CACHE_MAX_SIZE=12G
PROTON_ENABLE_HDR=1
PROTON_USE_OPTISCALER=1
PROTON_FSR4_UPGRADE=1
PROTON_XESS_UPGRADE=1
PROTON_ENABLE_WAYLAND=1
EOF
systemctl enable fstrim.timer 2>/dev/null || true
log "sysctl + ENV gesetzt"

# ── Firewall (ufw) ────────────────────────────────────────────────────────────
info "ufw einrichten..."
apt_try ufw
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw allow in 5353/udp comment 'mDNS (Drucker-Discovery)' >/dev/null
# Steam Local Network Game Transfer — bei Bedarf:
# ufw allow in 27040/tcp; ufw allow in 27036/udp
ufw --force enable >/dev/null
log "ufw aktiv (incoming dicht, mDNS offen)"

# ── Fish ──────────────────────────────────────────────────────────────────────
info "Fish installieren..."
apt_try fish
chsh -s /usr/bin/fish "$CURRENT_USER" || warn "Default-Shell nicht gesetzt — manuell: chsh -s /usr/bin/fish"
mkdir -p "$USER_HOME/.config/fish"
cat > "$USER_HOME/.config/fish/config.fish" << 'EOF'
# Fish — Ubuntu 26.10
if status is-interactive
    set -g fish_greeting

    # Update: apt + Flatpak (ProtonPlus)
    abbr -a up    'sudo apt update; and sudo apt full-upgrade; and flatpak update'
    abbr -a fw    'sudo fwupdmgr refresh --force; and sudo fwupdmgr update'

    # APT
    abbr -a in    'sudo apt install'
    abbr -a rem   'sudo apt remove'
    abbr -a purge 'sudo apt purge'
    abbr -a se    'apt search'
    abbr -a inf   'apt show'
    abbr -a li    'apt list --installed'
    abbr -a hist  'grep -E " install | remove | purge " /var/log/dpkg.log'
    abbr -a wp    'dpkg -S'
    abbr -a clean 'sudo apt autoremove -y; and sudo apt clean'

    # Flatpak
    abbr -a fin   'flatpak install flathub'
    abbr -a fse   'flatpak search'
    abbr -a frem  'flatpak uninstall'
    abbr -a fli   'flatpak list --app'
end
EOF
log "Fish konfiguriert"

# ── Kitty + Tokyo Night (optional) ────────────────────────────────────────────
if [[ $WITH_KITTY -eq 1 ]]; then
    info "Kitty + JetBrainsMono Nerd Font installieren..."
    apt_try kitty fonts-noto-color-emoji fonts-liberation
    FONT_DIR="/usr/local/share/fonts/JetBrainsMonoNF"
    mkdir -p "$FONT_DIR"
    if curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" -o /tmp/jbm.zip; then
        unzip -qo /tmp/jbm.zip -d "$FONT_DIR" && fc-cache -f >/dev/null
    else
        warn "Nerd Font Download fehlgeschlagen"
    fi
    rm -f /tmp/jbm.zip

    mkdir -p "$USER_HOME/.config/kitty"
    cat > "$USER_HOME/.config/kitty/kitty.conf" << 'EOF'
font_family      JetBrainsMono Nerd Font
font_size        11.0
confirm_os_window_close 0
enable_audio_bell no

# Tokyo Night
background #1a1b26
foreground #c0caf5
selection_background #283457
selection_foreground #c0caf5
cursor #c0caf5
url_color #73daca
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
EOF
    log "Kitty konfiguriert"
fi

# ── Vorlagen ──────────────────────────────────────────────────────────────────
info "Vorlagen anlegen..."
TEMPLATES_DIR="$USER_HOME/Vorlagen"
mkdir -p "$TEMPLATES_DIR"
touch "$TEMPLATES_DIR/Leere Textdatei.txt" "$TEMPLATES_DIR/Dokument.md" "$TEMPLATES_DIR/Skript.sh"
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
log "Vorlagen angelegt"

# ── Rechte + Aufräumen ────────────────────────────────────────────────────────
chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.config/fish" "$USER_HOME/.config/kitty" "$TEMPLATES_DIR" 2>/dev/null || true
info "Aufräumen..."
apt-get autoremove -y
apt-get clean
log "Aufgeräumt"

# ── Abschluss ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  Setup abgeschlossen!${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Nach dem Reboot prüfen:${NC}"
echo -e "  • Snap:     ${BOLD}snap list${NC}            → Befehl nicht gefunden"
echo -e "  • Firefox:  ${BOLD}firefox --version${NC}    → kein Snap"
echo -e "  • VA-API:   ${BOLD}vainfo${NC}               → H264/HEVC unter VAEntrypointVLD"
echo -e "  • Vulkan:   ${BOLD}vulkaninfo --summary${NC} → RADV"
echo -e "  • NTSYNC:   ${BOLD}ls /dev/ntsync${NC}"
echo -e "  • zram:     ${BOLD}zramctl${NC}  /  ${BOLD}swapon --show${NC} → nur zram0"
echo -e "  • LACT:     -70 mV / PL -25% setzen"
echo -e "  • Steam starten, Proton-GE via ProtonPlus ziehen"
echo ""
echo -e "  ${YELLOW}Neustart empfohlen.${NC}"
echo ""
