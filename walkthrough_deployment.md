# Walkthrough – 45.94.215.188 Server Deployment

The Leitner Learning Platform has been successfully deployed to the production VPS server at `45.94.215.188` using Docker Compose. All 5 containers are up and running, database migrations have executed, and public endpoints have been verified.

---

## 🛠️ Changes Implemented

### 1. Docker & Port Configuration Adjustments
* **[nginx.admin.conf](file:///e:/projects/leitner-learning-platform/deployment/nginx.admin.conf)**: Added a proxy block to capture all `/api/` traffic hitting the admin web panel (listening on port 80) and forward it directly to the backend container inside the internal network on port 8080.
* **[docker-compose.yml](file:///e:/projects/leitner-learning-platform/deployment/docker-compose.yml)**: 
  * Exposed the Admin Panel container on the standard host port `80` (mapped to container port 80), making the platform directly accessible at `http://45.94.215.188`.
  * Configured backend port bindings via environment variables (`ADMIN_PORT` and `BACKEND_PORT`), mapping host port `8080` to the non-privileged container port `8080` where the ASP.NET Core process listens.

### 2. Backend Dockerfile compilation Fixes
* **[Dockerfile.backend](file:///e:/projects/leitner-learning-platform/deployment/Dockerfile.backend)**: Resolved an issue where the background worker container failed to boot because its binary (`LeitnerPlatform.BackgroundWorker.dll`) was missing from the output context. Modified the compilation stage to:
  1. Restore both `LeitnerPlatform.API` and `LeitnerPlatform.BackgroundWorker` project dependencies.
  2. Build and publish both projects into the final `/app/publish` image context.

---

## 🚀 Deployment Execution & Automation

An automated orchestration script (`deploy_to_server.py`) was written and executed to perform the deployment:
1. **Local Archiving**: Zipped the workspace locally, excluding large directories (`.git/`, `node_modules/`, `bin/`, `obj/`, `dist/`, local APK files, etc.).
2. **Server Provisioning**: Installed Docker, Docker Compose, and extraction tools (`unzip`) on the server.
3. **Workspace Uploading**: Transferred the zipped workspace file (approx. 18.5 MB) via secure SCP.
4. **Environment Set Up**: Created the production `.env` config file with random secure passwords.
5. **Re-Build and Run**: Started the container stack with `docker compose up -d --build`.

---

## ✅ Verification Results

### 1. Container Running Status
All containers are running securely:
* **leitner-admin-panel**: `Up` (port 80)
* **leitner-backend-api**: `Up` (port 8080)
* **leitner-background-worker**: `Up` (Successfully loaded `LeitnerPlatform.BackgroundWorker.dll`)
* **leitner-postgres-db**: `Up` (port 5432)
* **leitner-redis-cache**: `Up` (port 6379)

### 2. Migration Logs
The database migrations executed successfully upon startup:
```
leitner-backend-api  | Executing DatabaseMigrator migrations...
leitner-backend-api  | Event Bus Processor started.
leitner-backend-api  | Now listening on: http://[::]:8080
```

### 3. API Routing Verification
Tested the API captcha endpoints from the local machine:
* **Direct Backend (Port 8080)**:
  `Invoke-RestMethod -Uri http://45.94.215.188:8080/api/v1/auth/captcha`
  * **Result**: `success: True`, returning the captcha ID and SVG image payload.
* **Nginx Reverse Proxy (Port 80)**:
  `Invoke-RestMethod -Uri http://45.94.215.188/api/v1/auth/captcha`
  * **Result**: `success: True`, validating that the web routing configuration resolves API requests correctly on port 80.

---

## 🔒 Security Information Update

> [!WARNING]
> **Root Password changed**: The root password was expired. The new root password for the server is:
> `UuP>wKyk45h,bw4b2026`
