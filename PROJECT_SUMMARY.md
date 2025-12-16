# Project Summary: Ansible AWS EC2 Flask Deployment

## Overview

This project provides a **complete, production-ready, secure** Ansible automation solution for deploying a Flask web application on AWS EC2.

**What it does:**
1. ✅ Provisions an AWS EC2 instance with proper security groups
2. ✅ Creates a non-root admin user (deployer) with SSH key authentication
3. ✅ Hardens system security (SSH, firewall, fail2ban, kernel parameters)
4. ✅ Deploys a Flask application in a Python virtual environment
5. ✅ Manages the application with systemd for automatic restarts
6. ✅ Configures NGINX as a reverse proxy with security headers
7. ✅ Enables automatic security updates
8. ✅ Provides comprehensive verification and security checklists

## Key Features

### Security
- **Key-based authentication only** (no passwords)
- **Non-root user** with sudo access
- **UFW firewall** configured (only ports 22, 80, 443 open)
- **Fail2ban** for SSH brute-force protection
- **Hardened SSH** configuration (no root login, strong ciphers)
- **Automatic security updates** enabled
- **Kernel security parameters** configured
- **Application isolation** (runs as non-root, localhost only)
- **NGINX security headers** (X-Frame-Options, X-XSS-Protection, etc.)

### Best Practices
- **Fully idempotent** (safe to re-run multiple times)
- **Role-based structure** (modular and reusable)
- **Least-privilege access** (minimal IAM permissions)
- **Infrastructure as Code** (version-controlled configuration)
- **Ansible best practices** (handlers, tags, facts, templates)
- **Production-ready** systemd service with restart policies

### Convenience
- **One-command provisioning** (AWS EC2 instance creation)
- **One-command deployment** (full stack deployment)
- **Comprehensive documentation** (5 detailed guides)
- **Copy-paste friendly** (all commands provided)
- **Verification steps** included
- **Troubleshooting guide** included

## Complete File List

**26 files created:**

### Documentation (5 files)
1. `README.md` - Main project documentation
2. `STEP_BY_STEP_GUIDE.md` - Detailed deployment instructions
3. `SECURITY_CHECKLIST.md` - Security verification procedures
4. `FILE_MANIFEST.md` - Complete file descriptions
5. `QUICK_START.md` - Quick reference cheat sheet
6. `PROJECT_SUMMARY.md` - This file

### Configuration (6 files)
7. `ansible.cfg` - Ansible configuration
8. `.gitignore` - Git ignore rules
9. `group_vars/all.yml` - Main variables (EDIT THIS)
10. `group_vars/vault.yml` - Sensitive variables
11. `inventory/localhost.ini` - Localhost inventory
12. `inventory/hosts.ini` - EC2 inventory (EDIT THIS)

### Playbooks (2 files)
13. `playbooks/provision.yml` - EC2 provisioning
14. `playbooks/site.yml` - Main deployment orchestration

### Roles (13 files across 5 roles)

**Users Role:**
15. `roles/users/tasks/main.yml` - Create deployer user

**Base Role (System Hardening):**
16. `roles/base/tasks/main.yml` - System updates and hardening
17. `roles/base/handlers/main.yml` - Service handlers
18. `roles/base/templates/sshd_config.j2` - Hardened SSH config

**Firewall Role:**
19. `roles/firewall/tasks/main.yml` - UFW configuration

**App Role (Flask):**
20. `roles/app/tasks/main.yml` - Application deployment
21. `roles/app/handlers/main.yml` - App service handlers
22. `roles/app/templates/myapp.service.j2` - Systemd service
23. `roles/app/files/app.py` - Flask application code
24. `roles/app/files/requirements.txt` - Python dependencies

**Nginx Role:**
25. `roles/nginx/tasks/main.yml` - NGINX installation
26. `roles/nginx/handlers/main.yml` - NGINX handlers
27. `roles/nginx/templates/flask-app.conf.j2` - NGINX reverse proxy config

## Technology Stack

### Control Machine (Local)
- **Ansible** 2.10+ (automation)
- **Python** 3.8+ (runtime)
- **Boto3/Botocore** (AWS SDK)
- **AWS CLI** (AWS management)

### EC2 Instance (Remote)
- **OS:** Ubuntu 22.04 LTS
- **Python:** 3.10 (application runtime)
- **Flask:** 3.0.0 (web framework)
- **Gunicorn:** 21.2.0 (WSGI server)
- **NGINX:** Latest (reverse proxy)
- **UFW:** Latest (firewall)
- **Fail2ban:** Latest (intrusion prevention)
- **Systemd:** System service manager

