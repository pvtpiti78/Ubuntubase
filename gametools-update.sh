#!/bin/bash
# =============================================================================
# gametools-update.sh — LACT · Heroic · Faugus Updater
# =============================================================================
# Kompatibel mit Ubuntu 24.04 / 26.04 / 26.10 und Debian-basierten Systemen
# Prüft installierte Version gegen GitHub latest — fragt vor jedem Update.
# Die .deb-URL wird per GitHub-API aus den Release-Assets aufgelöst (keine
# hartkodierten Dateinamen), damit Namenswechsel wie ubuntu-2404 -> ubuntu-2604
# das Script nicht stillschweigend brechen.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}[✓]${NC} $*"; }
info()    { echo -e "${CYAN}[→]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
err()     { echo -e "${RED}[✗]${NC} $*"; }
updated() { echo -e "${GREEN}[↑]${NC} $*"; }
skipped() { echo -e "${YELLOW}[–]${NC} $*"; }

[[ $EUID -ne 0 ]] && err "Bitte als root ausführen: sudo bash gametools-update.sh" && exit 1

clear
echo -e "${BOLD}${CYAN}"
echo "  ██████╗  █████╗ ███╗   ███╗███████╗"
echo "  ██╔════╝ ██╔══██╗████╗ ████║██╔════╝"
echo "  ██║  ███╗███████║██╔████╔██║█████╗  "
echo "  ██║   ██║██╔══██║██║╚██╔╝██║██╔══╝  "
echo "  ╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗"
echo "   ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Gaming Tools Updater${NC}"
echo -e "  LACT · Heroic · Faugus"
echo ""

# ── Distro-Variante für LACT-Asset (ubuntu-XXXX oder debian-XX) ──────────────
# shellcheck disable=SC1091
. /etc/os-release
if [[ "${ID:-}" == "ubuntu" || "${ID_LIKE:-}" == *ubuntu* ]]; then
    LACT_FLAVOUR="ubuntu"
else
    LACT_FLAVOUR="debian"
fi

# ── Hilfsfunktion: installierte dpkg-Version holen ───────────────────────────
dpkg_version() {
    local v
    v=$(dpkg-query -W -f='${Version}' "$1" 2>/dev/null || true)
    echo "${v:-nicht installiert}"
}

# ── Hilfsfunktion: Update-Frage ───────────────────────────────────────────────
ask_update() {
    local name="$1" installed="$2" latest="$3"
    echo ""
    echo -e "  ${BOLD}$name${NC}"
    echo -e "  Installiert : ${YELLOW}$installed${NC}"
    echo -e "  Verfügbar   : ${GREEN}$latest${NC}"
    echo -ne "  Updaten? [y/N] "
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# ── Hilfsfunktion: kein Update nötig ─────────────────────────────────────────
up_to_date() {
    echo ""
    echo -e "  ${BOLD}$1${NC}"
    echo -e "  $(skipped "Aktuell ($2) — kein Update nötig")"
}

# ── Zentrale Update-Funktion ──────────────────────────────────────────────────
# update_pkg <Anzeigename> <dpkg-Paket> <github-repo> <asset-regex> [post-hook]
# Der Regex wählt unter den .deb-Assets des latest-Releases aus; bei mehreren
# Treffern gewinnt die höchste Version (sort -V), z.B. ubuntu-2604 > ubuntu-2404.
update_pkg() {
    local name="$1" pkg="$2" repo="$3" rx="$4" post="${5:-}"
    local json tag latest url installed tmp="/tmp/gametools-$2.deb"

    info "Prüfe $name..."

    json=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" || true)
    if [[ -z "$json" ]]; then
        warn "$name: GitHub-API nicht erreichbar — übersprungen"
        return 0
    fi

    tag=$(grep -m1 '"tag_name"' <<<"$json" | sed 's/.*"\([^"]*\)".*/\1/' || true)
    latest="${tag#v}"
    url=$(grep -oP '"browser_download_url":\s*"\K[^"]+' <<<"$json" | grep -E "$rx" | sort -V | tail -n1 || true)

    if [[ -z "$tag" || -z "$url" ]]; then
        warn "$name: kein passendes .deb im latest-Release (Tag: ${tag:-?}) — Asset-Namen prüfen"
        return 0
    fi

    installed=$(dpkg_version "$pkg")

    if [[ "$installed" == *"$latest"* ]]; then
        up_to_date "$name" "$installed"
        return 0
    fi

    if ask_update "$name" "$installed" "$latest"; then
        info "Lade $name ${latest}..."
        info "  $url"
        if wget -q --show-progress -O "$tmp" "$url" && chmod 644 "$tmp" && apt-get install -y "$tmp"; then
            rm -f "$tmp"
            [[ -n "$post" ]] && eval "$post"
            updated "$name auf ${latest} aktualisiert"
        else
            rm -f "$tmp"
            err "$name: Download oder Installation fehlgeschlagen"
        fi
    else
        skipped "$name übersprungen"
    fi
}

# =============================================================================
# LACT / Heroic / Faugus
# =============================================================================
update_pkg "LACT" "lact" "ilya-zlobintsev/LACT" \
    "lact-[0-9.]+-[0-9]+\.amd64\.${LACT_FLAVOUR}-[0-9]+\.deb$" \
    "systemctl enable --now lactd 2>/dev/null || true"

update_pkg "Heroic Games Launcher" "heroic" "Heroic-Games-Launcher/HeroicGamesLauncher" \
    "Heroic-[0-9.]+-linux-amd64\.deb$"

update_pkg "Faugus Launcher" "faugus-launcher" "Faugus/faugus-launcher" \
    "faugus-launcher_[^/]*_all\.deb$"

# =============================================================================
# Abschluss
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  Update-Check abgeschlossen!${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo ""
