# GitHub Environment Setup mit Admin Approval

## Übersicht

Der Deploy-Step erfordert jetzt eine **manuelle Admin-Genehmigung** über GitHub Environments.

```
Workflow läuft → Tests ✓ → ⏸️ WARTET auf Admin Approval → ✓ Deploy nach Genehmigung
```

## Einrichtung (Einmalig erforderlich)

### Schritt 1: Environment erstellen

1. Gehe zu deinem Repository: `https://github.com/rezaDevOps/ansible-claude`
2. Klicke auf **Settings** (Zahnrad-Symbol oben rechts)
3. In der linken Sidebar: **Environments**
4. Klicke **New environment**
5. Name: `production`
6. Klicke **Configure environment**

### Schritt 2: Protection Rules aktivieren

#### Required Reviewers (Admin Approval)

1. In den Environment-Settings für "production"
2. ✅ Aktiviere: **Required reviewers**
3. Klicke auf das Textfeld und wähle dich selbst aus (oder andere Admins)
   - Du kannst bis zu 6 Reviewer hinzufügen
   - Mindestens 1 muss genehmigen
4. Klicke **Save protection rules**

#### Optionale Einstellungen

**Wait timer** (Optional):
- Füge eine Wartezeit hinzu (z.B. 5 Minuten)
- Deployment startet erst nach dieser Zeit + Approval

**Deployment branches** (Empfohlen):
- ✅ Selected branches
- Regel hinzufügen: `main`
- → Nur Deployments vom main branch erlauben

**Environment secrets** (Optional):
- Hier kannst du production-spezifische Secrets hinzufügen
- Diese überschreiben Repository-Secrets

### Schritt 3: Branch Protection (Optional, aber empfohlen)

1. Settings → **Branches**
2. **Add branch protection rule**
3. Branch name pattern: `main`
4. ✅ **Require a pull request before merging**
5. ✅ **Require status checks to pass before merging**
   - Wähle: `Lint Ansible Files`, `Syntax Check Playbooks`

## Verwendung

### Deploy-Workflow mit Approval

1. **Workflow starten:**
   ```
   GitHub → Actions → "Ansible CI/CD Pipeline" → Run workflow
   ✅ Deploy to target environment: true
   ```

2. **Workflow läuft:**
   ```
   ✓ Lint Ansible Files
   ✓ Syntax Check Playbooks
   ✓ Security Scanning
   ⏸️ Deploy to EC2 - Waiting for approval
   ```

3. **Du erhältst Benachrichtigung:**
   - Email von GitHub
   - In-App Notification
   - Text: "Deployment to production is awaiting your approval"

4. **Genehmigung erteilen:**
   - Öffne den Workflow Run
   - Du siehst: **"Review deployments"** Button (gelb)
   - Klicke darauf
   - Optional: Kommentar hinzufügen
   - Klicke **Approve and deploy**

5. **Deployment läuft:**
   ```
   ✓ Provision EC2 instance
   ✓ Extract EC2 IP
   ✓ Update inventory
   ✓ Wait for SSH
   ✓ Deploy application
   ```

### Ablehnen (Reject)

Falls du das Deployment nicht freigeben möchtest:
- Klicke **Review deployments**
- Wähle **Reject**
- Deployment wird abgebrochen

## Workflow-Verhalten

### Mit Environment Protection

```yaml
environment:
  name: production
  url: http://${{ env.EC2_IP }}
```

**Effekt:**
- ⏸️ Job pausiert vor Start
- 👤 Wartet auf manuelle Approval
- ✅ Startet nur nach Genehmigung
- 🔗 URL wird nach Deployment angezeigt

### Push zu main

```bash
git push origin main
```

**Verhalten:**
- ✅ Lint + Tests laufen automatisch
- ❌ Deploy läuft NICHT (nur bei manual trigger)

### Pull Request

```bash
gh pr create --title "Feature XYZ"
```

**Verhalten:**
- ✅ Lint + Tests + Dry Run
- ❌ Deploy läuft NICHT

### Manual Workflow Dispatch

**Mit "Deploy" = false:**
- ✅ Lint + Tests + Security Scan
- ❌ Deploy läuft NICHT

**Mit "Deploy" = true:**
- ✅ Lint + Tests + Security Scan
- ⏸️ Deploy WARTET auf Approval
- ✅ Deploy nach Genehmigung

## Berechtigungen

### Wer kann approven?

**Required Reviewers:**
- Nur die konfigurierten Reviewer können genehmigen
- Typischerweise: Repository Owner und Admins

**Bypass Protection:**
- Repository Admin kann Protection Rules umgehen (nicht empfohlen)

### Wer kann Workflow starten?

