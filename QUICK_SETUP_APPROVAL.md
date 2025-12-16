# ⚡ Quick Setup: Admin Approval für Deployments

## 🎯 Was du jetzt tun musst (5 Minuten)

### Schritt 1: Environment erstellen

```
1. Gehe zu: https://github.com/rezaDevOps/ansible-claude/settings/environments
2. Klicke: "New environment"
3. Name: production
4. Klicke: "Configure environment"
```

### Schritt 2: Required Reviewers aktivieren

```
1. ✅ Hake an: "Required reviewers"
2. Gib deinen GitHub Username ein
3. Klicke: "Save protection rules"
```

**Fertig!** 🎉

---

## 🚀 So funktioniert es dann

### Deployment starten

```
1. GitHub → Actions → "Ansible CI/CD Pipeline"
2. Run workflow
3. ✅ Deploy to target environment: true
4. Run workflow
```

### Was passiert

```
✓ Tests laufen (automatisch)
✓ Security Scan (automatisch)
⏸️ Deploy wartet auf DEINE Genehmigung
📧 Du bekommst Email
👉 Du klickst "Approve and deploy"
✓ Deployment läuft
🚀 Fertig!
```

---

## 📸 Screenshots (wo du klicken musst)

### 1. Settings → Environments

```
Repository → Settings (oben rechts) → Environments (links)
```

### 2. New Environment

```
Button: "New environment"
Name eingeben: production
Button: "Configure environment"
```

### 3. Required Reviewers

```
☑️ Required reviewers
[Textfeld] → Dein Username eingeben
Button: "Save protection rules"
```

### 4. Approval geben

```
Workflow Run öffnen
Button: "Review deployments" (gelb)
☑️ production
Optional: Kommentar
Button: "Approve and deploy" (grün)
```

---

## ✅ Checkliste

- [ ] Environment "production" erstellt
- [ ] Required reviewers aktiviert
- [ ] Dich selbst als Reviewer hinzugefügt
- [ ] Protection rules gespeichert
- [ ] Email-Benachrichtigungen aktiviert (optional)

---

## 🧪 Testen

Nach dem Setup:

```bash
# 1. Gehe zu Actions
# 2. Run workflow mit Deploy = true
# 3. Du solltest eine Approval-Anfrage sehen
```

Erwartetes Verhalten:
```
⏸️ "Deploy to EC2" wartet
📧 Email erhalten
👉 "Review deployments" Button sichtbar
```

---

## 🆘 Hilfe

**Problem:** "Environment not found"
→ Environment "production" noch nicht erstellt

**Problem:** Kein "Review deployments" Button
→ Required reviewers nicht aktiviert

**Problem:** Deployment läuft sofort durch
→ Protection rules nicht gespeichert

---

## 📚 Vollständige Anleitung

Siehe: [GITHUB_ENVIRONMENT_SETUP.md](GITHUB_ENVIRONMENT_SETUP.md)

---

**Zeit für Setup:** ~5 Minuten
**Danach:** Jedes Deployment benötigt deine Approval! ✅
