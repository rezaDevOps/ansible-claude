# Cleanup Guide

This guide explains how to safely destroy all AWS resources created by this project.

## Three Methods Available

### Method 1: Ansible Playbook (Recommended) ⭐

**Pros:**
- Uses Ansible modules for clean, idempotent operations
- Reads configuration from `group_vars/all.yml`
- Prompts for confirmation before destroying
- Creates a detailed cleanup log
- Handles retries and waits automatically

**Run:**
```bash
ansible-playbook -i inventory/localhost.ini playbooks/cleanup.yml
```

**What it does:**
1. Prompts you to type 'yes' to confirm
2. Shows all resources that will be destroyed
3. Gives you 5 seconds to cancel (Ctrl+C)
4. Terminates all EC2 instances with tag `Name=ansible-managed-ec2`
5. Waits for complete termination
6. Deletes the security group (with retries)
7. Deletes the AWS key pair
8. Creates a cleanup log file with timestamps

**Output:**
```
Are you sure you want to DESTROY all resources? Type 'yes' to confirm: yes

TASK [Display resources to be destroyed] ***************************************
ok: [localhost] => {
    "msg": [
        "==========================================",
        "The following resources will be DESTROYED:",
        "==========================================",
        "Region: us-west-2",
        "Instance tag: Name=ansible-managed-ec2",
        "Security group: ansible-ec2-sg",
        "Key pair: ansible-ec2-keypair",
        "=========================================="
    ]
}

TASK [Pause for 5 seconds] *****************************************************
Pausing for 5 seconds
(ctrl+C then 'C' = continue early, ctrl+C then 'A' = abort)
Destroying in 5 seconds... Press Ctrl+C to cancel!:

TASK [Terminate EC2 instances] *************************************************
changed: [localhost]

...

Cleanup completed successfully!
```

---

### Method 2: Bash Script (Fast & Simple) 🚀

**Pros:**
- No Ansible required (uses AWS CLI only)
- Colored output for clarity
- Automatic retries for security group deletion
- Shows exactly what will be destroyed
- Creates cleanup log

**Run:**
```bash
./scripts/cleanup.sh
```

**What it does:**
1. Checks AWS CLI is installed and configured
2. Reads configuration from `group_vars/all.yml`
3. Searches for all resources
4. Shows a summary of what will be destroyed
5. Prompts for confirmation
6. Gives 5 seconds to cancel
7. Destroys all resources with retries
8. Creates a cleanup log

**Output:**
```
==========================================
AWS Resource Cleanup Script
==========================================

Configuration loaded:
  Region: us-west-2
  Security Group: ansible-ec2-sg
  Key Pair: ansible-ec2-keypair

Searching for EC2 instances...
Found instance:
  Instance ID: i-0123456789abcdef0
  Public IP: 35.94.198.155

Checking security group...
Found security group: sg-0123456789abcdef0

Checking key pair...
Found key pair: ansible-ec2-keypair

==========================================
WARNING: The following will be DESTROYED:
==========================================
  - EC2 Instance: i-0123456789abcdef0
  - Security Group: sg-0123456789abcdef0
  - Key Pair: ansible-ec2-keypair

Type 'yes' to confirm destruction: yes

Starting cleanup in 5 seconds... (Press Ctrl+C to cancel)

Terminating EC2 instance...
Waiting for instance to terminate...
Instance terminated

Deleting security group...
Security group deleted

Deleting key pair from AWS...
Key pair deleted from AWS

==========================================
Cleanup completed successfully!
==========================================

AWS resources destroyed:
  ✓ EC2 instance terminated
  ✓ Security group deleted
  ✓ Key pair deleted
```

---

### Method 3: Manual AWS CLI (Full Control) 🔧

**Pros:**
- Complete manual control
- No dependencies on scripts
- Step-by-step destruction
- Good for learning AWS CLI

**Run each command separately:**

```bash
# 1. Set your region
export AWS_REGION="us-west-2"

# 2. Find and terminate EC2 instance
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ansible-managed-ec2" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text \
  --region $AWS_REGION)

echo "Instance ID: $INSTANCE_ID"

aws ec2 terminate-instances \
  --instance-ids $INSTANCE_ID \
  --region $AWS_REGION

# 3. Wait for termination (takes ~1 minute)
aws ec2 wait instance-terminated \
  --instance-ids $INSTANCE_ID \
  --region $AWS_REGION

echo "Instance terminated"

# 4. Delete security group (with retries if needed)
aws ec2 delete-security-group \
  --group-name ansible-ec2-sg \
  --region $AWS_REGION

# If security group deletion fails, wait 30 seconds and retry
sleep 30
aws ec2 delete-security-group \
  --group-name ansible-ec2-sg \
  --region $AWS_REGION

echo "Security group deleted"

# 5. Delete key pair from AWS
aws ec2 delete-key-pair \
  --key-name ansible-ec2-keypair \
  --region $AWS_REGION

echo "Key pair deleted"

# 6. Verify all resources are gone
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ansible-managed-ec2" \
  --region $AWS_REGION

# Should return empty
```

---

## Comparison Table

| Feature | Ansible Playbook | Bash Script | Manual CLI |
|---------|------------------|-------------|------------|
| **Ease of use** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **Speed** | Medium | Fast | Slow |
| **Dependencies** | Ansible + AWS CLI | AWS CLI only | AWS CLI only |
| **Automation** | Full | Full | Manual |
| **Logs** | Yes | Yes | No |
| **Retries** | Yes | Yes | Manual |
| **Confirmation** | Yes | Yes | No |
| **Colored output** | No | Yes | No |
| **Idempotent** | Yes | No | No |

