-- Add is_bundle_only column to courses table
-- Bundle-only courses are hidden from the individual catalog across all versions,
-- but remain active and delivered to users who purchase or own the parent course package.
ALTER TABLE courses ADD COLUMN IF NOT EXISTS is_bundle_only BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_courses_is_bundle_only ON courses(is_bundle_only);
