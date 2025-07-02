#!/bin/bash

# parallel_dns_zone_reset.sh
#
# Description:
#   Parallel DNS zone creation and reset script for cPanel/WHM servers.
#   Handles main domains, addon domains, subdomains, and aliases.
#   Designed to work efficiently in clustered DNS environments with DNSOnly.
#
# Author: Arshford T
# Copyright (c) 2025 Arshford T. All rights reserved.
# License: For internal administrative use only. Not for redistribution without permission.
#

# Set the maximum number of parallel jobs
MAX_PARALLEL=50

# This function will be called in parallel
process_user() {
  USER=$1

  echo "📦 [$USER] Starting"

  # Get all domains owned by this user (main + addon + parked + subdomains)
  DOMAINS=$(grep ": $USER" /etc/userdomains | cut -d':' -f1)

  if [[ -z "$DOMAINS" ]]; then
    echo "❌ [$USER] No domains found."
    return
  fi

  # Get user's assigned IP (usually used for all their domains)
  IP=$(whmapi1 accountsummary user="$USER" | awk '/ip: / {print $2}')
  if [[ -z "$IP" ]]; then
    echo "❌ [$USER] Could not determine IP"
    return
  fi

  for DOMAIN in $DOMAINS; do
    if [[ ! -f "/var/named/${DOMAIN}.db" ]]; then
      echo "➕ [$USER] Creating zone for $DOMAIN (IP: $IP)"
      whmapi1 adddns domain="$DOMAIN" trueowner="$USER" ip="$IP" --output=json > /dev/null 2>&1
    else
      echo "🔎 [$USER] Zone already exists for $DOMAIN, skipping creation"
    fi

    echo "🔁 [$USER] Resetting zone for $DOMAIN"
    whmapi1 resetzone user="$USER" domain="$DOMAIN" --output=json > /dev/null 2>&1

    # Optional: sync to DNSOnly server (uncomment to enable)
    echo "🔄 [$USER] Syncing $DOMAIN to DNSOnly"
    /usr/local/cpanel/scripts/dnscluster synczone "$DOMAIN" > /dev/null 2>&1

    echo "✅ [$USER] Done with $DOMAIN"
  done
}

# Export function so GNU parallel can use it
export -f process_user

# Run all usernames from input file in parallel with a progress bar
parallel --bar -j "$MAX_PARALLEL" process_user :::: phishing_suspended_Jul022025.txt
