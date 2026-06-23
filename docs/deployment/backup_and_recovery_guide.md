# Backup & Recovery Guide

This guide details the procedures for immediate database backup replication, S3-compatible domestic cloud storage synchronizations, and system recovery instructions for the Leitner Learning Platform.

---

## 1. Automated Backups & Off-Server Replication

To protect user accounts, study profiles, and transaction records from server hardware failure, the system performs **immediate, automatic replication** to secure external domestic Object Storage (e.g. ArvanCloud/ParsPack or custom S3/FTP endpoints) upon critical events.

### A. Architectural Workflow
1. **Trigger Event**: A user completes a registration, updates profile details, or makes a course purchase.
2. **Event bus emission**: An event `PurchaseCompleted` or `UserProfileUpdated` is emitted.
3. **Queue job**: The event handler schedules a background task in Hangfire.
4. **Replication**: The background job exports a snapshot of the transaction log and streams it encrypted using AES-GCM to the configured domestic S3 bucket.

### B. Daily Database Backups
A scheduled Hangfire task runs daily at 02:00 AM server time to dump the entire PostgreSQL database, compressing it and pushing it to the S3 bucket.

---

## 2. Manual Backup Procedures (PostgreSQL & Redis)

If you need to trigger a manual backup outside the automated pipelines:

### A. Backing Up PostgreSQL Database
If running inside Docker Compose (container named `leitner-db`):
```bash
docker compose exec db pg_dump -U postgres leitner_db | gzip > backup_$(date +%F_%T).sql.gz
```
If running on a standalone Windows Server:
```powershell
pg_dump -U postgres -d leitner_db | gzip > backup_$(Get-Date -Format "yyyyMMdd_HHmmss").sql.gz
```

### B. Backing Up Redis State
Redis persistence is configured via RDB snapshots. To force a point-in-time snapshot:
```bash
docker compose exec redis redis-cli -a your_redis_secure_password save
docker cp leitner-redis:/data/dump.rdb ./redis_dump.rdb
```

---

## 3. Disaster Recovery & Restoration Instructions

In the event of database corruption or hardware migration:

### A. Restore PostgreSQL Database
1. **Stop active API and worker services** to prevent active writes:
   ```bash
   docker compose stop backend worker
   ```
2. **Extract the backup file**:
   ```bash
   gunzip backup_file.sql.gz
   ```
3. **Drop and recreate the database schema**:
   ```bash
   docker compose exec db psql -U postgres -c "DROP DATABASE leitner_db;"
   docker compose exec db psql -U postgres -c "CREATE DATABASE leitner_db;"
   ```
4. **Import the SQL backup stream**:
   ```bash
   cat backup_file.sql | docker compose exec -T db psql -U postgres -d leitner_db
   ```
5. **Restart Backend and Worker services**:
   ```bash
   docker compose start backend worker
   ```

### B. Restore Redis State
1. **Stop Redis container**:
   ```bash
   docker compose stop redis
   ```
2. **Copy the backup RDB file** to the container volume mount:
   ```bash
   cp redis_dump.rdb ./deployment/db/redis_data/dump.rdb
   ```
3. **Restart the container**:
   ```bash
   docker compose start redis
   ```
