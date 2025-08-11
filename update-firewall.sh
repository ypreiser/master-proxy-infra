#!/bin/bash

# C:\master-proxy-infra\update-firewall.sh
#
# A robust firewall script for a server behind Cloudflare.
# - Allows SSH traffic from anywhere (relies on key-based auth).
# - Locks down web traffic (80/443) to ONLY Cloudflare IPs.
# --- NEW: Explicitly allows traffic from Docker interfaces to ensure inter-container communication.
# - This script is idempotent and can be run safely multiple times.

set -e

echo "--- Securing UFW Firewall for Cloudflare & Docker ---"

# Set default policies first
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Ensure SSH is allowed so we don't lock ourselves out
echo "Ensuring SSH access is allowed..."
sudo ufw allow 22/tcp

# --- KEY FIX: Allow all traffic from Docker's default bridge network ---
# This is crucial for allowing the master-proxy to forward traffic to other containers.
# We find the interface name dynamically.
DOCKER_BRIDGE_INTERFACE=$(ip addr | grep 'scope global docker' | awk '{print $NF}')
if [ -n "$DOCKER_BRIDGE_INTERFACE" ]; then
  echo "Allowing traffic from Docker bridge interface: $DOCKER_BRIDGE_INTERFACE"
  sudo ufw allow in on $DOCKER_BRIDGE_INTERFACE from any
else
  # Fallback for older Docker versions or different network setups
  echo "Could not dynamically find Docker bridge. Applying rule to default 'docker0'."
  sudo ufw allow in on docker0 from any
fi


# Fetch Cloudflare IPs
echo "Fetching Cloudflare IP ranges..."
CF_IPV4=$(curl -s https://www.cloudflare.com/ips-v4)
CF_IPV6=$(curl -s https://www.cloudflare.com/ips-v6)

# First, remove any existing Cloudflare rules to start fresh
echo "Deleting old Cloudflare rules..."
sudo ufw status numbered | grep "Cloudflare" | awk -F'[][]' '{print $2}' | tac | while read -r line ; do sudo ufw --force delete $line; done

# Add new Cloudflare rules with comments for easy identification
echo "Adding new rules for Cloudflare IPv4 addresses..."
for ip in $CF_IPV4; do
  sudo ufw allow from $ip to any port 80,443 proto tcp comment 'Cloudflare'
done

echo "Adding new rules for Cloudflare IPv6 addresses..."
for ip in $CF_IPV6; do
  sudo ufw allow from $ip to any port 80,443 proto tcp comment 'Cloudflare'
done

# IMPORTANT: Now we ensure the generic 'allow from anywhere' rules for web traffic are gone.
echo "Removing generic web traffic rules..."
# The > /dev/null 2>&1 || true part suppresses errors if the rule doesn't exist
sudo ufw delete allow 80/tcp > /dev/null 2>&1 || true
sudo ufw delete allow 443/tcp > /dev/null 2>&1 || true


# Enable the firewall
sudo ufw --force enable

echo "✅ Firewall is now active and locked down to Cloudflare IPs and internal Docker traffic."
sudo ufw status