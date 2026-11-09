#!/usr/bin/env bash
set -o pipefail

echo "=========================================="
echo "          Alcove Verification Loop        "
echo "=========================================="

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

# POSIX stream filter function: formats build/test output without re-invoking xcodebuild
filter_stream() {
  if command -v xcbeautify >/dev/null 2>&1; then
    xcbeautify
  elif command -v xcpretty >/dev/null 2>&1; then
    xcpretty
  else
    grep --line-buffered -E '\*\*( BUILD | TEST )|error:|warning:|passed|failed|fatal error:|Undefined symbol|clang: error:|ld:|Test suite|Test case|Suite|✔|✘|Expectation|Issue recorded' || true
  fi
}

cleanup() {
  echo "Cleaning up simulator instances..."
  xcrun simctl shutdown all 2>/dev/null || true
}
trap cleanup EXIT

# 1. Build Alcove Scheme
echo "[1/2] Building Alcove scheme..."
xcodebuild \
  -project Alcove.xcodeproj \
  -scheme Alcove \
  -destination "generic/platform=iOS Simulator" \
  build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  | filter_stream

if [ ${PIPESTATUS[0]} -ne 0 ]; then
  echo "=========================================="
  echo "  ❌ Build FAILED! Check compiler errors above."
  echo "=========================================="
  exit 1
fi

echo " Build completed successfully."

# 2. Run Tests
DEFAULT_DEVICE="iPad Air 11-inch (M4)"
DEVICE_NAME="${TEST_DEVICE_NAME:-$DEFAULT_DEVICE}"
if ! xcrun simctl list devices available | grep -q "${DEVICE_NAME}"; then
  FALLBACK_DEVICE=$(xcrun simctl list devices available | grep -m 1 -E "iPad" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+\([0-9A-F-]{36}\)[[:space:]]+\(.*[[:space:]]*$//' || true)
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
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  | filter_stream

if [ ${PIPESTATUS[0]} -ne 0 ]; then
  echo "=========================================="
  echo "  ❌ Test suite FAILED! Check test failures above."
  echo "=========================================="
  exit 1
fi

echo "=========================================="
echo "      All Alcove Verifications Passed!    "
echo "=========================================="
