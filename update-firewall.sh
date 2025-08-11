#!/bin/bash

# C:\master-proxy-infra\update-firewall.sh
#
# A robust firewall script for a server behind Cloudflare.
# - Allows SSH traffic from anywhere (relies on key-based auth).
# - Locks down web traffic (80/443) to ONLY Cloudflare IPs.
# - This script is idempotent and can be run safely multiple times.

set -e

echo "--- Securing UFW Firewall for Cloudflare ---"

# Ensure SSH is allowed so we don't lock ourselves out
echo "Ensuring SSH access is allowed..."
sudo ufw allow 22/tcp

# Fetch Cloudflare IPs
echo "Fetching Cloudflare IP ranges..."
CF_IPV4=$(curl -s https://www.cloudflare.com/ips-v4)
CF_IPV6=$(curl -s https://www.cloudflare.com/ips-v6)

# First, remove any existing Cloudflare rules to start fresh
echo "Deleting old Cloudflare rules..."
# Grep for "Cloudflare" comments and use awk/sed to extract the rule number to delete
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
sudo ufw delete allow 80/tcp > /dev/null 2>&1 || true
sudo ufw delete allow 443/tcp > /dev/null 2>&1 || true

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Enable the firewall
sudo ufw --force enable

echo "✅ Firewall is now active and locked down to Cloudflare IPs."
sudo ufw status