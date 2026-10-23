#!/usr/bin/env bash
set -e

echo "=========================================="
echo "Cleaning up generated HA installation files..."
echo "=========================================="

# Remove generated directories
echo "  - Removing ocp-install/ directory..."
rm -rf ocp-install/

# Remove generated boot parameter files
echo "  - Removing boot-params/ directory..."
rm -rf boot-params/

# Remove generated ISOs (keep the downloaded RHCOS ISO)
echo "  - Removing generated ISOs..."
rm -f gb300-*.iso 2>/dev/null || true

# Remove generated ignition files
echo "  - Removing ignition files..."
rm -f *.ign

echo ""
echo "=========================================="
echo "Cleanup complete!"
echo "=========================================="
echo ""
echo "Kept files:"
echo "  - Scripts (configure-ha.sh, prepare-ha-install.sh)"
echo "  - ssh.pub and pull-secret.json"
echo "  - Downloaded openshift-install and RHCOS ISO"
echo "  - NVIDIA node image manifest (99-os-layer-custom-5.0.yaml)"
echo "  - install-config-ha.yaml"
echo ""
echo "Next step:"
echo "  ./configure-ha.sh"
echo ""
