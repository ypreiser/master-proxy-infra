#!/bin/bash
# C:\master-proxy-infra\update-firewall.sh - FINAL CORRECTED VERSION

set -e

echo "--- Force-resetting UFW to a clean state ---"
# THIS IS THE CRITICAL FIX: It deletes ALL existing rules.
sudo ufw --force reset

echo "--- Securing UFW Firewall for Cloudflare ---"
# Re-enable the firewall immediately after the reset.
sudo ufw --force enable

# Set default policies: Block everything coming in, allow everything going out.
sudo ufw default deny incoming
sudo ufw default allow outgoing

# --- ESSENTIAL: Allow SSH so you don't get locked out ---
echo "Allowing SSH access..."
sudo ufw allow 22/tcp

# Fetch Cloudflare IPs
echo "Fetching Cloudflare IP ranges..."
CF_IPV4=$(curl -s https://www.cloudflare.com/ips-v4)
CF_IPV6=$(curl -s https://www.cloudflare.com/ips-v6)

# Add new Cloudflare rules
echo "Adding new rules for Cloudflare addresses..."
for ip in $CF_IPV4; do
  sudo ufw allow from $ip to any port 80,443 proto tcp comment 'Cloudflare'
done
for ip in $CF_IPV6; do
  sudo ufw allow from $ip to any port 80,443 proto tcp comment 'Cloudflare'
done

# Add Green API IPs
echo "Adding rules for Green API IPs..."
GREEN_API_IPS=(
  46.101.109.139
  51.250.12.167
  51.250.84.44
  51.250.95.149
  89.169.137.216
  158.160.49.84
  165.22.93.202
  167.172.162.71
  158.160.139.176
)

for ip in "${GREEN_API_IPS[@]}"; do
  sudo ufw allow from $ip to any port 80,443 proto tcp comment 'Green API'
done

echo "✅ Firewall has been reset and is now active, locked down to Cloudflare and Green API IPs."
sudo ufw status