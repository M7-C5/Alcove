#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG_FILE="${1:-$PROJECT_DIR/CHANGELOG.md}"

echo "Inspecting git commits for Conventional Commits in Alcove..."

FEAT=$(git -C "$PROJECT_DIR" log --no-merges --pretty=format:"- %s (%h)" --grep="^feat" 2>/dev/null || true)
CHANGED=$(git -C "$PROJECT_DIR" log --no-merges --pretty=format:"- %s (%h)" --grep="^refactor" 2>/dev/null || true)
FIX=$(git -C "$PROJECT_DIR" log --no-merges --pretty=format:"- %s (%h)" --grep="^fix" 2>/dev/null || true)
PERFORMANCE=$(git -C "$PROJECT_DIR" log --no-merges --pretty=format:"- %s (%h)" --grep="^perf" 2>/dev/null || true)
DOCS=$(git -C "$PROJECT_DIR" log --no-merges --pretty=format:"- %s (%h)" --grep="^docs" 2>/dev/null || true)
CHORE=$(git -C "$PROJECT_DIR" log --no-merges --pretty=format:"- %s (%h)" --grep="^chore\|^build\|^test\|^ci\|^style" 2>/dev/null || true)

cat <<EOF > "$CHANGELOG_FILE"
# Changelog

All notable changes to **Alcove** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

EOF

if [ -n "$FEAT" ]; then
    echo "### Added" >> "$CHANGELOG_FILE"
    echo "$FEAT" >> "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"
fi

if [ -n "$CHANGED" ]; then
    echo "### Changed" >> "$CHANGELOG_FILE"
    echo "$CHANGED" >> "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"
fi

if [ -n "$FIX" ]; then
    echo "### Fixed" >> "$CHANGELOG_FILE"
    echo "$FIX" >> "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"
fi

if [ -n "$PERFORMANCE" ]; then
    echo "### Performance" >> "$CHANGELOG_FILE"
    echo "$PERFORMANCE" >> "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"
fi

if [ -n "$DOCS" ]; then
    echo "### Documentation" >> "$CHANGELOG_FILE"
    echo "$DOCS" >> "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"
fi

if [ -n "$CHORE" ]; then
    echo "### Tooling & Maintenance" >> "$CHANGELOG_FILE"
    echo "$CHORE" >> "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"
fi

echo "✅ Successfully updated CHANGELOG.md"
