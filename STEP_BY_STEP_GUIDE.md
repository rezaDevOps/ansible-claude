# Step-by-Step Deployment Guide

This guide walks you through deploying a secure Flask application on AWS EC2 from scratch.

## Table of Contents

1. [Prerequisites Setup](#prerequisites-setup)
2. [AWS Preparation](#aws-preparation)
3. [SSH Key Generation](#ssh-key-generation)
4. [Configuration](#configuration)
5. [Provisioning](#provisioning)
6. [Deployment](#deployment)
7. [Verification](#verification)
8. [Post-Deployment](#post-deployment)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites Setup

### 1. Install Required Software

#### On macOS:
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Python 3
brew install python3

# Install pip packages
pip3 install ansible boto3 botocore awscli

# Verify installations
ansible --version
aws --version
python3 --version
```

#### On Ubuntu/Debian:
```bash
# Update package list
sudo apt update

# Install Python and pip
sudo apt install -y python3 python3-pip

# Install Ansible and AWS tools
pip3 install ansible boto3 botocore awscli

# Add pip bin to PATH (add to ~/.bashrc)
export PATH="$HOME/.local/bin:$PATH"

# Verify installations
ansible --version
aws --version
python3 --version
```

### 2. Install Ansible Collections

```bash
# Install required Ansible collections
ansible-galaxy collection install community.aws
ansible-galaxy collection install ansible.posix
ansible-galaxy collection install community.general

# Verify installation
ansible-galaxy collection list
```

**Expected output:**
```
# /Users/your-user/.ansible/collections/ansible_collections
Collection        Version
----------------- -------
ansible.posix     1.x.x
community.aws     6.x.x
community.general 7.x.x
```

---

## AWS Preparation

### 1. Create IAM User

1. Log into AWS Console → IAM → Users → Create User
2. User name: `ansible-deployer`
3. Enable "Programmatic access"
4. Attach policies:
   - `AmazonEC2FullAccess` (or create custom minimal policy below)

**Minimal IAM Policy (recommended):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:RunInstances",
        "ec2:DescribeInstances",
        "ec2:CreateSecurityGroup",
        "ec2:AuthorizeSecurityIngress",
        "ec2:DescribeSecurityGroups",
        "ec2:CreateTags",
        "ec2:DescribeKeyPairs",
        "ec2:DescribeImages",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeVolumes"
      ],
      "Resource": "*"
    }
  ]
}
```

5. Save the Access Key ID and Secret Access Key

### 2. Configure AWS CLI

```bash
# Configure AWS credentials
aws configure

# Enter the following when prompted:
# AWS Access Key ID: <YOUR_ACCESS_KEY_ID>
# AWS Secret Access Key: <YOUR_SECRET_ACCESS_KEY>
# Default region name: us-east-1  (or your preferred region)
# Default output format: json

# Verify configuration
aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "AIDAXXXXXXXXXXXXXXXXX",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/ansible-deployer"
# }
```

### 3. Create or Import EC2 Key Pair

**Option A: Create new key pair in AWS (easier)**
```bash
# Create key pair in AWS
aws ec2 create-key-pair \
    --key-name ansible-ec2-keypair \
    --region us-east-1 \
    --query 'KeyMaterial' \
    --output text > ~/.ssh/ansible-ec2-key.pem

# Set correct permissions
chmod 400 ~/.ssh/ansible-ec2-key.pem

# Verify
ls -la ~/.ssh/ansible-ec2-key.pem
# Expected: -r-------- 1 user group ... ansible-ec2-key.pem
```

**Option B: Import existing key (if you prefer)**
```bash
# Import your public key to AWS
aws ec2 import-key-pair \
    --key-name ansible-ec2-keypair \
    --region us-east-1 \
    --public-key-material fileb://~/.ssh/id_rsa.pub
```

---

## SSH Key Generation

### 1. Generate SSH Key for Deployer User

This key will be used for the non-root deployer user on the EC2 instance.

```bash
# Generate a new SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/deployer-key -C "deployer@ansible-managed-ec2"

# When prompted:
# - Enter passphrase (optional but recommended): <your-passphrase>
# - Confirm passphrase

# Set correct permissions
chmod 600 ~/.ssh/deployer-key
chmod 644 ~/.ssh/deployer-key.pub

# View the public key (you'll need this for configuration)
cat ~/.ssh/deployer-key.pub
```

**Copy the entire output** - it should look like:
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... deployer@ansible-managed-ec2
```

---

## Configuration

### 1. Clone or Download This Project

```bash
# If you haven't already, navigate to the project directory
cd /path/to/Ansible-Claude
```

### 2. Configure Variables

Edit `group_vars/all.yml` and replace all `REPLACE_ME` values:

```bash
# Open in your editor
vim group_vars/all.yml
# or
nano group_vars/all.yml
# or
code group_vars/all.yml
```

**Required changes:**

```yaml
# AWS Configuration
aws_region: "us-east-1"  # Your AWS region
aws_keypair_name: "ansible-ec2-keypair"  # Name from AWS key pair step

# SSH Configuration
local_ssh_private_key: "~/.ssh/ansible-ec2-key.pem"  # Path to AWS key pair
deployer_ssh_public_key: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC..."  # deployer-key.pub content

# Security: IMPORTANT - Restrict SSH access!
allowed_ssh_ips:
  - "YOUR_PUBLIC_IP/32"  # Use: curl ifconfig.me

# Optional: Set your domain (or leave as-is to use IP)
# app_domain: "example.com"
```

**Get your public IP:**
```bash
curl ifconfig.me
# Output: 203.0.113.42

# Then set in all.yml:
# allowed_ssh_ips:
#   - "203.0.113.42/32"
```

### 3. Update Inventory SSH Key Path

Edit `inventory/hosts.ini`:

```bash
vim inventory/hosts.ini
```

Change:
```ini
ansible_ssh_private_key_file=~/.ssh/REPLACE_ME_ansible-ec2-key
```

To:
```ini
ansible_ssh_private_key_file=~/.ssh/ansible-ec2-key.pem
```

### 4. (Optional) Encrypt Sensitive Variables

```bash
# Create vault password file (do NOT commit this)
echo "your-strong-vault-password-here" > .vault_pass
chmod 600 .vault_pass

# Add to .gitignore
echo ".vault_pass" >> .gitignore

# Encrypt vault file
ansible-vault encrypt group_vars/vault.yml --vault-password-file .vault_pass

# To edit later:
ansible-vault edit group_vars/vault.yml --vault-password-file .vault_pass
```

---

## Provisioning

### 1. Verify Configuration

```bash
# Test AWS connectivity
aws ec2 describe-regions --region us-east-1

# Check Ansible syntax
ansible-playbook --syntax-check -i inventory/localhost.ini playbooks/provision.yml
```

### 2. Provision EC2 Instance

```bash
# Run provisioning playbook
ansible-playbook -i inventory/localhost.ini playbooks/provision.yml

# This will:
# - Find latest Ubuntu 22.04 AMI
# - Create security group
# - Launch EC2 instance
# - Display instance information
```

**Expected output:**
```
TASK [Display instance information] *******************************************
ok: [localhost] => {
    "msg": [
        "==========================================",
        "EC2 Instance provisioned successfully!",
        "==========================================",
        "Instance ID: i-0123456789abcdef0",
        "Public IP: 54.123.45.67",
        "Private IP: 172.31.12.34",
        ...
    ]
}
```

**IMPORTANT:** Copy the Public IP address!

### 3. Update Inventory with EC2 IP

Edit `inventory/hosts.ini`:

```bash
vim inventory/hosts.ini
```

Replace `REPLACE_WITH_EC2_PUBLIC_IP` with your EC2 public IP:

```ini
[ec2_instances]
54.123.45.67  # Your actual EC2 public IP
```

### 4. Wait for Instance Initialization

```bash
# Wait 30-60 seconds for cloud-init to complete
sleep 60

# Test SSH connectivity (should use 'ubuntu' user initially)
ssh -i ~/.ssh/ansible-ec2-key.pem ubuntu@54.123.45.67

# If connection successful, exit:
exit
```

### 5. Test Ansible Connectivity

```bash
# Ping the EC2 instance
ansible -i inventory/hosts.ini ec2_instances -m ping --private-key ~/.ssh/ansible-ec2-key.pem -u ubuntu

# Expected output:
# 54.123.45.67 | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

---

## Deployment

### 1. Run Main Deployment Playbook

```bash
# Deploy the full stack
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --private-key ~/.ssh/ansible-ec2-key.pem

# This will take 5-10 minutes and will:
# - Create deployer user
# - Harden system security
# - Configure firewall
# - Deploy Flask application
# - Install and configure NGINX
```

**Expected output (abbreviated):**
```
PLAY [Deploy Flask Application to EC2] ****************************************

TASK [users : Create deployer user] *******************************************
changed: [54.123.45.67]

TASK [base : Update all packages] *********************************************
changed: [54.123.45.67]

TASK [firewall : Enable UFW] **************************************************
changed: [54.123.45.67]

TASK [app : Deploy Flask application] *****************************************
changed: [54.123.45.67]

TASK [nginx : Configure NGINX] ************************************************
changed: [54.123.45.67]

PLAY RECAP ********************************************************************
54.123.45.67               : ok=47   changed=32   unreachable=0    failed=0
```

### 2. Monitor Deployment Progress

If you want to watch the deployment in detail:

```bash
# Run with verbose output
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --private-key ~/.ssh/ansible-ec2-key.pem -v

# Or with more verbosity (-vv, -vvv, or -vvvv)
```

---

## Verification

### 1. Test Application Endpoint

```bash
# Replace with your EC2 public IP
EC2_IP="54.123.45.67"

# Test HTTP endpoint
curl http://$EC2_IP/

# Expected output:
# {
#   "message": "Hello from Flask on EC2!",
#   "status": "running",
#   "timestamp": "2024-01-15T10:30:00.123456",
#   "hostname": "ip-172-31-12-34"
# }
```

### 2. Test Additional Endpoints

```bash
# Health check
curl http://$EC2_IP/health

# Application info
curl http://$EC2_IP/info

# Echo endpoint (POST)
curl -X POST http://$EC2_IP/api/echo \
  -H "Content-Type: application/json" \
  -d '{"test": "Hello from client"}'
```

### 3. SSH as Deployer User

```bash
# SSH using deployer key (NOT the AWS key pair)
ssh -i ~/.ssh/deployer-key deployer@$EC2_IP

# Once connected, verify services:
sudo systemctl status myapp
sudo systemctl status nginx
sudo ufw status verbose

# Exit
exit
```

### 4. Run Security Verification

Follow the comprehensive checks in [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md).

Quick verification:
```bash
# SSH to instance
ssh -i ~/.ssh/deployer-key deployer@$EC2_IP

# Check services
sudo systemctl status myapp nginx fail2ban

# Check firewall
sudo ufw status verbose

# Check application is NOT exposed directly
sudo ss -tlnp | grep 5000
# Should show: 127.0.0.1:5000 (not 0.0.0.0:5000)

# Exit
exit
```

---

## Post-Deployment

### 1. Test Idempotency

Re-run the playbook to verify idempotency:

```bash
# Run again - should show minimal changes
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --private-key ~/.ssh/ansible-ec2-key.pem

# Expected: Most tasks should show "ok" (green), very few "changed" (yellow)
```

### 2. Update Inventory for Future Use

After deployer user is created, update `inventory/hosts.ini`:

```ini
[ec2_instances]
54.123.45.67

[ec2_instances:vars]
ansible_user=deployer  # Changed from ubuntu
ansible_ssh_private_key_file=~/.ssh/deployer-key  # Changed to deployer key
ansible_python_interpreter=/usr/bin/python3
```

### 3. Test with Deployer User

```bash
# Test Ansible with deployer user
ansible -i inventory/hosts.ini ec2_instances -m ping

# Run playbook with default config (no --private-key needed)
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
```

### 4. Configure DNS (Optional)

If you have a domain:

1. **Add A record** in your DNS provider:
   - Type: A
   - Name: @ (or subdomain)
   - Value: 54.123.45.67 (your EC2 IP)
   - TTL: 300

2. **Update configuration**:
   ```bash
   vim group_vars/all.yml
   # Change: app_domain: "yourdomain.com"
   ```

3. **Re-run playbook**:
   ```bash
   ansible-playbook -i inventory/hosts.ini playbooks/site.yml
   ```

### 5. Add SSL/TLS (Optional)

```bash
# SSH to instance
ssh -i ~/.ssh/deployer-key deployer@$EC2_IP

# Install certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain certificate (replace with your domain)
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Follow prompts:
# - Enter email address
# - Agree to terms
# - Choose redirect option (recommended)

# Verify certificate
sudo certbot certificates

# Test auto-renewal
sudo certbot renew --dry-run

# Exit
exit
```

Test HTTPS:
```bash
curl https://yourdomain.com/
```

---

## Troubleshooting

### Issue: Cannot connect to EC2 instance

**Symptoms:**
```bash
ssh: connect to host 54.123.45.67 port 22: Connection refused
```

**Solutions:**

1. **Wait for initialization:**
   ```bash
   # Wait 60 seconds and try again
   sleep 60
   ```

2. **Check security group:**
   ```bash
   aws ec2 describe-security-groups --group-names ansible-ec2-sg --region us-east-1
   # Verify your IP is in the SSH rule
   ```

3. **Update security group if needed:**
   ```bash
   # Get your current IP
   MY_IP=$(curl -s ifconfig.me)

   # Add your IP to security group
   aws ec2 authorize-security-group-ingress \
     --group-name ansible-ec2-sg \
     --protocol tcp \
     --port 22 \
     --cidr $MY_IP/32 \
     --region us-east-1
   ```

4. **Check instance status:**
   ```bash
   aws ec2 describe-instance-status --instance-ids i-0123456789abcdef0 --region us-east-1
   ```

### Issue: Permission denied (publickey)

**Symptoms:**
```bash
Permission denied (publickey).
```

**Solutions:**

1. **Check key permissions:**
   ```bash
   chmod 400 ~/.ssh/ansible-ec2-key.pem
   ls -la ~/.ssh/ansible-ec2-key.pem
   # Should show: -r-------- 1 user group ...
   ```

2. **Verify correct key:**
   ```bash
   # For initial connection, use AWS key pair:
   ssh -i ~/.ssh/ansible-ec2-key.pem ubuntu@$EC2_IP

   # After deployer user created, use deployer key:
   ssh -i ~/.ssh/deployer-key deployer@$EC2_IP
   ```

3. **Verify correct user:**
   ```bash
   # Initial: ubuntu
   ssh -i ~/.ssh/ansible-ec2-key.pem ubuntu@$EC2_IP

   # After deployment: deployer
   ssh -i ~/.ssh/deployer-key deployer@$EC2_IP
   ```

### Issue: Playbook fails on specific task

**Symptoms:**
```
TASK [some_role : Some task] **************************************************
fatal: [54.123.45.67]: FAILED! => {...}
```

**Solutions:**

1. **Check error message carefully:**
   ```bash
   # Run with verbose output
   ansible-playbook -i inventory/hosts.ini playbooks/site.yml -vvv
   ```

2. **Test specific role:**
   ```bash
   # Run only specific role
   ansible-playbook -i inventory/hosts.ini playbooks/site.yml --tags base
   ```

3. **SSH and manually test:**
   ```bash
   ssh -i ~/.ssh/ansible-ec2-key.pem ubuntu@$EC2_IP
   # Manually run the failing command to see what's wrong
   ```

### Issue: Application not responding

**Symptoms:**
```bash
curl: (7) Failed to connect to 54.123.45.67 port 80: Connection refused
```

**Solutions:**

1. **Check application service:**
   ```bash
   ssh -i ~/.ssh/deployer-key deployer@$EC2_IP
   sudo systemctl status myapp
   sudo journalctl -u myapp -n 50
   ```

2. **Check NGINX:**
   ```bash
   sudo systemctl status nginx
   sudo nginx -t
   sudo tail -f /var/log/nginx/myapp_error.log
   ```

3. **Check firewall:**
   ```bash
   sudo ufw status verbose
   # Make sure port 80 is allowed
   ```

4. **Test locally first:**
   ```bash
   # On EC2 instance
   curl http://localhost:5000/  # Test app directly
   curl http://localhost/       # Test through NGINX
   ```

5. **Restart services:**
   ```bash
   sudo systemctl restart myapp
   sudo systemctl restart nginx
   ```

### Issue: Ansible vault password error

**Symptoms:**
```bash
ERROR! Attempting to decrypt but no vault secrets found
```

**Solutions:**

1. **Provide vault password:**
   ```bash
   # If encrypted
   ansible-playbook -i inventory/hosts.ini playbooks/site.yml --vault-password-file .vault_pass

   # Or prompt for password
   ansible-playbook -i inventory/hosts.ini playbooks/site.yml --ask-vault-pass
   ```

2. **Decrypt if needed:**
   ```bash
   ansible-vault decrypt group_vars/vault.yml --vault-password-file .vault_pass
   ```

### Issue: AWS credentials not found

**Symptoms:**
```bash
fatal: [localhost]: FAILED! => {"msg": "Failed to describe AMIs: Unable to locate credentials"}
```

**Solutions:**

1. **Configure AWS CLI:**
   ```bash
   aws configure
   # Enter your credentials
   ```

2. **Verify credentials:**
   ```bash
   aws sts get-caller-identity
   cat ~/.aws/credentials
   ```

3. **Set environment variables (alternative):**
   ```bash
   export AWS_ACCESS_KEY_ID="your-key-id"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   export AWS_DEFAULT_REGION="us-east-1"
   ```

---

## Common Commands Reference

```bash
# Provisioning
ansible-playbook -i inventory/localhost.ini playbooks/provision.yml

# Full deployment
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# Deploy specific role
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --tags app

# Skip specific role
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --skip-tags base

# Dry run (check mode)
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check

# List all tasks
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --list-tasks

# List all tags
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --list-tags

# Test connectivity
ansible -i inventory/hosts.ini ec2_instances -m ping

# Run ad-hoc command
ansible -i inventory/hosts.ini ec2_instances -m command -a "uptime"

# Gather facts
ansible -i inventory/hosts.ini ec2_instances -m setup
```

---

## Next Steps

1. ✅ **Review Security Checklist**: See [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md)
2. ✅ **Set up monitoring**: Consider CloudWatch or external monitoring
3. ✅ **Configure backups**: Set up automated backups of your application
4. ✅ **Add CI/CD**: Integrate with GitHub Actions or similar
5. ✅ **Scale**: Consider using Auto Scaling Groups and Load Balancers

---

## Clean Up

To destroy the resources:

```bash
# Get instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ansible-managed-ec2" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text \
  --region us-east-1)

# Terminate instance
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region us-east-1

# Wait for termination
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region us-east-1

# Delete security group
aws ec2 delete-security-group --group-name ansible-ec2-sg --region us-east-1

# Delete key pair (if desired)
aws ec2 delete-key-pair --key-name ansible-ec2-keypair --region us-east-1

# Clean up local files
rm ~/.ssh/ansible-ec2-key.pem
```

---

## Support and Contributing

- Report issues on GitHub
- Contribute improvements via Pull Requests
- Review security best practices regularly

**Congratulations!** You now have a secure, production-ready Flask application running on AWS EC2! 🎉