---

## What Gets Destroyed

All three methods destroy the same resources:

✅ **EC2 Instance**
- Tag: `Name=ansible-managed-ec2`
- All associated volumes
- Elastic IP (if attached)

✅ **Security Group**
- Name: `ansible-ec2-sg`
- All ingress/egress rules

✅ **EC2 Key Pair**
- Name: `ansible-ec2-keypair`
- Only from AWS (local key files remain)

---

## What Does NOT Get Destroyed

These remain on your local machine:

❌ **Local SSH Keys** (manual cleanup needed)
```bash
rm ~/.ssh/ansible-ec2-key.pem
rm ~/.ssh/deployer-key
rm ~/.ssh/deployer-key.pub
```

❌ **Project Files**
```bash
rm ec2_instance_info.txt
rm cleanup_log_*.txt
```

❌ **Inventory Configuration**
- `inventory/hosts.ini` still has the old IP address
- Manually remove or comment out the IP

❌ **Ansible Fact Cache**
```bash
rm -rf /tmp/ansible_fact_cache
```

---

## Post-Cleanup Steps

After destroying AWS resources:

### 1. Clear Inventory File

Edit `inventory/hosts.ini` and remove or comment the EC2 IP:

```ini
[ec2_instances]
# 35.94.198.155  # Destroyed on 2024-12-05
```

### 2. Remove Local Files (Optional)

```bash
# Remove EC2 instance info
rm -f ec2_instance_info.txt

# Remove cleanup logs (optional - keep for records)
# rm -f cleanup_log_*.txt

# Remove SSH keys (if you won't redeploy)
rm -f ~/.ssh/ansible-ec2-key.pem
rm -f ~/.ssh/ansible-ec2-key.pub
rm -f ~/.ssh/deployer-key
rm -f ~/.ssh/deployer-key.pub
```

### 3. Clean Ansible Cache

```bash
# Remove fact cache
rm -rf /tmp/ansible_fact_cache

# Remove SSH control sockets
rm -rf ~/.ansible/cp
```

---

## Verify Complete Cleanup

Run these commands to ensure everything is destroyed:

```bash
# Check for instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ansible-managed-ec2" \
  --region us-west-2

# Should return: "Reservations": []

# Check for security groups
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=ansible-ec2-sg" \
  --region us-west-2

# Should return error: does not exist

# Check for key pairs
aws ec2 describe-key-pairs \
  --key-names ansible-ec2-keypair \
  --region us-west-2

# Should return error: does not exist
```

---

## Troubleshooting Cleanup

### Security Group Won't Delete

**Error:** `DependencyViolation: resource sg-xxx has a dependent object`

**Cause:** Instance not fully terminated yet

**Solution:**
```bash
# Wait 30-60 seconds
sleep 60

# Check instance state
aws ec2 describe-instances --instance-ids $INSTANCE_ID

# Retry security group deletion
aws ec2 delete-security-group --group-name ansible-ec2-sg --region us-west-2
```

### Key Pair Not Found

**Error:** `KeyPairNotFoundException`

**Cause:** Key pair already deleted or wrong name

**Solution:** This is fine - it means the key pair is already gone. Continue with cleanup.

### Multiple Instances Found

If you have multiple instances with the same tag:

**Ansible Playbook:** Automatically terminates all matching instances

**Bash Script:** Terminates first instance found (modify script to handle multiple)

**Manual CLI:** List all instances first:
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ansible-managed-ec2" \
  --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress]' \
  --output table
```

Then terminate each one individually.

---

## Estimated Cleanup Time

- **Ansible Playbook:** 3-5 minutes
- **Bash Script:** 2-3 minutes
- **Manual CLI:** 5-10 minutes (depending on typing speed)

Most time is spent waiting for EC2 instance termination (~90 seconds).

---

## Safety Features

All three methods include safety measures:

🛡️ **Confirmation Required**
- Must type 'yes' to proceed
- Shows exactly what will be destroyed

🛡️ **Cancellation Window**
- 5 second countdown
- Press Ctrl+C to abort

🛡️ **Logging**
- All actions logged with timestamps
- Cleanup logs saved for records

🛡️ **Retries**
- Automatic retries for security group deletion
- Handles temporary AWS API issues

---

## Recommended Method

**For most users:** Use the **Bash Script** (`./scripts/cleanup.sh`)
- Fast, simple, no extra dependencies
- Colored output is easy to read
- Works even if Ansible has issues

**For automation:** Use the **Ansible Playbook**
- Integrates with existing Ansible workflows
- Uses same modules as deployment
- Idempotent and predictable

**For learning:** Use **Manual CLI**
- Understand each step
- Good for troubleshooting
- Full control over timing

---

## Need Help?

If cleanup fails:
1. Check AWS Console manually: https://console.aws.amazon.com/ec2/
2. Look for resources in the correct region (us-west-2)
3. Manually delete via AWS Console if needed
4. Check [DEPLOYMENT_NOTES.md](DEPLOYMENT_NOTES.md) for troubleshooting

---

**Remember:** Cleanup is permanent! Make sure you've backed up any data before destroying resources.
