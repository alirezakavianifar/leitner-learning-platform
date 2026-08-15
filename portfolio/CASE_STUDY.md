# 📱 Case Study: Leitner Learning Platform

## 1. Executive Summary
The **Leitner Learning Platform** is an enterprise-grade, offline-first mobile learning ecosystem engineered for high-retention spaced repetition study. Built with **Flutter 3.x LTS**, **.NET 8 Web API**, **PostgreSQL 16**, **Redis 7**, and **React**, the platform allows learners to download entire interactive courses containing rich media (images and high-fidelity audio) into securely encrypted, local SQLite databases for zero-latency, completely offline study sessions.

The system enforces strict algorithmic Leitner progression rules, automated overdue resets, anti-piracy protections (including dynamic screenshot prevention and encrypted media bundles), and dynamic network failover capabilities managed through a pluggable administrative console.

---

## 2. Core Architecture & Tech Stack

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Leitner Learning Ecosystem                      │
└────────────────────────────────────────────────────────────────────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         ▼                          ▼                          ▼
┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│  Flutter Mobile  │      │  .NET 8 Backend  │      │   React Admin    │
│    (iOS / Android)│      │     Web API      │      │     Console      │
│  ─────────────── │      │  ─────────────── │      │  ─────────────── │
│ • Clean Arch     │      │ • Modular API    │      │ • Vite + TS      │
│ • BLoC / Cubit   │◄────►│ • PostgreSQL 16  │◄────►│ • Course Mgr     │
│ • Encrypted SQL  │      │ • Redis 7 Cache  │      │ • Sales Audit    │
│ • Offline Sync   │      │ • Hangfire Sync  │      │ • Remote Flags   │
└──────────────────┘      └──────────────────┘      └──────────────────┘
                                    │
                                    ▼
                          ┌──────────────────┐
                          │ Course Authoring │
                          │     Kit (CLI)    │
                          │ ──────────────── │
                          │ • Python 3       │
                          │ • AES Encryption │
                          │ • SQLite Packager│
                          └──────────────────┘
```

### 📱 Mobile Client (iOS & Android)
- **Framework:** Flutter 3.22+ LTS with Dart
- **Architecture:** Feature-Based Clean Architecture (`features/auth`, `features/courses`, `features/flashcards`, `features/statistics`, `features/settings`, `features/sync`)
- **State Management:** BLoC / Cubit pattern separating presentation from business logic
- **Local Storage & Offline Engine:** Encrypted SQLite (`sqflite` / `sqlite3`) with schema versioning and separated encrypted media directories
- **Security & Privacy:** Remote-toggled `FLAG_SECURE` window manager integration (anti-screenshot/screen recording blocker) and dynamic user watermarking
- **Network Layer:** Dio with custom Retry & Dynamic Host Failover interceptors

### 🖥️ Backend & Database Services
- **Runtime & Framework:** .NET 8 LTS (C#) Web API with Domain-Driven Design (DDD) principles
- **Database:** PostgreSQL 16 with Entity Framework Core (Code-First migrations)
- **Caching & Event Bus:** Redis 7 for distributed caching, OTP rate-limiting, and internal event propagation
- **Background Processing:** Hangfire worker service for off-server replication and automated database maintenance
- **Authentication:** JWT bearer tokens with refresh rotation and multi-provider SMS/OTP gateway integration (Kavenegar / FarazSMS / IranPayamak)
- **Containerization:** Multi-container Docker Compose orchestration with Nginx reverse proxy

### 🎛️ Administrative Control Center
- **Framework:** React 18/19, TypeScript, Vite, Tailwind CSS
- **Features:** Modular micro-dashboard architecture, live sales and user purchase management, SQLite course package deployment, real-time audit logging, banner scheduling, and remote feature toggles.

### 📦 Course Authoring Kit
- **Tooling:** Python 3 cryptographic CLI compiler
- **Functionality:** Compiles raw card metadata, markdown/text formatting, audio files, and images into encrypted standalone SQLite database packages with cryptographic verification.

---

## 3. Spaced Repetition Engine & Custom Business Logic

The platform implements a sophisticated 5-stage Leitner spaced repetition engine with customized retention constraints:

```
[ New Cards ] ──► [ Box 1 ] ──(Day 0)──► [ Box 2 ] ──(Day 3)──► [ Box 3 ] ──(Day 7)──► [ Box 4 ] ──(Day 16)──► [ Box 5 ] ──(Day 31)──► [ Finished Cards ]
                    ▲                      │                      │                      │                      │
                    └── (Answer Wrong) ────┴──────────────────────┴──────────────────────┴──────────────────────┘
                    └── (Overdue Miss) ─────────────────────────────────────────────────────────────────────────┘
