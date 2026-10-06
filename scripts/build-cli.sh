#!/bin/sh
# Builds the ampoule CLI and signs it with the virtualization entitlement.
# Virtualization.framework refuses to start VMs from an unsigned binary.
# Usage: scripts/build-cli.sh [debug|release]
set -eu

configuration="${1:-debug}"
cd "$(dirname "$0")/.."

swift build -c "$configuration" --product ampoule
binary="$(swift build -c "$configuration" --show-bin-path)/ampoule"
codesign --force --sign - --entitlements Resources/ampoule-cli.entitlements "$binary"
echo "$binary"
