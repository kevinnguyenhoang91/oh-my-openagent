#!/usr/bin/env bash
# install.sh — Install oh-my-opencode (linux-arm64) from GitHub releases
#
# Usage:
#   # From GitHub (latest release):
#   curl -fsSL https://github.com/kevinnguyenhoang91/oh-my-openagent/raw/HEAD/install.sh | bash
#
#   # Specific tag:
#   curl -fsSL https://github.com/kevinnguyenhoang91/oh-my-openagent/raw/HEAD/install.sh | bash -s -- --tag v4.0.0
#
#   # Custom install dir (default: ~/.local/bin):
#   ./install.sh --install-dir /usr/local/bin
#
#   # Build from source instead of downloading (requires bun):
#   ./install.sh --from-source

set -euo pipefail

REPO="kevinnguyenhoang91/oh-my-openagent"
BINARY_NAME="oh-my-opencode"
INSTALL_DIR="${HOME}/.local/bin"
TAG=""
FROM_SOURCE=false

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="$2"; shift 2 ;;
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    --from-source) FROM_SOURCE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Detect platform
# ---------------------------------------------------------------------------
OS="$(uname -s)"
ARCH="$(uname -m)"

if [[ "$OS" != "Linux" || "$ARCH" != "aarch64" ]]; then
  echo "Error: This installer supports linux/aarch64 (arm64) only."
  echo "  Detected: $OS / $ARCH"
  echo ""
  echo "For other platforms, install via npm:"
  echo "  npm install -g oh-my-opencode"
  exit 1
fi

mkdir -p "$INSTALL_DIR"

# ---------------------------------------------------------------------------
# Helper: print PATH hint if install dir is not in PATH
# ---------------------------------------------------------------------------
_print_path_hint() {
  if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "Add $INSTALL_DIR to your PATH:"
    echo "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
    echo ""
    echo "Or for zsh:"
    echo "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
  fi
  echo ""
  echo "Verify installation:"
  echo "  $BINARY_NAME --version"
}

# ---------------------------------------------------------------------------
# Helper: download a URL to a destination file
# ---------------------------------------------------------------------------
_download() {
  local url="$1" dest="$2"
  if command -v curl &>/dev/null; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget &>/dev/null; then
    wget -qO "$dest" "$url"
  else
    echo "Error: 'curl' or 'wget' is required."
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Option A: Build from source (requires bun in PATH)
# ---------------------------------------------------------------------------
if [[ "$FROM_SOURCE" == "true" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if ! command -v bun &>/dev/null; then
    echo "Error: 'bun' is required to build from source."
    echo "  Install bun: curl -fsSL https://bun.sh/install | bash"
    exit 1
  fi

  echo "Building from source..."
  cd "$SCRIPT_DIR"
  bun install --frozen-lockfile
  mkdir -p packages/linux-arm64/bin
  bun build src/cli/index.ts \
    --compile \
    --minify \
    --target=bun-linux-arm64 \
    --outfile=packages/linux-arm64/bin/oh-my-opencode

  BUILT_BINARY="$SCRIPT_DIR/packages/linux-arm64/bin/oh-my-opencode"
  chmod +x "$BUILT_BINARY"
  cp "$BUILT_BINARY" "$INSTALL_DIR/$BINARY_NAME"
  echo "Installed from source: $INSTALL_DIR/$BINARY_NAME"
  _print_path_hint
  exit 0
fi

# ---------------------------------------------------------------------------
# Option B: Download from GitHub releases
# ---------------------------------------------------------------------------

# Resolve release tag
if [[ -z "$TAG" ]]; then
  echo "Fetching latest release tag..."
  TMP_JSON="$(mktemp)"
  _download "https://api.github.com/repos/${REPO}/releases/latest" "$TMP_JSON"
  TAG="$(grep '"tag_name"' "$TMP_JSON" | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')"
  rm -f "$TMP_JSON"

  if [[ -z "$TAG" ]]; then
    echo "Error: Could not determine latest release tag."
    echo "  Check: https://github.com/${REPO}/releases"
    echo "  Or specify manually: ./install.sh --tag v4.0.0"
    exit 1
  fi
  echo "Latest release: $TAG"
fi

TARBALL_URL="https://github.com/${REPO}/releases/download/${TAG}/oh-my-opencode-linux-arm64.tar.gz"
TMP_DIR="$(mktemp -d)"
TMP_TAR="$TMP_DIR/oh-my-opencode-linux-arm64.tar.gz"

echo "Downloading: $TARBALL_URL"
_download "$TARBALL_URL" "$TMP_TAR"

echo "Extracting..."
tar -xzf "$TMP_TAR" -C "$TMP_DIR"

EXTRACTED_BIN="$TMP_DIR/bin/oh-my-opencode"
if [[ ! -f "$EXTRACTED_BIN" ]]; then
  echo "Error: Expected binary not found in archive."
  ls -la "$TMP_DIR/"
  rm -rf "$TMP_DIR"
  exit 1
fi

chmod +x "$EXTRACTED_BIN"
cp "$EXTRACTED_BIN" "$INSTALL_DIR/$BINARY_NAME"
rm -rf "$TMP_DIR"

echo "Installed: $INSTALL_DIR/$BINARY_NAME ($TAG)"
_print_path_hint
