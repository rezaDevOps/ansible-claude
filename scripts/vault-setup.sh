#!/bin/bash
#
# Ansible Vault Setup Script
# Hilft beim initialen Setup und Verschlüsselung der vault.yml
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VAULT_FILE="$PROJECT_ROOT/group_vars/vault.yml"
VAULT_PASS_FILE="$PROJECT_ROOT/.vault_pass"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Ansible Vault Setup${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Funktion: Prüfe ob vault.yml verschlüsselt ist
check_vault_encrypted() {
    if head -n 1 "$VAULT_FILE" | grep -q "\$ANSIBLE_VAULT"; then
        return 0  # Verschlüsselt
    else
        return 1  # Nicht verschlüsselt
    fi
}

# Funktion: Erstelle Vault-Passwort-Datei
setup_vault_password() {
    echo -e "${YELLOW}Schritt 1: Vault-Passwort einrichten${NC}"

    if [ -f "$VAULT_PASS_FILE" ]; then
        echo -e "${GREEN}✓ Vault-Passwort-Datei existiert bereits${NC}"
        read -p "Möchtest du ein neues Passwort setzen? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    echo ""
    echo "Bitte gib ein sicheres Passwort für Ansible Vault ein:"
    read -s -p "Passwort: " password1
    echo ""
    read -s -p "Passwort wiederholen: " password2
    echo ""

    if [ "$password1" != "$password2" ]; then
        echo -e "${RED}✗ Passwörter stimmen nicht überein!${NC}"
        exit 1
    fi

    if [ ${#password1} -lt 8 ]; then
        echo -e "${RED}✗ Passwort muss mindestens 8 Zeichen lang sein!${NC}"
        exit 1
    fi

    echo "$password1" > "$VAULT_PASS_FILE"
    chmod 600 "$VAULT_PASS_FILE"

    echo -e "${GREEN}✓ Vault-Passwort gespeichert in: $VAULT_PASS_FILE${NC}"
    echo -e "${YELLOW}  WICHTIG: Diese Datei ist in .gitignore und wird NICHT committed!${NC}"
    echo ""
}

# Funktion: Verschlüssele vault.yml
encrypt_vault() {
    echo -e "${YELLOW}Schritt 2: vault.yml verschlüsseln${NC}"

    if check_vault_encrypted; then
        echo -e "${GREEN}✓ vault.yml ist bereits verschlüsselt${NC}"
        return
    fi

    echo "Verschlüssele vault.yml..."
    ansible-vault encrypt "$VAULT_FILE" --vault-password-file="$VAULT_PASS_FILE"

    echo -e "${GREEN}✓ vault.yml erfolgreich verschlüsselt!${NC}"
    echo ""
}

# Funktion: GitHub Secret Information
show_github_instructions() {
    echo -e "${YELLOW}Schritt 3: GitHub Secrets einrichten${NC}"
    echo ""
    echo "Gehe zu deinem GitHub Repository:"
    echo "  Settings > Secrets and variables > Actions > New repository secret"
    echo ""
    echo "Füge folgende Secrets hinzu:"
    echo ""
    echo -e "${BLUE}1. ANSIBLE_VAULT_PASSWORD${NC}"
    echo "   Wert: $(cat $VAULT_PASS_FILE)"
    echo ""
    echo -e "${BLUE}2. AWS_ACCESS_KEY_ID${NC}"
    echo "   Wert: Dein AWS Access Key"
    echo ""
    echo -e "${BLUE}3. AWS_SECRET_ACCESS_KEY${NC}"
    echo "   Wert: Dein AWS Secret Key"
    echo ""
    echo -e "${BLUE}4. AWS_REGION${NC}"
    echo "   Wert: z.B. us-west-2"
    echo ""
    echo -e "${BLUE}5. SSH_PRIVATE_KEY${NC}"
    echo "   Wert: Inhalt deiner SSH Private Key Datei"
    echo "   Datei: ~/.ssh/ansible-ec2-key"
    echo ""
}

# Funktion: Zeige nützliche Befehle
show_useful_commands() {
    echo -e "${YELLOW}Nützliche Vault-Befehle:${NC}"
    echo ""
    echo "Vault bearbeiten:"
    echo "  ./scripts/vault-edit.sh"
    echo "  # oder:"
    echo "  ansible-vault edit group_vars/vault.yml --vault-password-file=.vault_pass"
    echo ""
    echo "Vault anzeigen (entschlüsselt):"
    echo "  ./scripts/vault-view.sh"
    echo "  # oder:"
    echo "  ansible-vault view group_vars/vault.yml --vault-password-file=.vault_pass"
    echo ""
    echo "Playbook mit Vault ausführen:"
    echo "  ansible-playbook playbooks/site.yml --vault-password-file=.vault_pass"
    echo ""
    echo "Vault-Status prüfen:"
    echo "  ./scripts/vault-status.sh"
    echo ""
}

# Hauptprogramm
main() {
    # Prüfe ob ansible-vault verfügbar ist
    if ! command -v ansible-vault &> /dev/null; then
        echo -e "${RED}✗ ansible-vault nicht gefunden!${NC}"
        echo "Installiere Ansible mit: pip install ansible"
        exit 1
    fi

    # Prüfe ob vault.yml existiert
    if [ ! -f "$VAULT_FILE" ]; then
        echo -e "${RED}✗ vault.yml nicht gefunden: $VAULT_FILE${NC}"
        exit 1
    fi

    setup_vault_password
    encrypt_vault
    show_github_instructions
    show_useful_commands

    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}  Setup abgeschlossen!${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo -e "${YELLOW}Nächste Schritte:${NC}"
    echo "1. Füge deine Secrets in vault.yml ein:"
    echo "   ./scripts/vault-edit.sh"
    echo ""
    echo "2. Konfiguriere GitHub Secrets (siehe oben)"
    echo ""
    echo "3. Committe die verschlüsselte vault.yml:"
    echo "   git add group_vars/vault.yml"
    echo "   git commit -m 'Add encrypted vault file'"
    echo ""
}

main
