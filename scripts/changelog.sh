#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG_FILE="${1:-$PROJECT_DIR/CHANGELOG.md}"

echo "Generating Keep a Changelog 1.1.0 compliant changelog for Alcove..."

/usr/bin/env python3 - <<EOF
import subprocess
import re
import sys
import os

project_dir = "$PROJECT_DIR"
changelog_file = "$CHANGELOG_FILE"

try:
    git_log = subprocess.check_output(
        ["git", "-C", project_dir, "log", "--no-merges", "--pretty=format:%s"],
        text=True
    ).splitlines()
except Exception as e:
    git_log = []

categories = {
    "Added": [],
    "Changed": [],
    "Deprecated": [],
    "Removed": [],
    "Fixed": [],
    "Security": []
}

pattern = re.compile(r"^(feat|refactor|perf|fix|chore|docs|ci|test|style|revert|sec|security)(?:\(([^)]+)\))?!?:\s*(.+)$")

# Deduplication set to avoid repeated entries
seen = set()

for line in git_log:
    m = pattern.match(line.strip())
    if not m:
        continue
    ctype, scope, desc = m.groups()

    # Exclude internal maintenance, CI, tests, and changelog meta-commits
    if ctype in ("docs", "ci", "test", "chore", "style"):
        continue
    if "changelog" in line.lower() or "release notes" in line.lower():
        continue

    clean_desc = desc.strip()
    if clean_desc:
        clean_desc = clean_desc[0].upper() + clean_desc[1:]
        if not clean_desc.endswith("."):
            clean_desc += "."

    if clean_desc in seen:
        continue
    seen.add(clean_desc)

    if ctype == "feat":
        categories["Added"].append(clean_desc)
    elif ctype in ("refactor", "perf"):
        categories["Changed"].append(clean_desc)
    elif ctype == "fix":
        categories["Fixed"].append(clean_desc)
    elif ctype in ("sec", "security"):
        categories["Security"].append(clean_desc)
    elif ctype == "revert":
        categories["Removed"].append(clean_desc)

# Read existing released sections if present to preserve history
existing_releases = ""
existing_links = []
if os.path.exists(changelog_file):
    with open(changelog_file, "r", encoding="utf-8") as f:
        existing_text = f.read()
    match = re.search(r"\n(## \[\d+\.\d+\.\d+\].*)", existing_text, re.DOTALL)
    if match:
        existing_releases = match.group(1).strip()

content = [
    "# Changelog",
    "",
    "All notable changes to this project will be documented in this file.",
    "",
    "The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),",
    "and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).",
    "",
    "## [Unreleased]",
    ""
]

for cat in ["Added", "Changed", "Deprecated", "Removed", "Fixed", "Security"]:
    items = categories[cat]
    if items:
        content.append(f"### {cat}")
        content.append("")
        for item in items:
            content.append(f"- {item}")
        content.append("")

if existing_releases:
    content.append(existing_releases)
    content.append("")

# Link reference definitions
content.append("[Unreleased]: https://github.com/M7-C5/Alcove/tree/dev")
content.append("")

with open(changelog_file, "w", encoding="utf-8") as f:
    f.write("\n".join(content))
EOF

echo "✅ Successfully updated CHANGELOG.md adhering strictly to Keep a Changelog 1.1.0"
