# File Manifest

Complete list of all files in this Ansible project with descriptions.

## Documentation Files

```
README.md                           # Main project documentation and quick start guide
STEP_BY_STEP_GUIDE.md              # Detailed step-by-step deployment instructions
SECURITY_CHECKLIST.md              # Comprehensive security verification checklist
FILE_MANIFEST.md                   # This file - complete file listing
.gitignore                         # Git ignore rules for sensitive files
```

## Configuration Files

```
ansible.cfg                        # Ansible configuration (SSH, defaults, callbacks)
```

## Inventory Files

```
inventory/
├── localhost.ini                  # Localhost inventory for provisioning tasks
└── hosts.ini                      # EC2 instance inventory (update after provision)
```

## Variable Files

```
group_vars/
├── all.yml                        # Non-sensitive variables (AWS, app, system config)
└── vault.yml                      # Sensitive variables (encrypt with ansible-vault)
```

## Playbooks

```
playbooks/
├── provision.yml                  # EC2 instance provisioning playbook
└── site.yml                       # Main deployment playbook (orchestrates all roles)
```

## Roles

### Users Role
```
roles/users/
└── tasks/
    └── main.yml                   # Create deployer user with SSH keys and sudo
```

**Purpose:** Creates non-root deployer user with key-based authentication and passwordless sudo.

### Base Role (System Hardening)
```
roles/base/
├── tasks/
│   └── main.yml                   # System updates, security hardening, fail2ban
├── handlers/
│   └── main.yml                   # Service restart handlers (sshd, fail2ban)
└── templates/
    └── sshd_config.j2             # Hardened SSH server configuration
```

**Purpose:** System-level security hardening, automatic updates, SSH lockdown, fail2ban setup.

### Firewall Role
```
roles/firewall/
└── tasks/
    └── main.yml                   # UFW configuration with least-privilege rules
```

**Purpose:** Configure UFW firewall to allow only necessary ports (22, 80, 443).

### App Role (Flask Application)
```
roles/app/
├── tasks/
│   └── main.yml                   # Deploy app, create virtualenv, install deps
├── handlers/
│   └── main.yml                   # Application service handlers
├── templates/
│   └── myapp.service.j2           # Systemd service unit file for Flask app
└── files/
    ├── app.py                     # Flask application code
    └── requirements.txt           # Python dependencies (Flask, gunicorn)
```

**Purpose:** Deploy Flask application in virtualenv, managed by systemd with gunicorn.

### Nginx Role
```
roles/nginx/
├── tasks/
│   └── main.yml                   # Install and configure NGINX
├── handlers/
│   └── main.yml                   # NGINX service handlers
└── templates/
    └── flask-app.conf.j2          # NGINX reverse proxy configuration
```

**Purpose:** Install and configure NGINX as reverse proxy with security headers.

## Quick Reference

### Files You MUST Edit Before Running

1. **group_vars/all.yml**
   - Replace all `REPLACE_ME` values
   - Set AWS region and key pair name
   - Add your SSH public key for deployer user
   - Restrict `allowed_ssh_ips` to your IP range

2. **inventory/hosts.ini**
   - Update with EC2 public IP after provisioning
   - Update SSH key path

### Key Files Explained

| File | Purpose | Edit Required |
|------|---------|---------------|
| `ansible.cfg` | Ansible behavior and defaults | No |
| `group_vars/all.yml` | All configuration variables | **YES** |
| `group_vars/vault.yml` | Sensitive data (optional) | Optional |
| `inventory/localhost.ini` | For provisioning playbook | No |
| `inventory/hosts.ini` | EC2 instance inventory | **YES** (after provision) |
| `playbooks/provision.yml` | Creates EC2 instance | No |
| `playbooks/site.yml` | Main deployment | No |
| `roles/*/tasks/main.yml` | Role logic | No |
| `roles/*/templates/*.j2` | Jinja2 templates | No |
| `roles/app/files/app.py` | Flask application | Customize as needed |

## File Relationships

```
┌─────────────────────────────────────────────────────────┐
│                      ansible.cfg                         │
│              (Global Ansible Configuration)              │
└─────────────────────────────────────────────────────────┘
                           │
           ┌───────────────┴────────────────┐
           │                                │
┌──────────▼───────────┐        ┌──────────▼──────────┐
│  inventory/          │        │  group_vars/        │
│  - localhost.ini     │        │  - all.yml          │
│  - hosts.ini         │        │  - vault.yml        │
└──────────┬───────────┘        └──────────┬──────────┘
           │                                │
           └───────────┬────────────────────┘
                       │
           ┌───────────▼────────────────┐
           │   playbooks/                │
           │   - provision.yml           │
           │   - site.yml                │
           └───────────┬────────────────┘
                       │
           ┌───────────▼────────────────┐
           │        roles/               │
           │   ├── users/                │
           │   ├── base/                 │
           │   ├── firewall/             │
           │   ├── app/                  │
           │   └── nginx/                │
           └─────────────────────────────┘
```

## Deployment Flow

```
1. provision.yml (on localhost)
   └── Creates EC2 instance using group_vars/all.yml

2. Update inventory/hosts.ini with EC2 IP

3. site.yml (on EC2 instance)
   ├── users role
   │   └── Creates deployer user
   ├── base role
   │   ├── Updates system
   │   ├── Hardens SSH (uses templates/sshd_config.j2)
   │   └── Configures fail2ban
   ├── firewall role
   │   └── Configures UFW
   ├── app role
   │   ├── Deploys files/app.py
   │   ├── Installs files/requirements.txt
   │   └── Creates systemd service (templates/myapp.service.j2)
   └── nginx role
       └── Configures reverse proxy (templates/flask-app.conf.j2)
```

