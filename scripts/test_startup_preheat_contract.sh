#!/bin/bash
set -euo pipefail

source_file="SnapClick/App/AppDelegate.swift"

rg -q 'finderPreheatQueue = DispatchQueue' "$source_file"
rg -q 'finderPreheatQueue\.async' "$source_file"
rg -q 'IconCache\.preheat' "$source_file"

echo "startup preheat contract passed"