```

1. **Box Intervals:**
   - **Box 1:** Initial entry stage (Daily queue).
   - **Box 2:** Reviewed **3 days** after promotion from Box 1.
   - **Box 3:** Reviewed **7 days** after promotion from Box 2.
   - **Box 4:** Reviewed **16 days** after promotion from Box 3.
   - **Box 5:** Reviewed **31 days** after promotion from Box 4.
   - **Finished Cards:** Successfully answered Box 5 cards graduate to the permanent Mastered pool.
2. **Incorrect Answer Reset:** An incorrect response immediately resets any card from Boxes 2–5 back to Box 1.
3. **Overdue Reset Rule:** If a card becomes due on a scheduled day and is not reviewed before midnight, the card's progress is automatically reset to Box 1 to ensure solid memory consolidation.
4. **Favorites & Direct Navigation Protection:** To prevent memorization exploits, opening a card directly via card number or favorites menu triggers an explicit confirmation dialog informing the user that accessing the card out-of-schedule will reset its progress back to Box 1.
5. **Strict Due-Card Filtering:** Active study sessions exclusively serve cards that are currently due or in Box 1, preventing premature review from skewing the memory retention curve.

---

## 4. Offline-First Architecture & Security

| Feature | Technical Implementation |
| :--- | :--- |
| **Zero-Latency Offline Study** | Complete courses are downloaded as self-contained SQLite packages. All card evaluations, flip animations, and Leitner schedule calculations happen locally on-device without requiring internet connectivity. |
| **Content Encryption at Rest** | Course SQLite databases and binary media assets (audio/images) are stored on device storage using AES encryption, preventing unauthorized file extraction. |
| **Dynamic Screen Capture Protection** | The mobile app integrates platform-native window flags (`FLAG_SECURE` on Android and secure overlay buffers on iOS) to block screenshots and screen recording. This protection can be toggled remotely per course from the Admin Panel. |
| **Resilient Dynamic Network Failover** | The mobile client’s HTTP client features a connection error interceptor. If the primary API endpoint experiences downtime or DNS blocks, the client pings verified fallback host mirrors, updates `baseUrl` dynamically, and retries in-flight requests transparently. |
| **Off-Server Disaster Recovery** | All user purchase records, course activations, and account registrations trigger asynchronous replication to external off-site cloud storage. |

---

## 5. Key Engineering Challenges & Solutions

| Challenge | Engineering Solution |
| :--- | :--- |
| **Offline-First Synchronization with Complex Scheduling Rules** | Engineered a client-side state machine in Dart that tracks UTC review timestamps, calculates due dates relative to device timezone, and syncs progress delta logs upon reconnecting to the network. |
| **Optimized Media Loading in Encrypted Flashcards** | Implemented an in-memory streaming decryption pipeline for card images and audio clips, eliminating unencrypted temporary files while maintaining 60 FPS flip animations. |
| **Multi-Flavor Build Configuration** | Configured Flutter flavors (`premium` and `store`) to support direct in-app payment gateway integrations (ZarinPal) alongside store-compliant distribution (Google Play, Cafe Bazaar, Myket) from a single unified codebase. |
| **High-Volume SMS/OTP Reliability** | Architected a pluggable SMS provider factory supporting automated failover between multiple domestic SMS gateways with an isolated development bypass mechanism. |

---

## 6. Deliverables & Verification
- **Cross-Platform Mobile App:** Production Flutter release for iOS & Android with full tablet and mobile responsive layouts.
- **Scalable RESTful Backend:** Production-ready .NET 8 API with Dockerized PostgreSQL and Redis.
- **Admin Dashboard:** Modern React + TypeScript single-page application with comprehensive audit trails.
- **Authoring Suite & Documentation:** Complete Python packaging kit, deployment scripts (`deploy-to-server.ps1`, `build-apk.ps1`), and comprehensive architecture blueprints.
