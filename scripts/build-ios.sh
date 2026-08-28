#!/usr/bin/env bash
# =============================================================================
#  Leitner Learning Platform - iOS IPA & Simulator Builder (macOS / CI)
#  Usage: ./scripts/build-ios.sh [--flavor premium|store] [--target-url <url>] [--build-type ipa|simulator|both] [--upload-rubika]
# =============================================================================

set -e

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;37m'
NC='\033[0m'

# Default Parameters
FLAVOR="premium"
TARGET_URL="https://api.rightlearn.ir"
BUILD_TYPE="both"
UPLOAD_RUBIKA=true
CLEANUP_BUILD=true

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --flavor|-f) FLAVOR="$2"; shift ;;
        --target-url|-u) TARGET_URL="$2"; shift ;;
        --build-type|-b) BUILD_TYPE="$2"; shift ;;
        --no-rubika) UPLOAD_RUBIKA=false ;;
        --no-clean) CLEANUP_BUILD=false ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
MOBILE_DIR="$ROOT/mobile-app"
IOS_DIR="$MOBILE_DIR/ios"

echo ""
echo -e "${CYAN}+======================================================+${NC}"
echo -e "${CYAN}|      Leitner Learning Platform  -  iOS Builder       |${NC}"
echo -e "${CYAN}+======================================================+${NC}"
echo ""

# Validate Flavor
if [ "$FLAVOR" != "premium" ] && [ "$FLAVOR" != "store" ]; then
    echo -e "${RED}[ERROR] Invalid flavor '$FLAVOR'. Supported values: 'premium', 'store'.${NC}"
    exit 1
fi

# Validate Host OS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${YELLOW}[WARNING] Native iOS compilation requires macOS with Xcode installed.${NC}"
    echo -e "${YELLOW}           Current OS detected: $OSTYPE${NC}"
    echo -e "${GRAY}           If you are on Windows, use .\\scripts\\build-ios.ps1 or GitHub Actions.${NC}"
fi

# Check Prerequisites
echo -e "${YELLOW}>> Checking build prerequisites...${NC}"
command -v flutter >/dev/null 2>&1 || { echo -e "${RED}[ERROR] 'flutter' command not found in PATH.${NC}"; exit 1; }

