#!/bin/bash
set -euo pipefail

# Build AppImage for Sheaf Linux desktop app
# Usage: ./build_appimage.sh [output-name]
#   output-name defaults to "Sheaf.AppImage"
#   Example: ./build_appimage.sh sheaf-v0.3.2-linux-x64.AppImage

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$PROJECT_ROOT/tools"
BUILD_DIR="$PROJECT_ROOT/build/linux/x64/release/bundle"
APPDIR="$PROJECT_ROOT/AppDir"

# Accept output filename as first argument, default to Sheaf.AppImage
OUTPUT_NAME="${1:-Sheaf.AppImage}"
OUTPUT_APPIMAGE="$PROJECT_ROOT/$OUTPUT_NAME"

mkdir -p "$TOOLS_DIR"

echo "📦 Building AppImage: $OUTPUT_NAME"

# Retry function with exponential backoff
retry() {
    local max_attempts=3
    local attempt=1
    local delay=2
    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        echo "⚠️  Attempt $attempt failed. Retrying in ${delay}s..."
        sleep $delay
        delay=$((delay * 2))
        attempt=$((attempt + 1))
    done
    echo "❌ Command failed after $max_attempts attempts: $*"
    return 1
}

# Download a tool if missing
download_tool() {
    local url="$1"
    local output="$2"
    if [ -f "$output" ] && [ -x "$output" ]; then
        echo "✅ $(basename "$output") already present"
        return 0
    fi
    echo "⬇️  Downloading $(basename "$output")..."
    rm -f "$output"
    if command -v wget >/dev/null 2>&1; then
        retry wget -q --show-progress -O "$output" "$url"
    elif command -v curl >/dev/null 2>&1; then
        retry curl -# -L -o "$output" "$url"
    else
        echo "❌ Neither wget nor curl found. Please install one."
        return 1
    fi
    chmod +x "$output"
    echo "✅ Downloaded $(basename "$output")"
}

# 1. Check prerequisites
if ! command -v flutter >/dev/null 2>&1; then
    echo "❌ flutter not found. Please install Flutter."
    exit 1
fi

# Download linuxdeploy and GTK plugin
LINUXDEPLOY_PATH="$TOOLS_DIR/linuxdeploy-x86_64.AppImage"
LINUXDEPLOY_EXTRACTED="$TOOLS_DIR/squashfs-root"
PLUGIN_SH="$TOOLS_DIR/linuxdeploy-plugin-gtk"
APPIMAGETOOL="$TOOLS_DIR/squashfs-root/plugins/linuxdeploy-plugin-appimage/usr/bin/appimagetool"

download_tool "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage" "$LINUXDEPLOY_PATH"

# Extract linuxdeploy AppImage (FUSE usually unavailable in CI/sandbox)
if [ ! -d "$LINUXDEPLOY_EXTRACTED" ]; then
    echo "📦 Extracting linuxdeploy..."
    cd "$TOOLS_DIR"
    "$LINUXDEPLOY_PATH" --appimage-extract >/dev/null 2>&1
    cd "$PROJECT_ROOT"
    echo "✅ Extracted linuxdeploy"
fi
LINUXDEPLOY_BIN="$LINUXDEPLOY_EXTRACTED/AppRun"

# Download the GTK plugin as a shell script
PLUGIN_SH_URL="https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh"
if [ -f "$PLUGIN_SH" ] && [ -x "$PLUGIN_SH" ]; then
    echo "✅ linuxdeploy-plugin-gtk already present"
else
    echo "⬇️  Downloading linuxdeploy-plugin-gtk (shell script)..."
    rm -f "$PLUGIN_SH"
    if command -v wget >/dev/null 2>&1; then
        retry wget -q --show-progress -O "$PLUGIN_SH" "$PLUGIN_SH_URL"
    elif command -v curl >/dev/null 2>&1; then
        retry curl -# -L -o "$PLUGIN_SH" "$PLUGIN_SH_URL"
    else
        echo "❌ Neither wget nor curl found. Please install one."
        exit 1
    fi
    chmod +x "$PLUGIN_SH"
    echo "✅ Downloaded linuxdeploy-plugin-gtk"
fi

# Add tools to PATH
export PATH="$TOOLS_DIR:$PATH"

# 2. Flutter build
echo "🔨 Building Linux bundle..."
cd "$PROJECT_ROOT"
export HOME="$(mktemp -d /tmp/sheaf-build-XXXXXX)"
export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
git config --file "$GIT_CONFIG_GLOBAL" --add safe.directory "*" >/dev/null 2>&1 || true
flutter build linux --release

if [ ! -d "$BUILD_DIR" ]; then
    echo "❌ Build failed – bundle not found at $BUILD_DIR"
    exit 1
fi

# 3. Prepare AppDir
echo "📁 Preparing AppDir..."
rm -rf "$APPDIR"
mkdir -p "$APPDIR"

# Copy the entire Flutter bundle (preserves original structure: sheaf + lib/ + data/)
cp -r "$BUILD_DIR"/* "$APPDIR/"

# Create AppRun wrapper
cat >"$APPDIR/AppRun" <<'APPRUN'
#!/bin/bash
set -euo pipefail
APPDIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$APPDIR/lib"
exec "$APPDIR/sheaf" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

# Create desktop file
cat >"$APPDIR/sheaf.desktop" <<EOF
[Desktop Entry]
Name=Sheaf
Comment=Sheaf note-taking app
Exec=sheaf
Icon=sheaf
Type=Application
Categories=Utility;
EOF

# Use the Android launcher icon as the desktop icon
ANDROID_ICON="$PROJECT_ROOT/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
if [ -f "$ANDROID_ICON" ]; then
    cp "$ANDROID_ICON" "$APPDIR/sheaf.png"
    echo "📱 Using Android icon as desktop icon"
fi

# 4. Use linuxdeploy (without --output) to bundle GTK libs into the AppDir
echo "📦 Bundling GTK dependencies..."
"$LINUXDEPLOY_BIN" --appdir "$APPDIR" \
    --plugin gtk \
    --executable "$APPDIR/sheaf" \
    --desktop-file "$APPDIR/sheaf.desktop" 2>/dev/null || true

# 5. Package into AppImage using appimagetool directly
echo "📦 Creating AppImage..."
export LDAI_OUTPUT="$OUTPUT_APPIMAGE"
"$APPIMAGETOOL" "$APPDIR" "$OUTPUT_APPIMAGE"

BUILD_HOME="$HOME"

# 6. Cleanup
rm -rf "$APPDIR" "$BUILD_HOME"
echo "✅ AppImage created: $OUTPUT_APPIMAGE"
ls -lh "$OUTPUT_APPIMAGE"
