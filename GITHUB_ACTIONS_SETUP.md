# GitHub Actions CI/CD Setup Guide

This document explains how to use the GitHub Actions workflows configured for this Ansible project.

## Overview

This project includes automated CI/CD pipelines using GitHub Actions with three main workflows:

1. **ansible-ci.yml** - Main CI/CD pipeline with linting, testing, and deployment
2. **test.yml** - Comprehensive testing for pull requests and changes
3. Security scanning with Trivy

## Workflows

### 1. Ansible CI/CD Pipeline (`ansible-ci.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Manual trigger via workflow_dispatch (with optional deployment)

**Jobs:**

#### a. Lint
- Runs yamllint to check YAML syntax
- Runs ansible-lint to validate Ansible best practices
- Checks all playbooks and roles

#### b. Syntax Check
- Validates syntax of all playbooks using `ansible-playbook --syntax-check`
- Tests: site.yml, provision.yml, cleanup.yml

#### c. Security Scan
- Runs Trivy vulnerability scanner
- Uploads results to GitHub Security tab
- Scans for security issues in code and dependencies

#### d. Dry Run
- Executes on pull requests only
- Simulates deployment without actual execution
- Validates the deployment would work

#### e. Deploy (Production)
- Only runs on manual trigger with deploy=true
- Requires `production` environment approval
- Provisions EC2 instances
- Deploys application
- Verifies deployment success

#### f. Notification
- Sends notifications after deployment
- Customizable for Slack, Discord, or Email

### 2. Test Ansible Changes (`test.yml`)

**Triggers:**
- Pull requests that modify:
  - YAML files
  - Roles
  - Playbooks
  - Variables
  - Inventory

**Jobs:**

#### a. Test Roles
- Validates structure of each role (users, base, firewall, app, nginx)
- Checks for required files
- Validates syntax of role tasks

#### b. Validate Inventory
- Checks inventory file structure
- Validates ansible.cfg

#### c. Check Variables
- Scans for potential exposed secrets
- Validates variable file structure
- Ensures vault files are encrypted

#### d. Test Playbook Dependencies
- Verifies all referenced roles exist
- Checks playbook includes and dependencies

## Setup Instructions

### Prerequisites

1. A GitHub repository for this project
2. AWS account with appropriate permissions
3. EC2 SSH key pair

### Step 1: Push Code to GitHub

```bash
# Initialize git repository (if not already done)
git init

# Add remote repository
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git

# Add all files
git add .

# Commit
git commit -m "Initial commit with GitHub Actions CI/CD"

# Push to GitHub
git push -u origin main
```

### Step 2: Configure GitHub Secrets

Navigate to your repository on GitHub: **Settings > Secrets and variables > Actions**

Add the following secrets:

#### Required Secrets

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key for EC2 provisioning | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key | `wJalr...` |
| `AWS_REGION` | AWS region for deployment | `us-west-2` |
| `SSH_PRIVATE_KEY` | Private SSH key for EC2 access | Contents of `~/.ssh/ansible-ec2-key` |
| `ANSIBLE_VAULT_PASSWORD` | Password for Ansible Vault | Your vault password |

#### Optional Secrets (for notifications)

| Secret Name | Description |
|------------|-------------|
| `SLACK_WEBHOOK` | Slack webhook URL for notifications |
| `DISCORD_WEBHOOK` | Discord webhook URL for notifications |

### Step 3: Configure GitHub Environment

1. Go to **Settings > Environments**
2. Create a new environment called `production`
3. Add protection rules:
   - Required reviewers (recommended)
   - Wait timer (optional)
   - Deployment branches: `main` only

### Step 4: Enable GitHub Actions

1. Go to **Actions** tab in your repository
2. GitHub Actions should be enabled by default
3. You'll see the workflows listed

## Using the Workflows

### Automatic Triggers

#### On Push to Main/Develop
- Automatically runs lint, syntax check, and security scanning
- No deployment occurs automatically

#### On Pull Request
- Runs full test suite
- Validates roles, inventory, and variables
- Checks for security issues
- No deployment occurs

### Manual Deployment

To manually trigger a deployment:

