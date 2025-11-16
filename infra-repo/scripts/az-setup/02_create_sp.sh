#!/usr/bin/env bash
# File: infra-repo/scripts/az-setup/02_create_sp.sh
# Purpose: Creates a Service Principal for Terraform with Contributor role scoped to the project's Resource Group.

# --- 1. PROFESSIONAL ERROR HANDLING (MID-LEVEL STANDARD) ---
# e: Exit immediately if a command exits with a non-zero status.
# u: Treat unset variables as an error.
# o pipefail: Ensures a piped command fails if any part of the pipe fails.
set -euo pipefail

# --- 2. CONFIGURATION VARIABLES ---
SP_NAME="sp-terraform-aks-nz" 
LOCATION="newzealandnorth"
PROJECT_RG_NAME="rg-nz-aks-project" 

echo "--- Starting Service Principal Creation for Terraform ---"

# Check if the user is logged in
if ! az account show 1> /dev/null; then
    echo "ERROR: You must run 'az login' before executing this script."
    exit 1
fi

# Get the current Subscription ID and Tenant ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

# --- 3. CREATE PROJECT RESOURCE GROUP (IDEMPOTENCY) ---
# We use '|| true' so the script does not error if the RG already exists. (Idempotency)
echo "Creating project resource group '$PROJECT_RG_NAME' (if it doesn't exist)..."
az group create --name $PROJECT_RG_NAME --location $LOCATION --output none || true

# --- 4. CREATE THE SERVICE PRINCIPAL WITH ROLE ASSIGNMENT (LEAST PRIVILEGE) ---
# Creates the SP and assigns the Contributor role, scoped ONLY to the project Resource Group.
echo "Creating SP ($SP_NAME) and assigning Contributor role to RG: $PROJECT_RG_NAME..."
SP_OUTPUT=$(az ad sp create-for-rbac \
    --name "${SP_NAME}" \
    --role "Contributor" \
    --scopes "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${PROJECT_RG_NAME}" \
    --query "{appId:appId, password:password, tenant:tenant}" -o json)

# --- 5. EXTRACT AND DISPLAY CREDENTIALS (CRITICAL) ---
APP_ID=$(echo "${SP_OUTPUT}" | jq -r '.appId')
PASSWORD=$(echo "${SP_OUTPUT}" | jq -r '.password')

echo ""
echo "========================================================================="
echo "✅ SERVICE PRINCIPAL CREATED SUCCESSFULLY!"
echo "========================================================================="
echo "!!! SENSITIVE CREDENTIALS - SAVE THESE IMMEDIATELY !!!"
echo ""
echo "ARM_SUBSCRIPTION_ID = ${SUBSCRIPTION_ID}"
echo "ARM_TENANT_ID       = ${TENANT_ID}"
echo "ARM_CLIENT_ID       = ${APP_ID}"
echo "ARM_CLIENT_SECRET   = ${PASSWORD}"
echo ""
echo "!!! The password will never be shown again. Do NOT commit to Git. !!!"
echo "========================================================================="

# --- 6. PERSIST ENVIRONMENT VARIABLES FOR TERRAFORM ---
# We use 'export' so the credentials are ready for Terraform in the current shell session.
export ARM_SUBSCRIPTION_ID=${SUBSCRIPTION_ID}
export ARM_TENANT_ID=${TENANT_ID}
export ARM_CLIENT_ID=${APP_ID}
export ARM_CLIENT_SECRET=${PASSWORD}

echo "Environment variables set. Run 'terraform init' next."