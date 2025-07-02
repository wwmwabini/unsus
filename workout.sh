#!/bin/bash

# Get all suspended users
suspended_users=$(whmapi1 listaccts | awk '/user: / {user=$2} /suspended: 1/ {print user}')

for user in $suspended_users; do
    # Get suspension reason
    reason=$(whmapi1 accountsummary user=$user | awk -F': ' '/suspendreason:/ {print $2}' | sed 's/^ *//;s/ *$//')

    # If reason includes "abuse"
    if [[ "$reason" =~ [Aa]buse ]]; then
        echo "Unsuspending $user (Reason: $reason)"
        whmapi1 unsuspendacct user=$user > /dev/null
    fi
done

# Sync all DNS zones to the cluster
echo "Syncing all DNS zones to cluster..."
/scripts/dnscluster --syncall
echo "✅ DNS sync complete."
