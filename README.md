# Secure AWS EC2 Flask Deployment with Ansible

This project provides a complete, production-ready Ansible automation to:
1. Provision an AWS EC2 instance
2. Harden and secure the instance
3. Deploy a Flask web application behind NGINX
4. Manage the app with systemd

## Prerequisites

### On Your Local Control Machine

1. **Python 3.8+** and pip
2. **Ansible 2.10+**
   ```bash
   pip install ansible
   ```

3. **AWS CLI configured**
   ```bash
   pip install awscli
   aws configure
   # Enter your AWS Access Key ID, Secret Key, region
   ```

4. **Boto3 and Botocore** (for AWS modules)
   ```bash
   pip install boto3 botocore
   ```

5. **Ansible Collections**
   ```bash
   ansible-galaxy collection install community.aws
   ansible-galaxy collection install ansible.posix
   ```

### AWS Requirements

- IAM user with permissions for:
  - `ec2:RunInstances`
  - `ec2:DescribeInstances`
  - `ec2:CreateSecurityGroup`
  - `ec2:AuthorizeSecurityIngress`
  - `ec2:DescribeSecurityGroups`
  - `ec2:CreateTags`
  - `ec2:DescribeKeyPairs`
  - `ec2:ImportKeyPair` (if creating key pair via Ansible)

## Quick Start

### Step 1: Generate SSH Key Pair

```bash
# Generate SSH key for EC2 access
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ansible-ec2-key -C "ansible-ec2-deployment"
chmod 400 ~/.ssh/ansible-ec2-key
```

### Step 2: Configure Variables

Edit `group_vars/all.yml` and replace all `REPLACE_ME` values:

- `aws_region`: Your AWS region (e.g., `us-east-1`)
- `aws_keypair_name`: Name for your EC2 key pair
- `local_ssh_private_key`: Path to your private key (e.g., `~/.ssh/ansible-ec2-key`)
- `deployer_ssh_public_key`: Your public key content for the deployer user
- `allowed_ssh_ips`: CIDR blocks allowed to SSH (default: `0.0.0.0/0` - **change this!**)
- `app_domain`: Your domain or leave as `"{{ ansible_host }}"` to use IP

### Step 3: Setup Ansible Vault for Secrets

```bash
# Run the automated vault setup
./scripts/vault-setup.sh

# This will:
# - Create a secure vault password
# - Encrypt group_vars/vault.yml
# - Show you how to configure GitHub Secrets
```

**Wichtig:** Lies den [Vault Guide](VAULT_GUIDE.md) für Details zur Secrets-Verwaltung!

**Quick Reference:** [Vault Quick Reference](VAULT_QUICK_REFERENCE.md)

### Step 4: Provision EC2 Instance

```bash
# Provision the EC2 instance
ansible-playbook -i inventory/localhost.ini playbooks/provision.yml

# The playbook will output the instance public IP
# Copy this IP and add it to inventory/hosts.ini
```

### Step 5: Update Inventory

After provisioning, edit `inventory/hosts.ini` and replace `REPLACE_WITH_EC2_PUBLIC_IP` with the actual IP address from Step 4.

### Step 6: Wait for Instance to be Ready

```bash
# Wait for SSH to be available (may take 30-60 seconds)
ansible -i inventory/hosts.ini ec2_instances -m wait_for_connection -u ubuntu --private-key ~/.ssh/ansible-ec2-key
```

### Step 7: Deploy Application

```bash
# Run the main deployment playbook
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --private-key ~/.ssh/ansible-ec2-key
```

### Step 8: Verify Deployment

```bash
# Get the public IP from your inventory
EC2_IP="YOUR_EC2_PUBLIC_IP"

# Test the application
curl http://$EC2_IP

# Should return: "Hello from Flask on EC2!"
```

## CI/CD mit GitHub Actions

Dieses Projekt enthält vollständige GitHub Actions Workflows für automatisiertes Testing und Deployment:

### Features
- ✅ Automatisches Linting (yamllint, ansible-lint)
- ✅ Syntax-Prüfung aller Playbooks
- ✅ Security Scanning (Trivy)
- ✅ Vault-Verschlüsselung Verifikation
- ✅ Automatisches Deployment (manuell trigger)

### Setup
Siehe [GitHub Actions Setup Guide](GITHUB_ACTIONS_SETUP.md) für Details.

### Quick Start CI/CD

```bash
# 1. Push zu GitHub
git push origin main

# 2. Workflows laufen automatisch
# 3. Manuelles Deployment: Actions Tab > Run workflow
```

## Project Structure

