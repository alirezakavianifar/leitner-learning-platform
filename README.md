# Leitner Learning Platform

Welcome to the Leitner Learning Platform repository. This repository contains the project documentation, specification, and implementation plans for the Leitner Learning Platform, designed as a highly secure, offline-first mobile application (iOS & Android) with a robust backend API and administrative panel.

## Repository Contents

*   **[plan.md](file:///e:/projects/leitner-learning-platform/plan.md)**: The complete, revised implementation plan detailing all 20 phases of development (Phases 0 through 19) and post-delivery policies.
*   **[rcd.md](file:///e:/projects/leitner-learning-platform/rcd.md)**: The Requirements Clarification Document (RCD) generated and locked in Phase 0.
*   **[document.PDF](file:///e:/projects/leitner-learning-platform/document.PDF)**: The original project requirement specifications and business rules provided by the client.
*   **[docs/ui/ui_design.md](file:///e:/projects/leitner-learning-platform/docs/ui/ui_design.md)**: The UI/UX design specifications including typography, HSL color variables, component library details, and user flow diagram mappings.
*   **[docs/ui/prototype/index.html](file:///e:/projects/leitner-learning-platform/docs/ui/prototype/index.html)**: Clickable interactive HTML/JS viewport prototype simulating all user screens.
*   **[docs/deployment/server_setup_guide.md](file:///e:/projects/leitner-learning-platform/docs/deployment/server_setup_guide.md)**: Prerequisites and server environment installations for Windows Server 2025 and Linux hosts.
*   **[docs/deployment/docker_deployment_guide.md](file:///e:/projects/leitner-learning-platform/docs/deployment/docker_deployment_guide.md)**: Container orchestration, Nginx reverse proxy configuration, environment variable schemas, and Let's Encrypt configurations.
*   **[docs/course/course_upload_guide.md](file:///e:/projects/leitner-learning-platform/docs/course/course_upload_guide.md)**: Steps to package, encrypt, compile, and upload Leitner courses using the Authoring Kit.
*   **[docs/deployment/backup_and_recovery_guide.md](file:///e:/projects/leitner-learning-platform/docs/deployment/backup_and_recovery_guide.md)**: Backup schedule policies, S3 replication workflows, and database recovery commands.
*   **[docs/sms_configuration_guide.md](file:///e:/projects/leitner-learning-platform/docs/sms_configuration_guide.md)**: Detailed reference guide for configuring, toggling, and deploying the SMS/OTP verification system.
*   **[portfolio/](file:///e:/projects/leitner-learning-platform/portfolio)**: Comprehensive English & Persian portfolio package ([English Details](file:///e:/projects/leitner-learning-platform/portfolio/UPWORK_PROJECT_DETAILS.md), [English Case Study](file:///e:/projects/leitner-learning-platform/portfolio/CASE_STUDY.md), [Persian Details](file:///e:/projects/leitner-learning-platform/portfolio/UPWORK_PROJECT_DETAILS_FA.md), [Persian Case Study](file:///e:/projects/leitner-learning-platform/portfolio/CASE_STUDY_FA.md)) with high-res showcase graphics and real live app screenshots for freelance portals.
*   **[AGENTS.md](file:///e:/projects/leitner-learning-platform/AGENTS.md)**: Instructions and constraints for autonomous AI coding agents working on this repository.


---

## Project Overview

The Leitner Learning Platform is designed around the classic Leitner flashcard system, modified with specific client business rules to optimize retention. The platform utilizes an **offline-first** architecture, allowing students to download entire courses packaged in a specialized encrypted SQLite format with separated media directories, enabling seamless studying without an active internet connection.

### Tech Stack & Architecture
*   **Mobile App:** Flutter (Android & iOS) using **Feature-Based Clean Architecture** (independent modules like `auth/`, `courses/`, `flashcards/`, `settings/`) enforcing **Repository Patterns** (UI -> Use Case -> Repository -> Data Source), explicit Dependency Injection (DI), and a client-side event bus.
*   **Backend:** Domain-separated RESTful API (Auth, User, Course, Purchase, Notification, Analytics, Configuration) with versioned endpoints (starting at `/api/v1/`), tokenized authentication, content protection, off-server backup replication, and an internal event emitter system.
*   **Admin Panel:** Pluggable, responsive web-based administrative console where core screens are treated as separate modules to allow seamless future extensions, featuring a comprehensive **Audit Logging** trail for administrative actions.
*   **Database Management:** Server databases and client SQLite databases configured with versioned database migration frameworks.
*   **Content Storage & Protection:** Encrypted local SQLite databases with separated media folders (images, audio), featuring SQLite database schema migration strategies.
*   **Remote Configuration:** Dynamic endpoint config, remote feature flags (remotely enable/disable features), dynamic social messengers (Telegram, Bale, Eitaa) and direct support (@RLAppSupport) configuration, dynamic banner configs, and global maintenance mode controls.
*   **Deployment & Compatibility:** Windows Server 2025 (development) and Linux (production target) compatible. The backend services, databases, background workers, and admin panels are containerized using **Docker** and orchestrated with **Docker Compose** to guarantee OS-independent behavior. **Mandatory Acceptance:** Successful deployment using the supplied Docker Compose package on a clean Ubuntu 24.04 server is required.
*   **Development Prerequisites & Tech Stack Locking:** Developed using .NET 8 LTS, Flutter 3.x LTS, React (TypeScript, Node.js v22 LTS), PostgreSQL 16, and Redis. The stack and versions are strictly locked to LTS (Long-Term Support) releases in Phase 1 and cannot be modified without written client approval. Windows development machines require a minimum of 8 Cores, 32 GB RAM, and 500 GB+ SSD.
*   **Secrets & Security Policies:**
    *   **Secrets Management:** No hardcoded secrets, keys, or passwords in source code; zero credentials committed to Git; all production configurations supplied through environment variables or secret vaults.
    *   **Dependency Security Policy:** Continuous vulnerability scanning in CI/CD pipelines, patch update strategies, and license compliance audits.
*   **CI/CD & Code Quality Standards:** Git version control with main branch protection rules. Automated build pipelines, test suites, and Docker builds configured in CI/CD (GitHub Actions / GitLab CI). Minimum code coverage requirements: 80% for backend business logic and 70% for core mobile features, validated alongside E2E user-journey tests.
*   **Authentication & Session Persistence:** SMS OTP verification with JWT Bearer tokens and rotating refresh tokens (`/api/v1/auth/refresh`). Administrators can dynamically configure JWT and Refresh Token durations (in minutes, hours, days, or months) and background renewal flags directly from the Web Admin Panel with full audit trail logging. The mobile client features automated background token renewal via Dio interceptors, offline-resilient startup state caching, and EncryptedSharedPreferences (Android Keystore / iOS Keychain) session storage.
*   **Integrations:** Unified payment gateway abstractions (`PaymentProvider` interface) to easily manage store-specific payments (Google Play, Cafe Bazaar, Myket, Direct Gateway).
*   **Handover & Deliverables:** Comprehensive handover including full source code, deployment templates, training sessions, and updated **Architecture Documentation** (System Architecture Diagram, Module Dependency Diagram, Event Bus Documentation, Repository Structure Documentation, Database Migration Guide, and Feature Flag Documentation).


---

## Key Features & Custom Rules

### 1. Custom Leitner Progression & Resets
*   **Box Stages & Timings (Configurable by Admin):**
    *   *Box 1:* Initial / Unlearned cards. First successful review promotes the card to Box 2 immediately.
    *   *Box 2:* Default 3 days (or configured value/unit).
    *   *Box 3:* Default 7 days (or configured value/unit).
    *   *Box 4:* Default 16 days (or configured value/unit).
    *   *Box 5:* Default 31 days (or configured value/unit).
    *   *Box 6 (Finished / Completed Cards):* Cards successfully reviewed in Box 5 graduate to Box 6 (Finished). Completed cards in Box 6 are excluded from the "Today's Cards" (کارت‌های امروز) review queue and due counters.
    *   *Dynamic Admin Configuration & Fast Verification Mode:* All box stage review intervals (Boxes 2, 3, 4, 5) and time units (`Seconds`, `Minutes`, `Hours`, `Days`) are fully configurable by the administrator in the Web Admin Panel. Admins can select presets such as **Fast Verification Mode (1 Hour Total)** (Box 2: 5m, Box 3: 10m, Box 4: 15m, Box 5: 20m) to verify the entire end-to-end Leitner lifecycle in ~50 minutes without waiting days.
*   **Incorrect Reset:** Answering incorrectly during review resets the card's progress back to Box 1 immediately.
*   **Overdue Reset (Rule A):** If a card is due on a given day/window and the user does NOT review it within that window, the card's progress resets, and it returns to Box 1. (Does not apply to Box 6 Finished cards).
*   **Favorites Reset (Rule B):** Viewing a card currently in active Leitner boxes (Boxes 2–5) from the "Favorites" screen prompts a reset warning to Box 1. Box 1 and Box 6 (Finished) cards open without reset warnings.
*   **Direct View & Navigation Reset (Rule C):** Users can enter a card number to jump directly to it. If the card is in active Leitner boxes (2–5), a warning confirmation is displayed, and upon confirmation, its Leitner progress is reset to Box 1.
*   **Finished Cards Action:** When viewing Finished Cards, pressing "Know It" does nothing; pressing "Don't Know" resets the card's progress, sending it back to Box 1.
*   **Only Due Cards Restriction:** Standard study navigation prevents browsing Box 2–5 cards before their due dates. Only Box 1 or due cards are shown in the study queue; Box 6 completed cards are accessed via the dedicated Finished Cards section.

### 2. UI Layout & Navigation
*   **Global Bottom Navigation:** A persistent bottom navigation bar (Home, Review, Courses) visible on all main screens.
*   **Course List Visual Rules:**
    *   Downloaded/purchased courses are displayed at the top of the list.
    *   Downloaded courses display with a green border; not purchased/not downloaded courses display with a yellow border.
    *   Course card displays title, card count, paid/free status, and the colored border.
    *   *Offline Behavior:* Displays cached course list and offline message stating internet is unavailable.
*   **My Courses Screen:** A dedicated screen displaying only purchased and downloaded courses, styled with a green border.
*   **Review Hub ("مرور"):** Strictly displays only purchased and unlocked courses belonging to the user. For purchased courses that are not yet downloaded locally, an inline download button is provided so users can download and initialize review directly from the tab. Unpurchased courses are strictly excluded and blocked from study at both the repository and UI layers. When no purchased courses exist, an empty state with a direct CTA to explore the Course Catalog is presented. Titles with Latin characters and numerical identifiers (e.g. "Words You Need to Know 1100") are rendered with explicit LTR text direction to prevent Arabic/Persian BiDi line-wrapping transposition glitches.
*   **Flashcard Layout:** Fixed header (displays course title and colored Leitner stage indicator), rotating center card (with flip animation, support for images and audio), and fixed footer (with left/right navigation arrows, favorites toggle, and card status).
    *   *Conditional Media Rendering:* If a card has no image, audio, or options, those sections must be hidden completely and not render or reserve empty layout space.
*   **Profile Management:** User can edit profile fields (username, interests, educational field, educational level) except for the mobile number field, which must be strictly read-only.
*   **Logout Confirmation:** A modal confirmation dialog is displayed before executing a logout to prevent accidental progress loss.
*   **Badge Count Indicators:**
    *   The *Today's Cards* button/icon displays a badge count showing today's pending review count.
    *   The *Finished Cards* button/icon displays a badge count of completed/learned cards.
*   **Onboarding Flow Sequence:** The first-run onboarding sequence follows the exact tutorial flow from the PDF: Courses -> Search -> Flashcard -> Know -> Don't Know -> Create Card -> Finished Cards -> Favorites -> My Courses -> Reports -> Today's Cards -> Statistics.

### 3. Course Bundles & Package Purchases
*   **Multi-Course Packages:** Multiple related courses can be grouped into promotional packages/bundles and offered at a discounted bundle price.
*   **Unified Checkout & Atomic Fulfillment:** Purchasing a package automatically and atomically unlocks full access to all individual constituent courses in that bundle.
*   **Package Discovery & Badges:** Courses belonging to active packages display contextual bundle recommendation chips (*"Available in [Package Name] with XX% discount"*).
*   **Admin Bundle Management:** Administrators can create, edit, publish, and delete bundles directly in the Web Admin Panel with custom pricing, discount calculation, and multi-course selection.

### 4. User-Created Cards Storage
*   **User-Created Cards:** Stored strictly locally on the device (device-only for privacy) and support backup/restore after app reinstallation. No server synchronization is performed.

### 5. Admin Management Capabilities
*   **Complimentary Course & Package Activations:** Manually grant free access to any paid single course or course package bundle directly for any user by mobile number or user profile, complete with mandatory audit logging and reason tracking.
*   **Access Revocation & Purchase Management:** Modify user purchase entries, revoke access, and filter transactions by gateway (including `ADMIN_GRANT`).
*   **Course & Package Management:** Upload and manage course metadata and SQLite packages; create, publish, and manage multi-course bundles & packages with custom pricing.
*   Create, publish, and manage multi-course bundles & packages with custom pricing.
*   Publish, schedule, or hide banners and announcements.
*   *Flashcard Reports Interface:* Admin review interface to browse and filter submitted flashcard reports by card, course, or user, and flag content issues.
*   *Dynamic Leitner Stage Intervals & 1-Hour Verification:* Configure review intervals per Leitner stage (Boxes 2–5) and time units (`Seconds`, `Minutes`, `Hours`, `Days`) with one-click presets for standard or fast verification testing (~1 hour total).
*   *Dynamic App Icon & Branding Logo Upload:* Upload custom high-resolution branding icons (PNG, WebP, SVG, ICO) directly via the Admin Panel (`POST /api/v1/admin/config/upload-logo` and `POST /api/v1/admin/config/reset-logo`). In-app branding propagates instantly over-the-air to all active mobile app clients across About Us, Drawer, and Headers via `/api/v1/config/features` with local caching and offline fallback.
*   *Icon Sizing & Visual Scaling:* Remotely configure global icon scaling (0.85x–1.30x), in-app logo/branding size (`app_logo_size` default `110px`), and section-specific icon sizes (Card Navigation arrows, Bottom Navigation Bar tabs, and App Header action icons) with instant live preview in the Web Admin Panel.

### 6. Security & Content Protection
*   Watermarked content displays to discourage piracy.
*   SQLite course databases and media files are encrypted at rest.
*   Secure, tokenized single-use download links.
*   Dynamic Screenshot & Screen Recording Protection (`FLAG_SECURE` / screen capture prevention) remotely controllable via Admin Panel.
*   Immediate, automatic off-server backups (replication of user registrations and purchases to secure S3/FTP/external storage upon every change).

### 6. Search, Statistics & Banners Workflows
*   **Targeted Search Workflow:**
    1. User searches courses.
    2. User selects one or more courses from the results.
    3. User searches cards inside those selected courses.
    4. Search results display the card numbers and matching card list.
    5. User taps a search result to open that matching card directly.
*   **Color-Coded Statistics:** Visual statistics status bars are strictly mapped to the following colors:
    *   *Orange:* Box 1 cards
    *   *Yellow:* Box 2 cards
    *   *Green:* Box 3 cards
    *   *Blue:* Box 4 cards
    *   *Purple:* Box 5 cards
    *   *Gold:* Finished Cards
*   **Banner Rotation & Management:** Displays a carousel of up to 5 banners on the main dashboard, rotating automatically every 4 seconds. Banners refresh from the server once every 24 hours.
*   **Banner Deep-Linking & In-App Routing:** Carousel banners support both external URLs (`https://...`) and rich internal in-app navigation routes (`course://<course_id>`, `package://<package_id>`, `tab://courses`, `tab://my_courses`, `tab://reviews`). Tapping an internal link navigates the user directly to the targeted course/package details inside the app.
*   **Course & Package Banner/Cover Images:** Courses and Course Packages support custom cover/banner image URLs (`image_url`) manageable directly through the Admin Panel and rendered in the mobile catalog and details modal with fallback gradients.
*   **Notification Ordering:** Inside the notification center, the latest notifications must appear at the top of the list.
*   **Top Notification Bar Review Alerts & Reminders:** Background scheduled local notifications informing users in their phone's top status notification bar when Leitner cards become due for review (even when outside the app) and daily customizable study reminders with in-app toggle controls in Settings.
*   **Flashcard Report System:** Users submit feedback storing User ID, Course ID/title, Card number, Report text, and Timestamp.

### 7. Remote Configuration & Dynamic Failover
*   **Remote Config Endpoint:** `/api/v1/config/features` aggregates dynamic parameters (endpoints, feature flags, active banners, and announcements) in a single public JSON payload.
*   **Maintenance Mode:** Can be enabled/disabled from the Admin Panel Settings dashboard. When enabled, a blocking "Scheduled Maintenance" screen is presented to all users on launch.
*   **Dynamic Failover Strategy:** The mobile client's network layer registers a custom connection error interceptor. Upon connection timeout or socket exceptions, the client sequentially pings fallback hosts to resolve a working server, updates `baseUrl` dynamically, and retries the request transparently.

---

## Setup & Deployment Instructions

### 1. Docker-Based Multi-Container Deployment (Production)

The entire backend infrastructure (Database, Cache, API, Background Worker, and Web Admin Panel) is containerized and orchestrated via Docker Compose.

#### Prerequisites
*   Docker Engine v26+ and Docker Compose v2+ installed on host (Ubuntu 24.04 LTS recommended).
*   Create an `.env` file in the root directory (referencing `deployment/docker-compose.yml`) containing:
    ```bash
    DB_PASSWORD=your_postgres_secure_password
    REDIS_PASSWORD=your_redis_secure_password
    JWT_SECRET_KEY=your_jwt_signing_secret_key_lts_2026
    BACKUP_S3_KEY=your_aws_s3_key
    BACKUP_S3_SECRET=your_aws_s3_secret
    SMS_PROVIDER=Kavenegar (or FarazSms / IranPayamak)
    SMS_GATEWAY_API_KEY=your_sms_gateway_api_key
    SMS_SENDER=your_sms_sender_line_number
    SMS_PATTERN_CODE=your_approved_pattern_code
    ZARINPAL_MERCHANT_ID=167ccd1b-f5d3-407d-85d1-a73c4f2ba3eb
    ZARINPAL_SANDBOX=false
    ZARINPAL_CALLBACK_URL=https://api.rightlearn.ir/api/v1/purchases/zarinpal/callback
    ```

#### Running the Stack
Navigate to the repository root directory and run:
```bash
docker compose -f deployment/docker-compose.yml --env-file .env up -d --build
```
This commands builds the backend and admin panel containers and boots the following:
*   **PostgreSQL 16 DB** listening on port `5432` (persistent data mapped to host volume `pgdata`).
*   **Redis 7 Cache & Event Bus** listening on port `6379`.
*   **Backend API (.NET 8)** listening on host port `8080`.
*   **Web Admin Panel** served on host port `3000`.
*   **Background Worker (Hangfire)** processing background synchronization and database cleanup jobs in the background.

#### Automated Deployment Script (deploy-to-server.ps1)
You can automate the packaging, upload, and deployment of local source files to the remote server using the provided PowerShell script. It supports configuring the SMS state (ON/OFF) dynamically during deployment:

```powershell
# Deploy with SMS ON (Default)
powershell -ExecutionPolicy Bypass -File ./scripts/deploy-to-server.ps1

# Deploy with SMS ON (Explicit)
powershell -ExecutionPolicy Bypass -File ./scripts/deploy-to-server.ps1 -Sms ON

# Deploy with SMS OFF (Disables live SMS sending and falls back to logging OTP codes to container logs)
powershell -ExecutionPolicy Bypass -File ./scripts/deploy-to-server.ps1 -Sms OFF
```

---

### 2. Manual Development Environment Setup

#### A. Backend API (.NET 8 LTS)
1.  **Dependencies:** Install .NET 8 LTS SDK, PostgreSQL 16, and Redis on your development machine (Windows Server 2025 or Linux).
2.  **Configuration:** Update the database connection string in `backend/LeitnerPlatform.API/appsettings.Development.json`.
3.  **Run Migrations:** Initialize the database schema:
    ```bash
    cd backend/LeitnerPlatform.API
    dotnet ef database update
    ```
4.  **Run Service:**
    ```bash
    dotnet run
    ```

#### B. Pluggable React Admin Panel
1.  **Dependencies:** Ensure Node.js (v22 LTS) is installed.
2.  **Install Packages:**
    ```bash
    cd admin-panel
    npm install
    ```
3.  **Configure Environment:** Create a `.env` file in `admin-panel/` setting `VITE_API_BASE_URL=http://localhost:5000/api/v1` (adjust port matching your active API port).
4.  **Admin Credentials & Development Bypass:**
    - To log in as the default seeded administrator:
      * **Mobile Number:** `+989120000000`
      * **CAPTCHA Challenge:** Answer the simple math problem displayed on screen.
      * **OTP Verification Code:** Enter `12345` (the built-in development OTP bypass code).
5.  **Run Server:**
    ```bash
    npm run dev
    ```
6.  **Production Build:** Compile static assets to `/dist` using `npm run build`.

#### C. Flutter Mobile Client
1.  **Dependencies:** Install Flutter SDK (3.22.x LTS) and Java JDK 21. Configure Android SDK / Xcode for target simulators.
    *   *Windows Desktop Run:* To run the client natively as a Windows application, ensure Visual Studio is installed with the "C++ desktop development" workload and the optional "C++ ATL for v143 build tools" component.
2.  **Get Packages:**
    ```bash
    cd mobile-app
    flutter pub get
    ```
3.  **Run App:**
    *   *Android Emulator / iOS Simulator:*
        ```bash
        flutter run
        ```
    *   *Windows Desktop Native:*
        ```bash
        flutter run -d windows
        ```
4.  **Build Configurations:**
    *   **Premium Version:** Build including payment gateway abstractions:
        ```bash
        flutter build apk --flavor premium -t lib/main_premium.dart
        ```
    *   **Store Version:** Build excluding in-app payment hooks for app stores (Google Play, Cafe Bazaar, Myket):
        ```bash
        flutter build apk --flavor store -t lib/main_store.dart
        ```
    *   **Appetize.io Cloud Emulator Testing (Automated):**
        To quickly build the APK, run a local backend, start an Ngrok tunnel, and automatically deploy/update the app on Appetize.io, see the [Appetize Testing Guide](file:///e:/projects/leitner-learning-platform/docs/appetize_testing_guide.md) or run the PowerShell script:
        ```powershell
        powershell -ExecutionPolicy Bypass -File ./scripts/deploy_to_appetize.ps1
        ```
    *   **Automated Release APK Build (Android):**
        1. **Start Tunnel:** Launch a persistent public tunnel pointing to your local backend (port 5217):
           ```powershell
           powershell -ExecutionPolicy Bypass -File ./scripts/start-tunnel.ps1
           ```
        2. **Build APK:** Compile the premium release APK targeting your server IP or active Ngrok URL:
           ```powershell
           # Target remote server directly (default):
           powershell -ExecutionPolicy Bypass -File ./scripts/build-apk.ps1 -TargetUrl "http://45.94.215.188"

           # Or target local/ngrok backend:
           powershell -ExecutionPolicy Bypass -File ./scripts/build-apk.ps1 -TargetUrl "https://api.rightlearn.ir"
           ```
        The compiled APK will be automatically copied to the repository root as `app-premium-release.apk` (and `app-premium-release.zip`), and dispatched to the Rubika distribution bot.

    *   **Automated iOS Build & Packaging (iOS IPA & Simulator):**
        1. **Local macOS Build (Mac workstation or CI runner):**
           ```bash
           # Run Bash builder on macOS:
           ./scripts/build-ios.sh --flavor premium --target-url "https://api.rightlearn.ir" --build-type both
           ```
           Or using PowerShell Core on macOS / Windows:
           ```powershell
           powershell -ExecutionPolicy Bypass -File ./scripts/build-ios.ps1 -Flavor premium -TargetUrl "https://api.rightlearn.ir"
           ```
        2. **Automated Cloud Build (GitHub Actions macOS Runner):**
           For developers on Windows without a physical Mac:
           - Go to **Actions** -> **iOS Build & Distribution Pipeline** in GitHub repository.
           - Select **Run workflow**, choose Flavor (`premium` or `store`), enter Backend Target URL, and click **Run**.
           - The GitHub macOS-14 runner automatically builds `app-premium-release.ipa` and `app-premium-ios-simulator.zip`, uploads workflow artifacts, and delivers the package to the Rubika bot.
        3. **Installing iOS Build on iPhone / iPad:**
           - **Sideloadly (Recommended):** Download [Sideloadly](https://sideloadly.io), plug in iPhone via USB, drag `app-premium-release.ipa`, enter your free Apple ID, and install.
           - **AltStore / Scarlet / TrollStore:** Import `app-premium-release.ipa` directly on the device.
           - **Appetize.io Live In-Browser Streaming:** Drag `app-premium-ios-simulator.zip` to [Appetize.io Upload](https://appetize.io/upload) to test the app in an interactive iOS simulator directly in your browser.



---

### 3. Course Authoring Kit (Content Creation)

The Course Authoring Kit allows content authors to compile raw card text and media assets into SQLite package database files with encrypted image and audio assets.

#### A. Prerequisites
Ensure Python 3.8+ and the `cryptography` package are installed on the authoring environment:
```bash
pip install cryptography
```

#### B. Compilation Command
To compile a raw course folder (such as the included sample source) into a zipped package:
```bash
python course-authoring-kit/tools/compile_course.py \
  --source course-authoring-kit/sample_course_source \
  --output course-authoring-kit/sample_course_package \
  --schema course-authoring-kit/schema/course_schema.sql \
  --key "default_dev_course_secret_key_32_bytes_long" \
  --zip course-authoring-kit/sample_course_package/course_package.zip
```

#### C. Validation Command
To verify that the compiled database structure and encrypted media assets are intact:
```bash
python course-authoring-kit/tools/verify_course.py
```


