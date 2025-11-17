#!/bin/bash
# Script to configure ArgoCD with the GitHub repository and secure the installation.
# This assumes the ArgoCD server is running and port-forwarding is NOT active (we use --port-forward).

set -euo pipefail

# --- CONFIGURATION (UPDATE THESE VALUES) ---
# Replace with the password you want for the 'admin' user.
NEW_ARGOCD_PASSWORD="admin000" 
# Replace with your actual GitHub username and the PAT you created earlier
GITHUB_USERNAME="irfan84" 
GITHUB_PAT="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" 
# This is the URL of your infra-repo on GitHub
REPO_URL="https://github.com/irfan84/nz-k8s-devops-project.git" 
# --- END CONFIGURATION ---

# 1. Install ArgoCD CLI (if not already installed)
echo "--- 1. Installing ArgoCD CLI ---"
# Check if argocd CLI is available. If not, prompt the user.
if ! command -v argocd &> /dev/null
then
    echo "argocd CLI not found. Please install it (e.g., using 'sudo snap install argocd --classic') and re-run."
    exit 1
fi

# 2. Login to ArgoCD using the initial password
echo "--- 2. Logging into ArgoCD with initial secret password ---"
# We retrieve the initial password again to ensure we get the latest one.
INITIAL_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Log in using the initial password. We use --core to talk directly to Kubernetes.
# We set ARGOCD_OPTS to avoid needing to pass --port-forward every time.
export ARGOCD_OPTS="--insecure --port-forward --port-forward-namespace argocd"

argocd login localhost:8080 --username admin --password "$INITIAL_PASSWORD"

# 3. Change the Admin Password (CRITICAL SECURITY STEP)
echo "--- 3. Changing initial Admin Password for security ---"
# The update-password command requires the current password and the new one.
argocd account update-password \
    --current-password "$INITIAL_PASSWORD" \
    --new-password "$NEW_ARGOCD_PASSWORD"

# 4. Cleanup: Delete the initial password Secret
echo "--- 4. Deleting initial secret (argocd-initial-admin-secret) ---"
# This clears the temporary secret that holds the default password in plain text.
kubectl delete secret argocd-initial-admin-secret -n argocd

# 5. Register the GitHub Repository (The Source of Truth)
echo "--- 5. Registering GitHub Repository with ArgoCD ---"
# We register the repo using the HTTPS URL and the Personal Access Token (PAT)
argocd repo add "$REPO_URL" \
    --username "$GITHUB_USERNAME" \
    --password "$GITHUB_PAT"

echo " "
echo "✅ GitOps Configuration Complete!"
echo "   - New ArgoCD Admin Password is set (DO NOT LOSE IT): ${NEW_ARGOCD_PASSWORD}"
echo "   - Your repository is registered."
echo "   - Next step: Create your application manifest in Git and deploy using 'argocd app create'."
echo " "