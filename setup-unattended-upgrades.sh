#!/bin/bash
# C:\master-proxy-infra\setup-unattended-upgrades.sh
# One-time manual setup on host: cd ~/master-proxy-infra && sudo ./setup-unattended-upgrades.sh
# Idempotent: enables automatic Ubuntu security updates (default origins = security only).
# No auto-reboot: host-health.yml alerts via Telegram when /var/run/reboot-required appears.

set -e

if ! dpkg -s unattended-upgrades >/dev/null 2>&1; then
  echo "Installing unattended-upgrades..."
  sudo apt-get -o DPkg::Lock::Timeout=300 update -q
  sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y -q unattended-upgrades
fi

sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'CONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
CONF

echo "✅ unattended-upgrades enabled (security updates, no auto-reboot)."
