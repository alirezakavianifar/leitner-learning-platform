-- Course Package SQLite Database Schema
-- File: course_schema.sql
-- Conforms to Phase 3 Specifications for Leitner Learning Platform course database.

PRAGMA foreign_keys = ON;

-- 1. Course Table
-- Stores the primary details of the specific course.
CREATE TABLE IF NOT EXISTS course (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT,
    difficulty TEXT,
    price REAL NOT NULL DEFAULT 0.0,
    version INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL
);

-- 2. Cards Table
-- Stores all flashcard items. Cards are read-only.
-- The card_number is sequential (1-based index) and unique within the course.
CREATE TABLE IF NOT EXISTS cards (
    id TEXT PRIMARY KEY,
    course_id TEXT NOT NULL,
    card_number INTEGER NOT NULL,
    question_text TEXT NOT NULL,
    answer_text TEXT NOT NULL,
    image_name TEXT,
    audio_name TEXT,
    FOREIGN KEY (course_id) REFERENCES course(id) ON DELETE CASCADE
);

-- Unique index to guarantee that each card_number is unique within a course
CREATE UNIQUE INDEX IF NOT EXISTS idx_cards_course_number ON cards (course_id, card_number);

-- 3. Metadata Table
-- Key-value table for general properties (e.g. build tool version, checksums, package date)
CREATE TABLE IF NOT EXISTS metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
