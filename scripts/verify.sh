#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "          Alcove Verification Loop        "
echo "=========================================="

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

# 1. Build Alcove Scheme
echo "[1/2] Building Alcove scheme..."
xcodebuild \
  -project Alcove.xcodeproj \
  -scheme Alcove \
  -destination "generic/platform=iOS Simulator" \
  build \
  CODE_SIGNING_ALLOWED=NO \
  | xcbeautify 2>/dev/null || xcodebuild \
  -project Alcove.xcodeproj \
  -scheme Alcove \
  -destination "generic/platform=iOS Simulator" \
  build \
  CODE_SIGNING_ALLOWED=NO

echo " Build completed successfully."

# 2. Run Tests
DEVICE_NAME="${TEST_DEVICE_NAME:-iPad Air 11-inch (M4)}"
if ! xcrun simctl list devices available | grep -q "${DEVICE_NAME}"; then
  FALLBACK_DEVICE="$(xcrun simctl list devices available | grep -E "iPad" | head -n 1 | sed -E 's/^[[:space:]]+//; s/[[:space:]]+\(.*//' || true)"
  if [ -n "${FALLBACK_DEVICE}" ]; then
    DEVICE_NAME="${FALLBACK_DEVICE}"
  fi
fi

echo "[2/2] Running test suite on iPad simulator (${DEVICE_NAME})..."
xcodebuild \
  -project Alcove.xcodeproj \
  -scheme Alcove \
  -destination "platform=iOS Simulator,name=${DEVICE_NAME}" \
  test \
  CODE_SIGNING_ALLOWED=NO \
  | xcbeautify 2>/dev/null || xcodebuild \
  -project Alcove.xcodeproj \
  -scheme Alcove \
  -destination "platform=iOS Simulator,name=${DEVICE_NAME}" \
  test \
  CODE_SIGNING_ALLOWED=NO

# 3. Thermal Cleanup
echo "Cleaning up simulator instances..."
xcrun simctl shutdown all 2>/dev/null || true

echo "=========================================="
echo "      All Alcove Verifications Passed!    "
echo "=========================================="
