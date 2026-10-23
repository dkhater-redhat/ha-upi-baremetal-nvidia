#!/bin/bash
set -e

# Re-run with sudo if not root
if [ "$EUID" -ne 0 ]; then
    echo "Re-running with sudo..."
    exec sudo "$0" "$@"
fi

echo "========================================"
echo "Copying ISOs to Mac mount"
echo "========================================"

# Check if /mnt/macos exists
if [ ! -d "/mnt/macos" ]; then
    echo "ERROR: /mnt/macos not found!"
    echo "Make sure macOS directory is mounted in VM"
    exit 1
fi

# Copy all generated ISOs
echo "Copying ISOs..."
cp gb300-bootstrap.iso /mnt/macos/
cp gb300-cp-1.iso /mnt/macos/
cp gb300-cp-2.iso /mnt/macos/
cp gb300-cp-3.iso /mnt/macos/

echo "Copying openshift-install binary..."
cp openshift-install /mnt/macos/

echo "Copying ocp-install directory..."
cp -r ocp-install /mnt/macos/

echo ""
echo "========================================"
echo "Files copied successfully!"
echo "========================================"
echo ""
echo "ISOs:"
ls -lh /mnt/macos/gb300-*.iso
echo ""
echo "Installation tools:"
ls -lh /mnt/macos/openshift-install
echo "  ocp-install/ directory copied"
echo ""
echo "Next steps:"
echo "  1. From Mac, SCP ISOs to bastion NFS"
echo "  2. Keep openshift-install and ocp-install/ for monitoring"
echo "========================================"
