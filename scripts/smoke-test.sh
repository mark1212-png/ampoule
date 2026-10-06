#!/bin/sh
# End-to-end check with the signed CLI: creates a throwaway Linux VM with a shared folder, validates it,
# and boots it. With no operating system on its disk the EFI firmware powers it off within seconds,
# which exercises what unit tests can't: configuration validation and starting a real VM (both need
# the virtualization entitlement). Opens a VM window briefly.
#
# Skips (exit 0) on machines without hardware virtualization, such as GitHub's macOS runners.
set -eu

if [ "$(sysctl -n kern.hv_support 2>/dev/null || echo 0)" != "1" ]; then
    echo "smoke test skipped: hardware virtualization isn't available on this machine"
    exit 0
fi

cd "$(dirname "$0")/.."
ampoule="$(scripts/build-cli.sh | tail -1)"

AMPOULE_HOME="$(mktemp -d)"
export AMPOULE_HOME
shared="$(mktemp -d)"
trap 'rm -rf "$AMPOULE_HOME" "$shared"' EXIT

fail() {
    echo "smoke test FAILED: $1" >&2
    exit 1
}

"$ampoule" create Smoke --os linux --cpus 2 --memory 1024 --disk 1 >/dev/null
"$ampoule" share add Smoke "$shared" --read-only >/dev/null
"$ampoule" validate "$AMPOULE_HOME/Smoke.ampoule" >/dev/null || fail "validate"

# perl's alarm is a portable timeout: the VM must start and stop within 60 seconds.
output="$(perl -e 'alarm 60; exec @ARGV' "$ampoule" run Smoke 2>&1)" || fail "run exited with $?: $output"
echo "$output" | grep -q "VM started" || fail "VM didn't start: $output"
echo "$output" | grep -q "VM stopped" || fail "VM didn't stop cleanly: $output"

for file in vz.json efi-variables.bin; do
    [ -f "$AMPOULE_HOME/Smoke.ampoule/$file" ] || fail "$file wasn't created"
done
"$ampoule" list >/dev/null || fail "list reported an invalid bundle"

echo "smoke test passed"
