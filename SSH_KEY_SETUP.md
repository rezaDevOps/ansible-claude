# 🔑 SSH Key Pair Setup für EC2

## Problem behoben!

Das Provision-Playbook erstellt jetzt **automatisch** einen EC2 Key Pair in AWS, falls er nicht existiert.

## Was passiert beim nächsten Deploy:

### Szenario 1: Key Pair existiert bereits ✅

```
✓ Using existing EC2 key pair: ansible-ec2-keypair
✓ Continue with deployment...
```

Alles läuft normal durch!

### Szenario 2: Key Pair existiert nicht (erstmaliges Setup)

Das Playbook wird:

1. **Prüfen** ob Key Pair existiert
2. **Erstellen** des Key Pairs in AWS
3. **Speichern** des privaten Keys (nur lokal, nicht in CI)
4. **Warnung anzeigen** dass du den Key als GitHub Secret hinzufügen musst

**Workflow-Output:**
```
⚠️  NEW SSH KEY PAIR CREATED!
Key name: ansible-ec2-keypair
Private key saved to: ansible-ec2-key-NEW.pem

IMPORTANT: You must update GitHub Secret 'SSH_PRIVATE_KEY'
```

## Was du dann tun musst:

### Option A: Key automatisch erstellen lassen (Empfohlen für ersten Run)

1. **Starte Workflow erneut:**
   - Der Key Pair wird in AWS erstellt
   - Deployment wird mit neuem Key fortgesetzt

2. **Nach dem Deployment:**
   - Gehe zu AWS EC2 Console → Key Pairs
   - Du siehst: `ansible-ec2-keypair` ✓
   - **Achtung:** Der private Key kann NICHT mehr heruntergeladen werden!

3. **GitHub Secret aktualisieren:**
   - Der neu erstellte Key ist nur im Workflow verfügbar
   - Du musst den Key manuell in AWS neu erstellen und als Secret hinzufügen

### Option B: Key manuell in AWS erstellen (Sicherer)

#### 1. Erstelle Key Pair in AWS Console

```
1. Gehe zu: https://console.aws.amazon.com/ec2/
2. Region auswählen: us-west-2 (oder deine konfigurierte Region)
3. Links: Network & Security → Key Pairs
4. Button: "Create key pair"
   Name: ansible-ec2-keypair
   Key pair type: RSA
   Private key file format: .pem
5. Klicke "Create key pair"
6. Datei wird heruntergeladen: ansible-ec2-keypair.pem
```

#### 2. Speichere den Key lokal

```bash
# Verschiebe den Key
mv ~/Downloads/ansible-ec2-keypair.pem ~/.ssh/ansible-ec2-key.pem

# Setze Permissions
chmod 600 ~/.ssh/ansible-ec2-key.pem

# Teste den Key
ssh-keygen -l -f ~/.ssh/ansible-ec2-key.pem
```

#### 3. Füge Key als GitHub Secret hinzu

```bash
# Kopiere Key-Inhalt
cat ~/.ssh/ansible-ec2-key.pem | pbcopy  # macOS
# oder
cat ~/.ssh/ansible-ec2-key.pem  # Linux/Windows - dann manuell kopieren
```

**In GitHub:**
```
1. Gehe zu: https://github.com/rezaDevOps/ansible-claude/settings/secrets/actions
2. Klicke: "New repository secret"
3. Name: SSH_PRIVATE_KEY
4. Value: [Füge kompletten Key-Inhalt ein, inkl. -----BEGIN/END-----]
5. Klicke: "Add secret"
```

#### 4. Starte Deployment erneut

Jetzt sollte alles funktionieren!

## Key Pair Überprüfung

### In AWS Console prüfen

```
1. AWS EC2 Console → Key Pairs
2. Region: us-west-2 (oder deine Region)
3. Suche nach: ansible-ec2-keypair
```

**Falls Key existiert:**
- ✅ Name: ansible-ec2-keypair
- ✅ Fingerprint: Zeigt eindeutigen Hash

**Falls Key NICHT existiert:**
- ❌ Key not found
- → Erstelle manuell oder lasse Playbook erstellen

### Via AWS CLI prüfen

