#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# scripts/audit-ui.sh
# Headless Multimodal Visual Inspector for iPad Landscape UI
# Audits Light-only appearance and Dynamic Type contrast & scaling
# ==============================================================================

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

BUNDLE_ID="com.Verzional.Alcove"
DEFAULT_DEVICE="iPad Air 11-inch (M4)"
OUTPUT_DIR="/tmp/alcove-ui-audit"
BUILD_DIR="/tmp/alcove-audit-build"
DO_BUILD=false
DO_LAUNCH=true
KEEP_ALIVE=false
BOOTED_BY_US=false

usage() {
  cat <<EOF
Usage: ./scripts/audit-ui.sh [OPTIONS]

Headless visual inspector capturing iPad landscape screenshots across
Light appearance and standard/accessibility Dynamic Type tiers.

Options:
  --build           Force recompiling and reinstalling the Alcove app scheme prior to auditing
  --no-launch       Skip launching the app (captures active screen)
  --output-dir DIR  Directory for output screenshots (default: /tmp/alcove-ui-audit)
  --keep-alive      Keep simulator running after audit (skips shutdown)
  --help            Show this help message
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build)
      DO_BUILD=true
      shift
      ;;
    --no-launch)
      DO_LAUNCH=false
      shift
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --keep-alive)
      KEEP_ALIVE=true
      shift
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

mkdir -p "${OUTPUT_DIR}"

echo "=========================================="
echo "        Alcove Headless UI Inspector      "
echo "=========================================="
echo "Output Directory: ${OUTPUT_DIR}"

# 1. Resolve or Boot iPad Simulator
echo "[1/4] Resolving iPad simulator..."
BOOTED_UDID=$(xcrun simctl list devices | grep -E "iPad" | grep "Booted" | head -n 1 | grep -o -E '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' || true)

if [ -z "${BOOTED_UDID}" ]; then
  # Find target iPad UDID
  TARGET_UDID=$(xcrun simctl list devices available | grep "${DEFAULT_DEVICE}" | head -n 1 | grep -o -E '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' || true)
  if [ -z "${TARGET_UDID}" ]; then
    TARGET_UDID=$(xcrun simctl list devices available | grep -E "iPad" | head -n 1 | grep -o -E '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' || true)
  fi

  if [ -z "${TARGET_UDID}" ]; then
    echo "❌ Error: No available iPad simulator found." >&2
    exit 1
  fi

  echo "Booting iPad simulator (${TARGET_UDID}) headlessly..."
  xcrun simctl boot "${TARGET_UDID}" 2>/dev/null || true
  BOOTED_UDID="${TARGET_UDID}"
  BOOTED_BY_US=true
else
  echo "Using already booted iPad simulator (${BOOTED_UDID})."
fi

# Ensure simulator finishes booting system apps before interacting
echo "Waiting for simulator SpringBoard initialization..."
xcrun simctl bootstatus "${BOOTED_UDID}" -b

