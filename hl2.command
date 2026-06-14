#!/bin/bash

# Dynamically get the directory where this script lives, no matter where it's run from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Sandboxed Configuration (All built inside a localized HL2Temp folder)
TEMP_WORKSPACE="$SCRIPT_DIR/HL2Temp"
INSTALL_DIR="$TEMP_WORKSPACE/Gaming/hl2"
REPO_DIR="$TEMP_WORKSPACE/source-engine"
LOCAL_DEPOTS_DIR="$TEMP_WORKSPACE/depots"

set -e # Exit immediately if a command exits with a non-zero status

# Ensure the temporary sandboxed folder exists before running tasks
mkdir -p "$TEMP_WORKSPACE"

echo "--- Starting hl2 Build Setup ---"

# 1. Install Homebrew
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    if [[ $(uname -m) == 'arm64' ]]; then
        (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        (echo; echo 'eval "$(/usr/local/bin/brew shellenv)"') >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo "Homebrew already installed. Skipping."
fi

# 2. Install Xcode Command Line Tools
if ! xcode-select -p &> /dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
    read -p "Press enter after the Xcode installation finishes..."
else
    echo "Xcode Command Line Tools already installed. Skipping."
fi

# 3. Install required packages
echo "Updating Homebrew and installing dependencies..."
brew update
brew install sdl2 freetype fontconfig pkg-config opus jpeg jpeg-turbo libpng libedit python3 fileicon
brew tap steamre/tools
brew trust --cask steamre/tools/depotdownloader
brew install depotdownloader

# 3b. Exhaustive System Language Detection & Valve Mapping Configuration
echo "Detecting system language layout..."
RAW_LANG=$(defaults read -g AppleLanguages | head -n 2 | tail -n 1 | tr -d ' ' | tr -d '"' | tr -d ',')
SYS_LANG=$(echo "$RAW_LANG" | cut -c1-2)

LANG_DEPOT=""
VALVE_LANG_NAME="english"

# --- FIXED SYNTAX HERE ---
if [[ "$RAW_LANG" == "pt-BR" || "$RAW_LANG" == "pt_BR" ]]; then
    VALVE_LANG_NAME="brazilian"
elif [[ "$RAW_LANG" == "zh-Hans" || "$RAW_LANG" == "zh_Hans" || "$RAW_LANG" == "zh-CN" ]]; then
    VALVE_LANG_NAME="schinese"
    LANG_DEPOT="231"
elif [[ "$RAW_LANG" == "zh-Hant" || "$RAW_LANG" == "zh_Hant" || "$RAW_LANG" == "zh-TW" || "$RAW_LANG" == "zh-HK" ]]; then
    VALVE_LANG_NAME="tchinese"
    LANG_DEPOT="230"
elif [[ "$RAW_LANG" == "es-419" || "$RAW_LANG" == "es_419" || "$RAW_LANG" == "es-MX" ]]; then
    VALVE_LANG_NAME="latam"
else
    case "$SYS_LANG" in
        "ru") VALVE_LANG_NAME="russian"; LANG_DEPOT="225" ;;
        "es") VALVE_LANG_NAME="spanish"; LANG_DEPOT="226" ;;
        "fr") VALVE_LANG_NAME="french"; LANG_DEPOT="227" ;;
        "de") VALVE_LANG_NAME="german"; LANG_DEPOT="228" ;;
        "ko") VALVE_LANG_NAME="korean"; LANG_DEPOT="229" ;;
        "it") VALVE_LANG_NAME="italian"; LANG_DEPOT="232" ;;
        "bg") VALVE_LANG_NAME="bulgarian" ;;
        "cs") VALVE_LANG_NAME="czech" ;;
        "da") VALVE_LANG_NAME="danish" ;;
        "nl") VALVE_LANG_NAME="dutch" ;;
        "fi") VALVE_LANG_NAME="finnish" ;;
        "el") VALVE_LANG_NAME="greek" ;;
        "hu") VALVE_LANG_NAME="hungarian" ;;
        "ja") VALVE_LANG_NAME="japanese" ;;
        "no") VALVE_LANG_NAME="norwegian" ;;
        "pl") VALVE_LANG_NAME="polish" ;;
        "pt") VALVE_LANG_NAME="portuguese" ;;
        "ro") VALVE_LANG_NAME="romanian" ;;
        "sv") VALVE_LANG_NAME="swedish" ;;
        "th") VALVE_LANG_NAME="thai" ;;
        "tr") VALVE_LANG_NAME="turkish" ;;
        "uk") VALVE_LANG_NAME="ukrainian" ;;
        "vi") VALVE_LANG_NAME="vietnamese" ;;
        *)    VALVE_LANG_NAME="english" ;;
    esac
fi

echo ">> Configured Localization Directives:"
echo "   Target Valve Engine Language Identifier: $VALVE_LANG_NAME"