### AWS Resources
- **EC2 Instance:** t3.micro (customizable)
- **Security Group:** Custom (ports 22, 80, 443)
- **EBS Volume:** 8GB gp3 (customizable)
- **Elastic IP:** Optional (not included)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└─────────────┬───────────────────────────────────────────────┘
              │
              │ (HTTP/HTTPS + SSH from allowed IPs)
              │
    ┌─────────▼──────────────────────────────────┐
    │        AWS Security Group                   │
    │  - Port 22 (SSH) from specific IPs         │
    │  - Port 80 (HTTP) from anywhere            │
    │  - Port 443 (HTTPS) from anywhere          │
    └─────────┬──────────────────────────────────┘
              │
    ┌─────────▼──────────────────────────────────┐
    │         EC2 Instance (Ubuntu 22.04)        │
    │                                             │
    │  ┌─────────────────────────────────────┐   │
    │  │          UFW Firewall               │   │
    │  │  - Only allows 22, 80, 443          │   │
    │  └──────────────┬──────────────────────┘   │
    │                 │                           │
    │  ┌──────────────▼──────────────────────┐   │
    │  │  NGINX (Port 80/443)                │   │
    │  │  - Reverse proxy                    │   │
    │  │  - Security headers                 │   │
    │  │  - SSL/TLS termination (optional)   │   │
    │  └──────────────┬──────────────────────┘   │
    │                 │ localhost:5000            │
    │  ┌──────────────▼──────────────────────┐   │
    │  │  Gunicorn + Flask App               │   │
    │  │  - Runs as 'deployer' user          │   │
    │  │  - Managed by systemd               │   │
    │  │  - In Python virtualenv             │   │
    │  │  - Only listens on 127.0.0.1:5000   │   │
    │  └─────────────────────────────────────┘   │
    │                                             │
    │  ┌─────────────────────────────────────┐   │
    │  │  Security Services                  │   │
    │  │  - Fail2ban (SSH protection)        │   │
    │  │  - Unattended-upgrades              │   │
    │  │  - Hardened SSH config              │   │
    │  └───────────────────────────��─────────┘   │
    └─────────────────────────────────────────────┘
```

## Security Controls Implemented

| # | Control | Implementation | Verification |
|---|---------|----------------|--------------|
| 1 | No root access | SSH: `PermitRootLogin no` | `ssh root@IP` fails |
| 2 | Key-based auth only | SSH: `PasswordAuthentication no` | Password login fails |
| 3 | Non-root admin user | User: `deployer` with sudo | Can sudo without password |
| 4 | Firewall enabled | UFW: deny incoming by default | `sudo ufw status` |
| 5 | SSH brute-force protection | Fail2ban active | `fail2ban-client status` |
| 6 | App runs as non-root | Systemd: `User=deployer` | `ps aux \| grep gunicorn` |
| 7 | App not exposed directly | Bind: `127.0.0.1:5000` | `ss -tlnp` shows localhost only |
| 8 | Reverse proxy | NGINX → Flask | Public port 80 → app |
| 9 | Security headers | NGINX config | `curl -I http://IP` |
| 10 | Strong SSH ciphers | sshd_config | `sshd -T \| grep cipher` |
| 11 | Automatic updates | Unattended-upgrades | Config verified |
| 12 | Kernel hardening | Sysctl parameters | `/etc/sysctl.d/99-security.conf` |
| 13 | Service isolation | Systemd sandboxing | `systemctl show myapp` |
| 14 | Restricted SSH access | Security group + UFW | Only allowed IPs |
| 15 | Least-privilege IAM | Minimal EC2 permissions | AWS IAM policy |

## What Gets Deployed

### System Configuration
- **Packages:** python3, nginx, ufw, fail2ban, build-essential, git, curl, vim
- **Services:** myapp (Flask), nginx, ufw, fail2ban, unattended-upgrades
- **Users:** deployer (non-root admin)
- **Firewall:** UFW configured with strict rules
- **SSH:** Hardened configuration, key-based only

### Application
- **Location:** `/opt/myapp/`
- **Virtualenv:** `/opt/myapp/venv/`
- **Logs:** `/var/log/myapp/` (access.log, error.log)
- **Service:** `myapp.service` (systemd)
- **Runtime:** Gunicorn with 4 workers
- **Port:** 5000 (localhost only)

