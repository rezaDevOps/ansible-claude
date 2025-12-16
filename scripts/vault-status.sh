#!/bin/bash
#
# Ansible Vault Status Script
# Zeigt den Status aller Vault-Dateien
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VAULT_FILE="$PROJECT_ROOT/group_vars/vault.yml"
VAULT_PASS_FILE="$PROJECT_ROOT/.vault_pass"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Ansible Vault Status${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Prüfe vault.yml
echo -e "${YELLOW}vault.yml Status:${NC}"
if [ ! -f "$VAULT_FILE" ]; then
    echo -e "${RED}  ✗ Datei nicht gefunden${NC}"
elif head -n 1 "$VAULT_FILE" | grep -q "\$ANSIBLE_VAULT"; then
    echo -e "${GREEN}  ✓ Verschlüsselt${NC}"

    # Zeige Verschlüsselungs-Version
    version=$(head -n 1 "$VAULT_FILE" | cut -d';' -f2)
    echo -e "    Version: $version"
else
    echo -e "${RED}  ✗ NICHT verschlüsselt!${NC}"
    echo -e "${YELLOW}    Führe aus: ./scripts/vault-setup.sh${NC}"
fi
echo ""

# Prüfe Vault-Passwort-Datei
echo -e "${YELLOW}Vault-Passwort (.vault_pass):${NC}"
if [ ! -f "$VAULT_PASS_FILE" ]; then
    echo -e "${RED}  ✗ Nicht gefunden${NC}"
    echo -e "${YELLOW}    Führe aus: ./scripts/vault-setup.sh${NC}"
else
    echo -e "${GREEN}  ✓ Vorhanden${NC}"

    # Prüfe Berechtigungen
    perms=$(stat -f "%OLp" "$VAULT_PASS_FILE" 2>/dev/null || stat -c "%a" "$VAULT_PASS_FILE" 2>/dev/null)
    if [ "$perms" = "600" ]; then
        echo -e "${GREEN}    Berechtigungen: $perms (korrekt)${NC}"
    else
        echo -e "${YELLOW}    Berechtigungen: $perms (sollte 600 sein)${NC}"
        echo -e "${YELLOW}    Fixe mit: chmod 600 $VAULT_PASS_FILE${NC}"
    fi
fi
echo ""

# Prüfe .gitignore
echo -e "${YELLOW}.gitignore Einträge:${NC}"
if [ -f "$PROJECT_ROOT/.gitignore" ]; then
    if grep -q ".vault_pass" "$PROJECT_ROOT/.gitignore"; then
        echo -e "${GREEN}  ✓ .vault_pass ist in .gitignore${NC}"
    else
        echo -e "${RED}  ✗ .vault_pass fehlt in .gitignore!${NC}"
    fi

    if grep -q "vault_pass.txt" "$PROJECT_ROOT/.gitignore"; then
        echo -e "${GREEN}  ✓ vault_pass.txt ist in .gitignore${NC}"
    else
        echo -e "${YELLOW}  ⚠ vault_pass.txt fehlt in .gitignore${NC}"
    fi
else
    echo -e "${RED}  ✗ .gitignore nicht gefunden${NC}"
fi
echo ""

# Prüfe ob ansible-vault verfügbar ist
echo -e "${YELLOW}Ansible Installation:${NC}"
if command -v ansible-vault &> /dev/null; then
    version=$(ansible-vault --version | head -n 1)
    echo -e "${GREEN}  ✓ $version${NC}"
else
    echo -e "${RED}  ✗ ansible-vault nicht gefunden${NC}"
    echo -e "${YELLOW}    Installiere mit: pip install ansible${NC}"
fi
echo ""

# Zusammenfassung
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Zusammenfassung:${NC}"
echo ""

vault_encrypted=false
vault_pass_exists=false

if [ -f "$VAULT_FILE" ] && head -n 1 "$VAULT_FILE" | grep -q "\$ANSIBLE_VAULT"; then
    vault_encrypted=true
fi

if [ -f "$VAULT_PASS_FILE" ]; then
    vault_pass_exists=true
fi

if $vault_encrypted && $vault_pass_exists; then
    echo -e "${GREEN}✓ Alles bereit! Vault ist korrekt konfiguriert.${NC}"
    echo ""
    echo "Nützliche Befehle:"
    echo "  Bearbeiten: ./scripts/vault-edit.sh"
    echo "  Anzeigen:   ./scripts/vault-view.sh"
elif ! $vault_encrypted; then
    echo -e "${YELLOW}⚠ vault.yml ist nicht verschlüsselt${NC}"
    echo ""
    echo "Nächster Schritt:"
    echo "  ./scripts/vault-setup.sh"
elif ! $vault_pass_exists; then
    echo -e "${YELLOW}⚠ Vault-Passwort-Datei fehlt${NC}"
    echo ""
    echo "Nächster Schritt:"
    echo "  ./scripts/vault-setup.sh"
fi
echo ""