# 3c. Prompt for Steam credentials and Run DepotDownloader
echo ""
echo "=== Steam Authentication Required for DepotDownloader ==="
read -p "Enter Steam Username: " STEAM_USER
read -sp "Enter Steam Password: " STEAM_PASS
echo ""

echo "Running DepotDownloader for core game files..."
depotdownloader -app 220 -depot 221 -manifest 3666218991449795038 -dir "$LOCAL_DEPOTS_DIR" -username "$STEAM_USER" -password "$STEAM_PASS"

if [ -n "$LANG_DEPOT" ]; then
    echo "Running DepotDownloader for localized translation package (Depot $LANG_DEPOT)..."
    depotdownloader -app 220 -depot "$LANG_DEPOT" -dir "$LOCAL_DEPOTS_DIR" -username "$STEAM_USER" -password "$STEAM_PASS"
fi

echo "Depot downloading completely processed."
echo "========================================================="
echo ""

# 4. Clone/Update Source Engine
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning Source Engine..."
    git clone --recursive https://github.com/nillerusr/source-engine "$REPO_DIR"
else
    echo "Repository exists. Updating..."
    cd "$REPO_DIR"
    git pull
    git submodule update --init --recursive
fi

# 5. Configure Build with Apple Silicon/Xcode environment
cd "$REPO_DIR"
echo "Setting up build environment for Apple Silicon..."

export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export CXXFLAGS="-std=c++11 -isysroot $SDKROOT -include alloca.h -Wno-null-dereference"
export CFLAGS="-isysroot $SDKROOT -include alloca.h"
export LDFLAGS="-L$SDKROOT/usr/lib -Wl,-syslibroot,$SDKROOT"

echo "Configuring..."
python3 waf distclean
python3 waf configure -T release --prefix='' --build-games=hl2

# 6. Build and Install
echo "Building..."
python3 waf build -v
echo "Installing to $INSTALL_DIR..."
python3 waf install --destdir="$INSTALL_DIR"

# 7. Post-Build Folder Swaps and Launcher Copy
echo "--- Performing Post-Build File Operations ---"

DEPOT_TARGET_DIR="$LOCAL_DEPOTS_DIR"

if [ -d "$DEPOT_TARGET_DIR" ]; then
    echo "Replacing game binaries folder: $DEPOT_TARGET_DIR/hl2/bin/ with $INSTALL_DIR/hl2/bin/"
    mkdir -p "$DEPOT_TARGET_DIR/hl2/bin"
    rm -rf "$DEPOT_TARGET_DIR/hl2/bin"
    cp -R "$INSTALL_DIR/hl2/bin/" "$DEPOT_TARGET_DIR/hl2/bin/"

    echo "Replacing engine binaries folder: $DEPOT_TARGET_DIR/bin/ with $INSTALL_DIR/bin/"
    rm -rf "$DEPOT_TARGET_DIR/bin"
    cp -R "$INSTALL_DIR/bin/" "$DEPOT_TARGET_DIR/bin/"

    echo "Copying launcher and renaming..."
    cp "$INSTALL_DIR/hl2_launcher" "$DEPOT_TARGET_DIR/hl2_osx"
else
    echo "ERROR: Target directory $DEPOT_TARGET_DIR not found."
    exit 1
fi

# 8. Create macOS Application Bundle (.app)
echo "--- Creating macOS Application Bundle ---"

APP_BUNDLE="$SCRIPT_DIR/Half Life 2.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MAC_OS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_BUNDLE"
mkdir -p "$MAC_OS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "Moving game content files into the application bundle..."
cp -R "$DEPOT_TARGET_DIR/" "$RESOURCES_DIR/"

# Create Info.plist
echo "Generating Info.plist file..."
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>English</string>
    <key>CFBundleExecutable</key>
    <string>hl2_osx</string>
    <key>CFBundleIconFile</key>
    <string>icon.icns</string>
    <key>CFBundleIdentifier</key>
    <string>com.valve.hl2.native</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Half Life 2</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Create the internal boot script
echo "Generating dynamic internal application bundle launcher script..."
cat << EOF > "$MAC_OS_DIR/hl2_osx"
#!/bin/bash
LAUNCH_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
RESOURCE_PATH="\$(cd "\$LAUNCH_DIR/../Resources" && pwd)"

cd "\$RESOURCE_PATH"
exec "./hl2_osx" -game hl2 -language "$VALVE_LANG_NAME" -audiolanguage "$VALVE_LANG_NAME" "\$@"
EOF

chmod +x "$MAC_OS_DIR/hl2_osx"

# Force configuration injection directly inside hl2/cfg
echo "Injecting native engine localization variables..."
mkdir -p "$RESOURCES_DIR/hl2/cfg"
cat << EOF > "$RESOURCES_DIR/hl2/cfg/autoexec.cfg"
cc_lang "$VALVE_LANG_NAME"
cl_language "$VALVE_LANG_NAME"
cc_subtitles "1"
EOF

