#!/bin/bash
# Half-Life 2: Episode One + Episode Two native Apple Silicon builder
# Based on nonoche2/HL2-patcher, with:
#  - Steam achievements enabled (DISABLE_STEAM removed)
#  - -language launch option taking priority over Steam's language
#  - episode content from Steam's official "steam_legacy" (pre-20th anniversary) branch
#
# Output: ~/Downloads/HL2-Episodes/episodic and ~/Downloads/HL2-Episodes/ep2
# These two folders go into the Steam "Half-Life 2" folder.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TEMP_WORKSPACE="$SCRIPT_DIR/hl2epTemp"
INSTALL_DIR="$TEMP_WORKSPACE/Gaming/episodic"
REPO_DIR="$TEMP_WORKSPACE/source-engine"
DEPOTS_DIR="$TEMP_WORKSPACE/depots"
OUT_DIR="$SCRIPT_DIR/HL2-Episodes"

set -e

ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    TARGET_ARCH="arm64"; BREW_PATH="/opt/homebrew/bin/brew"
else
    TARGET_ARCH="x86_64"; BREW_PATH="/usr/local/bin/brew"
fi

if [ -d "$OUT_DIR" ]; then
    echo "ERROR: $OUT_DIR already exists. Delete or rename it, then run again."
    exit 1
fi

rm -rf "$TEMP_WORKSPACE"
mkdir -p "$TEMP_WORKSPACE"
echo "--- Starting HL2 Episodes Build Setup ($TARGET_ARCH) ---"

# 1. Homebrew + tools
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    (echo; echo "eval \"\$($BREW_PATH shellenv)\"") >> ~/.zprofile
fi
[ -f "$BREW_PATH" ] && eval "$($BREW_PATH shellenv)"

if ! xcode-select -p &> /dev/null; then
    xcode-select --install
    read -p "Press enter after the Xcode installation finishes..."
fi

brew install sdl2 freetype fontconfig pkg-config opus jpeg jpeg-turbo libpng libedit python3 || true
brew tap steamre/tools
brew trust --cask steamre/tools/depotdownloader || true
brew install depotdownloader || true

# 2. Download episode content (official pre-20th-anniversary branch)
echo ""
echo "=== Steam Authentication Required for DepotDownloader ==="
read -p "Enter Steam Username: " STEAM_USER
read -sp "Enter Steam Password: " STEAM_PASS
echo ""

echo "Downloading Episode One content (depots 389, 380)..."
depotdownloader -app 380 -depot 389 -branch steam_legacy -dir "$DEPOTS_DIR" -username "$STEAM_USER" -password "$STEAM_PASS"
depotdownloader -app 380 -depot 380 -branch steam_legacy -dir "$DEPOTS_DIR" -username "$STEAM_USER" -password "$STEAM_PASS"

echo "Downloading Episode Two content (depot 420)..."
depotdownloader -app 420 -depot 420 -branch steam_legacy -dir "$DEPOTS_DIR" -username "$STEAM_USER" -password "$STEAM_PASS"

echo ">> Downloaded top-level folders:"
ls "$DEPOTS_DIR"

for d in episodic ep2; do
    if [ ! -d "$DEPOTS_DIR/$d" ]; then
        echo "ERROR: folder '$d' was not found in the downloaded content."
        exit 1
    fi
done

# 3. Source engine
echo "Cloning Source Engine..."
git clone --recursive https://github.com/nillerusr/source-engine "$REPO_DIR"

echo "Enabling Steam achievement support..."
sed -i '' "s/conf.env.append_unique('DEFINES', \['DISABLE_STEAM=1'\])/pass/" "$REPO_DIR/game/client/wscript" "$REPO_DIR/game/server/wscript"
if grep -q "DISABLE_STEAM=1" "$REPO_DIR/game/client/wscript" "$REPO_DIR/game/server/wscript"; then
    echo "ERROR: could not remove DISABLE_STEAM=1 from wscript files."
    exit 1
fi

echo "Making -language launch option take priority..."
perl -0pi -e 's/(Msg\("CL_InitLanguageCvar\\n"\);\n)/$1\tif ( CommandLine()->CheckParm( "-language" ) )\n\t{\n\t\tcl_language.SetValue( CommandLine()->ParmValue( "-language", "english" ) );\n\t\treturn;\n\t}\n/' "$REPO_DIR/engine/cl_main.cpp"
if ! grep -qF 'ParmValue( "-language", "english" ) )' "$REPO_DIR/engine/cl_main.cpp"; then
    echo "ERROR: could not patch language selection in engine/cl_main.cpp."
    exit 1
fi

# 4. Build (episodic = shared code for Episode One and Episode Two)
cd "$REPO_DIR"
export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export CXXFLAGS="-arch $TARGET_ARCH -std=c++11 -isysroot $SDKROOT -include alloca.h -Wno-null-dereference"
export CFLAGS="-arch $TARGET_ARCH -isysroot $SDKROOT -include alloca.h"
export LDFLAGS="-arch $TARGET_ARCH -L$SDKROOT/usr/lib -Wl,-syslibroot,$SDKROOT"

python3 waf distclean
python3 waf configure -T release --prefix='' --build-games=episodic --disable-warns
python3 waf build -v
python3 waf install --destdir="$INSTALL_DIR"

GAME_BIN="$INSTALL_DIR/episodic/bin"
if [ ! -f "$GAME_BIN/libclient.dylib" ] || [ ! -f "$GAME_BIN/libserver.dylib" ]; then
    echo "ERROR: built libclient.dylib / libserver.dylib not found in $GAME_BIN"
    ls -R "$INSTALL_DIR" | head -50
    exit 1
fi

# 5. Fix library paths so the game libs load the engine libs from ../../bin
echo "--- Fixing library paths ---"
for LIB in "$GAME_BIN/libclient.dylib" "$GAME_BIN/libserver.dylib"; do
    chmod +w "$LIB"
    otool -L "$LIB" | grep -E "source-engine|hl2epTemp" | while IFS= read -r RAW_LINE; do
        BAD_PATH=$(echo "$RAW_LINE" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*\(compatibility.*//')
        [ -z "$BAD_PATH" ] && continue
        NAME=$(basename "$BAD_PATH")
        if [[ "$NAME" == "$(basename "$LIB")" ]]; then
            install_name_tool -id "@loader_path/$NAME" "$LIB" 2>/dev/null || true
        else
            echo "  [$(basename "$LIB")] $BAD_PATH -> @loader_path/../../bin/$NAME"
            install_name_tool -change "$BAD_PATH" "@loader_path/../../bin/$NAME" "$LIB"
        fi
    done
done

# 6. Assemble output: content + compiled game libs
echo "--- Assembling output folder ---"
mkdir -p "$OUT_DIR"
for d in episodic ep2; do
    cp -R "$DEPOTS_DIR/$d" "$OUT_DIR/"
    rm -rf "$OUT_DIR/$d/bin"
    mkdir -p "$OUT_DIR/$d/bin"
    cp "$GAME_BIN/libclient.dylib" "$GAME_BIN/libserver.dylib" "$OUT_DIR/$d/bin/"
done

# 7. Cleanup
cd "$SCRIPT_DIR"
chmod -R u+w "$TEMP_WORKSPACE" 2>/dev/null || true
rm -rf "$TEMP_WORKSPACE" 2>/dev/null || true

echo ""
echo ">> Output contents:"
ls "$OUT_DIR"/episodic/bin "$OUT_DIR"/ep2/bin
echo ""
echo "--- Episodes Successfully Built at: $OUT_DIR ---"
echo "--- Build and Processing Cycle Complete! ---"
