#!/usr/bin/env bash
set -euo pipefail

# Sheaf Linux installer — downloads the self-contained tarball from GitHub
# Releases, extracts to ~/.local/share/sheaf (keep sheaf/ intact), links
# ~/.local/bin/sheaf and creates a desktop entry.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/AbrarAbe/sheaf/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/AbrarAbe/sheaf/main/install.sh | bash -s -- --version v0.3.0 --prefix "$HOME/.local/share"
#   ./install.sh --uninstall
#
# Idempotent: re-running overwrites the previous install.

REPO="AbrarAbe/sheaf"
PREFIX="${PREFIX:-$HOME/.local/share}"
BINDIR="${BINDIR:-$HOME/.local/bin}"
VERSION="latest"
DO_UNINSTALL=0
NO_DESKTOP=0
FORCE=0
URL_OVERRIDE=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --version <tag>     Version to install (e.g. v0.3.0) or 'latest' (default: latest)
  --prefix <dir>      Install prefix (default: \$HOME/.local/share)
  --bindir <dir>      Bin dir for symlink (default: \$HOME/.local/bin)
  --url <url>         Override download URL (for testing)
  --no-desktop        Skip desktop entry creation
  --force             Overwrite without prompt
  --uninstall         Remove installed files
  -h, --help          Show this help
EOF
}

log()  { printf '[sheaf] %s\n' "$*"; }
warn() { printf '[sheaf] WARN: %s\n' "$*" >&2; }
die()  { printf '[sheaf] ERROR: %s\n' "$*" >&2; exit 1; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

download() {
  local url="$1" dest="$2"
  if [[ "$url" == file://* ]]; then
    local path="${url#file://}"
    cp -f "$path" "$dest"
    return
  fi
  if has_cmd curl; then
    curl -fsSL -o "$dest" "$url"
  elif has_cmd wget; then
    wget -qO "$dest" "$url"
  else
    die "Need curl or wget to download $url"
  fi
}

resolve_version() {
  local ver="$1"
  if [[ "$ver" == "latest" ]]; then
    if has_cmd curl; then
      local api="https://api.github.com/repos/${REPO}/releases/latest"
      local tag
      tag=$(curl -fsSL "$api" 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4 || true)
      if [[ -n "$tag" ]]; then
        echo "$tag"
        return
      fi
    fi
    warn "Could not resolve latest tag via API, trying 'latest' URL"
    echo "latest"
  else
    if [[ "$ver" != v* ]]; then
      echo "v$ver"
    else
      echo "$ver"
    fi
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="${2:-}"; shift 2 ;;
    --prefix) PREFIX="${2:-}"; shift 2 ;;
    --bindir) BINDIR="${2:-}"; shift 2 ;;
    --url) URL_OVERRIDE="${2:-}"; shift 2 ;;
    --no-desktop) NO_DESKTOP=1; shift ;;
    --force) FORCE=1; shift ;;
    --uninstall) DO_UNINSTALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) die "Unknown option: $1 (see --help)" ;;
    *) break ;;
  esac
done

PREFIX="${PREFIX/#\~/$HOME}"
BINDIR="${BINDIR/#\~/$HOME}"

DESKTOP_FILE="$HOME/.local/share/applications/sheaf.desktop"
INSTALL_DIR="$PREFIX/sheaf"
BIN_LINK="$BINDIR/sheaf"

if [[ "$DO_UNINSTALL" -eq 1 ]]; then
  log "Uninstalling Sheaf..."
  rm -rf "$INSTALL_DIR" 2>/dev/null || true
  rm -f "$BIN_LINK" 2>/dev/null || true
  rm -f "$DESKTOP_FILE" 2>/dev/null || true
  if has_cmd update-desktop-database; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
  fi
  log "Removed $INSTALL_DIR, $BIN_LINK, $DESKTOP_FILE"
  exit 0
fi

if [[ -n "$URL_OVERRIDE" ]]; then
  URL="$URL_OVERRIDE"
else
  RESOLVED=$(resolve_version "$VERSION")
  if [[ "$RESOLVED" == "latest" ]]; then
    URL="https://github.com/${REPO}/releases/latest/download/sheaf-${RESOLVED}-linux-x64.tar.gz"
    warn "Using 'latest' download URL — if 404, retry with --version vX.Y.Z"
  else
    URL="https://github.com/${REPO}/releases/download/${RESOLVED}/sheaf-${RESOLVED}-linux-x64.tar.gz"
  fi
