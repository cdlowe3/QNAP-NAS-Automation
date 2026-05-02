#!/bin/bash
# =============================================================================
# Run: QNAP Firmware Check
# Usage:
#   Interactive:  bash scripts/run_firmware_check.sh
#   Headless:     bash scripts/run_firmware_check.sh --headless
# =============================================================================

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOGFILE="Logs/qnap/firmware_check_${TIMESTAMP}.log"
mkdir -p Logs/qnap

HEADLESS=false
EXTRA_ARGS=()

for arg in "$@"; do
    if [ "$arg" = "--headless" ]; then
        HEADLESS=true
    else
        EXTRA_ARGS+=("$arg")
    fi
done

cd "$(dirname "$0")/.." || exit 1

if [ "$HEADLESS" = true ]; then
    echo "Running headless (cron mode) — logging to ${LOGFILE}"
    ansible-playbook -i inventory playbooks/QNAP_Firmware_Check.yaml \
        --limit "nas" \
        --vault-password-file .vault_pass \
        --extra-vars "headless=true" \
        "${EXTRA_ARGS[@]}" 2>&1 | tee "${LOGFILE}"
else
    echo "Are you on the local network? (y/n)"
    read -r answer

    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        LIMIT="nas"
        echo "Using local network..."
    else
        LIMIT="tailscale_nas"
        echo "Using Tailscale..."
    fi

    ansible-playbook -i inventory playbooks/QNAP_Firmware_Check.yaml \
        --limit "$LIMIT" \
        --vault-password-file .vault_pass \
        "${EXTRA_ARGS[@]}"
fi

echo ""
echo "============================================"
echo "  Finished:  $(date)"
echo "  Exit Code: ${PIPESTATUS[0]:-$?}"
echo "============================================"
