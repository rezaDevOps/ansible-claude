# 🚀 Deployment ausführen - Schritt für Schritt

## Via GitHub Web Interface (Einfachste Methode)

### 1. Öffne Actions Tab

```
https://github.com/rezaDevOps/ansible-claude/actions
```

Oder:
- Gehe zu: https://github.com/rezaDevOps/ansible-claude
- Klicke Tab: **Actions** (oben)

### 2. Wähle Workflow

In der linken Sidebar:
- Klicke: **"Ansible CI/CD Pipeline"**

### 3. Starte Workflow

Oben rechts:
- Button: **"Run workflow"** ▼
- Klicke darauf

### 4. Konfiguriere

Dropdown öffnet sich:
```
Use workflow from
Branch: main

☑️ Deploy to target environment  ← WICHTIG: Haken setzen!
```

### 5. Run

- Button: **"Run workflow"** (grün)
- Klicke darauf

### 6. Beobachte

- Seite lädt neu
- Neuer Run erscheint (gelb = läuft)
- Klicke darauf für Details

---

## Via GitHub CLI

### Voraussetzung: `gh` installieren

```bash
# macOS
brew install gh

# Login
gh auth login
```

### Workflow starten MIT Deploy

```bash
# Im Projektverzeichnis
cd /Users/admin/Documents/DEV/Ansible/Ansible-Claude

# Workflow starten mit Deploy = true
gh workflow run "Ansible CI/CD Pipeline" \
  --ref main \
  -f deploy=true
```

### Workflow starten OHNE Deploy (nur Tests)

```bash
gh workflow run "Ansible CI/CD Pipeline" \
  --ref main \
  -f deploy=false
```

### Status prüfen

```bash
# Liste letzte Runs
gh run list --limit 5

# Details eines Runs
gh run view <run-id>

# Logs eines Runs
gh run view <run-id> --log

# Logs nur von fehlgeschlagenen Jobs
gh run view <run-id> --log-failed
```

### Live-Logs verfolgen

```bash
# Starte Workflow und schaue Logs live
gh workflow run "Ansible CI/CD Pipeline" -f deploy=true && \
sleep 5 && \
gh run watch
```

---

## Was passiert nach dem Start?

### Phase 1: Tests (automatisch)

```
✓ Lint Ansible Files      (1-2 min)
✓ Syntax Check Playbooks   (1 min)
✓ Security Scanning        (2-3 min)
```

### Phase 2: Warten auf Approval

```
⏸️ Deploy to EC2 - Waiting for approval

📧 Du erhältst Email-Benachrichtigung:
   "Deployment to production is awaiting your approval"
```

### Phase 3: Approval geben

**Im GitHub Web:**
1. Öffne den Workflow Run
2. Du siehst gelben Banner: **"Review deployments"**
3. Klicke: **"Review deployments"**
4. Dialog öffnet sich:
   ```
   ☑️ production

   Leave a comment (optional)
   [Textfeld für Kommentar]

   [Approve and deploy]  [Reject]
   ```
5. Klicke: **"Approve and deploy"** (grün)

### Phase 4: Deployment läuft

```
✓ Provision EC2 instance       (2-3 min)
✓ Extract EC2 IP               (10 sec)
✓ Update inventory             (5 sec)
✓ Wait for SSH                 (1-5 min)
✓ Deploy application           (2-5 min)
✓ Verify deployment            (30 sec)
```

### Phase 5: Fertig!

```
✅ Deployment completed successfully
🔗 URL: http://54.x.x.x
```

---

## Screenshots der wichtigen Stellen

### 1. Actions Tab

```
┌─────────────────────────────────────────────┐
│  Code  Issues  Pull requests  [Actions]  ←  │
└─────────────────────────────────────────────┘
```

### 2. Run workflow Button

```
┌─────────────────────────────────────────────┐
│  Ansible CI/CD Pipeline                      │
│                                               │
│                    [Run workflow ▼]  ←       │
└─────────────────────────────────────────────┘
```

### 3. Workflow Configuration

```
┌──────────────────────────────────────────┐
│  Run workflow                             │
│                                           │
│  Use workflow from                        │
│  Branch: main               ▼             │
│                                           │
│  ☑️ Deploy to target environment  ←      │
│                                           │
│  [Run workflow]                           │
└──────────────────────────────────────────┘
```

