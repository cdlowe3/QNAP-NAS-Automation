#!/bin/bash
# =============================================================================
# Run: QNAP Storage Monitor
# Usage: bash scripts/run_storage_monitor.sh
# =============================================================================

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOGFILE="Logs/qnap/storage_monitor_${TIMESTAMP}.log"
mkdir -p Logs/qnap

cd "$(dirname "$0")/.." || exit 1

echo "Are you on the local network? (y/n)"
read -r answer

LIMIT=$( [ "$answer" = "y" ] || [ "$answer" = "Y" ] && echo "nas" || echo "tailscale_nas" )

ansible-playbook -i inventory playbooks/QNAP_Storage_Monitor.yaml \
    --limit "$LIMIT" \
    --vault-password-file .vault_pass \
    "$@" 2>&1 | tee "${LOGFILE}"

echo ""
echo "============================================"
echo "  Finished:  $(date)"
echo "  Log saved: ${LOGFILE}"
echo "============================================"
