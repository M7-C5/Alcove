#!/usr/bin/env bash
set -euo pipefail

# scripts/changelog.sh - Compiles conventional commits into formatted changelog entries

OUTPUT_FILE="${1:-CHANGELOG.md}"

echo "Compiling Conventional Commits into ${OUTPUT_FILE}..."

CURRENT_DATE=$(date +%Y-%m-%d)
VERSION=${2:-"v0.1.0"}

TEMP_CHANGELOG=$(mktemp)

{
  echo "## [${VERSION}] - ${CURRENT_DATE}"
  echo ""
  
  # Features
  FEATS=$(git log --pretty=format:"- %s (%h)" --grep="^feat" 2>/dev/null || true)
  if [ -n "${FEATS}" ]; then
    echo "### Features"
    echo "${FEATS}"
    echo ""
  fi

  # Fixes
  FIXES=$(git log --pretty=format:"- %s (%h)" --grep="^fix" 2>/dev/null || true)
  if [ -n "${FIXES}" ]; then
    echo "### Bug Fixes"
    echo "${FIXES}"
    echo ""
  fi

  # Refactoring
  REFACTORS=$(git log --pretty=format:"- %s (%h)" --grep="^refactor" 2>/dev/null || true)
  if [ -n "${REFACTORS}" ]; then
    echo "### Refactoring & Polish"
    echo "${REFACTORS}"
    echo ""
  fi

  # Documentation & Chores
  OTHERS=$(git log --pretty=format:"- %s (%h)" --grep="^\(docs\|chore\|test\|perf\)" 2>/dev/null || true)
  if [ -n "${OTHERS}" ]; then
    echo "### Tooling & Maintenance"
    echo "${OTHERS}"
    echo ""
  fi
} > "${TEMP_CHANGELOG}"

if [ -f "${OUTPUT_FILE}" ]; then
  cat "${TEMP_CHANGELOG}" "${OUTPUT_FILE}" > "${OUTPUT_FILE}.new"
  mv "${OUTPUT_FILE}.new" "${OUTPUT_FILE}"
else
  mv "${TEMP_CHANGELOG}" "${OUTPUT_FILE}"
fi

rm -f "${TEMP_CHANGELOG}"
echo "Changelog compiled successfully."
