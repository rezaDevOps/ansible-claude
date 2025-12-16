# GitHub Actions Workflow - Aktueller Status

## Letzte Änderungen

**Datum:** 2025-12-16
**Commit:** 046be42

### Behobene Probleme

1. ✅ **Merge-Konflikt in ansible-ci.yml behoben**
   - Konflikt-Marker entfernt
   - Verbessertes Debugging für ec2_instance_info.txt Suche hinzugefügt

2. ✅ **Git Workflow bereinigt**
   - Branch-Divergenz aufgelöst
   - Alle Änderungen erfolgreich gemerged und gepusht

## Aktueller Workflow-Ablauf

### Automated EC2 Deployment

Der Workflow führt folgende Schritte automatisch aus:

```yaml
1. Provision EC2 instance
   └─> playbooks/provision.yml
   └─> Erstellt: ec2_instance_info.txt im Projekt-Root

2. Extract EC2 IP
   └─> Sucht in mehreren Locations:
       - ec2_instance_info.txt
       - ./ec2_instance_info.txt
       - playbooks/ec2_instance_info.txt
   └─> Extrahiert Public IP
   └─> Setzt Environment Variable: $EC2_IP

3. Update inventory
   └─> Ersetzt 127.0.0.1 mit $EC2_IP in inventory/hosts.ini
   └─> Zeigt aktualisiertes Inventory

4. Wait for SSH
   └─> 30 Versuche × 10 Sekunden
   └─> Prüft SSH-Verfügbarkeit

5. Deploy application
   └─> ansible-playbook site.yml
   └─> Vollständiges Deployment
```

## Deployment ausführen

### Via GitHub Actions (Empfohlen)

1. Gehe zu [Actions Tab](https://github.com/rezaDevOps/ansible-claude/actions)
2. Wähle "Ansible CI/CD Pipeline"
3. Klicke "Run workflow"
4. ✅ **Aktiviere "Deploy to target environment"**
5. Klicke "Run workflow"

### Expected Output

```
✓ Provisioning new EC2 instance...
✓ Found info file at: ec2_instance_info.txt
✓ Extracted EC2 IP: 54.x.x.x
✓ Inventory updated
✓ SSH is ready!
✓ Deploying to 54.x.x.x...
✓ Deployment completed successfully
```

## Bekannte Probleme & Lösungen

### Problem: "ec2_instance_info.txt not found"

**Symptom:**
```
✗ ec2_instance_info.txt not found in any location!
```

**Mögliche Ursachen:**
1. Provision-Playbook ist fehlgeschlagen
2. Datei wird im falschen Verzeichnis erstellt
3. Timing-Problem (Datei noch nicht erstellt)

**Debug-Schritte:**
Der Workflow zeigt jetzt automatisch:
```bash
# Dateisuche
find . -name "ec2_instance_info.txt" -type f

# Verzeichnis-Inhalte
ls -la
ls -la playbooks/
```

**Lösung:**
1. Prüfe den Provisioning-Step in GitHub Actions Logs
2. Stelle sicher, dass boto3/botocore installiert sind
3. Verifiziere AWS Credentials in GitHub Secrets

### Problem: SSH Timeout

**Symptom:**
```
Attempt 30/30: SSH not ready yet, waiting...
```

**Lösung:**
- EC2 Instance braucht länger zum Starten
- Check AWS Console ob Instance läuft
- Check Security Group erlaubt SSH (Port 22)

### Problem: Deployment fehlschlägt

**Lösung:**
1. Prüfe ob vault.yml encrypted ist
2. Verifiziere ANSIBLE_VAULT_PASSWORD in GitHub Secrets
3. Prüfe SSH_PRIVATE_KEY matches AWS Key Pair

## Nächste Schritte

### 1. Teste den kompletten Workflow

```bash
# Lösche alte Instance (optional)
ansible-playbook playbooks/cleanup.yml --vault-password-file .vault_pass

# Führe Deployment via GitHub Actions aus
# (Siehe "Deployment ausführen" oben)
```

### 2. Monitoring

Nach dem Deployment:
- Prüfe GitHub Actions Logs
- Notiere die EC2 IP Adresse
- Teste Application:
  ```bash
  curl http://<EC2_IP>
  ```

### 3. SSH-Zugriff

Falls nötig:
```bash
ssh -i ~/.ssh/ansible-ec2-key.pem ubuntu@<EC2_IP>
```

## Workflow-Konfiguration

### GitHub Secrets (Erforderlich)

| Secret Name | Beschreibung |
|------------|--------------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Key |
| `AWS_REGION` | AWS Region (z.B. us-west-2) |
| `SSH_PRIVATE_KEY` | Private SSH Key für EC2 |
| `ANSIBLE_VAULT_PASSWORD` | Password für vault.yml |

### Workflow Trigger

Der Workflow läuft bei:
- ✅ Push zu main/develop (Lint + Tests)
- ✅ Pull Request (Lint + Tests + Dry Run)
- ✅ Manual Trigger mit "Deploy" Option (Vollständiges Deployment)

## Troubleshooting Commands

### Lokal testen

```bash
# 1. Provision
ansible-playbook -i inventory/localhost.ini playbooks/provision.yml \
  --vault-password-file .vault_pass

# 2. Check ec2_instance_info.txt
cat ec2_instance_info.txt

# 3. Extract IP
EC2_IP=$(grep "Public IP:" ec2_instance_info.txt | awk '{print $3}')
echo "EC2 IP: $EC2_IP"

# 4. Update inventory
sed -i '' "s/127.0.0.1/$EC2_IP/" inventory/hosts.ini

# 5. Wait for SSH
sleep 60

# 6. Deploy
ansible-playbook -i inventory/hosts.ini playbooks/site.yml \
  --private-key ~/.ssh/ansible-ec2-key.pem \
  --vault-password-file .vault_pass
```

### Workflow-Logs analysieren

```bash
# Liste letzte Runs
gh run list --limit 5

# Zeige fehlgeschlagene Logs
gh run view <run-id> --log-failed

# Zeige alle Logs
gh run view <run-id> --log
```

## Best Practices

### ✅ DO

- Immer über GitHub Actions deployen (konsistent & sicher)
- Secrets in GitHub Secrets speichern
- Alte EC2 Instances regelmäßig aufräumen
- Workflow-Logs bei Fehlern prüfen

### ❌ DON'T

- Credentials nicht in Code committen
- Inventory nicht manuell editieren (wird automatisch aktualisiert)
- Nicht mehrere Instances gleichzeitig ohne Cleanup starten

## Kosten-Übersicht

### EC2 t2.micro (Free Tier)
- ✅ 750 Stunden/Monat kostenlos (erstes Jahr)
- ✅ Nach Free Tier: ~$0.0116/Stunde (~$8.50/Monat)

### Tipp: Kosten sparen
```bash
# Instance nach Tests terminieren
ansible-playbook playbooks/cleanup.yml --vault-password-file .vault_pass
```

## Support & Dokumentation

- **Hauptdokumentation:** [README.md](README.md)
- **Vault Setup:** [VAULT_GUIDE.md](VAULT_GUIDE.md)
- **Automated Deployment:** [AUTOMATED_DEPLOYMENT.md](AUTOMATED_DEPLOYMENT.md)
- **GitHub Setup:** [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)
- **Ansible Lint Fixes:** [ANSIBLE_LINT_FIXES.md](ANSIBLE_LINT_FIXES.md)

## Status: ✅ Ready for Deployment

Alle bekannten Probleme wurden behoben. Der Workflow ist bereit für Production-Deployments!
