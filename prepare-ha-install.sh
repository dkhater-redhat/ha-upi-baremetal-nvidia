#!/bin/bash
set -e

# Set OCP version - default to 5.0
VERSION="${VERSION:-5.0}"

case "${VERSION}" in
  "5.0")
    OCP_VERSION="5.0.0-ec.5"
    RHCOS_BUILD="10.2.20260617-0101"
    INSTALLER_URL="https://mirror.openshift.com/pub/openshift-v4/aarch64/clients/ocp-dev-preview/${OCP_VERSION}/openshift-install-linux.tar.gz"
    ;;
  *)
    echo "Error: Unsupported VERSION=${VERSION}. Supported versions: 5.0"
    exit 1
    ;;
esac

RHCOS_ISO="rhcos-${RHCOS_BUILD}-live-iso.aarch64.iso"

echo "========================================"
echo "GB300 HA UPI Installation"
echo "OCP Version: ${OCP_VERSION}"
echo "RHCOS Build: ${RHCOS_BUILD}"
echo "========================================"
echo ""

# Check prerequisites
if [ ! -f pull-secret.json ]; then
    echo "ERROR: pull-secret.json not found!"
    exit 1
fi

if [ ! -f ssh.pub ]; then
    echo "ERROR: ssh.pub not found!"
    exit 1
fi

if [ ! -f install-config-ha.yaml.template ]; then
    echo "ERROR: install-config-ha.yaml.template not found!"
    exit 1
fi

if [ ! -d boot-params ]; then
    echo "ERROR: boot-params/ directory not found! Run ./configure-ha.sh first."
    exit 1
fi

# Download installer if needed
if [[ ! -x ./openshift-install ]]; then
    echo "Downloading OpenShift installer..."
    curl -LO "${INSTALLER_URL}"
    tar -xzf openshift-install-linux.tar.gz
    chmod +x openshift-install
    echo "✓ Downloaded openshift-install"
fi

# Download RHCOS ISO if needed
if [[ ! -f "${RHCOS_ISO}" ]]; then
    echo "Downloading RHCOS ISO..."
    curl -L -O \
      "https://releases-rhcos--prod-pipeline.apps.int.prod-stable-spoke1-dc-iad2.itup.redhat.com/storage/prod/streams/rhel-10.2-ocp4nv-preview/builds/${RHCOS_BUILD}/aarch64/${RHCOS_ISO}"
    echo "✓ Downloaded ${RHCOS_ISO}"
fi

# Read pull secret and SSH key
PULL_SECRET=$(cat pull-secret.json)
SSH_KEY=$(cat ssh.pub)

# Read from boot-params or use defaults
if [ -f boot-params/cp1-boot-params.txt ]; then
    # Extract cluster name from hostname (e.g., gb300-cp-1.gb300-ha.nvidia.local -> gb300-ha)
    FULL_HOSTNAME=$(grep -o '[^:]*\.nvidia\.local' boot-params/cp1-boot-params.txt | head -1)
    CLUSTER_NAME=$(echo "$FULL_HOSTNAME" | cut -d'.' -f2)
    BASE_DOMAIN="nvidia.local"
    NETWORK_CIDR="172.16.2.0/24"
else
    CLUSTER_NAME="gb300-ha"
    BASE_DOMAIN="nvidia.local"
    NETWORK_CIDR="172.16.2.0/24"
fi

export CLUSTER_NAME BASE_DOMAIN NETWORK_CIDR PULL_SECRET SSH_KEY

# Create installation directory
rm -rf ocp-install
mkdir -p ocp-install

# Generate install-config.yaml from template
echo "Generating install-config.yaml..."
envsubst < install-config-ha.yaml.template > ocp-install/install-config.yaml

echo "✓ Created install-config.yaml"

# Create manifests
./openshift-install create manifests --dir ocp-install/

echo "✓ Created manifests"

# Copy custom manifests to openshift/ directory
echo "Copying custom manifests..."
cp local_openshift/99-os-layer-custom-5.0.yaml ocp-install/openshift/
cp local_openshift/99-cluster-dns-02-config.yaml ocp-install/openshift/
cp local_openshift/99-master-zz-unsigned-policy.yaml ocp-install/openshift/

echo "✓ Copied NVIDIA node image and DNS manifests"

# Create ignition configs
echo ""
echo "Creating Ignition configs..."
./openshift-install create ignition-configs --dir ocp-install/

echo "✓ Created bootstrap.ign and master.ign"

# Embed ignition configs into ISOs
echo ""
echo "Creating bootable ISOs..."

# Bootstrap ISO
echo "Creating bootstrap ISO..."
BOOTSTRAP_BOOT_PARAMS=$(cat boot-params/bootstrap-boot-params.txt)

coreos-installer iso kargs modify \
  -a "${BOOTSTRAP_BOOT_PARAMS} systemd.sandbox_generators=0 enforcing=0 selinux=0 rd.debug rd.info console=ttyS0,115200 console=tty0" \
  "${RHCOS_ISO}" \
  -o gb300-bootstrap-temp.iso

coreos-installer iso ignition embed \
  -i ocp-install/bootstrap.ign \
  gb300-bootstrap-temp.iso \
  -o gb300-bootstrap.iso

rm -f gb300-bootstrap-temp.iso

echo "✓ Created gb300-bootstrap.iso"

# Control Plane 1 ISO
echo "Creating control plane 1 ISO..."
CP1_BOOT_PARAMS=$(cat boot-params/cp1-boot-params.txt)

coreos-installer iso kargs modify \
  -a "${CP1_BOOT_PARAMS} systemd.sandbox_generators=0 enforcing=0 selinux=0 rd.debug rd.info console=ttyS0,115200 console=tty0" \
  "${RHCOS_ISO}" \
  -o gb300-cp-1.iso

echo "✓ Created gb300-cp-1.iso"

# Control Plane 2 ISO
echo "Creating control plane 2 ISO..."
CP2_BOOT_PARAMS=$(cat boot-params/cp2-boot-params.txt)

coreos-installer iso kargs modify \
  -a "${CP2_BOOT_PARAMS} systemd.sandbox_generators=0 enforcing=0 selinux=0 rd.debug rd.info console=ttyS0,115200 console=tty0" \
  "${RHCOS_ISO}" \
  -o gb300-cp-2.iso

echo "✓ Created gb300-cp-2.iso"

# Control Plane 3 ISO
echo "Creating control plane 3 ISO..."
CP3_BOOT_PARAMS=$(cat boot-params/cp3-boot-params.txt)

coreos-installer iso kargs modify \
  -a "${CP3_BOOT_PARAMS} systemd.sandbox_generators=0 enforcing=0 selinux=0 rd.debug rd.info console=ttyS0,115200 console=tty0" \
  "${RHCOS_ISO}" \
  -o gb300-cp-3.iso

echo "✓ Created gb300-cp-3.iso"

echo ""
echo "========================================"
echo "Installation ISOs ready!"
echo "Created:"
echo "  - gb300-bootstrap.iso (tray 18)"
echo "  - gb300-cp-1.iso (tray 15)"
echo "  - gb300-cp-2.iso (tray 16)"
echo "  - gb300-cp-3.iso (tray 17)"
echo ""
echo "Next steps:"
echo "  1. Mount each ISO to its corresponding node via BMC"
echo "  2. Boot all 4 nodes"
echo "  3. Monitor: ./openshift-install wait-for bootstrap-complete --dir ocp-install/"
echo "========================================"
