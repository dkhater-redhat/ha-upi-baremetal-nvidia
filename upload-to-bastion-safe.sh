#!/bin/bash
set -e

# Script to upload HA UPI files to bastion ONE AT A TIME (safe for unstable connections)
# Usage: ./upload-to-bastion-safe.sh <version>
# Example: ./upload-to-bastion-safe.sh v8

if [ -z "$1" ]; then
    echo "Usage: ./upload-to-bastion-safe.sh <version>"
    echo "Example: ./upload-to-bastion-safe.sh v8"
    exit 1
fi

VERSION="$1"
BASTION_USER="nvidia@50f99807-87652f36"
BASTION_HOST="global.prd.ga.launchpad.nvidia.com"
CONFIG_DIR="~/ha-upi-configuration"
TEMP_DIR="/tmp/ha-upi-upload-$$"

echo "========================================"
echo "Safe Upload to Bastion (One at a Time)"
echo "Version: ${VERSION}"
echo "========================================"
echo ""

# Check if ISOs exist
if [ ! -f "gb300-bootstrap.iso" ]; then
    echo "ERROR: ISOs not found. Run ./prepare-ha-install.sh first."
    exit 1
fi

echo "This will upload files one at a time. Press Ctrl+C to stop."
echo ""

# Create temp directory
echo "[Step 1/7] Creating temporary directory on bastion..."
ssh "${BASTION_USER}@${BASTION_HOST}" "mkdir -p ${TEMP_DIR}"
echo "  ✓ Done"
echo ""
read -p "Press Enter to continue..."

# Upload bootstrap ISO
echo "[Step 2/7] Uploading bootstrap ISO (840MB)..."
read -p "Upload bootstrap ISO? [Y/n]: " UPLOAD_BOOTSTRAP
UPLOAD_BOOTSTRAP=${UPLOAD_BOOTSTRAP:-Y}
if [[ "$UPLOAD_BOOTSTRAP" =~ ^[Yy]$ ]]; then
    scp gb300-bootstrap.iso "${BASTION_USER}@${BASTION_HOST}:${TEMP_DIR}/"
    echo "  ✓ Bootstrap ISO uploaded"
else
    echo "  ⊘ Skipped bootstrap ISO upload"
fi
echo ""
read -p "Press Enter to continue..."

# Upload CP1 ISO
echo "[Step 3/7] Uploading CP1 ISO (840MB)..."
read -p "Upload CP1 ISO? [Y/n]: " UPLOAD_CP1
UPLOAD_CP1=${UPLOAD_CP1:-Y}
if [[ "$UPLOAD_CP1" =~ ^[Yy]$ ]]; then
    scp gb300-cp-1.iso "${BASTION_USER}@${BASTION_HOST}:${TEMP_DIR}/"
    echo "  ✓ CP1 ISO uploaded"
else
    echo "  ⊘ Skipped CP1 ISO upload"
fi
echo ""
read -p "Press Enter to continue..."

# Upload CP2 ISO
echo "[Step 4/7] Uploading CP2 ISO (840MB)..."
read -p "Upload CP2 ISO? [Y/n]: " UPLOAD_CP2
UPLOAD_CP2=${UPLOAD_CP2:-Y}
if [[ "$UPLOAD_CP2" =~ ^[Yy]$ ]]; then
    scp gb300-cp-2.iso "${BASTION_USER}@${BASTION_HOST}:${TEMP_DIR}/"
    echo "  ✓ CP2 ISO uploaded"
else
    echo "  ⊘ Skipped CP2 ISO upload"
fi
echo ""
read -p "Press Enter to continue..."

# Upload CP3 ISO
echo "[Step 5/7] Uploading CP3 ISO (840MB)..."
read -p "Upload CP3 ISO? [Y/n]: " UPLOAD_CP3
UPLOAD_CP3=${UPLOAD_CP3:-Y}
if [[ "$UPLOAD_CP3" =~ ^[Yy]$ ]]; then
    scp gb300-cp-3.iso "${BASTION_USER}@${BASTION_HOST}:${TEMP_DIR}/"
    echo "  ✓ CP3 ISO uploaded"
else
    echo "  ⊘ Skipped CP3 ISO upload"
fi
echo ""
read -p "Press Enter to continue..."

# Move ISOs to NFS with version suffix
echo "[Step 6/7] Moving ISOs to /var/nfs/isos/ with version ${VERSION}..."
ssh "${BASTION_USER}@${BASTION_HOST}" << EOF
    if [ -f ${TEMP_DIR}/gb300-bootstrap.iso ]; then
        sudo mv ${TEMP_DIR}/gb300-bootstrap.iso /var/nfs/isos/bootstrap${VERSION}.iso
    fi
    if [ -f ${TEMP_DIR}/gb300-cp-1.iso ]; then
        sudo mv ${TEMP_DIR}/gb300-cp-1.iso /var/nfs/isos/cp1${VERSION}.iso
    fi
    if [ -f ${TEMP_DIR}/gb300-cp-2.iso ]; then
        sudo mv ${TEMP_DIR}/gb300-cp-2.iso /var/nfs/isos/cp2${VERSION}.iso
    fi
    if [ -f ${TEMP_DIR}/gb300-cp-3.iso ]; then
        sudo mv ${TEMP_DIR}/gb300-cp-3.iso /var/nfs/isos/cp3${VERSION}.iso
    fi
    sudo chmod 644 /var/nfs/isos/*${VERSION}.iso 2>/dev/null || true
    rm -rf ${TEMP_DIR}
EOF
echo "  ✓ ISOs moved to /var/nfs/isos/"
echo ""
read -p "Press Enter to continue..."

# Upload openshift-install and ocp-install
echo "[Step 7/7] Uploading openshift-install and ocp-install/..."
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
