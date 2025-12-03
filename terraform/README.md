# Dog Sounds Terraform Deployment

This Terraform configuration deploys the Dog Sounds Next.js application to AWS EC2 with Docker.

## Architecture

```
Internet
    ↓
EC2 Instance (port 80)
    ↓
Nginx Container (port 80) → Next.js Container (port 3000)
    ↓
AWS S3 (via IAM role)
```

## Prerequisites

1. AWS CLI configured with credentials
2. Terraform installed (`brew install terraform`)
3. An EC2 SSH key pair created in AWS
4. S3 bucket with dog sound files

## Setup

1. **Copy and configure variables:**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Plan deployment:**
   ```bash
   terraform plan
   ```

4. **Deploy:**
   ```bash
   terraform apply
   ```

5. **Get the public IP:**
   ```bash
   terraform output instance_public_ip
   ```

6. **Visit your app:**
   ```
   http://<instance_public_ip>
   ```

## Deploying Your Code

After Terraform creates the EC2 instance, you need to deploy your app code:

```bash
# SSH into the instance
ssh -i ~/.ssh/your-key.pem ubuntu@<instance_public_ip>

# Clone your repository
cd /home/ubuntu/app
git clone https://github.com/yourusername/a104-dog-sounds.git app

# Or use SCP to copy files
# From your local machine:
scp -i ~/.ssh/your-key.pem -r ../app ubuntu@<instance_public_ip>:/home/ubuntu/app/

# Restart containers
docker-compose restart
```

## What Gets Created

- **EC2 Instance:** t3.small running Ubuntu 22.04
- **IAM Role:** Allows EC2 to read from S3 bucket
- **Security Group:** Allows HTTP (80) and SSH (22)
- **Docker Containers:**
  - Nginx (port 80) - reverse proxy
  - Next.js (port 3000) - your app

## Updating the App

```bash
# SSH into instance
ssh -i ~/.ssh/your-key.pem ubuntu@<instance_public_ip>

# Pull latest code
cd /home/ubuntu/app/app
git pull

# Rebuild and restart
cd /home/ubuntu/app
docker-compose down
docker-compose up -d --build
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Cost Estimate

- **EC2 t3.small:** ~$15/month
- **Data transfer:** Minimal (mostly S3 → browser)
- **Total:** ~$15-20/month

## Troubleshooting

**Check if containers are running:**
```bash
ssh ubuntu@<ip>
docker ps
```

**View logs:**
```bash
docker-compose logs -f nextjs
docker-compose logs -f nginx
```

**Restart containers:**
```bash
docker-compose restart
```
