# Automated EC2 Deployment via GitHub Actions

## Übersicht

Der GitHub Actions Workflow wurde so konfiguriert, dass er **automatisch** folgendes tut:

1. ✅ Neue EC2-Instance provisionieren
2. ✅ IP-Adresse extrahieren
3. ✅ Inventory automatisch aktualisieren
4. ✅ Auf SSH warten (bis zu 5 Minuten)
5. ✅ Application deployen

**Keine manuelle Inventory-Aktualisierung mehr nötig!** 🎉

## Workflow-Schritte

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  1. Provision EC2    →  Neue Instance erstellen        │
│  2. Extract IP       →  IP aus ec2_instance_info.txt   │
│  3. Update Inventory →  hosts.ini automatisch anpassen │
│  4. Wait for SSH     →  Bis SSH verfügbar (max 5min)  │
│  5. Deploy App       →  Ansible Playbooks ausführen   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Verwendung

### Von GitHub Actions (Empfohlen)

```bash
# 1. Committe die Änderungen
git add .
git commit -m "Add automated EC2 provisioning to workflow"
git push origin main

# 2. Gehe zu GitHub Actions
# 3. Run workflow mit "Deploy to target environment" ✅
```

### Lokales Deployment

Falls du lokal deployen möchtest:

```bash
# 1. Provision EC2
ansible-playbook -i inventory/localhost.ini playbooks/provision.yml

# 2. Hole die IP aus der Output-Datei
EC2_IP=$(grep "Public IP:" ec2_instance_info.txt | awk '{print $3}')
echo "EC2 IP: $EC2_IP"

# 3. Update inventory
sed -i '' "s/127.0.0.1/$EC2_IP/" inventory/hosts.ini

# 4. Warte auf SSH
sleep 60  # Warte 1 Minute

# 5. Deploy
ansible-playbook -i inventory/hosts.ini playbooks/site.yml \
  --private-key ~/.ssh/ansible-ec2-key \
  --vault-password-file .vault_pass
```

## Wichtige Features

### 1. Automatische IP-Extraktion

```bash
# Der Workflow liest ec2_instance_info.txt
# Extrahiert die Public IP
# Speichert sie in $EC2_IP Environment Variable
```

### 2. Automatisches Inventory-Update

```bash
# Ersetzt die Placeholder-IP (127.0.0.1) mit der echten EC2 IP
sed -i "s/^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/$EC2_IP/"
```

### 3. SSH-Wartezeit

```bash
# Wartet bis zu 5 Minuten (30 Versuche × 10 Sekunden)
# Prüft alle 10 Sekunden ob SSH verfügbar ist
for i in {1..30}; do
  if ssh ... ubuntu@$EC2_IP 'exit'; then
    break  # SSH ist bereit!
  fi
  sleep 10
done
```

## Troubleshooting

### Problem: "ec2_instance_info.txt not found"

**Ursache:** Provision-Playbook hat die Datei nicht erstellt

**Lösung:**
```bash
# Prüfe ob provision.yml die Datei erstellt
# Sie sollte in playbooks/provision.yml Task "Save instance info to file" sein
```

### Problem: "SSH not ready after 5 minutes"

**Ursache:** EC2-Instance braucht länger zum Starten

**Lösung:**
- Erhöhe die Wartezeit im Workflow
- Oder: Warte manuell und führe nur deploy-step aus

### Problem: "Permission denied (publickey)"

**Ursache:** SSH-Key stimmt nicht

**Lösung:**
```bash
# Prüfe GitHub Secret SSH_PRIVATE_KEY
# Muss identisch sein mit dem Key in AWS EC2
```

### Problem: Alte IP bleibt im Inventory

**Ursache:** sed-Befehl funktioniert nicht auf allen Systemen gleich

**Lösung:**
```bash
# Für macOS (lokal)
sed -i '' "s/pattern/replacement/"

# Für Linux (GitHub Actions)
sed -i "s/pattern/replacement/"
```

