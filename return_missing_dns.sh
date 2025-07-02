#!/bin/bash

# Set the reseller username
reseller_user=truehost

# Get the reseller IP once
reseller_ip=$(whmapi1 getresellerips user=$reseller_user | grep -E '^\s+- ' | awk '{print $2}' | head -n1)

if [ -z "$reseller_ip" ]; then
  echo "❌ Failed to get reseller IP for $reseller_user"
  exit 1
fi

echo "✅ Using reseller IP: $reseller_ip"

# Loop through all cPanel users
for user in $(ls /var/cpanel/users); do
  # Get the user's main domain
  domain=$(awk -F= '/^DNS=/{print $2}' /var/cpanel/users/$user)

  # Skip if the DNS zone already exists
  if [ -f "/var/named/${domain}.db" ]; then
    continue
  fi

  echo "➕ Creating DNS zone for $domain (user: $user)"

  # Create the DNS zone with owner
  /scripts/adddns --domain=$domain --ip=$reseller_ip --owner=$user
done