# Normalize API URL
API_BASE_URL="$TARGET_URL"
if [[ ! "$API_BASE_URL" =~ ^https?:// ]]; then
    API_BASE_URL="https://$API_BASE_URL"
fi
API_BASE_URL="${API_BASE_URL%/}"
if [[ ! "$API_BASE_URL" =~ /api/v1$ ]]; then
    API_BASE_URL="$API_BASE_URL/api/v1"
fi
echo -e "${GREEN}[OK] Target Backend Endpoint: ${CYAN}$API_BASE_URL${NC}"

# Navigate to Mobile App
cd "$MOBILE_DIR"

# Clean & Dependencies
echo -e "${YELLOW}>> Cleaning previous build cache...${NC}"
flutter clean

echo -e "${YELLOW}>> Fetching Flutter packages (pub get)...${NC}"
flutter pub get

# CocoaPods check
if [ -d "$IOS_DIR" ]; then
    echo -e "${YELLOW}>> Installing CocoaPods dependencies...${NC}"
    cd "$IOS_DIR"
    if command -v pod >/dev/null 2>&1; then
        pod install --repo-update || pod install
    else
        echo -e "${YELLOW}[WARNING] 'pod' command not found. Skipping pod install.${NC}"
    fi
    cd "$MOBILE_DIR"
fi

# Build Outputs
IPA_OUT="$ROOT/app-${FLAVOR}-release.ipa"
IPA_ZIP="$ROOT/app-${FLAVOR}-ios-release.zip"
SIMULATOR_ZIP="$ROOT/app-${FLAVOR}-ios-simulator.zip"

# 1. Build Simulator App (if requested)
if [ "$BUILD_TYPE" == "simulator" ] || [ "$BUILD_TYPE" == "both" ]; then
    echo -e "${YELLOW}>> Compiling iOS Simulator Release bundle for flavor '${FLAVOR}'...${NC}"
    flutter build ios --simulator --release -t "lib/main_${FLAVOR}.dart" --dart-define=API_BASE_URL="$API_BASE_URL"
    
    if [ -d "build/ios/iphonesimulator/Runner.app" ]; then
        echo -e "${YELLOW}>> Packaging iOS Simulator bundle to ZIP archive...${NC}"
        cd build/ios/iphonesimulator
        zip -r -y "$SIMULATOR_ZIP" Runner.app
        cd "$MOBILE_DIR"
        echo -e "${GREEN}[OK] Simulator bundle created: $SIMULATOR_ZIP${NC}"
    fi
fi

# 2. Build Physical IPA (if requested)
if [ "$BUILD_TYPE" == "ipa" ] || [ "$BUILD_TYPE" == "both" ]; then
    echo -e "${YELLOW}>> Compiling iOS Release app bundle for flavor '${FLAVOR}'...${NC}"
    flutter build ios --release --no-codesign -t "lib/main_${FLAVOR}.dart" --dart-define=API_BASE_URL="$API_BASE_URL"
    
    if [ -d "build/ios/iphoneos/Runner.app" ]; then
        echo -e "${YELLOW}>> Assembling unsigned IPA package (Payload/Runner.app)...${NC}"
        cd build/ios/iphoneos
        rm -rf Payload "$IPA_OUT"
        mkdir -p Payload
        cp -r Runner.app Payload/
        zip -r -y "$IPA_OUT" Payload
        cd "$MOBILE_DIR"
        
        # Package into distribution zip
        cd "$ROOT"
        zip -r -y "$IPA_ZIP" "app-${FLAVOR}-release.ipa"
        cd "$MOBILE_DIR"
        echo -e "${GREEN}[OK] iOS IPA generated: $IPA_OUT${NC}"
    fi
fi

# Rubika Delivery
if [ "$UPLOAD_RUBIKA" = true ]; then
    TARGET_UPLOAD=""
    if [ -f "$IPA_ZIP" ]; then
        TARGET_UPLOAD="$IPA_ZIP"
    elif [ -f "$SIMULATOR_ZIP" ]; then
        TARGET_UPLOAD="$SIMULATOR_ZIP"
    fi

    if [ -n "$TARGET_UPLOAD" ] && [ -f "$ROOT/scripts/upload-to-rubika.py" ]; then
        echo -e "${YELLOW}>> Uploading build package to Rubika Bot...${NC}"
        python3 "$ROOT/scripts/upload-to-rubika.py" --file "$TARGET_UPLOAD" || true
    fi
fi

# Space reclamation
if [ "$CLEANUP_BUILD" = true ]; then
    echo -e "${YELLOW}>> Cleaning up temporary build artifacts...${NC}"
    flutter clean >/dev/null 2>&1 || true
fi

echo ""
echo -e "${GREEN}+======================================================+${NC}"
echo -e "${GREEN}|          iOS Build Pipeline Finished Successfully    |${NC}"
echo -e "${GREEN}+======================================================+${NC}"
echo ""
echo -e "${CYAN}Output Packages:${NC}"
[ -f "$IPA_OUT" ] && echo -e "  - ${GREEN}Physical Device IPA:${NC} $IPA_OUT"
[ -f "$IPA_ZIP" ] && echo -e "  - ${GREEN}Distribution ZIP:   ${NC} $IPA_ZIP"
[ -f "$SIMULATOR_ZIP" ] && echo -e "  - ${GREEN}Simulator / Appetize:${NC} $SIMULATOR_ZIP"
echo ""
echo -e "${CYAN}How to install on iOS:${NC}"
echo -e "  ${YELLOW}Option 1 (Sideloadly / AltStore / Scarlet):${NC}"
echo -e "    1. Download '${IPA_OUT##*/}' to your Mac or PC."
echo -e "    2. Open Sideloadly (https://sideloadly.io) or AltStore."
echo -e "    3. Connect your iPhone via USB/Wi-Fi and install the IPA using your free Apple ID."
echo ""
echo -e "  ${YELLOW}Option 2 (In-Browser Interactive Preview via Appetize.io):${NC}"
echo -e "    1. Upload '${SIMULATOR_ZIP##*/}' to https://appetize.io/upload."
echo -e "    2. Test and stream the iOS application directly in any web browser."
echo ""
