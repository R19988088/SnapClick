#!/usr/bin/env bash
set -euo pipefail

binary="$(mktemp -t snapclick-window-interaction-test)"
trap 'rm -f "$binary"' EXIT

xcrun swiftc \
    SnapClick/Core/WindowInteractionGeometry.swift \
    scripts/test_window_interaction_geometry.swift \
    -o "$binary"
"$binary"
