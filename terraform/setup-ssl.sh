#!/bin/bash
set -e

echo "Installing Certbot..."
sudo apt-get update
sudo apt-get install -y certbot

echo "Stopping Nginx container temporarily..."
cd /home/ubuntu/app
docker-compose stop nginx

echo "Obtaining SSL certificate..."
sudo certbot certonly --standalone \
  -d k9-watch.azamat.rocks \
  --non-interactive \
  --agree-tos \
  --email azamatalishev@gmail.com \
  --http-01-port=80

echo "Updating nginx.conf with SSL..."
cat > /home/ubuntu/app/nginx-ssl.conf <<'EOF'
events {
    worker_connections 1024;
}

http {
    upstream nextjs {
        server nextjs:3000;
    }

    # HTTP server - redirect to HTTPS
    server {
        listen 80;
        server_name k9-watch.azamat.rocks;

        # Let's Encrypt challenge
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 301 https://$host$request_uri;
        }
    }

    # HTTPS server
    server {
        listen 443 ssl;
        server_name k9-watch.azamat.rocks;

        ssl_certificate /etc/letsencrypt/live/k9-watch.azamat.rocks/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/k9-watch.azamat.rocks/privkey.pem;

        # SSL configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

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

echo "Updating docker-compose.yml with SSL volumes..."
cat > /home/ubuntu/app/docker-compose.yml <<'EOF'
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
      - "443:443"
    volumes:
      - ./nginx-ssl.conf:/etc/nginx/nginx.conf:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
      - /var/www/certbot:/var/www/certbot:ro
    depends_on:
      - nextjs
    restart: unless-stopped
EOF

echo "Starting Nginx with SSL..."
docker-compose up -d

echo "Setting up auto-renewal cron job..."
sudo crontab -l > /tmp/cron 2>/dev/null || true
echo "0 0 * * * certbot renew --quiet --deploy-hook 'cd /home/ubuntu/app && docker-compose restart nginx'" >> /tmp/cron
sudo crontab /tmp/cron
rm /tmp/cron

echo "SSL setup complete! Your site should now be available at https://k9-watch.azamat.rocks"
