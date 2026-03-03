#!/usr/bin/env bash
# scripts/deployment/deploy-stack.sh
# Run the full IT-Stack Ansible deployment.
#
# Usage:
#   bash scripts/deployment/deploy-stack.sh
#   bash scripts/deployment/deploy-stack.sh --phase 1
#   bash scripts/deployment/deploy-stack.sh --module nextcloud
#   bash scripts/deployment/deploy-stack.sh --check   (dry-run)
#
# Prerequisites:
#   - Ansible installed (ansible --version)
#   - vault/secrets.yml created from it-stack-ansible/vault/secrets.yml.example
#   - .vault_pass file in it-stack-ansible/ (chmod 600)
#   - SSH keys deployed to all 8 servers

set -euo pipefail

ANSIBLE_DIR="${ANSIBLE_DIR:-/opt/it-stack-dev/repos/meta/it-stack-ansible}"
VAULT_PASS="${ANSIBLE_DIR}/.vault_pass"
INVENTORY="${ANSIBLE_DIR}/inventory/hosts.ini"
PLAYBOOKS_DIR="${ANSIBLE_DIR}/playbooks"

PHASE=""
MODULE=""
CHECK_MODE=false
VERBOSE=false

# â”€â”€ Parse args â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
while [[ $# -gt 0 ]]; do
  case $1 in
    --phase)   PHASE="$2";   shift 2 ;;
    --module)  MODULE="$2";  shift 2 ;;
    --check)   CHECK_MODE=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# â”€â”€ Validate prerequisites â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
if ! command -v ansible-playbook &>/dev/null; then
  echo "ERROR: ansible-playbook not found. Install Ansible first."
  exit 1
fi

if [[ ! -f "$VAULT_PASS" ]]; then
  echo "ERROR: .vault_pass not found at $VAULT_PASS"
  echo "       Create it: echo 'your-vault-password' > $VAULT_PASS && chmod 600 $VAULT_PASS"
  exit 1
fi

if [[ ! -f "${ANSIBLE_DIR}/vault/secrets.yml" ]]; then
  echo "ERROR: vault/secrets.yml not found."
  echo "       Copy vault/secrets.yml.example, fill all values, encrypt:"
  echo "       ansible-vault encrypt vault/secrets.yml --vault-password-file .vault_pass"
  exit 1
fi

ANSIBLE_ARGS="-i $INVENTORY --vault-password-file $VAULT_PASS"
[[ "$CHECK_MODE" == "true" ]] && ANSIBLE_ARGS="$ANSIBLE_ARGS --check --diff"
[[ "$VERBOSE"    == "true" ]] && ANSIBLE_ARGS="$ANSIBLE_ARGS -v"

# â”€â”€ Run playbook â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
cd "$ANSIBLE_DIR"

if [[ -n "$MODULE" ]]; then
  PLAYBOOK="$PLAYBOOKS_DIR/deploy-${MODULE}.yml"
  if [[ ! -f "$PLAYBOOK" ]]; then
    echo "ERROR: Playbook not found: $PLAYBOOK"
    echo "Available modules:"
    ls "$PLAYBOOKS_DIR"/deploy-*.yml | xargs -n1 basename | sed 's/deploy-//;s/\.yml//' | sort
    exit 1
  fi
  echo "==> Deploying module: $MODULE"
  ansible-playbook $ANSIBLE_ARGS "$PLAYBOOK"

elif [[ -n "$PHASE" ]]; then
  case $PHASE in
    1) TAGS="phase1,common,freeipa,postgresql,redis,keycloak,traefik" ;;
    2) TAGS="phase2,nextcloud,mattermost,jitsi,iredmail,zammad,elasticsearch" ;;
    3) TAGS="phase3,freepbx,suitecrm,odoo,openkm" ;;
    4) TAGS="phase4,taiga,snipeit,glpi,zabbix,graylog" ;;
    *) echo "ERROR: Invalid phase $PHASE (use 1-4)"; exit 1 ;;
  esac
  echo "==> Deploying Phase $PHASE (tags: $TAGS)"
  ansible-playbook $ANSIBLE_ARGS --tags "$TAGS" "$PLAYBOOKS_DIR/site.yml"

else
  echo "==> Deploying full IT-Stack (all phases)"
  echo "    This will configure all 8 servers."
  read -rp "    Continue? [y/N] " confirm
  [[ "$confirm" == "y" || "$confirm" == "Y" ]] || { echo "Aborted."; exit 0; }
  ansible-playbook $ANSIBLE_ARGS "$PLAYBOOKS_DIR/site.yml"
fi

echo ""
echo "Deployment complete."