cleanup() {
  echo "Restoring default UI options..."
  xcrun simctl ui "${BOOTED_UDID}" appearance light 2>/dev/null || true
  xcrun simctl ui "${BOOTED_UDID}" content_size large 2>/dev/null || true
  xcrun simctl ui "${BOOTED_UDID}" increase_contrast disabled 2>/dev/null || true

  if [ "${BOOTED_BY_US}" = true ] && [ "${KEEP_ALIVE}" = false ]; then
    echo "Thermal Cleanup: Shutting down simulator instances..."
    xcrun simctl shutdown "${BOOTED_UDID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# 2. Build & Install if requested or missing
find_app_bundle() {
  # 1. Check local build directory
  if [ -d "${BUILD_DIR}/Build/Products/Debug-iphonesimulator/Alcove.app" ]; then
    echo "${BUILD_DIR}/Build/Products/Debug-iphonesimulator/Alcove.app"
    return
  fi
  # 2. Check standard Xcode DerivedData
  local derived_app
  derived_app=$(find ~/Library/Developer/Xcode/DerivedData/Alcove-*/Build/Products/Debug-iphonesimulator -name "Alcove.app" 2>/dev/null | head -n 1 || true)
  if [ -n "${derived_app}" ] && [ -d "${derived_app}" ]; then
    echo "${derived_app}"
    return
  fi
  echo ""
}

APP_BUNDLE=$(find_app_bundle)

if [ "${DO_BUILD}" = true ] || ([ "${DO_LAUNCH}" = true ] && [ -z "${APP_BUNDLE}" ]); then
  echo "[2/4] Building Alcove scheme for simulator..."
  xcodebuild \
    -project Alcove.xcodeproj \
    -scheme Alcove \
    -destination "id=${BOOTED_UDID}" \
    -derivedDataPath "${BUILD_DIR}" \
    build \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    -quiet
  APP_BUNDLE="${BUILD_DIR}/Build/Products/Debug-iphonesimulator/Alcove.app"
fi

if [ "${DO_LAUNCH}" = true ]; then
  if [ -n "${APP_BUNDLE}" ] && [ -d "${APP_BUNDLE}" ]; then
    echo "[2/4] Installing ${APP_BUNDLE} onto simulator..."
    xcrun simctl install "${BOOTED_UDID}" "${APP_BUNDLE}"
  fi

  echo "[2/4] Launching ${BUNDLE_ID} in landscape..."
  xcrun simctl launch "${BOOTED_UDID}" "${BUNDLE_ID}"
  sleep 3
else
  echo "[2/4] Skipping app launch (--no-launch)."
fi

# 3. Capture Visual Audit Matrix
echo "[3/4] Capturing UI contrast and Dynamic Type matrix..."

capture_variant() {
  local app="$1"
  local size="$2"
  local filename="$3"
  local label="$4"

  echo "  📸 Capturing ${label}..."
  xcrun simctl ui "${BOOTED_UDID}" appearance "${app}"
  xcrun simctl ui "${BOOTED_UDID}" content_size "${size}"
  sleep 1
  local raw_path="${OUTPUT_DIR}/${filename}"
  xcrun simctl io "${BOOTED_UDID}" screenshot "${raw_path}"

  # If screenshot is letterboxed on portrait device framebuffer (1640x2360), only crop if letterboxing black bars exist.
  # Without UIRequiresFullScreen, modern iPad multitasking fills the native canvas and must not be blindly truncated.
  local height width
  height=$(sips -g pixelHeight "${raw_path}" | awk '/pixelHeight/ {print $2}')
  width=$(sips -g pixelWidth "${raw_path}" | awk '/pixelWidth/ {print $2}')
  if [ "${height}" -gt "${width}" ] && [ "${width}" -eq 1640 ]; then
    local is_letterboxed="false"
    if command -v python3 >/dev/null 2>&1; then
      is_letterboxed=$(python3 -c "
import sys
try:
    from PIL import Image
    im = Image.open(sys.argv[1]).convert('RGB')
    top_box = im.crop((0, 0, im.width, 300))
    print('true' if top_box.getbbox() is None else 'false')
except Exception:
    print('false')
" "${raw_path}" 2>/dev/null || echo "false")
    fi

    if [ "${is_letterboxed}" = "true" ]; then
      sips -c 1140 1640 "${raw_path}" --out "${raw_path}" >/dev/null 2>&1 || true
    fi
  fi
}

capture_variant "light" "extra-large" "ipad-landscape-light-standard.png" "Light Appearance (Standard Dynamic Type)"
capture_variant "light" "accessibility-extra-large" "ipad-landscape-light-accessibility.png" "Light Appearance (Accessibility Dynamic Type)"

# 4. Audit Summary Report
echo "[4/4] Visual Audit Complete!"
echo "=========================================="
echo "          Visual Audit Artifacts          "
echo "=========================================="
echo "| Variant | File | Dimensions | Size |"
echo "| :--- | :--- | :--- | :--- |"
for f in "${OUTPUT_DIR}"/ipad-landscape-*.png; do
  if [ -f "$f" ]; then
    fname=$(basename "$f")
    fsize=$(ls -lh "$f" | awk '{print $5}')
    fdims=$(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w "x" h}')
    echo "| ${fname} | \`${OUTPUT_DIR}/${fname}\` | ${fdims} | ${fsize} |"
  fi
done
echo "=========================================="
echo "To inspect visual symmetry, open ${OUTPUT_DIR}"
