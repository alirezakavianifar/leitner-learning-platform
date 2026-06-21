-- V3__Add_Course_Fields.sql
-- Add version, checksum_sha256, download_url, and card_count columns to courses table

ALTER TABLE courses ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE courses ADD COLUMN checksum_sha256 VARCHAR(64);
ALTER TABLE courses ADD COLUMN download_url VARCHAR(512);
ALTER TABLE courses ADD COLUMN card_count INTEGER NOT NULL DEFAULT 0;