## Template Files (.j2)

All Jinja2 templates use variables from `group_vars/all.yml`:

| Template | Variables Used | Output Location |
|----------|---------------|-----------------|
| `sshd_config.j2` | ssh_* variables | `/etc/ssh/sshd_config` |
| `myapp.service.j2` | app_*, systemd_* | `/etc/systemd/system/myapp.service` |
| `flask-app.conf.j2` | nginx_*, app_* | `/etc/nginx/sites-available/myapp.conf` |

## Role Dependencies

```
users (no dependencies)
  ↓
base (requires users for SSH hardening)
  ↓
firewall (requires base packages)
  ↓
app (requires users for app_user)
  ↓
nginx (requires app to be running)
```

## Generated Files (Not in Repository)

These files are created during execution:

```
.vault_pass                        # Vault password (never commit!)
ec2_instance_info.txt             # EC2 instance details after provisioning
/tmp/ansible_fact_cache/          # Ansible fact cache
*.retry                           # Ansible retry files (if enabled)
```

## Security Notes

**Never commit these files:**
- `.vault_pass` or any vault password files
- `*.pem` or `*.key` files (SSH private keys)
- `ec2_instance_info.txt` (contains IP addresses)
- Any files containing AWS credentials

**Always encrypt:**
- `group_vars/vault.yml` if it contains sensitive data

**Always restrict permissions:**
- SSH private keys: `chmod 400 *.pem`
- Vault password: `chmod 600 .vault_pass`

## File Count Summary

```
Total Files: 30+
├── Documentation: 5 files
├── Configuration: 5 files
├── Playbooks: 2 files
├── Roles: 5 roles
│   ├── Tasks: 5 files
│   ├── Handlers: 3 files
│   ├── Templates: 3 files
│   └── Files: 2 files
└── Other: 1 file (.gitignore)
```

## Customization Guide

### To modify the Flask application:
Edit: `roles/app/files/app.py`

### To change system security settings:
Edit: `roles/base/tasks/main.yml`
Edit: `roles/base/templates/sshd_config.j2`

### To adjust firewall rules:
Edit: `group_vars/all.yml` (firewall_allowed_ports)
Edit: `roles/firewall/tasks/main.yml`

### To modify NGINX configuration:
Edit: `roles/nginx/templates/flask-app.conf.j2`
Edit: `group_vars/all.yml` (nginx_* variables)

### To change application deployment:
Edit: `roles/app/tasks/main.yml`
Edit: `roles/app/templates/myapp.service.j2`

### To add environment-specific variables:
Create: `group_vars/production.yml` or `group_vars/staging.yml`

### To create inventory groups:
Edit: `inventory/hosts.ini`
```ini
[production]
prod-server-1 ansible_host=1.2.3.4

[staging]
staging-server-1 ansible_host=5.6.7.8
```

## Execution Order

1. **Provisioning Phase:**
   ```bash
   ansible-playbook -i inventory/localhost.ini playbooks/provision.yml
   ```
   Uses: provision.yml → group_vars/all.yml → AWS

2. **Deployment Phase:**
   ```bash
   ansible-playbook -i inventory/hosts.ini playbooks/site.yml
   ```
   Uses: site.yml → inventory/hosts.ini → group_vars/all.yml → all roles

## Version Control Best Practices

**Commit to repository:**
- All `.yml`, `.j2`, `.ini` files (except vault.yml if encrypted)
- Documentation (`.md` files)
- `.gitignore`
- `roles/app/files/*` (application code)

**Do NOT commit:**
- `.vault_pass` or passwords
- `*.pem`, `*.key` (private keys)
- `ec2_instance_info.txt`
- Local cache or temporary files

## Directory Tree

```
Ansible-Claude/
├── README.md
├── STEP_BY_STEP_GUIDE.md
├── SECURITY_CHECKLIST.md
├── FILE_MANIFEST.md
├── .gitignore
├── ansible.cfg
├── group_vars/
│   ├── all.yml
│   └── vault.yml
├── inventory/
│   ├── localhost.ini
│   └── hosts.ini
├── playbooks/
│   ├── provision.yml
│   └── site.yml
└── roles/
    ├── users/
    │   └── tasks/
    │       └── main.yml
    ├── base/
    │   ├── tasks/
    │   │   └── main.yml
    │   ├── handlers/
    │   │   └── main.yml
    │   └── templates/
    │       └── sshd_config.j2
    ├── firewall/
    │   └── tasks/
    │       └── main.yml
    ├── app/
    │   ├── tasks/
    │   │   └── main.yml
    │   ├── handlers/
    │   │   └── main.yml
    │   ├── templates/
    │   │   └── myapp.service.j2
    │   └── files/
    │       ├── app.py
    │       └── requirements.txt
    └── nginx/
        ├── tasks/
        │   └── main.yml
        ├── handlers/
        │   └── main.yml
        └── templates/
            └── flask-app.conf.j2
```

---

**Total Lines of Code:** ~2000+
**Total Configuration:** ~500+ lines
**Security Controls:** 15+ implemented
**Roles:** 5 specialized roles
**Idempotent:** ✅ Yes (safe to re-run)
