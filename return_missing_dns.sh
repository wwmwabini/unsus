#!/bin/bash

# Reseller username
RESELLER=truehost

echo "📦 Getting IPs assigned to reseller '$RESELLER'..."
reseller_ip=$(whmapi1 getresellerips user=$RESELLER | grep -E '^\s+- ' | awk '{print $2}')

if [[ -z "$reseller_ip" ]]; then
    echo "❌ No IPs found for reseller $RESELLER. Exiting."
    exit 1
fi

echo "✅ Reseller IP: $reseller_ip"
echo "🔍 Checking for domains missing DNS zones..."

# Get all domains
all_domains=$(awk '{print $1}' /etc/userdomains | sort -u)

# Counter
created_count=0

for domain in $all_domains; do
    if ! whmapi1 dumpzone domain=$domain >/dev/null 2>&1; then
        echo "❌ Missing DNS zone for: $domain"

        # Get the cPanel user who owns the domain
        user=$(grep -w "$domain" /etc/userdomains | awk '{print $2}')

        if [[ -z "$user" ]]; then
            echo "⚠️ Could not find user for $domain. Skipping."
            continue
        fi

        # Create DNS zone using /scripts/adddns
        echo "🔧 Creating DNS zone for $domain (user: $user)..."
        /scripts/adddns --domain="$domain" --ip="$reseller_ip" --user="$user" >/dev/null 2>&1

        if [[ $? -eq 0 ]]; then
            echo "✅ Zone created and assigned IP: $reseller_ip"
            ((created_count++))
        else
            echo "❌ Failed to create zone for $domain"
        fi
    fi
done

# Sync DNS cluster
echo "🔁 Syncing all DNS zones to cluster..."
/scripts/dnscluster syncall

echo "✅ Done. Created $created_count zone(s) and synced DNS."
