# 🔧 SSH Key Fix - Deployment Issue

## Problem behoben!

### ❌ Was das Problem war:

```
fatal: [44.251.74.95]: UNREACHABLE!
no such identity: /home/runner/.ssh/ansible-ec2-key.pem: No such file or directory
Permission denied (publickey)
```

**Ursache:**
- SSH Key wurde als `~/.ssh/ansible-ec2-key` gespeichert
- Inventory erwartet aber `~/.ssh/ansible-ec2-key.pem`
- Dateiname stimmte nicht überein!

### ✅ Was gefixt wurde:

**Workflow-Änderung:**
```yaml
# VORHER
echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/ansible-ec2-key

# NACHHER
echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/ansible-ec2-key.pem
cp ~/.ssh/ansible-ec2-key.pem ~/.ssh/ansible-ec2-key  # Backup
```

Jetzt wird der Key mit `.pem` Extension gespeichert und funktioniert mit dem Inventory!

## Aktueller Status

### ✅ Was funktioniert hat:

```
✓ EC2 Key Pair erstellt in AWS
✓ EC2 Instance provisioniert
✓ Public IP: 44.251.74.95
✓ Inventory aktualisiert
✓ SSH-Wartezeit durchlaufen
```

### ❌ Was fehlgeschlagen ist:

```
✗ SSH Connection zur EC2 Instance
   → Grund: Falscher Key-Dateiname
```

### 🎯 EC2 Instance Status

**Instance läuft gerade:**
- IP: `44.251.74.95`
- Region: `us-west-2`
- Status: Running
- Key Pair: `ansible-ec2-keypair`

## Nächste Schritte

### Option 1: Workflow neu starten (Empfohlen)

Da die EC2 Instance bereits läuft, können wir entweder:

**A) Instance behalten und erneut deployen:**
```bash
# Die Instance läuft bereits mit IP: 44.251.74.95
# Starte Workflow erneut - es wird zur existierenden Instance deployed
```

**B) Instance terminieren und neu starten:**
```bash
# Cleanup alte Instance
ansible-playbook playbooks/cleanup.yml --vault-password-file .vault_pass

# Dann Workflow neu starten
```

### Option 2: Manuell zur existierenden Instance deployen

Falls du nicht warten möchtest:

```bash
# 1. Update inventory lokal
sed -i '' 's/127.0.0.1/44.251.74.95/' inventory/hosts.ini

# 2. Deploy
ansible-playbook -i inventory/hosts.ini playbooks/site.yml \
  --private-key ~/.ssh/ansible-ec2-key.pem \
  --vault-password-file .vault_pass
```

## Nächster Workflow-Run

Beim nächsten Run sollte alles funktionieren:

```
✓ Provision EC2 instance
✓ Extract EC2 IP
✓ Update inventory
✓ Wait for SSH
✓ Deploy application  ← Sollte jetzt funktionieren!
```

## Wichtig: EC2 Instance Management

### Aktuelle Instance

```
Instance ID: (siehe AWS Console)
Public IP: 44.251.74.95
Status: Running
```

**Du hast zwei Optionen:**

1. **Instance behalten:**
   - Zahle für die laufende Instance (~$0.01/Stunde)
   - Nächster Workflow-Run wird neue Instance erstellen
   - Du hast dann 2 Instances (alte + neue)

2. **Instance terminieren:** (Empfohlen)
   ```bash
   # Via Playbook
   ansible-playbook playbooks/cleanup.yml --vault-password-file .vault_pass

   # Oder via AWS Console
   # EC2 → Instances → Wähle Instance → Actions → Terminate
   ```

## Workflow neu starten

**Schritt-für-Schritt:**

1. **Gehe zu Actions:**
   ```
   https://github.com/rezaDevOps/ansible-claude/actions
   ```

2. **Starte Workflow:**
   - "Ansible CI/CD Pipeline"
   - "Run workflow" ▼
   - ✅ "Deploy to target environment"
   - "Run workflow"

3. **Nach Tests - Approve:**
   - Warte auf Email
   - "Review deployments" → "Approve and deploy"

4. **Erfolgreiche Ausgabe:**
   ```
   ✓ Provisioning new EC2 instance...
   ✓ Found info file at: ec2_instance_info.txt
   ✓ Extracted EC2 IP: 54.x.x.x
   ✓ Inventory updated
   ✓ SSH is ready!
   ✓ Deploying to 54.x.x.x...
   ✓ Application deployed successfully!
   ```

## SSH-Zugriff testen (nach Deployment)

Falls du manuell auf die Instance zugreifen möchtest:

```bash
# Mit der neuen IP (nach erfolgreichem Deployment)
ssh -i ~/.ssh/ansible-ec2-key.pem ubuntu@<NEW_EC2_IP>

# Aktuelle Instance (falls nicht terminiert)
ssh -i ~/.ssh/ansible-ec2-key.pem ubuntu@44.251.74.95
```

## Troubleshooting

### SSH Key funktioniert nicht

**Prüfe Key:**
```bash
# Existiert der Key lokal?
ls -la ~/.ssh/ansible-ec2-key.pem

# Richtige Permissions?
chmod 600 ~/.ssh/ansible-ec2-key.pem

# Teste Verbindung
ssh -i ~/.ssh/ansible-ec2-key.pem ubuntu@44.251.74.95
```

**Falls Connection fehlschlägt:**
```
# Prüfe Security Group
# AWS Console → EC2 → Security Groups → ansible-ec2-sg
# Muss Port 22 von deiner IP erlauben
```

### Workflow schlägt erneut fehl

**Logs prüfen:**
```bash
gh run list --limit 1
gh run view <run-id> --log-failed
```

**Häufige Probleme:**
- SSH_PRIVATE_KEY Secret falsch
- Security Group blockiert SSH
- Instance braucht länger zum Starten

## Kosten-Hinweis

### Laufende Instance

Die aktuelle Instance kostet:
```
t3.micro: ~$0.0104/Stunde
= ~$0.25/Tag
= ~$7.50/Monat
```

**Empfehlung:**
- Terminiere ungenutzte Instances
- Nutze Cleanup-Playbook nach Tests
- Überwache AWS Console regelmäßig

## Status-Check

### Prüfe laufende Instances (AWS CLI)

```bash
# Liste EC2 Instances
aws ec2 describe-instances \
  --region us-west-2 \
  --filters "Name=tag:ManagedBy,Values=ansible" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' \
  --output table
```

### Prüfe via AWS Console

```
1. AWS Console → EC2 Dashboard
2. Region: us-west-2
3. Instances
4. Filter: Tag "ManagedBy" = "ansible"
```

## Zusammenfassung

✅ **Problem identifiziert:** SSH Key Dateiname
✅ **Fix implementiert:** `.pem` Extension hinzugefügt
✅ **Gepusht zu GitHub:** Ready für nächsten Run
🔄 **Nächster Schritt:** Workflow erneut starten

**Empfohlene Aktion:**
1. Terminiere alte Instance (44.251.74.95)
2. Starte Workflow neu
3. Approve nach Tests
4. Deployment sollte durchlaufen!

---

**Bereit für erfolgreichen Deployment!** 🚀
