#!/bin/bash
# Compile finder-guard from source and ad-hoc sign it.
set -e
cd "$(dirname "$0")"
swiftc -O main.swift -o finder-guard
codesign -s - finder-guard
echo "Built: $(pwd)/finder-guard"
