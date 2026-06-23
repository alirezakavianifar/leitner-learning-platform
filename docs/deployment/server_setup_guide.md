# Server Setup Guide

This guide details the prerequisites and step-by-step setup instructions for hosting the Leitner Learning Platform backend API, database, and admin panel on both Windows Server 2025 (development/staging) and Linux hosts (production-ready).

---

## 1. Windows Server 2025 Setup Guide

To configure a Windows Server 2025 host for manual deployment or development/staging runs:

### A. Install Prerequisite Software
1. **.NET 8 LTS SDK**:
   * Download and run the official .NET 8.0 SDK installer from [dotnet.microsoft.com](https://dotnet.microsoft.com/download/dotnet/8.0).
   * Verify installation in PowerShell:
     ```powershell
     dotnet --version
     ```
2. **Node.js (v22 LTS)**:
   * Download the Windows Installer (`.msi`) from the official Node.js website.
   * Verify installation in PowerShell:
     ```powershell
     node -v
     npm -v
     ```
3. **PostgreSQL 16**:
   * Download the PostgreSQL 16 Windows installer from EnterpriseDB.
   * Run the installer. Keep the default port `5432` and set a strong master database password.
   * Configure the pgAdmin tool or add PostgreSQL binary directory (`C:\Program Files\PostgreSQL\16\bin`) to the system Environment `PATH` to access `psql` from CLI.
4. **Redis for Windows (Optional)**:
   * For local setups without Docker, install Memurai or Redis via WSL2, or configure it on a remote instance.

### B. Configure Database Schema
Create a new database named `leitner_db` inside PostgreSQL and run Entity Framework migrations:
```powershell
cd backend/LeitnerPlatform.API
$env:ASPNETCORE_ENVIRONMENT="Development"
dotnet ef database update
```

### C. Host Backend via Standalone Kestrel or IIS
* **Standalone Kestrel (Recommended for simplicity)**:
  Build and run the release output directly:
  ```powershell
  dotnet publish -c Release -o C:\inetpub\LeitnerPlatformAPI
  cd C:\inetpub\LeitnerPlatformAPI
  $env:ASPNETCORE_URLS="http://localhost:5000"
  dotnet LeitnerPlatform.API.dll
  ```
* **IIS Configuration (Internet Information Services)**:
  1. Open **Server Manager** -> **Add Roles and Features** -> Install **Web Server (IIS)**.
  2. Install the **.NET Core Hosting Bundle** (allows IIS to run ASP.NET Core apps as a reverse proxy).
  3. Open **IIS Manager**, right-click **Sites** -> **Add Website**.
  4. Point the physical path to your published directory `C:\inetpub\LeitnerPlatformAPI`.
  5. Set the Application Pool to **No Managed Code**.

---

## 2. Linux Server Setup Guide (Ubuntu 24.04 LTS)

The production stack is containerized and runs on Ubuntu 24.04 LTS.

### A. System Preparation & Package Updates
Log in as root or a user with `sudo` privileges and run:
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git ufw build-essential
```

### B. Docker Engine Configuration
Install Docker using the official Docker repository:
```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install Docker packages:
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Verify installation:
```bash
sudo docker compose version
```

### C. Nginx Reverse Proxy Setup
Install Nginx to act as the web entry point handling SSL/TLS:
```bash
sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```

---

## 3. Firewall Rules (UFW)
Secure your server by restricting open ports:
* On Windows Server: Open port `80` (HTTP) and `443` (HTTPS) inside Windows Defender Firewall.
* On Linux (Ubuntu):
  ```bash
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow ssh
  sudo ufw allow http
  sudo ufw allow https
  sudo ufw enable
  ```
