# Security Checklist and Verification Guide

This document provides a comprehensive security checklist and verification steps for your deployed EC2 Flask application.

## Pre-Deployment Security Checklist

### Control Machine Security

- [ ] AWS credentials stored securely (not in code/repo)
- [ ] SSH private key has correct permissions (`chmod 400`)
- [ ] Ansible vault password not committed to repository
- [ ] Using least-privilege IAM user/role for AWS operations
- [ ] Control machine has updated OS and security patches

### Configuration Review

- [ ] `allowed_ssh_ips` restricted to known IP ranges (not 0.0.0.0/0)
- [ ] Strong SSH key used (4096-bit RSA or Ed25519)
- [ ] `deployer_ssh_public_key` is YOUR public key
- [ ] AWS region and instance type configured correctly
- [ ] All `REPLACE_ME` values updated in configuration files

## Post-Deployment Verification

### 1. SSH Access Verification

```bash
# SSH into the instance as deployer user (NOT ubuntu)
EC2_IP="YOUR_EC2_PUBLIC_IP"
ssh -i ~/.ssh/ansible-ec2-key deployer@$EC2_IP

# Verify you can become root with sudo
sudo whoami
# Expected output: root
```

**Checklist:**
- [ ] Can SSH as deployer user with key
- [ ] Cannot SSH with password
- [ ] Cannot SSH as root user
- [ ] Sudo access works without password for deployer

**Test commands:**
```bash
# This should FAIL (password auth disabled)
ssh deployer@$EC2_IP
# (without -i flag, should fail if no keys in ssh-agent)

# This should FAIL (root login disabled)
ssh -i ~/.ssh/ansible-ec2-key root@$EC2_IP
```

### 2. User and Permissions Audit

```bash
# Check user configuration
id deployer
# Expected: uid=1000(deployer) gid=1000(deployer) groups=1000(deployer),27(sudo)

# Verify no password login possible
sudo passwd -S deployer
# Expected: deployer L ... (L = locked)

# Check sudoers configuration
sudo cat /etc/sudoers.d/deployer
# Expected: deployer ALL=(ALL) NOPASSWD:ALL

# List all users with login shells
cat /etc/passwd | grep -v nologin | grep -v false
# Should only see: root, deployer, and system users
```

**Checklist:**
- [ ] Deployer user exists and is in sudo group
- [ ] Deployer password is locked
- [ ] Deployer has passwordless sudo
- [ ] No unnecessary user accounts with shell access

### 3. SSH Configuration Audit

```bash
# Check SSH daemon configuration
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication'
# Expected output:
# permitrootlogin no
# passwordauthentication no
# pubkeyauthentication yes

# Check SSH port
sudo ss -tlnp | grep sshd
# Expected: LISTEN on 0.0.0.0:22

# Verify SSH key permissions
ls -la ~/.ssh/
# Expected: authorized_keys is 0600, .ssh directory is 0700
```

**Checklist:**
- [ ] Root login disabled (`PermitRootLogin no`)
- [ ] Password authentication disabled
- [ ] Public key authentication enabled
- [ ] Strong ciphers and MACs configured
- [ ] SSH running on expected port (default: 22)

### 4. Firewall Configuration

```bash
# Check UFW status
sudo ufw status verbose

# Expected output should show:
# Status: active
# Logging: on (low)
# Default: deny (incoming), allow (outgoing), deny (routed)
# To                         Action      From
# --                         ------      ----
# 22/tcp                     ALLOW IN    <your-ip-range>
# 80/tcp                     ALLOW IN    Anywhere
# 443/tcp                    ALLOW IN    Anywhere

# Check iptables rules (UFW uses iptables)
sudo iptables -L -n -v

# Check open ports
sudo ss -tulnp
# Should ONLY see: sshd (22), nginx (80), and app (5000 on localhost only)
```

**Checklist:**
- [ ] UFW is active and enabled
- [ ] Default deny for incoming traffic
- [ ] SSH restricted to allowed IP ranges
- [ ] Only ports 22, 80, 443 open to internet
- [ ] Application port (5000) NOT exposed to internet (127.0.0.1 only)

### 5. Application Security

```bash
# Check application is running as deployer (not root)
ps aux | grep gunicorn
# User column should show 'deployer', NOT 'root'

# Check application file permissions
ls -la /opt/myapp/
# All files should be owned by deployer:deployer

# Check systemd service security settings
sudo systemctl show myapp | grep -E 'User|Group|NoNewPrivileges|PrivateTmp|ProtectSystem|ProtectHome'
# Expected:
# User=deployer
# Group=deployer
# NoNewPrivileges=yes
# PrivateTmp=yes
# ProtectSystem=strict
# ProtectHome=yes

# Verify application responds correctly
curl http://localhost:5000/
curl http://localhost/
curl http://$EC2_IP/
# All should return: {"message": "Hello from Flask on EC2!", ...}

# Check application logs
sudo journalctl -u myapp -n 50 --no-pager
sudo tail -f /var/log/myapp/error.log
```

