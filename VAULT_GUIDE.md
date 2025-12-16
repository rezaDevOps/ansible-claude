# Ansible Vault Guide

Umfassende Anleitung zur Verwendung von Ansible Vault in diesem Projekt.

## Inhaltsverzeichnis

- [Übersicht](#übersicht)
- [Best Practices: Ansible Vault vs GitHub Secrets](#best-practices-ansible-vault-vs-github-secrets)
- [Schnellstart](#schnellstart)
- [Verwaltungs-Scripts](#verwaltungs-scripts)
- [Manuelle Verwaltung](#manuelle-verwaltung)
- [Integration mit GitHub Actions](#integration-mit-github-actions)
- [Secrets Struktur](#secrets-struktur)
- [Troubleshooting](#troubleshooting)
- [Sicherheitshinweise](#sicherheitshinweise)

## Übersicht

Ansible Vault ermöglicht die sichere Verwaltung sensibler Daten wie Passwörter, API-Keys und Zertifikate direkt im Git-Repository - verschlüsselt und versioniert.

### Warum Ansible Vault UND GitHub Secrets?

**Kurze Antwort:** Nutze beide zusammen für optimale Sicherheit und Flexibilität!

**Lange Antwort:**

| Kriterium | Ansible Vault | GitHub Secrets |
|-----------|---------------|----------------|
| **Zweck** | Applikations-Secrets | Infrastructure-Secrets |
| **Versionierung** | ✅ Mit Git versioniert | ❌ Außerhalb Git |
| **Portabilität** | ✅ Funktioniert überall | ❌ Nur in GitHub Actions |
| **Team-Sharing** | ✅ Ein Passwort für alle | ❌ UI-basierte Verwaltung |
| **Änderungs-Tracking** | ✅ Git-History | ❌ Keine History |
| **CI/CD Unabhängig** | ✅ Ja | ❌ GitHub-spezifisch |

## Best Practices: Ansible Vault vs GitHub Secrets

### ✅ In Ansible Vault speichern:

```yaml
# group_vars/vault.yml (verschlüsselt)

# Applikations-Secrets
vault_db_password: "secret123"
vault_app_secret_key: "flask-secret-key"
vault_api_key: "external-api-key"
vault_jwt_secret: "jwt-signing-key"

# Service Credentials
vault_redis_password: "redis-pass"
vault_smtp_password: "email-pass"
```

**Warum?**
- Gehören zur Applikation
- Team muss sie teilen können
- Sollen versioniert werden
- Funktionieren auch lokal

### ✅ In GitHub Secrets speichern:

```yaml
# GitHub Repository Settings > Secrets

AWS_ACCESS_KEY_ID          # Infrastructure
AWS_SECRET_ACCESS_KEY      # Infrastructure
SSH_PRIVATE_KEY            # Infrastructure
ANSIBLE_VAULT_PASSWORD     # Vault-Passwort selbst!
AWS_REGION                 # Infrastructure
```

**Warum?**
- Infrastructure-spezifisch
- Nicht für lokale Entwicklung benötigt
- Häufige Rotation erforderlich
- Rollenbasierter Zugriff via GitHub

### ❌ NIE committen (auch nicht verschlüsselt):

- AWS Credentials (gehören in GitHub Secrets)
- SSH Private Keys (gehören in GitHub Secrets)
- Das Vault-Passwort selbst

## Schnellstart

### 1. Initial Setup

```bash
# Führe das Setup-Script aus
./scripts/vault-setup.sh
```

Das Script:
- Erstellt ein Vault-Passwort (`.vault_pass`)
- Verschlüsselt `group_vars/vault.yml`
- Zeigt Anweisungen für GitHub Secrets

### 2. Secrets hinzufügen

```bash
# Öffne vault.yml zum Bearbeiten
./scripts/vault-edit.sh
```

Ersetze alle `CHANGE_ME_` Werte mit deinen echten Secrets.

### 3. Status prüfen

```bash
# Zeige Vault-Status
./scripts/vault-status.sh
```

### 4. Committen

```bash
# Prüfe dass vault.yml verschlüsselt ist
head -n 1 group_vars/vault.yml
# Sollte mit $ANSIBLE_VAULT beginnen

# Committe die verschlüsselte Datei
git add group_vars/vault.yml
git commit -m "Add encrypted vault file"
git push
```

## Verwaltungs-Scripts

### vault-setup.sh

**Zweck:** Initial Setup und Verschlüsselung

```bash
./scripts/vault-setup.sh
```

**Was es tut:**
1. Erstellt `.vault_pass` mit deinem Passwort
2. Verschlüsselt `group_vars/vault.yml`
3. Zeigt GitHub Secrets Anweisungen
4. Zeigt nützliche Befehle

### vault-edit.sh

**Zweck:** Vault-Datei bearbeiten

```bash
./scripts/vault-edit.sh
```

**Was es tut:**
1. Entschlüsselt temporär die Datei
2. Öffnet sie in deinem $EDITOR
3. Verschlüsselt sie wieder beim Speichern

### vault-view.sh

**Zweck:** Vault-Inhalt anzeigen (read-only)

```bash
./scripts/vault-view.sh
```

**Was es tut:**
- Zeigt den entschlüsselten Inhalt
- Keine Bearbeitung möglich
- Sicher für schnelle Überprüfung

### vault-status.sh

**Zweck:** Status-Überprüfung

```bash
./scripts/vault-status.sh
```

**Zeigt:**
- Vault-Verschlüsselungsstatus
- Vault-Passwort-Datei Status
- .gitignore Konfiguration
- Ansible Installation
- Zusammenfassung und nächste Schritte

## Manuelle Verwaltung

Falls du die Scripts nicht nutzen möchtest:

### Verschlüsseln

```bash
ansible-vault encrypt group_vars/vault.yml
# Passwort eingeben wenn gefragt
```

### Bearbeiten

```bash
ansible-vault edit group_vars/vault.yml
```

### Anzeigen

```bash
ansible-vault view group_vars/vault.yml
```

### Entschlüsseln (nicht empfohlen!)

```bash
ansible-vault decrypt group_vars/vault.yml
# WARNUNG: Datei ist dann unverschlüsselt!
```

### Mit Passwort-Datei

```bash
# Erstelle Passwort-Datei
echo "mein-sicheres-passwort" > .vault_pass
chmod 600 .vault_pass

# Nutze mit --vault-password-file
ansible-vault view group_vars/vault.yml --vault-password-file=.vault_pass
ansible-playbook playbooks/site.yml --vault-password-file=.vault_pass
```

## Integration mit GitHub Actions

### Setup in GitHub

1. **Gehe zu:** Repository Settings > Secrets and variables > Actions

2. **Füge hinzu:**

   ```
   Name: ANSIBLE_VAULT_PASSWORD
   Value: [Inhalt von .vault_pass]
   ```

3. **Weitere Secrets:**
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION`
   - `SSH_PRIVATE_KEY`

### Wie GitHub Actions Vault nutzt

Die Workflows in [.github/workflows/](.github/workflows/) nutzen Vault automatisch:

```yaml
# 1. Vault-Passwort aus GitHub Secret laden
- name: Setup Ansible Vault password
  run: |
    echo "${{ secrets.ANSIBLE_VAULT_PASSWORD }}" > .vault_pass
    chmod 600 .vault_pass

# 2. Überprüfen dass vault.yml verschlüsselt ist
- name: Verify vault file is encrypted
  run: |
    if ! head -n 1 group_vars/vault.yml | grep -q "\$ANSIBLE_VAULT"; then
      echo "ERROR: vault.yml is not encrypted!"
      exit 1
    fi

# 3. Playbook mit Vault ausführen
- name: Deploy application
  run: |
    ansible-playbook playbooks/site.yml \
      --vault-password-file .vault_pass

# 4. Aufräumen
- name: Cleanup
  if: always()
  run: rm -f .vault_pass
```

### Test-Workflow

Der [test.yml](.github/workflows/test.yml) Workflow prüft automatisch:

- ✅ Ist `vault.yml` verschlüsselt?
- ✅ Wurde `.vault_pass` **nicht** committed?
- ✅ Sind sensible Daten im Klartext vorhanden?

## Secrets Struktur

### Beispiel: group_vars/vault.yml

```yaml
---
# Database Credentials
vault_db_host: "localhost"
vault_db_port: 5432
vault_db_name: "myapp_production"
vault_db_user: "myapp_user"
vault_db_password: "super-secret-password"

# Application Secret Key
vault_app_secret_key: "flask-session-secret-key-min-32-chars"

# External API Keys
vault_external_api_key: "external-service-api-key"
vault_payment_api_key: "stripe-or-paypal-key"
vault_email_api_key: "sendgrid-or-ses-key"

# JWT Configuration
vault_jwt_secret: "jwt-signing-secret"

# Encryption Keys
vault_data_encryption_key: "aes-256-encryption-key"

# Service Credentials
vault_redis_password: "redis-password"
vault_rabbitmq_password: "rabbitmq-password"
```

### Verwendung in Playbooks/Roles

```yaml
# roles/app/tasks/main.yml

- name: Create application config
  template:
    src: app_config.j2
    dest: "{{ app_root }}/config.py"
  vars:
    db_password: "{{ vault_db_password }}"
    secret_key: "{{ vault_app_secret_key }}"
```

### Verwendung in Templates

```jinja2
{# roles/app/templates/app_config.j2 #}

DATABASE_URI = 'postgresql://{{ vault_db_user }}:{{ vault_db_password }}@{{ vault_db_host }}/{{ vault_db_name }}'
SECRET_KEY = '{{ vault_app_secret_key }}'
API_KEY = '{{ vault_external_api_key }}'
```

## Troubleshooting

### Problem: "Decryption failed"

```
ERROR! Decryption failed (no vault secrets were found that could decrypt)
```

**Lösung:**
```bash
# Prüfe dass das richtige Passwort verwendet wird
cat .vault_pass

# Oder setze neu auf
./scripts/vault-setup.sh
```

### Problem: vault.yml ist nicht verschlüsselt

```bash
# Prüfen
head -n 1 group_vars/vault.yml
# Sollte beginnen mit: $ANSIBLE_VAULT;1.1;AES256

# Falls nicht:
./scripts/vault-setup.sh
```

### Problem: Kann vault.yml nicht bearbeiten

```
ERROR! vault.yml is not a vault encrypted file
```

**Lösung:**
```bash
# Falls Datei nicht verschlüsselt ist
ansible-vault encrypt group_vars/vault.yml

# Falls verschlüsselt aber Passwort falsch
./scripts/vault-setup.sh
```

### Problem: GitHub Actions schlagen fehl

```
ERROR: vault.yml is not encrypted!
```

**Lösung:**
1. Verschlüssele lokal: `./scripts/vault-setup.sh`
2. Committe: `git add group_vars/vault.yml && git commit -m "Encrypt vault" && git push`
3. Überprüfe GitHub Secret `ANSIBLE_VAULT_PASSWORD` ist gesetzt

### Problem: .vault_pass wurde committed

```bash
# Aus Git entfernen (behält lokale Datei)
git rm --cached .vault_pass

# Committe
git commit -m "Remove vault password from git"
git push

# Rotiere das Passwort!
# 1. Neues Passwort setzen
./scripts/vault-setup.sh

# 2. GitHub Secret aktualisieren
# 3. Team informieren
```

## Sicherheitshinweise

### ✅ DO:

1. **Verschlüssele vault.yml immer**
   ```bash
   ./scripts/vault-setup.sh
   ```

2. **Nutze starke Passwörter**
   - Mindestens 16 Zeichen
   - Mischung aus Groß-/Kleinbuchstaben, Zahlen, Sonderzeichen
   - Nutze einen Passwort-Manager

3. **Teile Vault-Passwort sicher**
   - Nutze sichere Kanäle (1Password, LastPass, etc.)
   - NIE per E-Mail oder Slack
   - Dokumentiere wer Zugriff hat

4. **Rotiere Secrets regelmäßig**
   ```bash
   # 1. Ändere Secrets
   ./scripts/vault-edit.sh

   # 2. Committe
   git add group_vars/vault.yml
   git commit -m "Rotate secrets"
   git push
   ```

5. **Prüfe Status regelmäßig**
   ```bash
   ./scripts/vault-status.sh
   ```

6. **Separate Vault-Dateien für Environments**
   ```
   group_vars/
     production/vault.yml
     staging/vault.yml
     development/vault.yml
   ```

### ❌ DON'T:

1. **NIE .vault_pass committen**
   - Ist in `.gitignore`
   - Prüfe mit: `git status`

2. **NIE vault.yml unverschlüsselt committen**
   - Test in CI/CD prüft automatisch
   - Prüfe mit: `./scripts/vault-status.sh`

3. **NIE AWS/SSH Keys in Vault**
   - Gehören in GitHub Secrets
   - Infrastructure ≠ Application

4. **NIE Vault-Passwort in Code**
   ```python
   # ❌ FALSCH
   vault_password = "my-password"

   # ✅ RICHTIG
   # In GitHub Secret: ANSIBLE_VAULT_PASSWORD
   ```

5. **NIE sensible Daten in Logs**
   ```yaml
   - name: Show secret
     debug:
       var: vault_db_password  # ❌ FALSCH

   - name: Show secret
     debug:
       msg: "Password is set"  # ✅ RICHTIG
     no_log: true              # ✅ RICHTIG
   ```

## Erweiterte Nutzung

### Multiple Vault-Dateien

```bash
# Verschiedene Dateien für verschiedene Zwecke
group_vars/
  vault.yml           # Hauptvault
  vault_aws.yml       # AWS-spezifisch
  vault_db.yml        # Datenbank-spezifisch

# Nutzen mit
ansible-playbook playbooks/site.yml \
  --vault-password-file .vault_pass
```

### Vault-IDs (verschiedene Passwörter)

```bash
# Verschiedene Passwörter für verschiedene Zwecke
echo "prod-password" > .vault_pass_prod
echo "dev-password" > .vault_pass_dev

# Verschlüsseln mit ID
ansible-vault encrypt group_vars/production/vault.yml \
  --vault-id prod@.vault_pass_prod

ansible-vault encrypt group_vars/development/vault.yml \
  --vault-id dev@.vault_pass_dev

# Nutzen
ansible-playbook playbooks/site.yml \
  --vault-id prod@.vault_pass_prod \
  --vault-id dev@.vault_pass_dev
```

### Vault-Variablen inline

```yaml
# Einzelne Variable verschlüsseln
vault_db_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  66386439653234336462626566653863...
```

## Zusammenfassung

### Workflow

```bash
# 1. Initial Setup
./scripts/vault-setup.sh

# 2. Secrets bearbeiten
./scripts/vault-edit.sh

# 3. Status prüfen
./scripts/vault-status.sh

# 4. Committen
git add group_vars/vault.yml
git commit -m "Update secrets"

# 5. GitHub Secrets setzen
# ANSIBLE_VAULT_PASSWORD = [Inhalt von .vault_pass]

# 6. Lokal testen
ansible-playbook playbooks/site.yml \
  --vault-password-file .vault_pass \
  --check

# 7. Pushen
git push
```

### Best Practice Checklist

- [ ] vault.yml ist verschlüsselt
- [ ] .vault_pass ist in .gitignore
- [ ] .vault_pass hat Berechtigung 600
- [ ] GitHub Secret ANSIBLE_VAULT_PASSWORD ist gesetzt
- [ ] Alle CHANGE_ME Werte wurden ersetzt
- [ ] Team kennt das Vault-Passwort
- [ ] Vault-Passwort ist stark (16+ Zeichen)
- [ ] Infrastructure-Secrets sind in GitHub Secrets
- [ ] Application-Secrets sind in Ansible Vault
- [ ] CI/CD Tests laufen durch

## Weitere Ressourcen

- [Ansible Vault Dokumentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [GitHub Actions Setup Guide](GITHUB_ACTIONS_SETUP.md)
- [Project README](README.md)

## Support

Bei Fragen oder Problemen:

1. Prüfe Status: `./scripts/vault-status.sh`
2. Lies Troubleshooting-Sektion
3. Prüfe GitHub Actions Logs
4. Kontaktiere Team-Admin
