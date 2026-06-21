-- V1__Client_Initial_Schema.sql
-- Client SQLite database initialization schema definitions for local app storage (app_local.db)

-- 1. Client Leitner Progress Table
-- Tracks study progress per card. References cards in read-only course packages using composite keys.
CREATE TABLE IF NOT EXISTS client_progress (
    id TEXT PRIMARY KEY, -- Formatted as "{course_id}_{card_number}"
    course_id TEXT NOT NULL,
    card_number INTEGER NOT NULL,
    current_box INTEGER NOT NULL DEFAULT 1, -- Boxes 1 to 5, and 6 (Finished)
    last_reviewed_at TEXT, -- ISO8601 string
    next_review_due TEXT -- ISO8601 string
);

-- Index review scheduling to find due cards efficiently
CREATE INDEX IF NOT EXISTS idx_progress_next_due ON client_progress (course_id, next_review_due);

-- 2. User Created Cards Table
-- Stores custom, device-only cards. Does not sync to server.
CREATE TABLE IF NOT EXISTS user_created_cards (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    course_title TEXT NOT NULL DEFAULT 'My Custom Cards',
    question_text TEXT NOT NULL,
    answer_text TEXT NOT NULL,
    image_path TEXT,
    audio_path TEXT,
    created_at TEXT NOT NULL
);

-- 3. Bookmark Favorites Table
-- Stores bookmarked cards referencing course and card number.
CREATE TABLE IF NOT EXISTS favorites (
    course_id TEXT NOT NULL,
    card_number INTEGER NOT NULL,
    added_at TEXT NOT NULL,
    PRIMARY KEY (course_id, card_number)
);

-- 4. User Settings Table
-- Persists local user application settings (font sizes, local theme).
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Seed basic default settings on initialization
INSERT OR IGNORE INTO settings (key, value) VALUES ('font_size', '16');
INSERT OR IGNORE INTO settings (key, value) VALUES ('theme', 'light');
