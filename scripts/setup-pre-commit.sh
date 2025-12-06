#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}===== Setting up Pre-commit Hooks =====${NC}\n"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗ Python 3 is required but not installed${NC}"
    echo "Install Python 3: https://www.python.org/downloads/"
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo -e "${RED}✗ pip3 is required but not installed${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/6] Installing pre-commit framework...${NC}"
pip3 install pre-commit --quiet
echo -e "${GREEN}✓ pre-commit installed${NC}\n"

echo -e "${YELLOW}[2/6] Installing detect-secrets...${NC}"
pip3 install detect-secrets --quiet
echo -e "${GREEN}✓ detect-secrets installed${NC}\n"

echo -e "${YELLOW}[3/6] Creating secrets baseline...${NC}"
if [ ! -f ".secrets.baseline" ]; then
    detect-secrets scan > .secrets.baseline
    echo -e "${GREEN}✓ Secrets baseline created${NC}\n"
else
    echo -e "${GREEN}✓ Secrets baseline already exists${NC}\n"
fi

echo -e "${YELLOW}[4/6] Installing optional tools...${NC}"

# Check for Trivy
if ! command -v trivy &> /dev/null; then
    echo -e "${YELLOW}⚠ Trivy not found. Install for vulnerability scanning:${NC}"
    echo "  macOS:  brew install trivy"
    echo "  Ubuntu: apt-get install trivy"
else
    echo -e "${GREEN}✓ Trivy found${NC}"
fi

# Check for hadolint
if ! command -v hadolint &> /dev/null; then
    echo -e "${YELLOW}⚠ hadolint not found. Install for Dockerfile linting:${NC}"
    echo "  macOS:  brew install hadolint"
    echo "  Ubuntu: wget -qO /usr/local/bin/hadolint https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64 && chmod +x /usr/local/bin/hadolint"
else
    echo -e "${GREEN}✓ hadolint found${NC}"
fi

# Check for tflint
if ! command -v tflint &> /dev/null; then
    echo -e "${YELLOW}⚠ tflint not found. Install for Terraform linting:${NC}"
    echo "  macOS:  brew install tflint"
    echo "  Ubuntu: curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash"
else
    echo -e "${GREEN}✓ tflint found${NC}"
fi

# Check for tfsec
if ! command -v tfsec &> /dev/null; then
    echo -e "${YELLOW}⚠ tfsec not found. Install for Terraform security scanning:${NC}"
    echo "  macOS:  brew install tfsec"
    echo "  Ubuntu: curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash"
else
    echo -e "${GREEN}✓ tfsec found${NC}"
fi

echo ""
echo -e "${YELLOW}[5/6] Installing git hooks...${NC}"
pre-commit install
echo -e "${GREEN}✓ Git hooks installed${NC}\n"

echo -e "${YELLOW}[6/6] Running initial scan on all files...${NC}"
if pre-commit run --all-files; then
    echo -e "${GREEN}✓ All checks passed!${NC}\n"
else
    echo -e "${YELLOW}⚠ Some checks failed. Please review and fix the issues above.${NC}\n"
fi

echo -e "${GREEN}===== Pre-commit Setup Complete! =====${NC}\n"

echo -e "${BLUE}What happens now:${NC}"
echo "  • Every time you run 'git commit', the following will be checked:"
echo "    ✓ Secrets (AWS keys, passwords, etc.)"
echo "    ✓ npm audit (vulnerable packages)"
echo "    ✓ Dockerfile security"
echo "    ✓ Terraform security (if tfsec installed)"
echo "    ✓ Large files"
echo "    ✓ Merge conflicts"
echo "    ✓ Private keys"
echo ""
echo -e "${BLUE}Manual testing:${NC}"
echo "  Run all checks:  pre-commit run --all-files"
echo "  Skip hooks:      git commit --no-verify (NOT RECOMMENDED)"
echo ""
echo -e "${BLUE}Update hooks:${NC}"
echo "  Update versions: pre-commit autoupdate"
echo ""
