#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Checking Dockerfile security best practices...${NC}"

DOCKERFILE="Dockerfile"
ERRORS=0

if [ ! -f "$DOCKERFILE" ]; then
    echo -e "${RED}✗ Dockerfile not found${NC}"
    exit 1
fi

# Check for USER directive
if ! grep -q "^USER " "$DOCKERFILE"; then
    echo -e "${RED}✗ No USER directive found - container will run as root!${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ USER directive found${NC}"
fi

# Check for HEALTHCHECK
if ! grep -q "^HEALTHCHECK " "$DOCKERFILE"; then
    echo -e "${YELLOW}⚠ No HEALTHCHECK directive found${NC}"
fi

# Check for specific vulnerable patterns
if grep -q "npm install" "$DOCKERFILE" | grep -v "npm ci"; then
    echo -e "${YELLOW}⚠ Found 'npm install' - consider using 'npm ci' for reproducible builds${NC}"
fi

# Check for --ignore-scripts flag
if grep -q "npm.*install" "$DOCKERFILE" && ! grep -q "ignore-scripts" "$DOCKERFILE"; then
    echo -e "${YELLOW}⚠ Consider using --ignore-scripts flag to prevent malicious postinstall scripts${NC}"
fi

# Check for multi-stage build
if ! grep -q "FROM.*AS " "$DOCKERFILE"; then
    echo -e "${YELLOW}⚠ Not using multi-stage build - consider using it to reduce image size${NC}"
fi

# Check for security updates
if ! grep -q "upgrade" "$DOCKERFILE"; then
    echo -e "${YELLOW}⚠ No system security updates found - consider adding 'apt-get upgrade' or 'apk upgrade'${NC}"
fi

# Check for secrets in ENV
if grep -E "^ENV.*(PASSWORD|SECRET|KEY|TOKEN)=.+" "$DOCKERFILE"; then
    echo -e "${RED}✗ Found hardcoded secrets in ENV directives!${NC}"
    ERRORS=$((ERRORS + 1))
fi

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}✗ Dockerfile security check failed with $ERRORS error(s)${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Dockerfile security check passed${NC}"
    exit 0
fi
