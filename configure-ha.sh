#!/bin/bash
set -e

echo "========================================"
echo "HA UPI Configuration Script"
echo "========================================"
echo ""
echo "This script will configure network settings for all 4 nodes"
echo "Please provide the following information:"
echo ""

# Cluster-wide settings
read -p "Cluster name [gb300-ha]: " CLUSTER_NAME
CLUSTER_NAME=${CLUSTER_NAME:-gb300-ha}

read -p "Base domain [nvidia.local]: " BASE_DOMAIN
BASE_DOMAIN=${BASE_DOMAIN:-nvidia.local}

read -p "Network CIDR [172.16.2.0/24]: " NETWORK_CIDR
NETWORK_CIDR=${NETWORK_CIDR:-172.16.2.0/24}

read -p "Gateway [172.16.2.1]: " GATEWAY
GATEWAY=${GATEWAY:-172.16.2.1}

read -p "DNS Server (load balancer) [172.16.0.1]: " DNS_SERVER
DNS_SERVER=${DNS_SERVER:-172.16.0.1}

read -p "Network interface name [enP5p9s0]: " INTERFACE
INTERFACE=${INTERFACE:-enP5p9s0}

echo ""
echo "========================================"
echo "Control Plane Node 1 (tray-15)"
echo "========================================"
read -p "CP1 IP address [172.16.2.117]: " CP1_IP
CP1_IP=${CP1_IP:-172.16.2.117}

read -p "CP1 hostname [gb300-cp-1]: " CP1_HOSTNAME
CP1_HOSTNAME=${CP1_HOSTNAME:-gb300-cp-1}

read -p "CP1 disk ID [nvme3n1]: " CP1_DISK
CP1_DISK=${CP1_DISK:-nvme3n1}

echo ""
echo "========================================"
echo "Control Plane Node 2 (tray-16)"
echo "========================================"
read -p "CP2 IP address [172.16.2.118]: " CP2_IP
CP2_IP=${CP2_IP:-172.16.2.118}

read -p "CP2 hostname [gb300-cp-2]: " CP2_HOSTNAME
CP2_HOSTNAME=${CP2_HOSTNAME:-gb300-cp-2}

read -p "CP2 disk ID [nvme1n1]: " CP2_DISK
CP2_DISK=${CP2_DISK:-nvme1n1}

echo ""
echo "========================================"
echo "Control Plane Node 3 (tray-17)"
echo "========================================"
read -p "CP3 IP address [172.16.2.119]: " CP3_IP
CP3_IP=${CP3_IP:-172.16.2.119}

read -p "CP3 hostname [gb300-cp-3]: " CP3_HOSTNAME
CP3_HOSTNAME=${CP3_HOSTNAME:-gb300-cp-3}

read -p "CP3 disk ID [nvme1n1]: " CP3_DISK
CP3_DISK=${CP3_DISK:-nvme1n1}

echo ""
echo "========================================"
echo "Bootstrap Node (tray-18)"
echo "========================================"
read -p "Bootstrap IP address [172.16.2.120]: " BOOTSTRAP_IP
BOOTSTRAP_IP=${BOOTSTRAP_IP:-172.16.2.120}

read -p "Bootstrap hostname [gb300-bootstrap]: " BOOTSTRAP_HOSTNAME
BOOTSTRAP_HOSTNAME=${BOOTSTRAP_HOSTNAME:-gb300-bootstrap}

read -p "Bootstrap disk ID [nvme1n1]: " BOOTSTRAP_DISK
BOOTSTRAP_DISK=${BOOTSTRAP_DISK:-nvme1n1}

echo ""
echo "========================================"
echo "Configuration Summary:"
echo "========================================"
echo "Cluster: ${CLUSTER_NAME}.${BASE_DOMAIN}"
echo "Network: ${NETWORK_CIDR}"
echo "Gateway: ${GATEWAY}"
echo "DNS: ${DNS_SERVER}"
echo "Interface: ${INTERFACE}"
echo ""
echo "Control Plane 1: ${CP1_HOSTNAME}.${CLUSTER_NAME}.${BASE_DOMAIN} (${CP1_IP}) -> /dev/${CP1_DISK}"
echo "Control Plane 2: ${CP2_HOSTNAME}.${CLUSTER_NAME}.${BASE_DOMAIN} (${CP2_IP}) -> /dev/${CP2_DISK}"
echo "Control Plane 3: ${CP3_HOSTNAME}.${CLUSTER_NAME}.${BASE_DOMAIN} (${CP3_IP}) -> /dev/${CP3_DISK}"
echo "Bootstrap: ${BOOTSTRAP_HOSTNAME}.${CLUSTER_NAME}.${BASE_DOMAIN} (${BOOTSTRAP_IP}) -> /dev/${BOOTSTRAP_DISK}"
echo "========================================"
echo ""
read -p "Continue with these settings? [Y/n]: " CONFIRM
CONFIRM=${CONFIRM:-Y}

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Updating configuration files..."

