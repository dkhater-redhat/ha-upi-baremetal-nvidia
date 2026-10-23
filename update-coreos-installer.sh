#!/bin/bash
set -e

# Script to download and install the latest coreos-installer for ARM64
# Usage: ./update-coreos-installer.sh

MIN_VERSION="0.26.0"
MIRROR_BASE="https://mirror.openshift.com/pub/openshift-v4"
GITHUB_RELEASES="https://github.com/coreos/coreos-installer/releases"

echo "========================================"
echo "CoreOS Installer Update Script"
echo "========================================"
echo ""

# Function to compare versions
version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

# Function to extract version from binary
get_version() {
    local binary="$1"
    if [ -f "$binary" ] && [ -x "$binary" ]; then
        "$binary" --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1
    else
        echo "0.0.0"
    fi
}

# Check if coreos-installer is installed
if command -v coreos-installer &> /dev/null; then
    CURRENT_VERSION=$(get_version "$(which coreos-installer)")
    echo "Current coreos-installer version: ${CURRENT_VERSION}"
    echo "Location: $(which coreos-installer)"

    if version_gt "${CURRENT_VERSION}" "${MIN_VERSION}"; then
        echo "  ✓ Version is acceptable (>= ${MIN_VERSION})"
        read -p "Update anyway? [y/N]: " UPDATE
        UPDATE=${UPDATE:-N}
        if [[ ! "$UPDATE" =~ ^[Yy]$ ]]; then
            echo "Keeping current version."
            exit 0
        fi
    else
        echo "  ✗ Version is too old (minimum: ${MIN_VERSION})"
        echo "  Updating to latest version..."
    fi
else
    echo "coreos-installer not found. Installing latest version..."
fi

echo ""
echo "========================================"
echo "Finding latest coreos-installer..."
echo "========================================"
echo ""

# Try multiple sources
DOWNLOAD_SUCCESS=false

# Source 1: Try the "latest" symlink
echo "[1/4] Trying latest symlink..."
LATEST_URL="${MIRROR_BASE}/x86_64/clients/coreos-installer/latest/coreos-installer_arm64"
if curl -L "${LATEST_URL}" -o /tmp/coreos-installer-test 2>/dev/null; then
    chmod +x /tmp/coreos-installer-test
    TEST_VERSION=$(get_version "/tmp/coreos-installer-test")
    echo "  Latest symlink points to: ${TEST_VERSION}"

    if version_gt "${TEST_VERSION}" "${MIN_VERSION}"; then
        echo "  ✓ Version is acceptable"
        mv /tmp/coreos-installer-test /tmp/coreos-installer
        DOWNLOAD_SUCCESS=true
        FINAL_VERSION="${TEST_VERSION}"
    else
        echo "  ✗ Version too old, trying other sources..."
        rm -f /tmp/coreos-installer-test
    fi
else
    echo "  ✗ Download failed"
fi

# Source 2: Try RHCOS 5.0 dependencies
if [ "$DOWNLOAD_SUCCESS" = false ]; then
    echo ""
    echo "[2/4] Trying RHCOS 5.0 dependencies..."
    RHCOS_URL="${MIRROR_BASE}/aarch64/dependencies/rhcos/5.0/latest/coreos-installer"
    if curl -L "${RHCOS_URL}" -o /tmp/coreos-installer-test 2>/dev/null; then
        chmod +x /tmp/coreos-installer-test
        TEST_VERSION=$(get_version "/tmp/coreos-installer-test")
        echo "  RHCOS 5.0 version: ${TEST_VERSION}"

        if version_gt "${TEST_VERSION}" "${MIN_VERSION}"; then
            echo "  ✓ Version is acceptable"
            mv /tmp/coreos-installer-test /tmp/coreos-installer
            DOWNLOAD_SUCCESS=true
            FINAL_VERSION="${TEST_VERSION}"
        else
            echo "  ✗ Version too old"
            rm -f /tmp/coreos-installer-test
        fi
    else
        echo "  ✗ Download failed"
    fi
fi