**Checklist:**
- [ ] Application runs as non-root user (deployer)
- [ ] Application only listens on localhost (not 0.0.0.0)
- [ ] Systemd service has security hardening enabled
- [ ] Application responds to health checks
- [ ] No errors in application logs

### 6. NGINX Security

```bash
# Check NGINX is running
sudo systemctl status nginx

# Test NGINX configuration
sudo nginx -t

# Check NGINX is running as www-data (not root)
ps aux | grep nginx
# Worker processes should run as 'www-data'

# Verify security headers
curl -I http://$EC2_IP/
# Should include:
# X-Frame-Options: SAMEORIGIN
# X-Content-Type-Options: nosniff
# X-XSS-Protection: 1; mode=block
# Referrer-Policy: no-referrer-when-downgrade

# Check NGINX access logs
sudo tail -f /var/log/nginx/myapp_access.log

# Check NGINX error logs
sudo tail -f /var/log/nginx/myapp_error.log
```

**Checklist:**
- [ ] NGINX running and enabled
- [ ] NGINX configuration test passes
- [ ] Worker processes run as www-data
- [ ] Security headers present in responses
- [ ] Reverse proxy correctly forwards to application
- [ ] No errors in NGINX logs

### 7. Fail2ban Verification

```bash
# Check fail2ban status
sudo fail2ban-client status

# Check SSH jail status
sudo fail2ban-client status sshd
# Should show:
# - Currently failed: X
# - Currently banned: Y
# - Total banned: Z

# Check fail2ban logs
sudo tail -f /var/log/fail2ban.log

# Test fail2ban (optional - use with caution)
# Try to SSH with wrong password/key 5 times from a test IP
# Then check if that IP is banned:
sudo fail2ban-client status sshd
```

**Checklist:**
- [ ] Fail2ban service is running
- [ ] SSH jail is enabled
- [ ] Ban rules configured correctly (5 attempts in 10 minutes)
- [ ] Failed login attempts are being logged

### 8. System Updates and Packages

```bash
# Check for available updates
sudo apt update
sudo apt list --upgradable

# Verify unattended-upgrades is configured
sudo cat /etc/apt/apt.conf.d/50unattended-upgrades
sudo cat /etc/apt/apt.conf.d/20auto-upgrades

# Check unattended-upgrades service
sudo systemctl status unattended-upgrades

# List installed packages and versions
dpkg -l | grep -E 'python3|nginx|ufw|fail2ban'
```

**Checklist:**
- [ ] System packages are up to date
- [ ] Unattended-upgrades configured for security updates
- [ ] No critical security updates pending

### 9. Kernel Security Parameters

```bash
# Check kernel security settings
sudo sysctl -a | grep -E 'net.ipv4.conf.all.accept_source_route|net.ipv4.conf.all.accept_redirects|net.ipv4.tcp_syncookies'

# Expected values:
# net.ipv4.conf.all.accept_source_route = 0
# net.ipv4.conf.all.accept_redirects = 0
# net.ipv4.tcp_syncookies = 1
# (and others from base role)

# Check custom sysctl file
sudo cat /etc/sysctl.d/99-security.conf
```

**Checklist:**
- [ ] IP forwarding disabled (if not needed)
- [ ] ICMP redirects disabled
- [ ] TCP SYN cookies enabled
- [ ] Source routing disabled
- [ ] Martian packet logging enabled

### 10. Log Monitoring

```bash
# Check system logs for errors
sudo journalctl -p err -n 50 --no-pager

# Check authentication logs
sudo tail -50 /var/log/auth.log | grep -i failed

# Monitor all logs in real-time
sudo tail -f /var/log/syslog

# Check disk space (logs can fill up)
df -h
```

**Checklist:**
- [ ] No critical errors in system logs
- [ ] No suspicious authentication attempts
- [ ] Sufficient disk space for logs (>20% free)
- [ ] Log rotation configured

## Security Testing (External)

### Port Scanning

From your local machine, scan the EC2 instance:

```bash
# Using nmap (install if needed: brew install nmap or apt install nmap)
nmap -sV -p- $EC2_IP

# Expected output:
# PORT    STATE SERVICE VERSION
# 22/tcp  open  ssh     OpenSSH X.X
# 80/tcp  open  http    nginx X.X
# 443/tcp open  https   nginx X.X (if SSL configured)
```