1. Go to **Actions** tab
2. Select "Ansible CI/CD Pipeline"
3. Click "Run workflow"
4. Select branch (should be `main`)
5. Check "Deploy to target environment"
6. Click "Run workflow"
7. Approve in the `production` environment if required

## Workflow Status Badges

Add these badges to your README.md:

```markdown
[![Ansible CI/CD](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/ansible-ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/ansible-ci.yml)

[![Test Ansible Changes](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/test.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/test.yml)
```

## Customization

### Adding Notifications

Edit [.github/workflows/ansible-ci.yml](.github/workflows/ansible-ci.yml):

**For Slack:**
```yaml
- name: Send success notification
  if: needs.deploy.result == 'success'
  run: |
    curl -X POST -H 'Content-type: application/json' \
      --data '{"text":"✅ Deployment successful!"}' \
      ${{ secrets.SLACK_WEBHOOK }}
```

**For Discord:**
```yaml
- name: Send success notification
  if: needs.deploy.result == 'success'
  run: |
    curl -X POST -H 'Content-type: application/json' \
      --data '{"content":"✅ Deployment successful!"}' \
      ${{ secrets.DISCORD_WEBHOOK }}
```

### Modifying Linting Rules

Edit [.yamllint.yml](.yamllint.yml) to adjust YAML linting rules:

```yaml
rules:
  line-length:
    max: 120  # Adjust maximum line length
    level: warning
```

### Adding More Tests

Edit [.github/workflows/test.yml](.github/workflows/test.yml) to add custom tests:

```yaml
- name: Custom validation
  run: |
    # Add your custom validation commands
    echo "Running custom tests..."
```

## Troubleshooting

### Workflow Fails on Lint

**Problem:** ansible-lint or yamllint failures

**Solution:**
```bash
# Run locally first
pip install ansible-lint yamllint
yamllint -c .yamllint.yml .
ansible-lint playbooks/*.yml roles/*/tasks/*.yml
```

### Deployment Fails - SSH Key Issues

**Problem:** Cannot connect to EC2 instance

**Solution:**
1. Verify `SSH_PRIVATE_KEY` secret contains the complete private key
2. Check the private key format (should start with `-----BEGIN RSA PRIVATE KEY-----`)
3. Ensure the key has no passphrase

### Deployment Fails - AWS Credentials

**Problem:** AWS authentication errors

**Solution:**
1. Verify AWS credentials in GitHub Secrets
2. Check IAM permissions for the AWS user
3. Ensure the AWS region is correct

### Vault Password Issues

**Problem:** Cannot decrypt vault files

**Solution:**
1. Verify `ANSIBLE_VAULT_PASSWORD` secret is set correctly
2. Test locally: `ansible-vault view group_vars/vault.yml`
3. Ensure no extra whitespace in the password

## Best Practices

1. **Never commit secrets** - Always use GitHub Secrets
2. **Test locally first** - Run ansible-lint and yamllint before pushing
3. **Use pull requests** - Let the test workflow validate changes
4. **Require approvals** - Use environment protection rules for production
5. **Monitor workflows** - Check the Actions tab regularly
6. **Keep workflows updated** - Update action versions periodically

## Security Considerations

1. **Secrets Management:**
   - Never hardcode secrets in workflows
   - Rotate AWS credentials regularly
   - Use least privilege IAM policies

2. **Branch Protection:**
   - Protect `main` branch
   - Require PR reviews
   - Require status checks to pass

3. **Environment Protection:**
   - Use environment secrets for production
   - Require manual approval for deployments
   - Limit who can approve deployments

4. **Audit:**
   - Review workflow runs regularly
   - Monitor security scan results
   - Check for failed authentication attempts

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [AWS Security Best Practices](https://aws.amazon.com/security/security-resources/)

## Support

For issues or questions:
1. Check workflow logs in the Actions tab
2. Review this documentation
3. Check GitHub Actions documentation
4. Review Ansible documentation

## Future Enhancements

Consider adding:
- [ ] Molecule for role testing
- [ ] Integration tests with test EC2 instances
- [ ] Performance benchmarking
- [ ] Automated rollback on failure
- [ ] Multi-environment deployments (staging, production)
- [ ] Scheduled security scans
- [ ] Automated dependency updates with Dependabot