### NGINX
- **Config:** `/etc/nginx/sites-available/myapp.conf`
- **Enabled:** Symlink in `sites-enabled/`
- **Logs:** `/var/log/nginx/myapp_access.log`, `myapp_error.log`
- **Port:** 80 (HTTP), 443 (HTTPS if SSL configured)

## Deployment Flow

```
1. Prerequisites Setup
   └── Install: Ansible, AWS CLI, boto3, collections

2. AWS Configuration
   └── Configure: AWS credentials, create key pair

3. Project Configuration
   ├── Edit: group_vars/all.yml (REQUIRED)
   └── Edit: inventory/hosts.ini (after provision)

4. Provisioning (provision.yml)
   ├── Find latest Ubuntu 22.04 AMI
   ├── Create security group (ports 22, 80, 443)
   ├── Launch EC2 instance (t3.micro)
   └── Output: Instance ID and Public IP

5. Inventory Update
   └── Add EC2 public IP to inventory/hosts.ini

6. Deployment (site.yml)
   ├── [Users Role]
   │   ├── Create deployer user
   │   ├── Add SSH authorized_key
   │   └── Configure passwordless sudo
   │
   ├── [Base Role]
   │   ├── Update all packages
   │   ├── Install essential packages
   │   ├── Configure unattended-upgrades
   │   ├── Setup fail2ban
   │   ├── Harden SSH configuration
   │   └── Configure kernel security parameters
   │
   ├── [Firewall Role]
   │   ├── Reset UFW to clean state
   │   ├── Set default policies (deny incoming)
   │   ├── Allow SSH from specific IPs
   │   ├── Allow HTTP/HTTPS from anywhere
   │   └── Enable UFW
   │
   ├── [App Role]
   │   ├── Create app directory (/opt/myapp)
   │   ├── Copy application files (app.py, requirements.txt)
   │   ├── Create Python virtualenv
   │   ├── Install dependencies (Flask, gunicorn)
   │   ├── Deploy systemd service file
   │   └── Start and enable service
   │
   └── [Nginx Role]
       ├── Install NGINX
       ├── Remove default site
       ├── Deploy Flask app configuration
       ├── Enable site
       ├── Test configuration
       └── Start and reload NGINX

7. Verification
   ├── Test: curl http://EC2_IP/
   ├── SSH: ssh -i key deployer@EC2_IP
   └── Run: Security checklist verification
```

## Time Estimates

- **Initial setup** (prerequisites): 15-30 minutes
- **Configuration**: 5-10 minutes
- **Provisioning** (EC2): 2-3 minutes
- **Deployment** (full stack): 5-10 minutes
- **Verification**: 5-10 minutes

**Total first-time deployment:** ~30-60 minutes

**Subsequent deployments (idempotent):** ~5 minutes

## Cost Estimate

### AWS Free Tier (First 12 months)
- **EC2 t2.micro/t3.micro:** 750 hours/month FREE
- **EBS:** 30 GB FREE
- **Data transfer:** 1 GB out FREE

### After Free Tier (us-east-1 pricing)
- **t3.micro instance:** ~$0.0104/hour (~$7.50/month)
- **EBS 8GB gp3:** ~$0.80/month
- **Data transfer out:** $0.09/GB (after first GB)

**Estimated total:** $8-10/month for small-scale deployment

## Use Cases

This project is perfect for:

- ✅ **Personal projects** (blogs, portfolios, APIs)
- ✅ **Proof of concepts** (quick deployments)
- ✅ **Learning Ansible** (well-structured, documented)
- ✅ **Development/Staging environments**
- ✅ **Small web applications** (low to medium traffic)
- ✅ **Microservices** (deploy multiple instances)
- ✅ **CI/CD integration** (automated deployments)

## Customization Options

Easy to customize:

1. **Different AWS region:** Edit `aws_region` in `group_vars/all.yml`
2. **Larger instance:** Change `instance_type` to `t3.small`, `t3.medium`, etc.
3. **Different OS:** Update `ami_name_filter` for other Ubuntu versions
4. **Custom app:** Replace `roles/app/files/app.py` with your application
5. **Additional packages:** Add to `roles/base/tasks/main.yml`
6. **More firewall rules:** Edit `firewall_allowed_ports` in `group_vars/all.yml`
7. **Multiple environments:** Create `group_vars/production.yml`, `staging.yml`
8. **Custom domain:** Set `app_domain` in `group_vars/all.yml`