**Checklist:**
- [ ] Only ports 22, 80 (and 443 if SSL) are open
- [ ] No other unexpected services exposed
- [ ] Application port (5000) is NOT visible externally

### SSL/TLS Testing (if configured)

```bash
# Test SSL configuration (after setting up Let's Encrypt)
curl https://$DOMAIN/

# Use SSL Labs for comprehensive testing
# Visit: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN
```

**Checklist:**
- [ ] SSL certificate valid and trusted
- [ ] TLS 1.2+ enabled
- [ ] Strong cipher suites only
- [ ] HSTS header present
- [ ] Grade A or A+ on SSL Labs

### Application Security Testing

```bash
# Test HTTP methods
curl -X POST http://$EC2_IP/
curl -X PUT http://$EC2_IP/
curl -X DELETE http://$EC2_IP/

# Test directory traversal
curl http://$EC2_IP/../../../etc/passwd

# Test for common vulnerabilities
# Consider using tools like:
# - OWASP ZAP
# - Nikto
# - Burp Suite
```

**Checklist:**
- [ ] Unnecessary HTTP methods blocked
- [ ] No directory traversal vulnerabilities
- [ ] No information disclosure in error messages
- [ ] No exposed sensitive files (.git, .env, etc.)

## Compliance Checks

### AWS Security Best Practices

```bash
# From AWS CLI on local machine

# Check security group rules
aws ec2 describe-security-groups --group-names ansible-ec2-sg --region $AWS_REGION

# Check instance metadata
aws ec2 describe-instances --filters "Name=tag:Name,Values=ansible-managed-ec2" --region $AWS_REGION

# Check IAM policies (if using IAM role)
aws iam list-attached-role-policies --role-name $ROLE_NAME
```

**Checklist:**
- [ ] Security group follows least privilege
- [ ] IAM roles/policies follow least privilege
- [ ] Instance has required tags
- [ ] EBS volumes encrypted (optional but recommended)
- [ ] CloudWatch monitoring enabled (optional)

## Incident Response Procedures

### If Compromise is Suspected

1. **Isolate the instance**
   ```bash
   # From AWS CLI
   aws ec2 modify-instance-attribute --instance-id $INSTANCE_ID --no-source-dest-check
   # Update security group to deny all traffic except your IP
   ```

2. **Capture forensics data**
   ```bash
   # Create snapshot
   aws ec2 create-snapshot --volume-id $VOLUME_ID --description "Forensics snapshot"

   # On instance, capture logs
   sudo tar -czf /tmp/logs-$(date +%Y%m%d).tar.gz /var/log
   ```

3. **Review logs**
   ```bash
   sudo journalctl -u myapp --since "1 hour ago"
   sudo tail -100 /var/log/auth.log
   sudo fail2ban-client status sshd
   ```

4. **Terminate and redeploy**
   ```bash
   # Terminate compromised instance
   aws ec2 terminate-instances --instance-ids $INSTANCE_ID

   # Redeploy from clean Ansible playbook
   ansible-playbook -i inventory/localhost.ini playbooks/provision.yml
   ansible-playbook -i inventory/hosts.ini playbooks/site.yml
   ```

## Continuous Security Monitoring

### Daily Checks

- [ ] Review fail2ban banned IPs
- [ ] Check application error logs
- [ ] Verify services are running

### Weekly Checks

- [ ] Review authentication logs
- [ ] Check for available security updates
- [ ] Verify backups (if configured)

### Monthly Checks

- [ ] Review and rotate SSH keys
- [ ] Update dependencies (Python packages)
- [ ] Review firewall rules
- [ ] Audit user accounts

## Additional Hardening (Optional)

### Enable AWS CloudWatch Logging

```bash
# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb
```

### Enable Two-Factor Authentication

```bash
# Install Google Authenticator
sudo apt install libpam-google-authenticator

# Configure for deployer user
su - deployer
google-authenticator
```

### Configure Intrusion Detection (AIDE)

```bash
# Install AIDE
sudo apt install aide

# Initialize database
sudo aideinit

# Check for changes
sudo aide --check
```

### Enable Disk Encryption

When provisioning, specify encrypted EBS volumes in the provision playbook.

## References

- [CIS Ubuntu Linux 22.04 LTS Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [AWS Security Best Practices](https://aws.amazon.com/security/best-practices/)
- [Ansible Security Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html#security)

## Summary

This checklist ensures:
- ✅ Least privilege access (non-root user, key-based auth only)
- ✅ Network security (firewall, restricted SSH access)
- ✅ Application security (running as non-root, isolated)
- ✅ System hardening (kernel parameters, security updates)
- ✅ Monitoring and logging (fail2ban, systemd journals)
- ✅ Incident response procedures documented

**Remember:** Security is an ongoing process. Regularly review and update your security posture!
