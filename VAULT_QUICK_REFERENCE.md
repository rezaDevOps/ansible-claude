# Ansible Vault - Quick Reference

## Schnellzugriff Befehle

### Setup (Einmalig)
```bash
./scripts/vault-setup.sh
```

### Tägliche Nutzung

| Aktion | Befehl |
|--------|--------|
| 📝 Bearbeiten | `./scripts/vault-edit.sh` |
| 👀 Anzeigen | `./scripts/vault-view.sh` |
| ℹ️ Status | `./scripts/vault-status.sh` |

### Playbooks ausführen

```bash
# Mit Vault
ansible-playbook playbooks/site.yml --vault-password-file=.vault_pass

# Nur prüfen (kein Deploy)
ansible-playbook playbooks/site.yml --vault-password-file=.vault_pass --check
```

## Wichtige Regeln

### ✅ In Ansible Vault
- Datenbank-Passwörter
- Application Secret Keys
- API Keys (externe Services)
- Service Credentials (Redis, SMTP, etc.)

### ✅ In GitHub Secrets
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `SSH_PRIVATE_KEY`
- `ANSIBLE_VAULT_PASSWORD`

### ❌ NIE committen
- `.vault_pass`
- `vault_pass.txt`
- Unverschlüsselte vault.yml

## Status-Check

```bash
# Schneller Check
head -n 1 group_vars/vault.yml
# Sollte starten mit: $ANSIBLE_VAULT;1.1;AES256

# Vollständiger Check
./scripts/vault-status.sh
```

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| "Decryption failed" | `./scripts/vault-setup.sh` |
| vault.yml nicht verschlüsselt | `./scripts/vault-setup.sh` |
| GitHub Actions schlagen fehl | Prüfe `ANSIBLE_VAULT_PASSWORD` Secret |
| .vault_pass committed | `git rm --cached .vault_pass` |

## GitHub Secrets Setup

1. Gehe zu: **Settings** > **Secrets and variables** > **Actions**
2. Klick: **New repository secret**
3. Füge hinzu:

```
Name:  ANSIBLE_VAULT_PASSWORD
Value: [Inhalt von .vault_pass Datei]
```

## Manuelle Befehle (ohne Scripts)

```bash
# Bearbeiten
ansible-vault edit group_vars/vault.yml

# Anzeigen
ansible-vault view group_vars/vault.yml

# Verschlüsseln
ansible-vault encrypt group_vars/vault.yml

# Mit Passwort-Datei
ansible-vault edit group_vars/vault.yml --vault-password-file=.vault_pass
```

## Workflow

```
1. Setup      → ./scripts/vault-setup.sh
2. Bearbeiten → ./scripts/vault-edit.sh
3. Status     → ./scripts/vault-status.sh
4. Commit     → git add group_vars/vault.yml
5. Push       → git push
```

## Hilfe

Ausführliche Anleitung: [VAULT_GUIDE.md](VAULT_GUIDE.md)
