# Deployment Notes and Lessons Learned

This document captures important notes, fixes, and clarifications discovered during the actual deployment.

## SSH Key Configuration - IMPORTANT

There are **TWO different SSH keys** used in this setup:

### 1. AWS EC2 Key Pair (`ansible-ec2-key.pem`)
- **Purpose:** Initial access to the EC2 instance as the `ubuntu` user
- **Created with:** `aws ec2 create-key-pair` or AWS Console
- **Used for:**
  - Initial Ansible connection during deployment
  - Emergency access as ubuntu user
- **Connection:** `ssh -i ~/.ssh/ansible-ec2-key.pem ubuntu@YOUR_EC2_IP`

### 2. Deployer User Key (`deployer-key`)
- **Purpose:** Ongoing management access as the `deployer` user
- **Created with:** `ssh-keygen -t rsa -b 4096 -f ~/.ssh/deployer-key`
- **Public key configured in:** `group_vars/all.yml` → `deployer_ssh_public_key`
- **Used for:**
  - Day-to-day server management
  - Application updates
  - System administration
- **Connection:** `ssh -i ~/.ssh/deployer-key deployer@YOUR_EC2_IP`

### Which Key to Use When

| Task | User | Key | Command |
|------|------|-----|---------|
| Initial deployment | ubuntu | ansible-ec2-key.pem | `ansible-playbook -i inventory/hosts.ini playbooks/site.yml` |
| Ongoing management | deployer | deployer-key | `ssh -i ~/.ssh/deployer-key deployer@IP` |
| Emergency access | ubuntu | ansible-ec2-key.pem | `ssh -i ~/.ssh/ansible-ec2-key.pem ubuntu@IP` |

## Issues Fixed During Deployment

### Issue 1: Ansible Version Compatibility

**Problem:** Ansible 2.10.2 was incompatible with newer collections and the `yaml` stdout callback.

**Solution:**
```bash
pip3 install --upgrade ansible
ansible-galaxy collection install amazon.aws community.aws ansible.posix
```

**Fixed in:** `ansible.cfg` - commented out `stdout_callback = yaml`

### Issue 2: Variables Not Loading in Playbooks

**Problem:** `group_vars/all.yml` wasn't being loaded automatically.

**Root Cause:** The inventory group is `ec2_instances` but Ansible expects `all` or matching group names.

**Solution:** Added `vars_files` directive to both playbooks:
```yaml
vars_files:
  - ../group_vars/all.yml
```

**Files Modified:**
- `playbooks/provision.yml` (line 8-9)
- `playbooks/site.yml` (line 9-10)

### Issue 3: AWS Key Pair Not Found

**Problem:** `InvalidKeyPair.NotFound: The key pair 'ansible-ec2-keypair' does not exist`

**Solution:** Create the key pair in AWS:
```bash
aws ec2 create-key-pair \
    --key-name ansible-ec2-keypair \
    --region us-west-2 \
    --query 'KeyMaterial' \
    --output text > ~/.ssh/ansible-ec2-key.pem
chmod 400 ~/.ssh/ansible-ec2-key.pem
```

### Issue 4: NGINX Configuration Corruption

**Problem:** Initial nginx role tried to modify `nginx.conf` with `lineinfile`, which placed directives in wrong context, breaking the config.

**Error:** `nginx: [emerg] "keepalive_timeout" directive is not allowed here in /etc/nginx/nginx.conf:84`

**Solution:**
1. Removed the `lineinfile` tasks that modified `nginx.conf`
2. Added tasks to purge and reinstall nginx cleanly
3. Only modify site-specific configuration in `sites-available/`

**Files Modified:**
- `roles/nginx/tasks/main.yml` (lines 16-45)

**Final approach:**
```yaml
- name: Purge nginx completely
- name: Remove /etc/nginx directory
- name: Install nginx fresh
- name: Only configure site-specific settings
```

### Issue 5: SSH Key Mismatch for Deployer User

**Problem:** Tried to SSH as deployer with wrong key (AWS key instead of deployer key).

**Solution:** Use the correct key that matches the public key in `group_vars/all.yml`:
```bash
# Find which key was configured
grep -l "AAAAB3NzaC1yc2EAAAADAQABAAACAQDOHXsnKEAB" ~/.ssh/*.pub
# Output: /Users/admin/.ssh/deployer-key.pub

# Use the corresponding private key
ssh -i ~/.ssh/deployer-key deployer@35.94.198.155
```

## Ansible Configuration Adjustments

### ansible.cfg Changes

**Line 19:** Commented out `stdout_callback = yaml` for compatibility with Ansible 2.17+

### inventory/hosts.ini Changes

**Line 11:** Updated from `~/.ssh/ansible-ec2-key` to `~/.ssh/ansible-ec2-key.pem` to match actual filename

## Best Practices Learned

### 1. Test SSH Keys Before Deployment

Before running the deployment:
```bash
# Test AWS key
ssh -i ~/.ssh/ansible-ec2-key.pem ubuntu@YOUR_IP

# After deployment, test deployer key
ssh -i ~/.ssh/deployer-key deployer@YOUR_IP
```

### 2. Verify AWS Resources Exist

Before provisioning:
```bash
# Check if key pair exists
aws ec2 describe-key-pairs --region us-west-2

# Check default VPC
aws ec2 describe-vpcs --region us-west-2 --filters "Name=isDefault,Values=true"
```

### 3. Never Modify nginx.conf Directly

**Bad:**
```yaml
- name: Configure NGINX main settings
  ansible.builtin.lineinfile:
    path: /etc/nginx/nginx.conf
    regexp: "{{ item.regexp }}"
    line: "{{ item.line }}"
```

