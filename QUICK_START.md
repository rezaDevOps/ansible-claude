# Quick Start Cheat Sheet

Ultra-condensed commands for experienced users. For detailed instructions, see [STEP_BY_STEP_GUIDE.md](STEP_BY_STEP_GUIDE.md).

## Prerequisites (One-Time Setup)

```bash
# Install tools
pip3 install ansible boto3 botocore awscli

# Install Ansible collections
ansible-galaxy collection install community.aws ansible.posix community.general

# Configure AWS
aws configure
# Enter: Access Key ID, Secret Key, Region (e.g., us-east-1), Format (json)

# Generate SSH keys
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ansible-ec2-key -C "ec2-access"
ssh-keygen -t rsa -b 4096 -f ~/.ssh/deployer-key -C "deployer-user"
chmod 400 ~/.ssh/ansible-ec2-key ~/.ssh/deployer-key

# Create AWS key pair
aws ec2 create-key-pair \
    --key-name ansible-ec2-keypair \
    --region us-east-1 \
    --query 'KeyMaterial' \
    --output text > ~/.ssh/ansible-ec2-key.pem
chmod 400 ~/.ssh/ansible-ec2-key.pem
```

## Configuration (Required)

```bash
# Edit group_vars/all.yml - REPLACE THESE:
# 1. aws_region: "us-east-1"  # Your region
# 2. aws_keypair_name: "ansible-ec2-keypair"  # Key pair name from AWS
# 3. deployer_ssh_public_key: "ssh-rsa AAA..."  # Content of ~/.ssh/deployer-key.pub
# 4. allowed_ssh_ips: ["YOUR_IP/32"]  # Get IP: curl ifconfig.me

vim group_vars/all.yml

# Edit inventory/hosts.ini - REPLACE:
# 1. ansible_ssh_private_key_file=~/.ssh/ansible-ec2-key.pem

vim inventory/hosts.ini
```

## Deploy Everything (5 Commands)

```bash
# 1. Provision EC2 instance
ansible-playbook -i inventory/localhost.ini playbooks/provision.yml

# 2. Copy the Public IP from output

# 3. Update inventory with EC2 IP
sed -i '' 's/REPLACE_WITH_EC2_PUBLIC_IP/YOUR_EC2_IP/' inventory/hosts.ini

# 4. Wait for instance to initialize
sleep 60

# 5. Deploy application
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --private-key ~/.ssh/ansible-ec2-key.pem
```

## Verify Deployment

```bash
# Test application
curl http://YOUR_EC2_IP/

# SSH to instance
ssh -i ~/.ssh/deployer-key deployer@YOUR_EC2_IP

# Check services (on EC2)
sudo systemctl status myapp nginx fail2ban
sudo ufw status verbose
exit
```

## Common Commands

```bash
# Re-run deployment (idempotent)
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# Deploy specific role only
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --tags app

# Check mode (dry run)
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check

# Verbose output
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -vvv

# Test connectivity
ansible -i inventory/hosts.ini ec2_instances -m ping
```

## Add SSL/TLS (Optional)

```bash
# SSH to instance
ssh -i ~/.ssh/deployer-key deployer@YOUR_EC2_IP

# Get certificate (replace domain)
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com

# Test auto-renewal
sudo certbot renew --dry-run
exit

# Verify
curl https://yourdomain.com/
```

## Cleanup / Destroy

```bash
# Get instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ansible-managed-ec2" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text --region us-east-1)

# Terminate
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region us-east-1
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region us-east-1

# Delete security group and key pair
aws ec2 delete-security-group --group-name ansible-ec2-sg --region us-east-1
aws ec2 delete-key-pair --key-name ansible-ec2-keypair --region us-east-1
```

## Troubleshooting Quick Fixes

```bash
# Can't connect? Wait longer
sleep 60

# Permission denied? Check key permissions
chmod 400 ~/.ssh/ansible-ec2-key.pem
ls -la ~/.ssh/ansible-ec2-key.pem

# Wrong user? Use ubuntu initially, deployer after deployment
ssh -i ~/.ssh/ansible-ec2-key.pem ubuntu@YOUR_EC2_IP  # Initial
ssh -i ~/.ssh/deployer-key deployer@YOUR_EC2_IP       # After deployment

# App not responding? Check services on EC2
ssh -i ~/.ssh/deployer-key deployer@YOUR_EC2_IP
sudo systemctl restart myapp nginx
sudo journalctl -u myapp -n 50
```

