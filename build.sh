#!/bin/bash
# Compile finder-typeban from source and ad-hoc sign it.
set -e
cd "$(dirname "$0")"
swiftc -O main.swift -o finder-typeban
codesign -s - finder-typeban
echo "Built: $(pwd)/finder-typeban"
