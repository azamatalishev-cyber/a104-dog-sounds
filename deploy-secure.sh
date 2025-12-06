#!/bin/bash
set -euo pipefail

# ============================================
# SECURE DEPLOYMENT SCRIPT
# Builds, scans, and deploys Docker image to ECR
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY="dog-sounds-app"
IMAGE_TAG="${1:-$(date +%Y%m%d-%H%M%S)}"

echo -e "${GREEN}===== Secure Deployment Script =====${NC}"
echo "AWS Account: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo "Image Tag: $IMAGE_TAG"
echo ""

# ============================================
# Step 1: Audit npm dependencies
# ============================================
echo -e "${YELLOW}[1/7] Auditing npm dependencies...${NC}"
if npm audit --audit-level=moderate; then
    echo -e "${GREEN}✅ No moderate or higher vulnerabilities found${NC}"
else
    echo -e "${RED}❌ npm audit found vulnerabilities!${NC}"
    echo -e "${YELLOW}Review the vulnerabilities above and fix them before deploying.${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ============================================
# Step 2: Build Docker image
# ============================================
echo -e "${YELLOW}[2/7] Building Docker image...${NC}"
docker build -t dog-sounds:$IMAGE_TAG .

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Docker build failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker image built successfully${NC}"

# ============================================
# Step 3: Scan Docker image for vulnerabilities
# ============================================
echo -e "${YELLOW}[3/7] Scanning Docker image for vulnerabilities...${NC}"

# Check if trivy is installed
if command -v trivy &> /dev/null; then
    echo "Running Trivy security scan..."
    if trivy image --severity HIGH,CRITICAL --exit-code 1 dog-sounds:$IMAGE_TAG; then
        echo -e "${GREEN}✅ No HIGH or CRITICAL vulnerabilities found${NC}"
    else
        echo -e "${RED}❌ Security vulnerabilities detected!${NC}"
        echo -e "${YELLOW}Fix the vulnerabilities above before deploying.${NC}"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    echo -e "${YELLOW}⚠️  Trivy not installed. Skipping vulnerability scan.${NC}"
    echo "Install with: brew install trivy (macOS) or apt-get install trivy (Ubuntu)"
fi

# ============================================
# Step 4: Test image locally
# ============================================
echo -e "${YELLOW}[4/7] Testing image locally...${NC}"
echo "Starting container..."
docker run -d --name dog-sounds-test -p 3001:3000 \
    -e AWS_REGION=$AWS_REGION \
    -e S3_BUCKET_NAME=frigate-dog-barks-azamat \
    dog-sounds:$IMAGE_TAG

# Wait for app to start
echo "Waiting for application to start..."
sleep 5

# Test health endpoint
if curl -f http://localhost:3001/api/clips > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Container health check passed${NC}"
else
    echo -e "${RED}❌ Container health check failed!${NC}"
    docker logs dog-sounds-test
    docker rm -f dog-sounds-test
    exit 1
fi

# Cleanup test container
docker rm -f dog-sounds-test > /dev/null 2>&1

# ============================================
# Step 5: Authenticate with ECR
# ============================================
echo -e "${YELLOW}[5/7] Authenticating with ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ ECR authentication failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ ECR authentication successful${NC}"

# ============================================
# Step 6: Tag and push image to ECR
# ============================================
echo -e "${YELLOW}[6/7] Pushing image to ECR...${NC}"

ECR_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY"

# Tag image
docker tag dog-sounds:$IMAGE_TAG $ECR_IMAGE:$IMAGE_TAG
docker tag dog-sounds:$IMAGE_TAG $ECR_IMAGE:latest

# Push image
docker push $ECR_IMAGE:$IMAGE_TAG
docker push $ECR_IMAGE:latest

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to push image to ECR!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Image pushed to ECR successfully${NC}"

# ============================================
# Step 7: Deploy to EC2 (optional)
# ============================================
echo -e "${YELLOW}[7/7] Ready to deploy to EC2${NC}"
echo ""
echo -e "${GREEN}Image successfully built and pushed to ECR!${NC}"
echo ""
echo "ECR Image: $ECR_IMAGE:$IMAGE_TAG"
echo ""
echo "To deploy to EC2, run:"
echo -e "${YELLOW}cd terraform${NC}"
echo -e "${YELLOW}terraform apply -var=\"docker_image_tag=$IMAGE_TAG\"${NC}"
echo ""
echo "Or to use the latest tag:"
echo -e "${YELLOW}terraform apply${NC}"
echo ""

# Ask if user wants to deploy now
read -p "Deploy to EC2 now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deploying to EC2...${NC}"
    cd terraform

    # Use hardened configuration
    if [ -f "main-hardened.tf" ]; then
        echo "Using hardened Terraform configuration..."
        # Backup current main.tf
        if [ -f "main.tf" ]; then
            mv main.tf main.tf.backup
        fi
        cp main-hardened.tf main.tf
    fi

    terraform init
    terraform apply -var="docker_image_tag=$IMAGE_TAG"

    echo -e "${GREEN}✅ Deployment complete!${NC}"
else
    echo -e "${YELLOW}Deployment skipped. Run terraform apply when ready.${NC}"
fi

echo -e "${GREEN}===== Deployment script complete =====${NC}"