# Source 3: List available versions and try the latest
if [ "$DOWNLOAD_SUCCESS" = false ]; then
    echo ""
    echo "[3/4] Listing available versions..."
    VERSIONS=$(curl -s "${MIRROR_BASE}/x86_64/clients/coreos-installer/" | grep -o 'href="v[0-9.]*/"' | sed 's/href="v//;s/\/"//g' | sort -V)

    if [ -n "$VERSIONS" ]; then
        LATEST_VERSION=$(echo "$VERSIONS" | tail -1)
        echo "  Latest version found: v${LATEST_VERSION}"

        SPECIFIC_URL="${MIRROR_BASE}/x86_64/clients/coreos-installer/v${LATEST_VERSION}/coreos-installer_arm64"
        if curl -L "${SPECIFIC_URL}" -o /tmp/coreos-installer-test 2>/dev/null; then
            chmod +x /tmp/coreos-installer-test
            TEST_VERSION=$(get_version "/tmp/coreos-installer-test")
            echo "  Downloaded version: ${TEST_VERSION}"

            mv /tmp/coreos-installer-test /tmp/coreos-installer
            DOWNLOAD_SUCCESS=true
            FINAL_VERSION="${TEST_VERSION}"
        else
            echo "  ✗ Download failed"
        fi
    else
        echo "  ✗ Could not list versions"
    fi
fi

# Source 4: Try GitHub releases (for v0.26.0+)
if [ "$DOWNLOAD_SUCCESS" = false ]; then
    echo ""
    echo "[4/5] Trying GitHub releases for v0.26.0..."
    GITHUB_URL="https://github.com/coreos/coreos-installer/releases/download/v0.26.0/coreos-installer-aarch64-unknown-linux-gnu"
    if curl -L "${GITHUB_URL}" -o /tmp/coreos-installer 2>/dev/null; then
        chmod +x /tmp/coreos-installer
        TEST_VERSION=$(get_version "/tmp/coreos-installer")
        echo "  Downloaded version: ${TEST_VERSION}"
        DOWNLOAD_SUCCESS=true
        FINAL_VERSION="${TEST_VERSION}"
    else
        echo "  ✗ Download failed"
    fi
fi

# Source 5: Try known good version v0.23.0 as fallback
if [ "$DOWNLOAD_SUCCESS" = false ]; then
    echo ""
    echo "[5/5] Trying fallback version v0.23.0..."
    FALLBACK_URL="${MIRROR_BASE}/x86_64/clients/coreos-installer/v0.23.0/coreos-installer_arm64"
    if curl -L "${FALLBACK_URL}" -o /tmp/coreos-installer 2>/dev/null; then
        chmod +x /tmp/coreos-installer
        TEST_VERSION=$(get_version "/tmp/coreos-installer")
        echo "  Downloaded version: ${TEST_VERSION}"
        DOWNLOAD_SUCCESS=true
        FINAL_VERSION="${TEST_VERSION}"
    else
        echo "  ✗ Download failed"
    fi
fi

if [ "$DOWNLOAD_SUCCESS" = false ]; then
    echo ""
    echo "========================================"
    echo "ERROR: Failed to download coreos-installer from all sources"
    echo "========================================"
    exit 1
fi

# Verify the downloaded binary
echo ""
echo "Verifying downloaded binary..."
if ! file /tmp/coreos-installer | grep -q "ARM aarch64"; then
    echo "ERROR: Downloaded binary is not ARM64"
    file /tmp/coreos-installer
    exit 1
fi

echo "Installing to /usr/local/bin/coreos-installer..."
sudo install -m 755 /tmp/coreos-installer /usr/local/bin/coreos-installer
rm -f /tmp/coreos-installer

# Verify installation
NEW_VERSION=$(get_version "/usr/local/bin/coreos-installer")
echo ""
echo "========================================"
echo "Installation complete!"
echo "========================================"
echo "coreos-installer version: ${NEW_VERSION}"
echo "Location: /usr/local/bin/coreos-installer"
echo ""

if version_gt "${NEW_VERSION}" "${MIN_VERSION}"; then
    echo "✓ Version is acceptable (>= ${MIN_VERSION})"
else
    echo "⚠ Warning: Version ${NEW_VERSION} is older than recommended ${MIN_VERSION}"
    echo "  This may cause issues with network configuration during installation"
fi

echo ""
echo "You can now run ./prepare-ha-install.sh to generate ISOs"
echo "========================================"
