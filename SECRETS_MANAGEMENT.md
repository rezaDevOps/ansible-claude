# Secrets Management Strategie

## Übersicht

Dieses Projekt nutzt eine **Hybrid-Strategie** zur Secrets-Verwaltung:
- **Ansible Vault** für Applikations-Secrets
- **GitHub Secrets** für Infrastructure-Secrets

## Warum diese Strategie?

### Problem
Wohin mit sensiblen Daten wie Passwörtern, API-Keys und Credentials?

### Lösung
Nutze **beide** Systeme für ihre jeweiligen Stärken!

## Entscheidungsmatrix

```
┌─────────────────────────────────────────────────────────────────┐
│                    Welches System?                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Frage: "Brauche ich das Secret für lokale Entwicklung?"       │
│                                                                 │
│     ┌─────────────────┐              ┌─────────────────┐       │
│     │       JA        │              │      NEIN       │       │
│     └────────┬────────┘              └────────┬────────┘       │
│              │                                │                │
│              ▼                                ▼                │
│     ┌─────────────────┐              ┌─────────────────┐       │
│     │ ANSIBLE VAULT   │              │ GITHUB SECRETS  │       │
│     │                 │              │                 │       │
│     │ • DB Password   │              │ • AWS Keys      │       │
│     │ • API Keys      │              │ • SSH Keys      │       │
│     │ • App Secrets   │              │ • Vault Pass    │       │
│     └─────────────────┘              └─────────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Detaillierte Zuordnung

### ✅ Ansible Vault (group_vars/vault.yml)

**Regel:** Secrets die zur **Applikation** gehören

| Secret Type | Beispiel | Warum Vault? |
|------------|----------|--------------|
| Database | `vault_db_password` | App braucht es |
| App Secret Key | `vault_app_secret_key` | Flask Session |
| API Keys | `vault_payment_api_key` | Externe Services |
| JWT Secret | `vault_jwt_secret` | Token Signing |
| Redis/Cache | `vault_redis_password` | App Service |
| SMTP | `vault_smtp_password` | Email versenden |

**Vorteile:**
- ✅ Team teilt ein Vault-Passwort
- ✅ Versioniert in Git (verschlüsselt)
- ✅ Funktioniert lokal UND in CI/CD
- ✅ Unabhängig von CI/CD System

### ✅ GitHub Secrets

**Regel:** Secrets die zur **Infrastructure** gehören

| Secret Name | Zweck | Warum GitHub? |
|-------------|-------|---------------|
| `AWS_ACCESS_KEY_ID` | AWS Zugriff | Infrastructure |
| `AWS_SECRET_ACCESS_KEY` | AWS Zugriff | Infrastructure |
| `SSH_PRIVATE_KEY` | Server SSH | Infrastructure |
| `ANSIBLE_VAULT_PASSWORD` | Vault öffnen | Meta-Secret |
| `AWS_REGION` | Deployment Region | Infrastructure |

**Vorteile:**
- ✅ Rollenbasierter Zugriff
- ✅ Keine Git-Commits bei Änderungen
- ✅ UI-basierte Verwaltung
- ✅ Audit-Log

### ❌ NIEMALS committen (auch nicht verschlüsselt)

- AWS Access Keys → GitHub Secrets
- SSH Private Keys → GitHub Secrets
- `.vault_pass` → Lokal only, in .gitignore

## Workflow

### Setup (Einmalig)

```bash
# 1. Ansible Vault Setup
./scripts/vault-setup.sh
# → Erstellt .vault_pass
# → Verschlüsselt vault.yml
# → Zeigt Vault-Passwort an

# 2. GitHub Secrets konfigurieren
# Repository > Settings > Secrets > Actions
#
# Füge hinzu:
# - ANSIBLE_VAULT_PASSWORD: [Inhalt von .vault_pass]
# - AWS_ACCESS_KEY_ID: [Dein AWS Key]
# - AWS_SECRET_ACCESS_KEY: [Dein AWS Secret]
# - SSH_PRIVATE_KEY: [Inhalt von ~/.ssh/ansible-ec2-key]
# - AWS_REGION: us-west-2
```

### Tägliche Nutzung

```bash
# App-Secrets bearbeiten
./scripts/vault-edit.sh

