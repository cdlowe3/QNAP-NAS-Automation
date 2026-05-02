#!/bin/bash
# =============================================================================
# Run: QNAP Network Status
# Usage: bash scripts/run_network_status.sh
# =============================================================================

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOGFILE="Logs/qnap/network_status_${TIMESTAMP}.log"
mkdir -p Logs/qnap

cd "$(dirname "$0")/.." || exit 1

echo "Are you on the local network? (y/n)"
read -r answer

LIMIT=$( [ "$answer" = "y" ] || [ "$answer" = "Y" ] && echo "nas" || echo "tailscale_nas" )

ansible-playbook -i inventory playbooks/QNAP_Network_Status.yaml \
    --limit "$LIMIT" \
    --vault-password-file .vault_pass \
    "$@" 2>&1 | tee "${LOGFILE}"

echo ""
echo "============================================"
echo "  Finished:  $(date)"
echo "  Log saved: ${LOGFILE}"
echo "============================================"
