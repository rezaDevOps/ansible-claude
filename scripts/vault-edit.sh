#!/bin/bash
#
# Ansible Vault Edit Script
# Öffnet vault.yml zum Bearbeiten
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VAULT_FILE="$PROJECT_ROOT/group_vars/vault.yml"
VAULT_PASS_FILE="$PROJECT_ROOT/.vault_pass"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Öffne vault.yml zum Bearbeiten...${NC}"

# Prüfe ob vault-pass existiert
if [ ! -f "$VAULT_PASS_FILE" ]; then
    echo -e "${RED}✗ Vault-Passwort nicht gefunden: $VAULT_PASS_FILE${NC}"
    echo "Führe zuerst aus: ./scripts/vault-setup.sh"
    exit 1
fi

# Prüfe ob vault.yml existiert
if [ ! -f "$VAULT_FILE" ]; then
    echo -e "${RED}✗ vault.yml nicht gefunden: $VAULT_FILE${NC}"
    exit 1
fi

# Bearbeite Vault
ansible-vault edit "$VAULT_FILE" --vault-password-file="$VAULT_PASS_FILE"

echo -e "${GREEN}✓ Änderungen gespeichert${NC}"
