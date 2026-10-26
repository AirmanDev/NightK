#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
swiftc -parse-as-library NightK/Support.swift NightK/GammaTransfer.swift tests/GammaTransferTests.swift -o "$tmp/test-gamma"
"$tmp/test-gamma"