cat << EOF > "$RESOURCES_DIR/hl2/cfg/config.cfg"
cc_lang "$VALVE_LANG_NAME"
cl_language "$VALVE_LANG_NAME"
cc_subtitles "1"
skill "1"
EOF

# Extracting the native icon
echo "Locating game icon within Steam assets..."
DEPOT_ICNS="$RESOURCES_DIR/hl2/resource/game.icns"

if [ -f "$DEPOT_ICNS" ]; then
    echo "Found authentic game icon at: $DEPOT_ICNS"
    cp "$DEPOT_ICNS" "$RESOURCES_DIR/icon.icns"
    fileicon set "$APP_BUNDLE" "$RESOURCES_DIR/icon.icns"
else
    echo "Warning: game.icns was not found at $DEPOT_ICNS. Creating fallback asset."
    touch "$RESOURCES_DIR/icon.icns"
fi

# 9. Isolate Dependencies and Relink Dynamic Paths
echo "--- Fixing Hardcoded Source Engine Library Links ---"

ENGINE_BIN_DIR="$RESOURCES_DIR/bin"
if [ -f "$REPO_DIR/build/togl/libtogl.dylib" ]; then
    echo "Copying libtogl.dylib dependency into bundle..."
    cp "$REPO_DIR/build/togl/libtogl.dylib" "$ENGINE_BIN_DIR/libtogl.dylib"
else
    cd "$SCRIPT_DIR"
    TOGL_SEARCH=$(find "$TEMP_WORKSPACE" -name "libtogl.dylib" | head -n 1)
    if [ -n "$TOGL_SEARCH" ]; then
        echo "Copying libtogl.dylib dependency from: $TOGL_SEARCH"
        cp "$TOGL_SEARCH" "$ENGINE_BIN_DIR/libtogl.dylib"
    fi
fi

echo "Re-linking absolute dylib path references to relative coordinates..."
TARGET_BIN_FOLDERS=("$RESOURCES_DIR" "$ENGINE_BIN_DIR" "$RESOURCES_DIR/hl2/bin")

for TARGET_DIR in "${TARGET_BIN_FOLDERS[@]}"; do
    if [ -d "$TARGET_DIR" ]; then
        find "$TARGET_DIR" -maxdepth 1 -type f \( -name "*.dylib" -o -name "hl2_osx" \) | while read -r BINARY_FILE; do
            
            # PERFECT PATH EXTRACTION: Reads lines completely raw, stripping out version context brackets smoothly
            otool -L "$BINARY_FILE" | grep -E "source-engine|HL2Temp|libtogl" | while IFS= read -r RAW_LINE; do
                # Isolate absolute references between the leading tab space and the trailing parenthesis layout completely safe of spaces
                BAD_PATH=$(echo "$RAW_LINE" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*\(compatibility.*//')
                
                if [ -n "$BAD_PATH" ]; then
                    LIB_NAME=$(basename "$BAD_PATH")
                    
                    if [[ "$BINARY_FILE" == *"/hl2/bin/"* ]]; then
                        NEW_RELATIVE_PATH="@loader_path/../../bin/$LIB_NAME"
                    else
                        NEW_RELATIVE_PATH="@loader_path/$LIB_NAME"
                    fi
                    
                    echo "  [$BINARY_FILE]: Correcting reference $BAD_PATH -> $NEW_RELATIVE_PATH"
                    
                    chmod +w "$BINARY_FILE" 2>/dev/null || true
                    install_name_tool -change "$BAD_PATH" "$NEW_RELATIVE_PATH" "$BINARY_FILE"
                fi
            done
            
            if [[ "$BINARY_FILE" == *"/libtogl.dylib" ]]; then
                chmod +w "$BINARY_FILE" 2>/dev/null || true
                install_name_tool -id "@loader_path/libtogl.dylib" "$BINARY_FILE"
            fi
        done
    fi
done

# 10. Housekeeping and Clean Up
echo "--- Performing Automated Cleanup Phase ---"

# Step outside the target sandbox directory explicitly to free terminal engine frames
cd "$SCRIPT_DIR"

if [ -d "$TEMP_WORKSPACE" ]; then
    echo "Purging temporary sandboxed runtime environment folder ($TEMP_WORKSPACE)..."
    
    # Decouple user file blocks and strip absolute file system immutability frames
    chmod -R 777 "$TEMP_WORKSPACE" 2>/dev/null || true
    chflags -R nouchg "$TEMP_WORKSPACE" 2>/dev/null || true
    
    # Aggressively clear active directory elements individually to circumvent race locks
    find "$TEMP_WORKSPACE" -type f -delete 2>/dev/null || true
    find "$TEMP_WORKSPACE" -type d -empty -delete 2>/dev/null || true
    
    # Final sweeping cleanup confirmation path pass
    rm -rf "$TEMP_WORKSPACE" 2>/dev/null || true
fi

echo ""
echo "--- Application Bundle Successfully Built at: $APP_BUNDLE ---"
echo "--- Build and Processing Cycle Complete! ---"