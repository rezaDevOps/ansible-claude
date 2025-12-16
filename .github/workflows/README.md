# GitHub Actions Workflows

This directory contains CI/CD workflows for the Ansible project.

## Workflows

### 1. ansible-ci.yml
**Main CI/CD Pipeline**

- Linting (yamllint, ansible-lint)
- Syntax checking
- Security scanning (Trivy)
- Deployment to production (manual trigger)
- Notifications

### 2. test.yml
**Testing Pipeline for Pull Requests**

- Role validation
- Inventory validation
- Variable security checks
- Dependency verification

## Quick Commands

### Test locally before pushing:

```bash
# Install dependencies
pip install ansible ansible-lint yamllint

# Run yamllint
yamllint -c .yamllint.yml .

# Run ansible-lint
ansible-lint playbooks/*.yml roles/*/tasks/*.yml

# Syntax check
ansible-playbook playbooks/site.yml --syntax-check
```

### Manual deployment via GitHub Actions:

1. Go to Actions tab
2. Select "Ansible CI/CD Pipeline"
3. Click "Run workflow"
4. Check "Deploy to target environment"
5. Click "Run workflow"

## Required Secrets

Configure these in **Settings > Secrets and variables > Actions**:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `SSH_PRIVATE_KEY`
- `ANSIBLE_VAULT_PASSWORD`

## See Also

- [Complete Setup Guide](../../GITHUB_ACTIONS_SETUP.md)
- [Project README](../../README.md)