```
.
├── README.md                          # This file
├── VAULT_GUIDE.md                     # Ansible Vault Anleitung
├── VAULT_QUICK_REFERENCE.md           # Vault Quick Reference
├── GITHUB_ACTIONS_SETUP.md            # CI/CD Setup Guide
├── ansible.cfg                        # Ansible configuration
├── .github/
│   └── workflows/
│       ├── ansible-ci.yml             # Main CI/CD pipeline
│       └── test.yml                   # Testing pipeline
├── scripts/
│   ├── vault-setup.sh                 # Vault initial setup
│   ├── vault-edit.sh                  # Edit vault file
│   ├── vault-view.sh                  # View vault file
│   └── vault-status.sh                # Check vault status
├── inventory/
│   ├── localhost.ini                  # Localhost inventory for provisioning
│   └── hosts.ini                      # EC2 instance inventory (update after provision)
├── group_vars/
│   ├── all.yml                        # Non-sensitive variables
│   └── vault.yml                      # Sensitive variables (encrypt with ansible-vault)
├── playbooks/
│   ├── provision.yml                  # EC2 provisioning playbook
│   ├── site.yml                       # Main deployment playbook
│   └── cleanup.yml                    # Cleanup playbook
├── roles/
│   ├── provision_ec2/                 # AWS EC2 provisioning
│   │   └── tasks/main.yml
│   ├── base/                          # System hardening and updates
│   │   ├── tasks/main.yml
│   │   └── handlers/main.yml
│   ├── users/                         # Create deployer user
│   │   └── tasks/main.yml
│   ├── firewall/                      # UFW configuration
│   │   └── tasks/main.yml
│   ├── app/                           # Flask app deployment
│   │   ├── tasks/main.yml
│   │   ├── templates/
│   │   │   └── myapp.service.j2
│   │   └── files/
│   │       ├── app.py
│   │       └── requirements.txt
│   └── nginx/                         # NGINX reverse proxy
│       ├── tasks/main.yml
│       ├── templates/
│       │   └── flask-app.conf.j2
│       └── handlers/main.yml
└── files/
    └── sshd_config.j2                 # Hardened SSH config template
```

## Idempotency

All roles are designed to be idempotent. You can safely re-run the playbook multiple times:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --private-key ~/.ssh/ansible-ec2-key
```

Each run should show minimal changes after the first successful deployment.

## Security Features

- ✅ Non-root user (`deployer`) with sudo access
- ✅ SSH key-based authentication only
- ✅ Root login disabled
- ✅ Password authentication disabled
- ✅ UFW firewall configured (ports 22, 80, 443 only)
- ✅ Automatic security updates enabled
- ✅ Fail2ban for SSH brute-force protection
- ✅ Application runs as non-privileged user
- ✅ Systemd service with restart policies
- ✅ NGINX reverse proxy (no direct app exposure)

## Post-Deployment Verification

See [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md) for detailed verification steps.

Quick checks:

```bash
# SSH into the instance as deployer (not ubuntu)
ssh -i ~/.ssh/ansible-ec2-key deployer@YOUR_EC2_IP

# Check app status
sudo systemctl status myapp

# Check nginx status
sudo systemctl status nginx

# Check firewall
sudo ufw status verbose

# Check open ports
sudo ss -tunlp

# Check fail2ban
sudo fail2ban-client status sshd
```

## Adding TLS/SSL (Optional)

If you have a domain pointing to your EC2 instance:

1. Update `app_domain` in `group_vars/all.yml`
2. Run the playbook
3. SSH to the instance and run:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

## Troubleshooting

### Instance not reachable after provision
- Wait 60 seconds for instance initialization
- Check security group allows SSH from your IP
- Verify key permissions: `chmod 400 ~/.ssh/ansible-ec2-key`

### "Permission denied (publickey)" error
- Ensure you're using the correct private key with `--private-key`
- For initial connection, use `-u ubuntu` (default AMI user)
- After deployment, use `-u deployer`

### Application not responding
```bash
ssh -i ~/.ssh/ansible-ec2-key deployer@YOUR_EC2_IP
sudo systemctl status myapp
sudo journalctl -u myapp -n 50
```

### Nginx errors
```bash
sudo nginx -t  # Test configuration
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log
```

## Cleanup / Destroy Resources

### Option 1: Automated Cleanup Playbook (Recommended)

```bash
# Run the cleanup playbook
ansible-playbook -i inventory/localhost.ini playbooks/cleanup.yml

# You'll be prompted to confirm destruction
# Type 'yes' to proceed
```

### Option 2: Bash Script

```bash
# Run the cleanup script
./scripts/cleanup.sh

# Follow the prompts to confirm
```

### Option 3: Manual AWS CLI

```bash
# Get instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ansible-managed-ec2" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text --region us-west-2)

# Terminate instance
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region us-west-2

# Wait for termination
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region us-west-2

# Delete security group
aws ec2 delete-security-group --group-name ansible-ec2-sg --region us-west-2

# Delete key pair
aws ec2 delete-key-pair --key-name ansible-ec2-keypair --region us-west-2
```

**Note:** The cleanup playbook and script will:
- Terminate all EC2 instances with tag `Name=ansible-managed-ec2`
- Delete the security group
- Delete the AWS key pair
- Generate a cleanup log file
- Prompt for confirmation before destroying anything

## License

MIT

## Contributing

Contributions welcome! Please test changes in a non-production environment first.