**Good:**
```yaml
- name: Deploy site-specific NGINX configuration
  ansible.builtin.template:
    src: flask-app.conf.j2
    dest: /etc/nginx/sites-available/myapp.conf
```

### 4. Always Use vars_files for Custom Group Variables

When your inventory groups don't match `all`:
```yaml
- name: Your Playbook
  hosts: ec2_instances
  vars_files:
    - ../group_vars/all.yml
```

### 5. Keep Collection Versions Compatible

For older Ansible versions (2.10.x):
```bash
ansible-galaxy collection install 'amazon.aws:<=3.5.0'
```

For newer Ansible versions (2.15+):
```bash
ansible-galaxy collection install amazon.aws  # latest
```

## Deployment Checklist

Use this checklist for future deployments:

- [ ] Ansible 2.15+ installed
- [ ] AWS CLI configured (`aws sts get-caller-identity`)
- [ ] Collections installed (`ansible-galaxy collection list`)
- [ ] AWS key pair created in correct region
- [ ] Deployer SSH key pair generated locally
- [ ] `group_vars/all.yml` edited (all REPLACE_ME values)
- [ ] `inventory/hosts.ini` SSH key path correct
- [ ] Provision playbook runs successfully
- [ ] EC2 IP added to `inventory/hosts.ini`
- [ ] Wait 60 seconds for instance initialization
- [ ] Test SSH as ubuntu: `ssh -i ~/.ssh/ansible-ec2-key.pem ubuntu@IP`
- [ ] Deploy playbook runs successfully
- [ ] Test SSH as deployer: `ssh -i ~/.ssh/deployer-key deployer@IP`
- [ ] Test application: `curl http://IP/`
- [ ] Verify all services running
- [ ] Run security checklist

## Common Errors and Solutions

### Error: "ansible_date_time is undefined"

**Cause:** `gather_facts: false` prevents date/time variables from being available.

**Solution:** Use `lookup('pipe', 'date +%Y-%m-%dT%H:%M:%S')` instead of `ansible_date_time.iso8601`

### Error: "Permission denied (publickey)"

**Cause:** Using wrong SSH key or wrong user.

**Solutions:**
```bash
# For ubuntu user (initial)
ssh -i ~/.ssh/ansible-ec2-key.pem ubuntu@IP

# For deployer user (after deployment)
ssh -i ~/.ssh/deployer-key deployer@IP

# Find which key matches your configured public key
grep -l "FIRST_PART_OF_YOUR_PUBLIC_KEY" ~/.ssh/*.pub
```

### Error: "InvalidKeyPair.NotFound"

**Cause:** AWS key pair doesn't exist in the specified region.

**Solution:**
```bash
aws ec2 create-key-pair --key-name ansible-ec2-keypair --region us-west-2 \
  --query 'KeyMaterial' --output text > ~/.ssh/ansible-ec2-key.pem
chmod 400 ~/.ssh/ansible-ec2-key.pem
```

### Error: "keepalive_timeout directive is not allowed here"

**Cause:** NGINX configuration directive in wrong context.

**Solution:** Don't modify `nginx.conf` directly. Use site configs in `sites-available/` instead.

## Performance Notes

**First Deployment Time:** ~10-15 minutes
- Provisioning: 2-3 minutes
- System updates: 3-5 minutes
- Package installation: 2-3 minutes
- Application setup: 2-3 minutes

**Subsequent Deployments (Idempotent):** ~2-5 minutes
- Most tasks show "ok" (no changes)
- Only changed files trigger handlers

## Security Verification

After deployment, verify these security controls:

```bash
# SSH to deployer
ssh -i ~/.ssh/deployer-key deployer@IP

# Check no password authentication
sudo passwd -S deployer  # Should show "L" (locked)

# Check firewall
sudo ufw status verbose  # Should show only 22, 80, 443

# Check fail2ban
sudo fail2ban-client status sshd  # Should be active

# Check app runs as non-root
ps aux | grep gunicorn  # User should be "deployer"

# Check app not exposed directly
sudo ss -tlnp | grep 5000  # Should show 127.0.0.1:5000 only

# Try to SSH as root (should fail)
ssh -i ~/.ssh/ansible-ec2-key.pem root@IP  # Should be denied
```

## Cleanup Instructions

To destroy all AWS resources:

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

# Remove local key files (optional)
rm ~/.ssh/ansible-ec2-key.pem
```

## Files Modified During Troubleshooting

| File | Lines Changed | Reason |
|------|---------------|--------|
| `ansible.cfg` | 19 | Disabled yaml callback for compatibility |
| `playbooks/provision.yml` | 8-9, 125 | Added vars_files, fixed date variable |
| `playbooks/site.yml` | 9-10 | Added vars_files |
| `inventory/hosts.ini` | 11 | Fixed SSH key path (.pem extension) |
| `roles/nginx/tasks/main.yml` | 16-45 | Removed nginx.conf modification, added purge/reinstall |

## Additional Resources

- **Ansible Best Practices:** https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html
- **AWS EC2 Security Groups:** https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html
- **NGINX Configuration:** https://nginx.org/en/docs/
- **Ubuntu Security Guide:** https://ubuntu.com/security/certifications/docs/2204

## Contact and Support

For issues with this deployment:
1. Check [STEP_BY_STEP_GUIDE.md](STEP_BY_STEP_GUIDE.md) troubleshooting section
2. Review [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md) for verification steps
3. Check this document for known issues and solutions

## Version History

- **v1.0 (2024-12-05):** Initial deployment
  - Fixed variable loading issues
  - Fixed NGINX configuration approach
  - Fixed SSH key configuration
  - Verified full deployment on AWS us-west-2

---

**Deployment Status:** ✅ Successfully deployed to production
**Application URL:** http://35.94.198.155/
**Deployment Date:** December 5, 2024
**Region:** us-west-2
