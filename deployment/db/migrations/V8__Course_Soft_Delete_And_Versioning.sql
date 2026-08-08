-- V8__Course_Soft_Delete_And_Versioning.sql
-- Adds soft-delete (archive) support and update-tracking fields to courses.
-- Archiving a course hides it from the catalog/admin active list without
-- deleting its row, cards, or purchases, so existing buyers keep access.

ALTER TABLE courses ADD COLUMN updated_at TIMESTAMP;
ALTER TABLE courses ADD COLUMN is_archived BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE courses ADD COLUMN archived_at TIMESTAMP;
ALTER TABLE courses ADD COLUMN is_critical_update BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE courses SET updated_at = created_at WHERE updated_at IS NULL;