# Status prüfen
./scripts/vault-status.sh

# Lokal deployen
ansible-playbook playbooks/site.yml \
  --vault-password-file=.vault_pass

# Committen
git add group_vars/vault.yml
git commit -m "Update app secrets"
git push
```

### In GitHub Actions

GitHub Actions nutzt **automatisch beide Systeme**:

```yaml
# 1. Lädt Vault-Passwort aus GitHub Secret
- name: Setup Vault
  run: echo "${{ secrets.ANSIBLE_VAULT_PASSWORD }}" > .vault_pass

# 2. Lädt AWS Credentials aus GitHub Secrets
- name: Configure AWS
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

# 3. Nutzt Vault-verschlüsselte App-Secrets
- name: Deploy
  run: |
    ansible-playbook playbooks/site.yml \
      --vault-password-file=.vault_pass
    # Vault-Datei wird entschlüsselt
    # App-Secrets werden geladen
```

## Sicherheits-Checkliste

### Vor dem ersten Commit

- [ ] vault.yml ist verschlüsselt
  ```bash
  head -n 1 group_vars/vault.yml
  # Muss starten mit: $ANSIBLE_VAULT;1.1;AES256
  ```

- [ ] .vault_pass ist in .gitignore
  ```bash
  cat .gitignore | grep vault_pass
  # Sollte enthalten: .vault_pass
  ```

- [ ] .vault_pass hat richtige Permissions
  ```bash
  ls -la .vault_pass
  # Sollte sein: -rw------- (600)
  ```

- [ ] Keine AWS Keys in Files
  ```bash
  grep -r "AKIA" . --include="*.yml"
  # Sollte nichts finden
  ```

### GitHub Setup

- [ ] `ANSIBLE_VAULT_PASSWORD` in GitHub Secrets
- [ ] `AWS_ACCESS_KEY_ID` in GitHub Secrets
- [ ] `AWS_SECRET_ACCESS_KEY` in GitHub Secrets
- [ ] `SSH_PRIVATE_KEY` in GitHub Secrets
- [ ] `AWS_REGION` in GitHub Secrets
- [ ] Production Environment mit Approvals konfiguriert

### Nach jedem Secret-Change

- [ ] Vault-Status prüfen: `./scripts/vault-status.sh`
- [ ] Lokal testen vor dem Push
- [ ] Team über Änderungen informieren
- [ ] Dokumentieren was sich geändert hat

## Backup & Wiederherstellung

### Vault-Passwort sichern

```bash
# Backup (sicher aufbewahren!)
cat .vault_pass > vault_password_backup.txt

# An sicherem Ort speichern:
# - Passwort-Manager (1Password, LastPass)
# - Verschlüsselter USB-Stick
# - Team-Tresor

# ⚠️ NIEMALS in Git committen!
```

### Secrets wiederherstellen

```bash
# Falls .vault_pass verloren:
# 1. Hole Passwort aus Backup
echo "recovered-password" > .vault_pass
chmod 600 .vault_pass

# 2. Teste
./scripts/vault-view.sh

# 3. Falls Passwort wirklich verloren:
# → Alle Secrets müssen neu gesetzt werden
# → vault.yml kann nicht entschlüsselt werden
# → Das ist der Grund für sichere Backups!
```

## Rotation von Secrets

### App-Secrets rotieren (Ansible Vault)

```bash
# 1. Bearbeite Secrets
./scripts/vault-edit.sh

# 2. Ändere die Werte
# vault_db_password: "NEW_PASSWORD"

# 3. Speichern & Committen
git add group_vars/vault.yml
git commit -m "Rotate database password"
git push

# 4. Re-deployen
ansible-playbook playbooks/site.yml \
  --vault-password-file=.vault_pass
