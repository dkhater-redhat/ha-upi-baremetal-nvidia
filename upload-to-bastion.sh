#!/bin/bash
set -e

# Script to upload HA UPI files to bastion
# Usage: ./upload-to-bastion.sh <version>
# Example: ./upload-to-bastion.sh v6

if [ -z "$1" ]; then
    echo "Usage: ./upload-to-bastion.sh <version>"
    echo "Example: ./upload-to-bastion.sh v6"
    exit 1
fi

VERSION="$1"
BASTION_USER="nvidia@50f99807-87652f36"
BASTION_HOST="global.prd.ga.launchpad.nvidia.com"
CONFIG_DIR="~/ha-upi-configuration"
TEMP_DIR="/tmp/ha-upi-upload-$$"

echo "========================================"
echo "Uploading HA UPI files to Bastion"
echo "Version: ${VERSION}"
echo "========================================"
echo ""

# Check if ISOs exist
if [ ! -f "gb300-bootstrap.iso" ]; then
    echo "ERROR: ISOs not found. Run ./prepare-ha-install.sh first."
    exit 1
fi

# Upload ISOs to temporary location first
echo "[1/3] Uploading ISOs to bastion..."
ssh "${BASTION_USER}@${BASTION_HOST}" "mkdir -p ${TEMP_DIR}"
scp gb300-bootstrap.iso gb300-cp-1.iso gb300-cp-2.iso gb300-cp-3.iso \
    "${BASTION_USER}@${BASTION_HOST}:${TEMP_DIR}/"
echo "  ✓ Uploaded ISOs"
echo ""

# Move ISOs to NFS with version suffix
echo "[2/3] Moving ISOs to /var/nfs/isos/ with version ${VERSION}..."
ssh "${BASTION_USER}@${BASTION_HOST}" << EOF
    sudo mv ${TEMP_DIR}/gb300-bootstrap.iso /var/nfs/isos/bootstrap${VERSION}.iso
    sudo mv ${TEMP_DIR}/gb300-cp-1.iso /var/nfs/isos/cp1${VERSION}.iso
    sudo mv ${TEMP_DIR}/gb300-cp-2.iso /var/nfs/isos/cp2${VERSION}.iso
    sudo mv ${TEMP_DIR}/gb300-cp-3.iso /var/nfs/isos/cp3${VERSION}.iso
    sudo chmod 644 /var/nfs/isos/*${VERSION}.iso
    rm -rf ${TEMP_DIR}
EOF
echo "  ✓ ISOs moved to /var/nfs/isos/"
echo ""

# Upload openshift-install and ocp-install to ha-upi-configuration
echo "[3/3] Uploading openshift-install and ocp-install/ to ${CONFIG_DIR}..."
if [ -f "openshift-install" ]; then
    scp openshift-install "${BASTION_USER}@${BASTION_HOST}:${CONFIG_DIR}/"
    echo "  ✓ Uploaded openshift-install"
else
    echo "  WARNING: openshift-install not found (skipping)"
fi

if [ -d "ocp-install" ]; then
    scp -r ocp-install "${BASTION_USER}@${BASTION_HOST}:${CONFIG_DIR}/"
    echo "  ✓ Uploaded ocp-install/"
else
    echo "  WARNING: ocp-install/ directory not found (skipping)"
fi
echo ""

echo "========================================"
echo "Upload complete!"
echo "========================================"
echo ""
echo "ISOs uploaded to /var/nfs/isos/:"
echo "  - bootstrap${VERSION}.iso"
echo "  - cp1${VERSION}.iso"
echo "  - cp2${VERSION}.iso"
echo "  - cp3${VERSION}.iso"
echo ""
echo "Installation files uploaded to ${CONFIG_DIR}/:"
echo "  - openshift-install"
echo "  - ocp-install/"
echo ""
echo "NFS URLs for BMC virtual media:"
echo "  Bootstrap (tray 18): nfs://172.16.0.1/var/nfs/isos/bootstrap${VERSION}.iso"
echo "  CP1 (tray 15):       nfs://172.16.0.1/var/nfs/isos/cp1${VERSION}.iso"
echo "  CP2 (tray 16):       nfs://172.16.0.1/var/nfs/isos/cp2${VERSION}.iso"
echo "  CP3 (tray 17):       nfs://172.16.0.1/var/nfs/isos/cp3${VERSION}.iso"
echo ""
echo "Next steps:"
echo "  1. Mount ISOs via BMC"
echo "  2. Boot bootstrap first, wait 5-10 min"
echo "  3. Boot control planes"
echo "  4. Monitor: ssh bastion 'cd ${CONFIG_DIR} && ./openshift-install wait-for bootstrap-complete --dir ocp-install/'"
echo "========================================"
