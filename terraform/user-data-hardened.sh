#!/bin/bash
set -euo pipefail

# ============================================
# HARDENED EC2 USER DATA SCRIPT
# No dynamic npm installs - pulls pre-built images only
# ============================================

# Logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "===== Starting hardened instance setup ====="
echo "Timestamp: $(date)"

# ============================================
# System Updates & Security Patches
# ============================================
echo "Applying security updates..."
export DEBIAN_FRONTEND=noninteractive

# Update package lists
apt-get update

# Install security updates only (faster than full upgrade)
apt-get upgrade -y

# Install required packages
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    unattended-upgrades \
    fail2ban \
    ufw

# ============================================
# Enable Automatic Security Updates
# ============================================
echo "Enabling automatic security updates..."
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "$${distro_id}:$${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

# ============================================
# Install Docker (from official repository)
# ============================================
echo "Installing Docker from official repository..."

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# ============================================
# Harden Docker Daemon
# ============================================
echo "Hardening Docker daemon..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "icc": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

systemctl restart docker

# ============================================
# Configure Firewall (UFW)
# ============================================
echo "Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   # SSH (emergency only)
ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS
ufw --force enable

# ============================================
# Configure fail2ban (SSH protection)
# ============================================
echo "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

systemctl enable fail2ban
systemctl start fail2ban

# ============================================
# Install CloudWatch Agent
# ============================================
echo "Installing CloudWatch agent..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/ec2/dog-sounds",
            "log_stream_name": "{instance_id}/user-data"
          },
          {
            "file_path": "/var/log/docker.log",
            "log_group_name": "/aws/ec2/dog-sounds",
            "log_stream_name": "{instance_id}/docker"
          }
        ]
      }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# ============================================
# Create App Directory
# ============================================
echo "Creating application directory..."
mkdir -p /home/ubuntu/app
cd /home/ubuntu/app

# ============================================
# Authenticate with ECR
# ============================================
echo "Authenticating with ECR..."
aws ecr get-login-password --region ${aws_region} | \
  docker login --username AWS --password-stdin ${ecr_repository_url}

# ============================================
# Pull Pre-Built Docker Image (NO npm install!)
# ============================================
echo "Pulling pre-built Docker image from ECR..."
docker pull ${ecr_repository_url}:${docker_image_tag}

# ============================================
# Create docker-compose.yml
# ============================================
echo "Creating docker-compose.yml..."
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  nextjs:
    image: ${ecr_repository_url}:${docker_image_tag}
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - AWS_REGION=${aws_region}
    # Security: Read-only root filesystem
    read_only: true
    # Security: Drop all capabilities
    cap_drop:
      - ALL
    # Security: No new privileges
    security_opt:
      - no-new-privileges:true
    # Resource limits
    mem_limit: 512m
    cpus: 0.5
    # Health check
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/api/clips', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - nextjs
    # Security: Read-only root filesystem (except cache)
    read_only: true
    tmpfs:
      - /var/cache/nginx
      - /var/run
    # Security: Drop all capabilities except NET_BIND_SERVICE
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    security_opt:
      - no-new-privileges:true
    mem_limit: 128m
    cpus: 0.25
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF

# ============================================
# Create Hardened nginx.conf with Security Headers
# ============================================
echo "Creating hardened nginx configuration..."
cat > nginx.conf <<'EOF'
events {
    worker_connections 1024;
}

http {
    # Security: Hide nginx version
    server_tokens off;

    # Security: Rate limiting
    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=api:10m rate=5r/s;
    limit_conn_zone $binary_remote_addr zone=addr:10m;

    upstream nextjs {
        server nextjs:3000;
    }

    server {
        listen 80;
        server_name _;

        # Connection limits
        limit_conn addr 10;
        limit_req zone=general burst=20 nodelay;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;

        # HSTS (uncomment after SSL is configured)
        # add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        location / {
            proxy_pass http://nextjs;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # Timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;

            # Buffer limits
            client_max_body_size 10m;
        }

        # API rate limiting (stricter)
        location /api/ {
            limit_req zone=api burst=10 nodelay;
            proxy_pass http://nextjs;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF

# ============================================
# Set Ownership
# ============================================
chown -R ubuntu:ubuntu /home/ubuntu/app

# ============================================
# Start Application
# ============================================
echo "Starting application..."
cd /home/ubuntu/app
docker compose up -d

# ============================================
# Verify Deployment
# ============================================
sleep 10
if docker compose ps | grep -q "Up"; then
    echo "✅ Application started successfully!"
else
    echo "❌ Application failed to start!"
    docker compose logs
    exit 1
fi

# ============================================
# Setup Completed
# ============================================
echo "===== Setup complete! ====="
echo "Application is running on port 80"
echo "Timestamp: $(date)"