fi

log "Install prefix: $PREFIX"
log "Bin dir: $BINDIR"
log "Version: $VERSION (resolved: ${RESOLVED:-$VERSION})"
log "URL: $URL"

if ! has_cmd tar; then die "Need tar"; fi
if ! has_cmd mkdir; then die "Need mkdir"; fi
if ! has_cmd ln; then die "Need ln"; fi

# Check GTK 3 (soft check) — avoid pipefail SIGPIPE
GTK_OK=0
if has_cmd ldconfig; then
  if ldconfig -p 2>/dev/null | grep -q libgtk-3 2>/dev/null; then
    GTK_OK=1
  fi || true
fi
if [[ $GTK_OK -eq 0 ]]; then
  if has_cmd dpkg; then
    if dpkg -l libgtk-3-0 2>/dev/null | grep -q "^ii" 2>/dev/null; then
      GTK_OK=1
    fi || true
  fi
fi
if [[ $GTK_OK -eq 0 ]]; then
  warn "libgtk-3-0 not detected — Sheaf needs GTK 3 (sudo apt install libgtk-3-0)"
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
TARBALL="$TMPDIR/sheaf.tar.gz"

log "Downloading..."
if ! download "$URL" "$TARBALL"; then
  die "Download failed from $URL — check version/network (try --version v0.3.0)"
fi
if [[ ! -s "$TARBALL" ]]; then die "Downloaded file is empty"; fi

log "Extracting to $PREFIX..."
mkdir -p "$PREFIX"

TOP=$(tar tzf "$TARBALL" 2>/dev/null | head -1 | cut -d/ -f1)
if [[ "$TOP" != "sheaf" ]]; then
  warn "Tarball top-level is '$TOP' (expected 'sheaf') — extracting as-is"
fi

if [[ -d "$INSTALL_DIR" && "$FORCE" -eq 0 ]]; then
  log "Existing install at $INSTALL_DIR — overwriting"
fi
rm -rf "$INSTALL_DIR"
tar xzf "$TARBALL" -C "$PREFIX"
if [[ ! -x "$INSTALL_DIR/sheaf" ]]; then
  warn "Binary not found at $INSTALL_DIR/sheaf — listing $PREFIX:"
  ls -R "$PREFIX" | head -n 50 >&2 || true
  die "Extraction failed — binary missing"
fi
chmod +x "$INSTALL_DIR/sheaf" 2>/dev/null || true

mkdir -p "$BINDIR"
ln -sf "$INSTALL_DIR/sheaf" "$BIN_LINK"
log "Linked $BIN_LINK -> $INSTALL_DIR/sheaf"

if [[ "$NO_DESKTOP" -eq 0 ]]; then
  mkdir -p "$(dirname "$DESKTOP_FILE")"
  cat > "$DESKTOP_FILE" <<EOF2
[Desktop Entry]
Name=Sheaf
Comment=Local-first Markdown notes desk
Exec=$BIN_LINK
Icon=$INSTALL_DIR/data/flutter_assets/assets/icon.png
Terminal=false
Type=Application
Categories=Office;TextEditor;
StartupWMClass=sheaf
EOF2
  if [[ ! -f "$INSTALL_DIR/data/flutter_assets/assets/icon.png" ]]; then
    ICON_CANDIDATE=$(find "$INSTALL_DIR" -name "*.png" | head -1 || true)
    if [[ -n "$ICON_CANDIDATE" ]]; then
      sed -i "s|^Icon=.*|Icon=$ICON_CANDIDATE|" "$DESKTOP_FILE"
    else
      sed -i "s|^Icon=.*|Icon=text-editor|" "$DESKTOP_FILE"
    fi
  fi
  chmod +x "$DESKTOP_FILE" 2>/dev/null || true
  if has_cmd update-desktop-database; then
    update-desktop-database "$(dirname "$DESKTOP_FILE")" 2>/dev/null || true
  fi
  log "Desktop entry: $DESKTOP_FILE"
fi

log "Installed Sheaf to $INSTALL_DIR"
log "Run: $BIN_LINK  (or $INSTALL_DIR/sheaf)"
if [[ ":$PATH:" != *":$BINDIR:"* ]]; then
  warn "$BINDIR is not in PATH — add: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
log "Done."
