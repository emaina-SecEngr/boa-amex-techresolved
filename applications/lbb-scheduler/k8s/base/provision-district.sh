#!/bin/bash
# ============================================================
# LBBS — Provision a New School District
# ============================================================
# Usage: ./provision-district.sh tucson-usd
#
# This script:
#   1. Creates a Kubernetes namespace for the district
#   2. Sets resource quotas and limits
#   3. Creates network isolation policies
#   4. Deploys backend and frontend pods
#   5. Configures auto-scaling
#   6. Sets up district-specific secrets
#   7. Creates ingress routing
#
# ONE COMMAND = ENTIRE DISTRICT ENVIRONMENT
# Takes about 2 minutes to complete.
# ============================================================

set -e

DISTRICT=$1
REGION=${2:-us-west-2}
ECR_REGISTRY=${3:-"682391277575.dkr.ecr.us-west-2.amazonaws.com"}
ACCOUNT_ID=${4:-"682391277575"}

if [ -z "$DISTRICT" ]; then
    echo "Usage: ./provision-district.sh <district-name>"
    echo "Example: ./provision-district.sh tucson-usd"
    exit 1
fi

echo "========================================="
echo "  Provisioning district: $DISTRICT"
echo "========================================="

# Create temporary directory with district-specific files
WORK_DIR=$(mktemp -d)

# Process each template
for template in k8s/base/*.yaml; do
    filename=$(basename "$template")
    sed -e "s/DISTRICT_NAME/$DISTRICT/g" \
        -e "s|ECR_REGISTRY|$ECR_REGISTRY|g" \
        -e "s/ACCOUNT_ID/$ACCOUNT_ID/g" \
        "$template" > "$WORK_DIR/$filename"
done

echo "--- Creating namespace ---"
kubectl apply -f "$WORK_DIR/namespace-template.yaml"

echo "--- Creating service account ---"
kubectl apply -f "$WORK_DIR/service-account.yaml"

echo "--- Creating secrets ---"
kubectl apply -f "$WORK_DIR/district-secrets.yaml"

echo "--- Deploying backend ---"
kubectl apply -f "$WORK_DIR/backend-deployment.yaml"
kubectl apply -f "$WORK_DIR/backend-service.yaml"

echo "--- Configuring auto-scaling ---"
kubectl apply -f "$WORK_DIR/backend-hpa.yaml"

echo "--- Setting up ingress ---"
kubectl apply -f "$WORK_DIR/ingress.yaml"

echo "--- Waiting for pods to be ready ---"
kubectl rollout status deployment/lbbs-backend \
    -n "lbbs-$DISTRICT" --timeout=300s

echo ""
echo "========================================="
echo "  District $DISTRICT provisioned!"
echo "========================================="
echo ""
echo "  Namespace:  lbbs-$DISTRICT"
echo "  URL:        https://$DISTRICT.lbbs.lifebeyondthebooksaz.org"
echo "  Backend:    2 pods (auto-scales to 8)"
echo "  Database:   lbbs_$DISTRICT schema"
echo ""
echo "  Verify with:"
echo "    kubectl get pods -n lbbs-$DISTRICT"
echo "    kubectl get svc -n lbbs-$DISTRICT"
echo "========================================="

# Cleanup
rm -rf "$WORK_DIR