```bash
# Key Pair auflisten
aws ec2 describe-key-pairs \
  --region us-west-2 \
  --key-names ansible-ec2-keypair

# Falls existiert:
{
    "KeyPairs": [
        {
            "KeyPairId": "key-xxxxx",
            "KeyFingerprint": "xx:xx:xx...",
            "KeyName": "ansible-ec2-keypair",
            "KeyType": "rsa",
            "Tags": []
        }
    ]
}

# Falls nicht existiert:
An error occurred (InvalidKeyPair.NotFound) when calling the DescribeKeyPairs operation
```

## Troubleshooting

### Problem: "InvalidKeyPair.NotFound"

**Ursache:** Key Pair existiert nicht in AWS

**Lösung:**
1. Erstelle Key manuell (siehe Option B oben)
2. ODER: Lasse Playbook automatisch erstellen (nächster Run)

### Problem: "Permission denied (publickey)" beim SSH

**Ursache:** Falscher Key oder Key nicht als Secret gespeichert

**Lösung:**
```bash
# 1. Prüfe Key Fingerprint lokal
ssh-keygen -l -f ~/.ssh/ansible-ec2-key.pem

# 2. Prüfe Key Fingerprint in AWS
aws ec2 describe-key-pairs --region us-west-2 --key-names ansible-ec2-keypair

# 3. Fingerprints müssen übereinstimmen!

# 4. Falls nicht: Erstelle neuen Key in AWS und update GitHub Secret
```

### Problem: Neuer Key wurde erstellt, aber ich kann nicht auf EC2 zugreifen

**Ursache:** GitHub Secret enthält alten Key

**Lösung:**
1. Lösche alten Key Pair in AWS
2. Erstelle neuen Key Pair in AWS (siehe Option B)
3. Update GitHub Secret mit neuem Key
4. Starte Deployment erneut

## Best Practices

### ✅ DO

- Erstelle Key Pair manuell in AWS (mehr Kontrolle)
- Speichere privaten Key sicher lokal
- Nutze unterschiedliche Keys für Staging/Production
- Rotiere Keys regelmäßig (alle 90 Tage)

### ❌ DON'T

- Committe niemals private Keys in Git
- Teile Keys nicht per Email/Slack
- Nutze nicht denselben Key für alle Projekte
- Verlasse dich nicht auf automatische Key-Erstellung in Production

## Automatisierung

### Key Pair automatisch erstellen (Development)

Für Development/Testing kannst du das Playbook lokal laufen lassen:

```bash
# Provision lokal (erstellt Key automatisch)
ansible-playbook -i inventory/localhost.ini playbooks/provision.yml \
  --vault-password-file .vault_pass

# Neuer Key wird gespeichert als:
# ansible-ec2-key-NEW.pem

# Dann:
mv ansible-ec2-key-NEW.pem ~/.ssh/ansible-ec2-key.pem
chmod 600 ~/.ssh/ansible-ec2-key.pem
```

### Key Pair mit Terraform (Fortgeschritten)

Falls du später Terraform nutzen möchtest:

```hcl
resource "aws_key_pair" "ansible" {
  key_name   = "ansible-ec2-keypair"
  public_key = file("~/.ssh/ansible-ec2-key.pub")
}
```

## Status nach Fix

✅ Playbook prüft automatisch Key Pair Existenz
✅ Erstellt Key falls nicht vorhanden
✅ Zeigt Warnung wenn neuer Key erstellt wurde
✅ Workflow kann jetzt durchlaufen

## Nächster Schritt

**Starte Workflow erneut:**

1. Gehe zu: https://github.com/rezaDevOps/ansible-claude/actions
2. Klicke: "Ansible CI/CD Pipeline"
3. Klicke: "Run workflow" ▼
4. ✅ Deploy to target environment
5. Klicke: "Run workflow"

Jetzt sollte das Provisioning funktionieren! 🚀

## Weitere Dokumentation

- **AWS Key Pairs Docs:** https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html
- **GitHub Secrets:** https://docs.github.com/en/actions/security-guides/encrypted-secrets
- **SSH Best Practices:** https://www.ssh.com/academy/ssh/key
