#!/bin/bash
# =============================================================================
# dpi_bypass_setup.sh - ISP DPI (SNI-RST) bypass via zapret/nfqws
# =============================================================================
# Why: FPT Telecom's DPI sits at the international gateway, reads the TLS SNI
# and injects RST (store.steampowered.com, medium.com, luatkhoa.net, ...).
# DNS changes can't help (the block is post-resolve). Splitting the ClientHello
# across TCP segments blinds the DPI. zapret's nfqws does that system-wide via
# nftables NFQUEUE — no VPN needed. Fedora ships no zapret package → we build
# nfqws from a pinned upstream commit.
#
# Idempotent: re-runs only rebuild when the pinned commit changes (or --rebuild),
# only rewrite configs that differ, only restart the service when something changed.
#
# Usage:
#   ./dpi_bypass_setup.sh            # install / update
#   ./dpi_bypass_setup.sh --rebuild  # force rebuild nfqws from source
#   ./dpi_bypass_setup.sh --uninstall
#
# Rollback: --uninstall (service disabled, nft table dropped, files removed).
# Quick toggle without uninstalling: sudo systemctl stop|start zapret
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
check_not_root

ASSETS_DIR="$SCRIPT_DIR/../assets/zapret"
ZAPRET_REPO="https://github.com/bol-van/zapret.git"
ZAPRET_COMMIT="${ZAPRET_COMMIT:-87e0586}"   # pinned; override via env to bump
NFQWS_BIN="/usr/local/bin/nfqws"
ETC_DIR="/etc/zapret"
UNIT_DST="/etc/systemd/system/zapret.service"
VERIFY_HOSTS="store.steampowered.com luatkhoa.net medium.com"

REBUILD=false
UNINSTALL=false
for arg in "$@"; do
    case $arg in
        --rebuild)   REBUILD=true ;;
        --uninstall) UNINSTALL=true ;;
        *) log_error "Unknown option: $arg"; exit 1 ;;
    esac
done

# -----------------------------------------------------------------------------
# Uninstall
# -----------------------------------------------------------------------------
if $UNINSTALL; then
    log_section "Removing zapret DPI bypass..."
    run_sudo systemctl disable --now zapret 2>/dev/null || true
    run_sudo nft delete table inet zapret 2>/dev/null || true
    run_sudo rm -f "$UNIT_DST" "$NFQWS_BIN"
    run_sudo rm -rf "$ETC_DIR"
    run_sudo systemctl daemon-reload
    log_success "zapret removed (build deps left installed)"
    exit 0
fi

log_section "Configuring DPI bypass (zapret/nfqws)..."

# -----------------------------------------------------------------------------
# 1. Build dependencies
# -----------------------------------------------------------------------------
DEPS=(gcc make git nftables libnetfilter_queue-devel libmnl-devel libnfnetlink-devel zlib-ng-compat-devel)
MISSING=()
for p in "${DEPS[@]}"; do rpm -q "$p" &>/dev/null || MISSING+=("$p"); done
if [[ ${#MISSING[@]} -gt 0 ]]; then
    log_info "Installing build deps: ${MISSING[*]}"
    dnf_install "${MISSING[@]}"
else
    log_info "Build deps already installed"
fi

# -----------------------------------------------------------------------------
# 2. Build nfqws from pinned commit (only if missing / commit changed / --rebuild)
# -----------------------------------------------------------------------------
INSTALLED_COMMIT=""
[[ -f "$ETC_DIR/zapret.commit" ]] && INSTALLED_COMMIT="$(cat "$ETC_DIR/zapret.commit")"

CHANGED=false
if $REBUILD || [[ ! -x "$NFQWS_BIN" ]] || [[ "$INSTALLED_COMMIT" != "$ZAPRET_COMMIT" ]]; then
    log_info "Building nfqws from $ZAPRET_REPO @ $ZAPRET_COMMIT"
    BUILD_DIR="$(mktemp -d)"
    trap 'rm -rf "$BUILD_DIR"' EXIT
    git clone -q --filter=blob:none "$ZAPRET_REPO" "$BUILD_DIR/zapret"
    git -C "$BUILD_DIR/zapret" checkout -q "$ZAPRET_COMMIT"
    make -C "$BUILD_DIR/zapret/nfq" -j"$(nproc)" >/dev/null
    run_sudo install -m 755 "$BUILD_DIR/zapret/nfq/nfqws" "$NFQWS_BIN"
    run_sudo install -d -m 755 "$ETC_DIR"
    echo "$ZAPRET_COMMIT" | run_sudo tee "$ETC_DIR/zapret.commit" >/dev/null
    log_success "Installed $NFQWS_BIN ($("$NFQWS_BIN" --version 2>&1 | head -1))"
    CHANGED=true
else
    log_info "nfqws already at commit $ZAPRET_COMMIT — skipping build"
fi

# -----------------------------------------------------------------------------
# 3. Config + unit (write only when different)
# -----------------------------------------------------------------------------
install_if_changed() {
    local src="$1" dst="$2"
    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        log_info "Up to date: $dst"
    else
        run_sudo install -D -m 644 "$src" "$dst"
        log_success "Installed: $dst"
        CHANGED=true
    fi
}
install_if_changed "$ASSETS_DIR/zapret.nft"     "$ETC_DIR/zapret.nft"
install_if_changed "$ASSETS_DIR/nfqws.conf"     "$ETC_DIR/nfqws.conf"
install_if_changed "$ASSETS_DIR/zapret.service" "$UNIT_DST"

# -----------------------------------------------------------------------------
# 4. Service
# -----------------------------------------------------------------------------
run_sudo systemctl daemon-reload
run_sudo systemctl enable zapret >/dev/null 2>&1
if $CHANGED || ! systemctl is-active --quiet zapret; then
    run_sudo systemctl restart zapret
    log_success "zapret service (re)started"
else
    log_info "zapret service already running, nothing changed"
fi

# -----------------------------------------------------------------------------
# 5. Verify
# -----------------------------------------------------------------------------
sleep 1
if ! systemctl is-active --quiet zapret; then
    log_error "zapret service failed to start:"
    systemctl status zapret --no-pager | tail -15
    exit 1
fi
run_sudo nft list table inet zapret >/dev/null || { log_error "nft table 'inet zapret' missing"; exit 1; }

FAIL=0
for h in $VERIFY_HOSTS; do
    code=$(curl -sS -o /dev/null -m 8 -w "%{http_code}" "https://$h/" 2>/dev/null || true)
    if [[ "$code" == "000" || -z "$code" ]]; then
        log_warn "  $h → no TLS response (still blocked, or site down)"
        FAIL=$((FAIL+1))
    else
        log_success "  $h → HTTP $code"
    fi
done
if [[ $FAIL -eq 0 ]]; then
    log_success "DPI bypass active — SNI-blocked sites reachable without VPN"
else
    log_warn "$FAIL/$(echo $VERIFY_HOSTS | wc -w) test hosts unreachable. Tune NFQWS_OPTS in $ETC_DIR/nfqws.conf (see assets/zapret/nfqws.conf) and restart."
fi