## File Structure Quick Reference

```
ansible.cfg              # Ansible config
group_vars/all.yml       # **EDIT THIS** - All variables
inventory/hosts.ini      # **EDIT THIS** - EC2 IP address
playbooks/provision.yml  # Creates EC2 instance
playbooks/site.yml       # Deploys everything
roles/                   # All automation logic
```

## Security Verification (5 Commands)

```bash
# SSH to instance
ssh -i ~/.ssh/deployer-key deployer@YOUR_EC2_IP

# Run checks
sudo systemctl status myapp nginx fail2ban ufw
sudo ufw status verbose
sudo ss -tlnp | grep -E ':(22|80|443|5000)'
sudo fail2ban-client status sshd
ps aux | grep -E 'gunicorn|nginx'
```

## Variables to Customize

Edit `group_vars/all.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | REPLACE_ME | AWS region |
| `aws_keypair_name` | REPLACE_ME | EC2 key pair name |
| `deployer_ssh_public_key` | REPLACE_ME | SSH public key content |
| `allowed_ssh_ips` | 0.0.0.0/0 | **CHANGE THIS!** Allowed SSH IPs |
| `instance_type` | t3.micro | EC2 instance type |
| `app_port` | 5000 | Flask application port |
| `app_domain` | {{ ansible_host }} | Domain name or IP |

## Endpoints Available

After deployment, your application exposes:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Hello message with hostname |
| `/health` | GET | Health check endpoint |
| `/info` | GET | Application information |
| `/api/echo` | POST | Echo JSON endpoint |

Test:
```bash
EC2_IP="YOUR_EC2_IP"
curl http://$EC2_IP/
curl http://$EC2_IP/health
curl http://$EC2_IP/info
curl -X POST http://$EC2_IP/api/echo -H "Content-Type: application/json" -d '{"test":"hello"}'
```

## Update After Deployer User Created

After first deployment, update `inventory/hosts.ini`:

```ini
[ec2_instances]
54.123.45.67  # Your EC2 IP

[ec2_instances:vars]
ansible_user=deployer  # Changed from ubuntu
ansible_ssh_private_key_file=~/.ssh/deployer-key  # Changed from ansible-ec2-key.pem
ansible_python_interpreter=/usr/bin/python3
```

Then you can run without `--private-key`:
```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
```

## Performance Tips

```bash
# Use SSH multiplexing (already in ansible.cfg)
# Run with parallel execution
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --forks 10

# Use pipelining (already in ansible.cfg)
# Skip gathering facts if not needed
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --skip-tags base
```

## Documentation Files

- [README.md](README.md) - Main overview and quick start
- [STEP_BY_STEP_GUIDE.md](STEP_BY_STEP_GUIDE.md) - Detailed instructions
- [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md) - Security verification
- [FILE_MANIFEST.md](FILE_MANIFEST.md) - All files explained
- [QUICK_START.md](QUICK_START.md) - This file

## Get Help

```bash
# Ansible help
ansible-playbook --help
ansible --help

# List all tasks
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --list-tasks

# List all tags
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --list-tags

# Check syntax
ansible-playbook --syntax-check -i inventory/hosts.ini playbooks/site.yml
```

## Cost Estimate

- **t3.micro instance**: ~$0.0104/hour (~$7.50/month)
- **EBS volume (8GB)**: ~$0.80/month
- **Data transfer**: First 1GB free, then $0.09/GB
- **Total estimated**: ~$8-10/month

AWS Free Tier eligible (750 hours/month t2.micro or t3.micro for 12 months).

---

**Time to deploy:** ~10-15 minutes (first time)
**Re-run time:** ~5 minutes (idempotent)
**Minimum requirements:** AWS account, Python 3.8+, 5 commands

For complete documentation, see [README.md](README.md).
