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
echo "[2/2] Running test suite on iPad simulator..."
xcodebuild \
  -project Alcove.xcodeproj \
  -scheme Alcove \
  -destination "platform=iOS Simulator,name=iPad Air 11-inch (M4)" \
  test \
  CODE_SIGNING_ALLOWED=NO \
  | xcbeautify 2>/dev/null || xcodebuild \
  -project Alcove.xcodeproj \
  -scheme Alcove \
  -destination "platform=iOS Simulator,name=iPad Air 11-inch (M4)" \
  test \
  CODE_SIGNING_ALLOWED=NO

# 3. Thermal Cleanup
echo "Cleaning up simulator instances..."
xcrun simctl shutdown all 2>/dev/null || true

echo "=========================================="
echo "      All Alcove Verifications Passed!    "
echo "=========================================="