### 4. Waiting for Approval

```
┌──────────────────────────────────────────┐
│  ⏸️ Deploy to EC2                         │
│                                           │
│  This job is waiting for approval         │
│  from required reviewers                  │
│                                           │
│  [Review deployments]  ←                  │
└──────────────────────────────────────────┘
```

### 5. Approve Dialog

```
┌──────────────────────────────────────────┐
│  Review pending deployments               │
│                                           │
│  ☑️ production  ←                         │
│                                           │
│  Comment (optional)                       │
│  ┌────────────────────────────────────┐  │
│  │ Looks good, deploying to prod      │  │
│  └────────────────────────────────────┘  │
│                                           │
│  [Approve and deploy]  [Reject]           │
└──────────────────────────────────────────┘
```

---

## Troubleshooting

### Kein "Run workflow" Button

**Problem:** Button ist nicht sichtbar

**Ursache:** Du hast keine Write-Berechtigung

**Lösung:**
- Prüfe ob du Owner/Admin des Repos bist
- Oder: Repository → Settings → Actions → Allow all actions

### "Deploy to target environment" Checkbox fehlt

**Problem:** Checkbox ist nicht da

**Ursache:** Workflow wurde noch nicht gepusht

**Lösung:**
```bash
git pull origin main
# Prüfe ob .github/workflows/ansible-ci.yml die workflow_dispatch inputs hat
```

### Workflow läuft nicht durch bis Deploy

**Problem:** Deploy-Job läuft nicht

**Ursache:** Checkbox nicht gesetzt

**Lösung:**
- Workflow neu starten
- ✅ Haken bei "Deploy to target environment" setzen

### Kein "Review deployments" Button

**Problem:** Deploy läuft sofort ohne Approval

**Ursache:** Environment "production" nicht konfiguriert

**Lösung:**
1. Repository → Settings → Environments
2. Erstelle "production"
3. Aktiviere "Required reviewers"

---

## Quick Commands

### Workflow starten (CLI)

```bash
# Mit Deploy
gh workflow run "Ansible CI/CD Pipeline" -f deploy=true

# Ohne Deploy
gh workflow run "Ansible CI/CD Pipeline" -f deploy=false
```

### Status prüfen (CLI)

```bash
# Aktueller Status
gh run list --limit 1

# Live verfolgen
gh run watch
```

### Logs ansehen (CLI)

```bash
# Letzte Run-ID holen
RUN_ID=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')

# Logs ansehen
gh run view $RUN_ID --log

# Nur Fehler
gh run view $RUN_ID --log-failed
```

---

## Best Practices

### Vor dem Deploy

- [ ] Pull neueste Changes: `git pull origin main`
- [ ] Prüfe offene PRs
- [ ] Checke ob alte EC2 Instance gelöscht ist
- [ ] Stelle sicher, dass Secrets aktuell sind

### Während dem Deploy

- [ ] Beobachte Workflow-Logs
- [ ] Warte auf Email-Benachrichtigung
- [ ] Review Changes bevor du approvest
- [ ] Gib sinnvollen Kommentar beim Approval

### Nach dem Deploy

- [ ] Teste die Application: `curl http://<EC2_IP>`
- [ ] Prüfe SSH-Zugriff (falls nötig)
- [ ] Dokumentiere die IP-Adresse
- [ ] Monitoring aktivieren

---

## Nächste Schritte

1. **Environment Setup durchführen** (falls noch nicht geschehen)
   - Siehe: [QUICK_SETUP_APPROVAL.md](QUICK_SETUP_APPROVAL.md)

2. **Ersten Deploy testen**
   - Actions → Run workflow → ✅ Deploy

3. **Approval geben**
   - Email-Benachrichtigung abwarten
   - Review deployments → Approve

4. **Application testen**
   - SSH: `ssh -i ~/.ssh/ansible-ec2-key.pem ubuntu@<EC2_IP>`
   - HTTP: `curl http://<EC2_IP>`

---

## Direkte Links

- **Actions:** https://github.com/rezaDevOps/ansible-claude/actions
- **Environments:** https://github.com/rezaDevOps/ansible-claude/settings/environments
- **Secrets:** https://github.com/rezaDevOps/ansible-claude/settings/secrets/actions

---

**Bereit für deinen ersten Deployment!** 🚀