## Workflow-Logs

Typischer erfolgreicher Workflow:

```
✓ Provisioning new EC2 instance...
✓ Found EC2 IP: 54.123.45.67
✓ Inventory updated
✓ SSH is ready!
✓ Deploying to 54.123.45.67...
✓ Deployment completed successfully
```

## Cleanup

### Alte EC2-Instances löschen

**Via GitHub Actions:**
1. Run workflow: "Ansible CI/CD Pipeline"
2. Ohne "Deploy" checkbox
3. Manuell cleanup.yml ausführen (nicht automatisiert)

**Lokal:**
```bash
ansible-playbook playbooks/cleanup.yml \
  --vault-password-file .vault_pass
```

**Via AWS Console:**
1. EC2 Dashboard
2. Instances
3. Wähle Instance
4. Actions > Instance State > Terminate

## Best Practices

### 1. Immer über GitHub Actions deployen

- ✅ Automatische Provisioning
- ✅ Konsistente Umgebung
- ✅ Audit Trail
- ✅ Secrets Management

### 2. Inventory nicht manuell editieren

- ✅ Wird automatisch aktualisiert
- ❌ Keine manuellen Änderungen nötig

### 3. Alte Instances aufräumen

```bash
# Regelmäßig alte Instances löschen um Kosten zu sparen
# AWS Console > EC2 > Filter by "ansible-managed-ec2"
```

### 4. Logs überwachen

- Workflow-Logs in GitHub Actions prüfen
- Bei Fehlern: Logs analysieren
- Bei Erfolg: EC2 IP notieren für Zugriff

## Kosten-Optimierung

### Auto-Termination nach Tests

Füge zum Workflow hinzu (optional):

```yaml
- name: Terminate instance after testing
  if: github.event_name == 'pull_request'
  run: |
    ansible-playbook playbooks/cleanup.yml \
      --vault-password-file .vault_pass
```

Dies löscht die Instance automatisch nach PR-Tests.

## Nächste Schritte

1. **Teste den neuen Workflow:**
   ```bash
   git add .
   git commit -m "Add automated provisioning and deployment"
   git push
   ```

2. **Führe Deployment aus:**
   - GitHub Actions > Run workflow
   - ✅ Deploy to target environment
   - Beobachte die Logs

3. **Zugriff auf Application:**
   ```bash
   # IP wird in Workflow-Logs angezeigt
   curl http://<EC2_IP>
   ```

4. **SSH-Zugriff (falls nötig):**
   ```bash
   ssh -i ~/.ssh/ansible-ec2-key ubuntu@<EC2_IP>
   ```

## Erweiterte Konfiguration

### Multi-Instance Deployment

Für mehrere Instances, passe an:

```yaml
# In workflow: Loop über mehrere Provisions
for i in {1..3}; do
  ansible-playbook playbooks/provision.yml ...
done
```

### Blue-Green Deployment

1. Provision neue Instance (green)
2. Deploy auf neue Instance
3. Teste
4. Update Load Balancer
5. Terminate alte Instance (blue)

## Support

Bei Problemen:

1. **Workflow-Logs prüfen:** GitHub Actions > Workflow Run > Logs
2. **Dokumentation:** [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)
3. **Lokales Testing:** Führe Playbooks lokal aus
4. **AWS Console:** Prüfe EC2-Status

## Zusammenfassung

✅ **Vollautomatisches Deployment**
- Keine manuellen Schritte
- Inventory wird automatisch aktualisiert
- SSH-Wartezeit integriert
- Fehlerbehandlung eingebaut

🚀 **Einfach zu nutzen**
- Ein Klick in GitHub Actions
- Komplette Automation
- Sichere Secrets-Verwaltung

💰 **Kosten-bewusst**
- Nur zahlen wenn Instance läuft
- Einfaches Cleanup
- Optional: Auto-Termination