- Jeder mit Write-Zugriff zum Repository
- Aber: Deploy benötigt immer Approval

## Vorteile

### Sicherheit
- ✅ Kein versehentliches Deployment
- ✅ Vier-Augen-Prinzip
- ✅ Audit Trail (wer hat wann genehmigt)

### Kontrolle
- ✅ Review vor Production-Deployment
- ✅ Zeit zum Checken von Changes
- ✅ Kann abgelehnt werden

### Compliance
- ✅ Dokumentation von Deployments
- ✅ Approval-History
- ✅ Nachvollziehbar wer deployed hat

## Notifications

### Email-Benachrichtigung aktivieren

1. GitHub → Settings (dein Profil, nicht Repo)
2. **Notifications**
3. ✅ **Actions**
4. ✅ **Send notifications for workflows requiring approval**

### Slack-Integration (Optional)

```yaml
- name: Request approval notification
  run: |
    curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
      -H 'Content-Type: application/json' \
      -d '{"text":"🚨 Deployment zu production wartet auf Approval!"}'
```

## Monitoring

### Deployment History

1. Repository → **Environments** (in Settings)
2. Klicke auf **production**
3. Du siehst:
   - Alle Deployments
   - Status (Approved/Rejected)
   - Wer approved hat
   - Wann deployed wurde
   - Deployment URL

### Activity Log

1. Repository → **Insights**
2. **Deployments**
3. Filter: Environment = production

## Troubleshooting

### Problem: "Environment not found"

**Ursache:** Environment "production" existiert nicht

**Lösung:**
1. Repository Settings → Environments
2. Erstelle "production" Environment
3. Konfiguriere Required Reviewers

### Problem: "No reviewers available"

**Ursache:** Keine Reviewer konfiguriert

**Lösung:**
1. Environment Settings → Required reviewers
2. Füge mindestens einen Reviewer hinzu

### Problem: "User is not a reviewer"

**Ursache:** Der User ist nicht als Reviewer konfiguriert

**Lösung:**
1. Environment Settings
2. Füge den User zu Required reviewers hinzu

### Problem: Deployment läuft ohne Approval

**Ursache:** Environment Protection nicht aktiviert

**Lösung:**
1. Prüfe Environment Settings
2. Aktiviere "Required reviewers"
3. Speichern nicht vergessen!

## Best Practices

### ✅ DO

- Minimum 2 Reviewer konfigurieren (Redundanz)
- Branch Protection aktivieren
- Deployment-History regelmäßig reviewen
- Notifications aktivieren

### ❌ DON'T

- Protection Rules nicht umgehen (auch als Admin)
- Nicht selbst approven, wenn du auch committest (Vier-Augen-Prinzip)
- Keine automatischen Approvals via Scripts

## Beispiel-Ablauf

### Kompletter Deploy-Zyklus

```
1. Developer committed Code
   ↓
2. Push zu main
   ↓
3. CI Tests laufen (automatisch)
   ↓
4. Admin startet Deploy-Workflow
   ↓
5. Tests + Security Scan laufen
   ↓
6. ⏸️ Workflow pausiert bei Deploy-Job
   ↓
7. 📧 Admin erhält Email-Benachrichtigung
   ↓
8. Admin reviewed Changes im PR/Commit
   ↓
9. Admin approved Deployment in GitHub
   ↓
10. ✅ Deployment läuft automatisch
   ↓
11. 🚀 Application deployed to EC2
   ↓
12. 📊 Deployment URL wird angezeigt
```

## Weiterführende Konfiguration

### Staging Environment (Optional)

Erstelle zusätzliches Environment ohne Approval:

```yaml
# Neuer Job für Staging
staging-deploy:
  name: Deploy to Staging
  runs-on: ubuntu-latest
  environment:
    name: staging  # Kein required reviewers
  # ... deployment steps
```

### Multiple Approvers

Erfordere 2+ Approvals:

1. Environment Settings
2. Füge mehrere Reviewer hinzu
3. Alle müssen approven

### Zeitfenster (Deployment Windows)

Erlaube Deployments nur zu bestimmten Zeiten:
- Nutze Branch Protection Rules
- Oder: Workflow Schedule + Conditions

## Kosten

**GitHub Free:**
- ✅ Environments: Unbegrenzt
- ✅ Required reviewers: Ja
- ✅ Deployment History: Ja

**Keine zusätzlichen Kosten!**

## Support

- [GitHub Environments Docs](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Required Reviewers](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#required-reviewers)

## Status nach Setup

✅ Environment "production" erstellt
✅ Required Reviewers konfiguriert
✅ Workflow updated mit environment
✅ Deploy benötigt manuelle Approval

**Bereit für kontrollierte Production-Deployments!** 🎉
