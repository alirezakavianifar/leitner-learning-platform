# Phase 1 – System Architecture & Technical Design

Design and document the complete system architecture for the Leitner Learning Platform. This includes defining all mobile clean architectural patterns, backend modular domain boundaries, pluggable admin panel structures, event-driven internal logic, unified database ER diagrams, API specifications, and Docker container deployment configurations.

## User Review Required

> [!NOTE]
> All deliverables will be written as clean, comprehensive documentation files in the repository under a new `docs/architecture/` folder, and deployment templates will be created in a new `deployment/` folder.
> 
> Once approved, we will proceed with the immediate execution.

## Proposed Changes

We will create a structured set of architecture documentation files, deployment files, and database migrations.

### Architecture Documentation

#### [NEW] [architectural_design.md](file:///e:/projects/leitner-learning-platform/docs/architecture/architectural_design.md)
Contains detailed structural and pattern designs:
- **Mobile clean architecture** featuring a feature-based structure (`auth/`, `courses/`, `flashcards/`, `settings/` etc.) with presentation, domain, and data layer isolation.
- **Repository patterns** decoupling the UI from local SQLite and API clients.
- **Pluggable Admin Panel** layout and interface design rules.
- **Event-Driven Bus contract** (internal emitters on both frontend and backend).
- **Dependency Injection interfaces** (Service abstractions for notifications, storage, payment, etc.).
- **Backend Domain Separation** guidelines.
- **Unified Payment Gateway Abstraction** interface schema.
- **Feature Flag System** JSON and REST API specifications.
- **OS-Independent execution policies** (filesystem operations, background schedulers).

#### [NEW] [database_architecture.md](file:///e:/projects/leitner-learning-platform/docs/architecture/database_architecture.md)
Specifies the database designs:
- RDBMS schemas for the backend database (PostgreSQL 16).
- SQLite schemas for the client database.
- Database migration strategy for server schema updates and client local course SQLite package updates (handling updates without losing user study progress).
- Complete ER Diagram mappings (in Mermaid markup).

#### [NEW] [api_specification.md](file:///e:/projects/leitner-learning-platform/docs/architecture/api_specification.md)
Defines REST API routes, schemas, and versioning rules:
- Versioned pathways (`/api/v1/auth`, `/api/v1/courses`, `/api/v1/purchases`, `/api/v1/admin`, `/api/v1/statistics`, `/api/v1/config`).
- JSON payloads and query formats for all core screens (OTP, user profile, course list, reports, analytics, banners, configs).

#### [NEW] [offline_and_sync.md](file:///e:/projects/leitner-learning-platform/docs/architecture/offline_and_sync.md)
Defines offline storage, downloads, and synchronization:
- Single-use tokenized package download process.
- Media assets and database decryption flow (client-side keys).
- Offline indicator UI fallback rule.
- Full offline-first sync process mapping.

#### [NEW] [tech_stack_spec.md](file:///e:/projects/leitner-learning-platform/docs/architecture/tech_stack_spec.md)
Specifies the locked technology stacks:
- LTS Versions of all frameworks and runtimes (.NET 8 LTS, Flutter 3.x, React + TS, Node 22, PostgreSQL 16, Redis).
- Hardware/Software setup checklist for Windows Server 2025 development machine.
- Production setup specifications for Linux (Ubuntu 24.04).

#### [NEW] [ci_cd_spec.md](file:///e:/projects/leitner-learning-platform/docs/architecture/ci_cd_spec.md)
Specifies policies and automation:
- Git branching policies, PR merge checks.
- Automated testing targets (80% business logic backend coverage, 70% mobile features, E2E tests).
- Automated CI pipeline workflow design.

### Deployment & Config Files

#### [NEW] [docker-compose.yml](file:///e:/projects/leitner-learning-platform/deployment/docker-compose.yml)
Initial multi-container setup orchestration template for:
- API Server (.NET 8)
- PostgreSQL 16 DB
- Redis cache/event bus
- Background Worker

#### [NEW] [Dockerfile.backend](file:///e:/projects/leitner-learning-platform/deployment/Dockerfile.backend)
Dockerfile for building the ASP.NET Core API server container.

#### [NEW] [Dockerfile.admin](file:///e:/projects/leitner-learning-platform/deployment/Dockerfile.admin)
Dockerfile for building the pluggable React admin panel container.

#### [NEW] [build-pipeline.yml](file:///e:/projects/leitner-learning-platform/deployment/github-actions-build.yml)
GitHub Actions workflow template automating compilation, testing, and Docker builds on Pull Requests.

#### [NEW] [V1__Initial_Schema.sql](file:///e:/projects/leitner-learning-platform/deployment/db/migrations/V1__Initial_Schema.sql)
Server-side SQL migration script for initial database setup (Users, Purchases, Progress, Reports, Banners, Announcements).

#### [NEW] [V1__Client_Initial_Schema.sql](file:///e:/projects/leitner-learning-platform/deployment/db/client_migrations/V1__Client_Initial_Schema.sql)
Client-side local SQLite database schema definition file.

### Plan Update

#### [MODIFY] [plan.md](file:///e:/projects/leitner-learning-platform/plan.md)
Update the Project Progress Dashboard:
- Mark **Phase 1** as Completed.
- Change progress completion to **10%** (2 / 20 Phases Completed).

## Verification Plan

### Manual Verification
- Verify that all newly created documents (`docs/architecture/*`) and deployment files exist and are fully populated with consistent designs matching `plan.md` constraints.
- Run `git status` to ensure all deliverables are properly structured and ready for committing.
- Confirm all Mermaid diagrams render correctly.
- Review technology specifications, path handling rules, and Docker files to ensure zero Windows-only dependencies.
