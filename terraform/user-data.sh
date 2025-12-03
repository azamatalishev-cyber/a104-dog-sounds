#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create app directory
mkdir -p /home/ubuntu/app
cd /home/ubuntu/app

# Create docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  nextjs:
    image: node:20-alpine
    working_dir: /app
    command: sh -c "npm install && npm run build && npm start"
    volumes:
      - ./app:/app
    environment:
      - AWS_REGION=${aws_region}
      - S3_BUCKET_NAME=${s3_bucket_name}
      - NODE_ENV=production
    ports:
      - "3000:3000"
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - nextjs
    restart: unless-stopped
EOF

# Create nginx.conf
cat > nginx.conf <<'EOF'
events {
    worker_connections 1024;
}

http {
    upstream nextjs {
        server nextjs:3000;
    }

    server {
        listen 80;
        server_name _;

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
        }
    }
}
EOF

# Clone your repository (you'll need to update this)
# For now, create a placeholder
mkdir -p app
cat > app/package.json <<'EOF'
{
  "name": "dog-sounds",
  "version": "1.0.0",
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  }
}
EOF

# Set ownership
chown -R ubuntu:ubuntu /home/ubuntu/app

# Start Docker Compose
cd /home/ubuntu/app
docker-compose up -d

echo "Setup complete! Application should be running on port 80"
