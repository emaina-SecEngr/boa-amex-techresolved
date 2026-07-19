#!/bin/bash
# ============================================================
# LBBS — Provision ALL Arizona School Districts
# ============================================================
# Usage: ./provision-all-arizona.sh
#
# Provisions all 8 Arizona districts in one command.
# Each district gets its own isolated environment.
# Total time: ~15 minutes for all 8 districts.
# ============================================================

set -e

echo "========================================="
echo "  LBBS — Provisioning All Arizona Districts"
echo "========================================="

DISTRICTS=(
    "tucson-usd"
    "sunnyside-usd"
    "amphitheater-usd"
    "marana-usd"
    "catalina-foothills-usd"
    "flowing-wells-usd"
    "tanque-verde-usd"
    "vail-usd"
)

TOTAL=${#DISTRICTS[@]}
CURRENT=0

for district in "${DISTRICTS[@]}"; do
    CURRENT=$((CURRENT + 1))
    echo ""
    echo "[$CURRENT/$TOTAL] Provisioning: $district"
    echo "────────────────────────────────────"
    ./k8s/provision-district.sh "$district"
    echo ""
done

echo ""
echo "========================================="
echo "  ALL $TOTAL DISTRICTS PROVISIONED!"
echo "========================================="
echo ""
echo "  District URLs:"
for district in "${DISTRICTS[@]}"; do
    echo "    https://$district.lbbs.lifebeyondthebooksaz.org"
done
echo ""
echo "  Verify all pods:"
echo "    kubectl get pods --all-namespaces -l app=lbbs-backend"
echo ""
echo "  Total resources:"
echo "    Namespaces: $TOTAL"
echo "    Backend pods: $((TOTAL * 2)) (2 per district)"
echo "    Auto-scale max: $((TOTAL * 8)) pods"
echo "========================================="
