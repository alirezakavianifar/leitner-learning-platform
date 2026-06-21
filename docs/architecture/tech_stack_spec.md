# Technology Stack Specification & Setup Checklist

To ensure long-term stability and cross-platform reliability, all frameworks, runtimes, database engines, and utilities are strictly locked to Long-Term Support (LTS) versions. Any deviations from these specifications require written approval from the client.

---

## 1. Locked Technology Stack (LTS Stack)

### A. Mobile Client
*   **Framework:** Flutter SDK v3.22.x LTS (or latest stable 3.x LTS branch)
*   **Language:** Dart SDK v3.4.x (paired with the Flutter LTS version)
*   **State Management:** `flutter_bloc` v8.1.x (or latest stable BloC architecture)
*   **Local Storage:** `sqflite` (with `sqlcipher` database encryption plugins)
*   **Service Locator:** `get_it` v7.6.x (dependency injection container)

### B. Backend REST API Server
*   **Runtime:** .NET 8.0 LTS SDK / ASP.NET Core v8.0 LTS
*   **Language:** C# 12
*   **Database ORM:** Entity Framework Core v8.0 LTS (with PostgreSQL database provider)
*   **Background Jobs:** Hangfire v1.8.x (using Redis storage adapter)
*   **SMS Gateway API:** Kavenegar or local SMS gateway clients (configured via service abstraction)

### C. Web Administrative Panel
*   **Framework:** React v18.3.x
*   **Build Tooling:** Vite v5.x
*   **Language:** TypeScript v5.4.x
*   **Package Manager:** npm v10.x / Node.js v22.x LTS
*   **Router:** React Router v6.x (with lazy-load boundaries)

### D. Production Servers & Infrastructure
*   **Operating System:** Ubuntu 24.04 LTS (Production Host)
*   **RDBMS Engine:** PostgreSQL v16.x LTS
*   **Cache & Message Bus:** Redis v7.2.x LTS
*   **Web Server / Proxy:** Nginx v1.26.x (configured with SSL and proxy forwarding)
*   **Container Runtime:** Docker Engine v26.x & Docker Compose v2.x

---

## 2. Development Machine Prerequisites (Windows Server 2025)

The development and testing environment setup for Windows Server 2025 systems.

### Hardware Prerequisites (Minimum Configuration)
*   **Processor (CPU):** 8 Cores (Intel Core i7/i9 or AMD Ryzen 7/9 comparable)
*   **Memory (RAM):** 32 GB (minimum) to handle simultaneous execution of Android Emulators, Docker Containers, PostgreSQL instances, and Visual Studio IDE environments.
*   **Disk Storage:** 500 GB+ Solid State Drive (SSD) with at least 150 GB free space.

### Software Installation Checklist

| Component | Target Version | Installation Source / Instructions | Verified |
| :--- | :--- | :--- | :---: |
| **.NET SDK** | 8.0 LTS | [Microsoft SDK Portal](https://dotnet.microsoft.com/en-us/download/dotnet/8.0) | [ ] |
| **Flutter SDK** | 3.x LTS | [Flutter SDK Release Archive](https://docs.flutter.dev/release/archive) | [ ] |
| **Node.js** | v22 LTS | [NodeJS LTS Installer](https://nodejs.org/en) | [ ] |
| **PostgreSQL** | 16 LTS | [PostgreSQL Windows Installer](https://www.postgresql.org/download/windows/) | [ ] |
| **Docker Desktop** | Latest Stable | [Docker Hub Windows Setup](https://www.docker.com/products/docker-desktop/) | [ ] |
| **Git** | 2.x | [Git for Windows Client](https://git-scm.com/download/win) | [ ] |
| **Android Studio** | Latest Stable | [Android Developer Portal](https://developer.android.com/studio) | [ ] |
| **IDE Environments** | VS 2022 / VS Code | Visual Studio 2022 with ASP.NET development workload and Flutter plugins. | [ ] |

---

## 3. Linux Production Server Stack Specification

The target production server deployment maps onto a Linux stack. All dependencies run inside isolated Docker containers.

```text
[Internet / Student Requests]
            │
            ▼ (HTTPS: Port 443)
┌──────────────────────────────────────────────┐
│  Ubuntu 24.04 LTS (Host Machine)             │
│  - Nginx Reverse Proxy (SSL Certs)           │
│                                              │
│   ┌──────────────────────────────────────┐   │
│   │ Docker Compose Network               │   │
│   │                                      │   │
│   │  ├─ API Server Container (Port 80)   │   │
│   │  ├─ Background Worker Container      │   │
│   │  ├─ PostgreSQL 16 DB (Port 5432)     │   │
│   │  └─ Redis Event Bus Cache (Port 6379)│   │
│   └──────────────────────────────────────┘   │
└──────────────────────────────────────────────┘
```

### Server Execution Constraints
1.  **Strict Containerization:** Direct installation of .NET runtime or Node.js on the production host system is prohibited. All components must run within the Docker Compose network.
2.  **Encapsulated SQL:** PostgreSQL operates in a container, writing to a mapped persistent volume on the host (`/var/lib/postgresql/data`).
3.  **Reverse Proxy Enforcement:** Direct exposure of container application ports (e.g., Kestrel Port 5000/80) is disabled. All external requests route through Nginx.
4.  **Automatic Restarts:** All containers are flagged with `restart: always` to guarantee automatic recovery after server power cycles.