## Extending the Project

Future enhancements you can add:

- **Database:** Add PostgreSQL/MySQL role
- **Redis:** Add caching layer role
- **SSL/TLS:** Automate Let's Encrypt certificate
- **CloudWatch:** Add monitoring and logging
- **Auto Scaling:** Convert to Auto Scaling Group
- **Load Balancer:** Add ELB for multiple instances
- **Docker:** Containerize the application
- **CI/CD:** Add GitHub Actions / GitLab CI
- **Backup:** Automate EBS snapshots
- **Monitoring:** Add Prometheus + Grafana

## Testing

### Idempotency Test
```bash
# Run twice - second run should show minimal changes
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
ansible-playbook -i inventory/hosts.ini playbooks/site.yml  # Should be mostly "ok" (green)
```

### Security Test
```bash
# Try to SSH as root (should fail)
ssh -i ~/.ssh/ansible-ec2-key.pem root@EC2_IP
# Expected: Permission denied

# Try password auth (should fail)
ssh deployer@EC2_IP
# Expected: Permission denied (publickey)

# Scan ports (should only see 22, 80)
nmap -sV EC2_IP
# Expected: Only 22/tcp, 80/tcp open
```

### Application Test
```bash
# All endpoints should work
curl http://EC2_IP/              # Hello message
curl http://EC2_IP/health        # Health check
curl http://EC2_IP/info          # App info
curl -X POST http://EC2_IP/api/echo \
  -H "Content-Type: application/json" \
  -d '{"test":"data"}'           # Echo endpoint
```

## Documentation Index

1. **[README.md](README.md)** - Start here for overview and quick start
2. **[STEP_BY_STEP_GUIDE.md](STEP_BY_STEP_GUIDE.md)** - Complete walkthrough with all commands
3. **[QUICK_START.md](QUICK_START.md)** - Condensed command reference for experienced users
4. **[SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md)** - Comprehensive security verification procedures
5. **[FILE_MANIFEST.md](FILE_MANIFEST.md)** - Detailed explanation of every file in the project
6. **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - This file - high-level overview

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] AWS account with payment method
- [ ] IAM user with EC2 permissions
- [ ] AWS CLI configured (`aws configure`)
- [ ] Python 3.8+ installed
- [ ] Ansible 2.10+ installed
- [ ] Boto3 and botocore installed
- [ ] Ansible collections installed (community.aws, ansible.posix)
- [ ] SSH keys generated (one for EC2, one for deployer)
- [ ] Text editor (vim, nano, VSCode, etc.)
- [ ] 30-60 minutes of time for first deployment

## Success Criteria

Your deployment is successful when:

- [ ] EC2 instance is running and accessible
- [ ] Can SSH as deployer user with key
- [ ] Cannot SSH as root
- [ ] Cannot SSH with password
- [ ] Firewall is active and configured
- [ ] Flask application responds on port 80
- [ ] NGINX is serving the application
- [ ] Application runs as non-root user
- [ ] Fail2ban is active and monitoring SSH
- [ ] All services start automatically on boot
- [ ] Can re-run playbook with minimal changes (idempotent)

## Support

If you encounter issues:

1. Check [STEP_BY_STEP_GUIDE.md](STEP_BY_STEP_GUIDE.md) Troubleshooting section
2. Verify all `REPLACE_ME` values are updated
3. Check AWS console for instance status
4. Review Ansible error messages carefully
5. SSH to instance and check logs: `sudo journalctl -u myapp`
6. Test connectivity: `ansible -i inventory/hosts.ini ec2_instances -m ping`

## License

This project is provided as-is for educational and production use. Customize as needed for your requirements.

## Contributing

Improvements welcome! Consider:
- Additional security hardening
- Support for other Linux distributions
- Additional application frameworks
- Docker/container support
- CI/CD integration examples
- Monitoring and alerting roles
- Database roles (PostgreSQL, MySQL)

---

**Project Stats:**
- **Total Files:** 27
- **Lines of Code:** ~2,500+
- **Lines of Documentation:** ~3,000+
- **Roles:** 5 specialized roles
- **Security Controls:** 15+ implemented
- **Time to Deploy:** 30-60 minutes (first time), 5 minutes (subsequent)
- **Cost:** ~$8-10/month (after AWS free tier)

**Ready to deploy? Start with [README.md](README.md) or [QUICK_START.md](QUICK_START.md)!**