```

### Infrastructure-Secrets rotieren (GitHub)

```bash
# 1. Neue AWS Keys generieren in AWS Console

# 2. In GitHub aktualisieren:
# Settings > Secrets > AWS_ACCESS_KEY_ID > Update

# 3. Alte Keys in AWS deaktivieren

# 4. Testen durch Deployment
```

### Vault-Passwort rotieren

```bash
# 1. Entschlüssele mit altem Passwort
ansible-vault decrypt group_vars/vault.yml \
  --vault-password-file=.vault_pass

# 2. Erstelle neues Passwort
echo "NEW_PASSWORD" > .vault_pass
chmod 600 .vault_pass

# 3. Verschlüssele mit neuem Passwort
ansible-vault encrypt group_vars/vault.yml \
  --vault-password-file=.vault_pass

# 4. Update GitHub Secret
# ANSIBLE_VAULT_PASSWORD = NEW_PASSWORD

# 5. Team informieren!
```

## Troubleshooting

### "Decryption failed"

```bash
# Prüfe Passwort
cat .vault_pass

# Falls falsch, aus Backup wiederherstellen
# Oder aus GitHub Secret holen (falls gesetzt)
```

### vault.yml ist unverschlüsselt committed

```bash
# ⚠️ WICHTIG: Sofort handeln!

# 1. Alle Secrets als kompromittiert betrachten
# 2. Rotiere ALLE Secrets in vault.yml
./scripts/vault-edit.sh

# 3. Verschlüssele
./scripts/vault-setup.sh

# 4. Committe verschlüsselte Version
git add group_vars/vault.yml
git commit -m "Encrypt vault (security incident)"
git push

# 5. History cleanen (wenn möglich)
# git filter-branch oder BFG Repo-Cleaner

# 6. Team informieren
# 7. Post-Mortem durchführen
```

### GitHub Actions Fehler

```bash
# Fehler: "vault.yml is not encrypted"
# → Lösung: ./scripts/vault-setup.sh && git push

# Fehler: "Decryption failed"
# → Lösung: GitHub Secret ANSIBLE_VAULT_PASSWORD prüfen

# Fehler: AWS authentication failed
# → Lösung: GitHub Secrets AWS_* prüfen
```

## Best Practices

### ✅ DO

1. **Nutze beide Systeme für ihre Stärken**
2. **Dokumentiere welches Secret wo ist**
3. **Rotiere Secrets regelmäßig** (90 Tage)
4. **Teste Wiederherstellung** (Disaster Recovery)
5. **Schulen neuer Team-Mitglieder**
6. **Audit-Log führen** (wer hat wann was geändert)

### ❌ DON'T

1. **NIE unverschlüsselte Secrets committen**
2. **NIE .vault_pass committen**
3. **NIE Passwörter per E-Mail/Slack teilen**
4. **NIE Production-Secrets für Development nutzen**
5. **NIE Secrets in Logs ausgeben**

## Weiterführende Dokumentation

- [Vault Guide](VAULT_GUIDE.md) - Detaillierte Vault-Anleitung
- [Vault Quick Reference](VAULT_QUICK_REFERENCE.md) - Schnellreferenz
- [GitHub Actions Setup](GITHUB_ACTIONS_SETUP.md) - CI/CD Integration
- [README](README.md) - Projekt-Übersicht

## Zusammenfassung

```
┌────────────────────────────────────────────────────────────┐
│                  Secrets Management                        │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Ansible Vault          →  App-Secrets                    │
│  • Versioniert                                            │
│  • Team-shared                                            │
│  • Lokal nutzbar                                          │
│                                                            │
│  GitHub Secrets         →  Infrastructure-Secrets         │
│  • Nicht versioniert                                      │
│  • UI-managed                                             │
│  • CI/CD only                                             │
│                                                            │
│  Beide zusammen         →  Beste Sicherheit               │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**Golden Rule:** Wenn du dir nicht sicher bist → Frag das Team! 🛡️