# Export variables for templates
export CLUSTER_NAME BASE_DOMAIN NETWORK_CIDR GATEWAY DNS_SERVER INTERFACE
export CP1_IP CP1_HOSTNAME CP1_DISK
export CP2_IP CP2_HOSTNAME CP2_DISK
export CP3_IP CP3_HOSTNAME CP3_DISK
export BOOTSTRAP_IP BOOTSTRAP_HOSTNAME BOOTSTRAP_DISK

# Calculate netmask from CIDR (assuming /24)
SUBNET_BITS=$(echo $NETWORK_CIDR | cut -d'/' -f2)
if [ "$SUBNET_BITS" = "24" ]; then
    NETMASK="255.255.255.0"
elif [ "$SUBNET_BITS" = "23" ]; then
    NETMASK="255.255.254.0"
elif [ "$SUBNET_BITS" = "28" ]; then
    NETMASK="255.255.255.240"
else
    NETMASK="255.255.255.0"  # default
fi
export NETMASK

# Create boot parameter file for each node
echo "  - Creating boot parameter files..."
mkdir -p boot-params

cat > boot-params/cp1-boot-params.txt << EOF
rd.neednet=1 ip=${CP1_IP}::${GATEWAY}:${NETMASK}:${CP1_HOSTNAME}.${CLUSTER_NAME}.${BASE_DOMAIN}:${INTERFACE}:none nameserver=${DNS_SERVER} coreos.inst.install_dev=/dev/${CP1_DISK} coreos.inst.ignition_url=https://${BOOTSTRAP_IP}:22623/config/master coreos.inst.insecure-ignition
EOF

cat > boot-params/cp2-boot-params.txt << EOF
rd.neednet=1 ip=${CP2_IP}::${GATEWAY}:${NETMASK}:${CP2_HOSTNAME}.${CLUSTER_NAME}.${BASE_DOMAIN}:${INTERFACE}:none nameserver=${DNS_SERVER} coreos.inst.install_dev=/dev/${CP2_DISK} coreos.inst.ignition_url=https://${BOOTSTRAP_IP}:22623/config/master coreos.inst.insecure-ignition
EOF

cat > boot-params/cp3-boot-params.txt << EOF
rd.neednet=1 ip=${CP3_IP}::${GATEWAY}:${NETMASK}:${CP3_HOSTNAME}.${CLUSTER_NAME}.${BASE_DOMAIN}:${INTERFACE}:none nameserver=${DNS_SERVER} coreos.inst.install_dev=/dev/${CP3_DISK} coreos.inst.ignition_url=https://${BOOTSTRAP_IP}:22623/config/master coreos.inst.insecure-ignition
EOF

cat > boot-params/bootstrap-boot-params.txt << EOF
rd.neednet=1 ip=${BOOTSTRAP_IP}::${GATEWAY}:${NETMASK}:${BOOTSTRAP_HOSTNAME}.${CLUSTER_NAME}.${BASE_DOMAIN}:${INTERFACE}:none nameserver=${DNS_SERVER} coreos.inst.install_dev=/dev/${BOOTSTRAP_DISK} coreos.inst.ignition_url=https://${BOOTSTRAP_IP}:22623/config/bootstrap coreos.inst.insecure-ignition
EOF

echo ""
echo "========================================"
echo "Configuration complete!"
echo "========================================"
echo ""
echo "Generated files:"
echo "  - boot-params/cp1-boot-params.txt"
echo "  - boot-params/cp2-boot-params.txt"
echo "  - boot-params/cp3-boot-params.txt"
echo "  - boot-params/bootstrap-boot-params.txt"
echo ""
echo "Next steps:"
echo "  1. Ensure pull-secret.json and ssh.pub files exist in this directory"
echo "  2. Run: ./prepare-ha-install.sh"
echo ""
echo "Note: Boot parameters include coreos.inst.* arguments to automatically"
echo "install RHCOS to disk on first boot per Red Hat UPI installation docs."
echo ""
