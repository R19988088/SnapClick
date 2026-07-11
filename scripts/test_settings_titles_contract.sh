#!/bin/bash
set -euo pipefail

main="SnapClick/UI/MainWindow.swift"

if rg -q 'SettingsPageHeader\(title: dest\.localizedTitle\)' "$main"; then
    echo "right-side page title duplicates the selected sidebar title" >&2
    exit 1
fi

if rg -q 'SectionLabel\(title: "其他"\.localized' "$main"; then
    echo "Other section title duplicates the selected sidebar title" >&2
    exit 1
fi

echo "settings title contract passed."
