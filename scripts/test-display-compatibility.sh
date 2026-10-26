#!/usr/bin/env bash
# Pure policy/model tests: never touches a live gamma LUT or the WindowServer.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
swiftc NightK/Support.swift NightK/DisplayCompatibility.swift tests/DisplayCompatibilitySmoke.swift -o "$tmp/display-policy-smoke"
"$tmp/display-policy-smoke"
