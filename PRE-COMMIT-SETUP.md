# Pre-Commit Hooks Setup Guide

## What Are Pre-Commit Hooks?

Pre-commit hooks are automated checks that run **before** you commit code to git. They catch security issues, vulnerabilities, and secrets before they reach GitHub.

### What Gets Checked:

✅ **npm vulnerabilities** - Catches CVEs like the one that got you hacked
✅ **Secrets** - AWS keys, passwords, tokens
✅ **Dockerfile security** - Best practices, running as root, etc.
✅ **Terraform security** - Hardcoded secrets, misconfigurations
✅ **Private keys** - SSH keys, certificates
✅ **Large files** - Prevents committing huge files
✅ **Merge conflicts** - Catches unresolved conflicts

---

## Quick Setup

Run the setup script:

```bash
cd /Users/azamat.alishev/dev/a104-dog-sounds
./scripts/setup-pre-commit.sh
```

This will:
1. Install pre-commit framework
2. Install detect-secrets
3. Create secrets baseline
4. Install git hooks
5. Run initial scan

---

## Manual Setup (if script fails)

### 1. Install Python Dependencies

```bash
# Install pre-commit
pip3 install pre-commit

# Install detect-secrets
pip3 install detect-secrets
```

### 2. Install Optional Security Tools

**macOS:**
```bash
brew install trivy        # Docker vulnerability scanning
brew install hadolint     # Dockerfile linting
brew install tflint       # Terraform linting
brew install tfsec        # Terraform security scanning
```

**Ubuntu:**
```bash
# Trivy
sudo apt-get install trivy

# hadolint
wget -qO /usr/local/bin/hadolint \
  https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64
chmod +x /usr/local/bin/hadolint

# tflint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# tfsec
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
```

### 3. Create Secrets Baseline

```bash
detect-secrets scan > .secrets.baseline
```

This creates a baseline of "known" patterns that aren't actually secrets (like example keys in docs).

### 4. Install Git Hooks

```bash
pre-commit install
```

### 5. Test the Hooks

```bash
# Run on all files
pre-commit run --all-files
```

---

## How It Works

### Every Time You Commit:

```bash
git add .
git commit -m "My changes"
```

**Before the commit is created**, pre-commit will:

1. **Check for secrets:**
   ```
   Detect secrets.................................................Passed
   ```

2. **Run npm audit:**
   ```
   npm audit.....................................................Passed
   ```

3. **Check Dockerfile:**
   ```
   Check Dockerfile security best practices......................Passed
   ```

4. **Scan Terraform:**
   ```
   Terraform security scan.......................................Passed
   ```

5. **If ALL pass** → Commit is created ✅
6. **If ANY fail** → Commit is BLOCKED ❌

### Example Blocked Commit:

```bash
$ git commit -m "Add AWS credentials"

Detect secrets.................................................Failed
- hook id: detect-secrets
- exit code: 1

ERROR: Potential secrets detected!
File: .env
Line 3: AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

Please remove the secret or add it to .secrets.baseline if it's a false positive.
```

The commit is **BLOCKED** until you fix it!

---

## What Each Hook Does

### 1. **detect-secrets**
- Scans all files for secrets (AWS keys, passwords, tokens)
- Uses entropy-based detection + regex patterns
- Prevents accidental credential leaks

### 2. **npm-audit**
- Runs `npm audit --audit-level=high`
- Blocks commits if HIGH or CRITICAL vulnerabilities found
- **Would have caught Next.js 16.0.6 vulnerability!**

### 3. **dockerfile-security-check**
- Ensures USER directive exists (non-root)
- Checks for hardcoded secrets
- Verifies security best practices
- Recommends multi-stage builds

### 4. **terraform_tfsec**
- Scans Terraform for security issues
- Checks for:
  - Unencrypted storage
  - Overly permissive security groups
  - Missing encryption
  - Hardcoded secrets

### 5. **env-file-check**
- Prevents committing `.env` files
- Blocks `.env.local`, `.env.production`, etc.

### 6. **aws-credentials-check**
- Regex scan for AWS access keys (AKIA/ASIA prefix)
- Prevents credential leaks

### 7. **check-added-large-files**
- Prevents committing files > 500KB
- Keeps repo size manageable

### 8. **detect-private-key**
- Scans for SSH private keys
- Prevents accidental key exposure

---

## Common Workflows

### Fix a Vulnerability Before Commit

```bash
# Add files
git add .

# Commit triggers npm audit
git commit -m "Update dependencies"

# npm audit fails!
# Output shows: next@16.0.6 has critical vulnerability

# Fix it
npm audit fix

# Try again
git add package*.json
git commit -m "Fix Next.js vulnerability"

# ✅ Passes!
```

### False Positive Secret

Sometimes the detector finds things that aren't actually secrets:

```bash
# Edit .secrets.baseline to mark as known
detect-secrets scan --baseline .secrets.baseline

# Or add inline exception
# pragma: allowlist secret
const EXAMPLE_KEY = "not-a-real-secret"  # pragma: allowlist secret
```

### Skip Hooks (Emergency Only!)

```bash
# NOT RECOMMENDED - only for emergencies
git commit --no-verify -m "Emergency fix"
```

**WARNING:** This bypasses all security checks!

### Update Hook Versions

```bash
# Update to latest hook versions
pre-commit autoupdate

# Re-run on all files
pre-commit run --all-files
```

---

## CI/CD Integration

You can also run these checks in GitHub Actions:

```yaml
# .github/workflows/security.yml
name: Security Checks

on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'

      - name: Install pre-commit
        run: pip install pre-commit

      - name: Run pre-commit
        run: pre-commit run --all-files
```

---

## Troubleshooting

### "pre-commit: command not found"

```bash
# Install pre-commit
pip3 install pre-commit

# Or use pipx
pipx install pre-commit
```

### "detect-secrets: command not found"

```bash
pip3 install detect-secrets
```

### Hooks are slow

```bash
# Run only on changed files (default)
git commit -m "message"

# Skip specific hooks
SKIP=terraform_tfsec git commit -m "message"
```

### Can't commit anything

```bash
# See what's failing
pre-commit run --all-files --verbose

# Fix each issue
# Then commit again
```

---

## Security Checklist

Before pushing to GitHub:

- [ ] No HIGH/CRITICAL npm vulnerabilities
- [ ] No AWS credentials in code
- [ ] No `.env` files committed
- [ ] No private SSH keys
- [ ] Dockerfile uses non-root user
- [ ] No hardcoded secrets in Terraform
- [ ] All pre-commit hooks passing

---

## What This Prevents

✅ **CVE-2025-55182** - Would have been caught by npm audit
✅ **Credential leaks** - Detect-secrets catches AWS keys
✅ **Insecure Dockerfiles** - Security check enforces best practices
✅ **Terraform misconfigurations** - tfsec finds security issues
✅ **Large file commits** - Keeps repo clean
✅ **Accidental secrets** - Multiple layers of detection

---

## Next Steps

1. ✅ Run `./scripts/setup-pre-commit.sh`
2. ✅ Make a test commit to verify hooks work
3. ✅ Share this with your team
4. ✅ Add to CI/CD pipeline

**Remember:** These hooks are your first line of defense against security issues!

---

## Support

If you run into issues:

1. Check Python is installed: `python3 --version`
2. Check pip is installed: `pip3 --version`
3. Reinstall pre-commit: `pip3 install --upgrade pre-commit`
4. Re-run setup: `./scripts/setup-pre-commit.sh`

For more info: https://pre-commit.com/
