# Linux & Docker Deployment Guide

This document describes how to deploy the containerized Leitner Learning Platform services (Database, Caching, API, Background Worker, and Web Admin Panel) in a production Linux environment using Docker Compose and Nginx.

---

## 1. Directory Layout & Docker Compose Configuration

The deployment files are organized in the `/deployment` folder:
* **[docker-compose.yml](file:///e:/projects/leitner-learning-platform/deployment/docker-compose.yml)**: Directs container bindings, resource policies, and services networking.
* **[Dockerfile.backend](file:///e:/projects/leitner-learning-platform/deployment/Dockerfile.backend)**: Multi-stage build compilation for the .NET 8 API and Hangfire scheduler.
* **[Dockerfile.admin](file:///e:/projects/leitner-learning-platform/deployment/Dockerfile.admin)**: Node-based compilation outputting static assets served via an optimized Nginx container.
* **[nginx.admin.conf](file:///e:/projects/leitner-learning-platform/deployment/nginx.admin.conf)**: Internal SPA redirect rules for the React admin panel router.

---

## 2. Environment Variables (.env Template)

Create a secure `.env` file in the root directory. This contains critical production secrets and database credentials.

```bash
# ==============================================================================
# Database & Cache Configurations
# ==============================================================================
DB_PASSWORD=your_super_secure_db_password_2026
REDIS_PASSWORD=your_super_secure_redis_password_2026

# ==============================================================================
# Backend API Options
# ==============================================================================
ASPNETCORE_ENVIRONMENT=Production
JWT_SECRET_KEY=your_lts_jwt_secret_signing_key_32_chars_or_more
SMS_GATEWAY_API_KEY=your_kavenegar_or_sms_ir_domestic_api_key

# ==============================================================================
# Backup Configurations (Secure S3 Domestic Object Storage)
# ==============================================================================
BACKUP_S3_ENDPOINT=https://s3.ir-thr-at1.arvanstorage.ir
BACKUP_S3_BUCKET=leitner-backups
BACKUP_S3_KEY=your_domestic_s3_access_key
BACKUP_S3_SECRET=your_domestic_s3_secret_key

# ==============================================================================
# Admin Panel Configurations
# ==============================================================================
VITE_API_BASE_URL=https://api.yourdomain.com/api/v1
```

---

## 3. Web Gateway & Reverse Proxy (Nginx)

On the host machine (outside the Docker network), configure Nginx to route external traffic to the appropriate containers.

### Create Site Configuration File
Create `/etc/nginx/sites-available/leitner.conf` on the host:

```nginx
server {
    listen 80;
    server_name api.yourdomain.com admin.yourdomain.com;

    # Redirect all HTTP traffic to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name api.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://localhost:8080; # Map to Backend API Docker port
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 443 ssl;
    server_name admin.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://localhost:3000; # Map to Admin Panel Container port
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable the configuration and reload Nginx:
```bash
sudo ln -s /etc/nginx/sites-available/leitner.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### Enable HTTPS with Certbot (Let's Encrypt)
To obtain free SSL certificates:
```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.yourdomain.com -d admin.yourdomain.com
```

---

## 4. Booting and Managing the Containers Stack

1. **Build and Start Services**:
   From the repository root directory, run:
   ```bash
   docker compose -f deployment/docker-compose.yml --env-file .env up -d --build
   ```
2. **Check Container Status**:
   ```bash
   docker compose -f deployment/docker-compose.yml ps
   ```
3. **Inspect Application Logs**:
   To read real-time log outputs:
   ```bash
   docker compose -f deployment/docker-compose.yml logs -f backend
   ```
4. **Shutdown the Stack**:
   ```bash
   docker compose -f deployment/docker-compose.yml down
   ```
