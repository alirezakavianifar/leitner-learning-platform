-- V15: Add ImageUrl column to courses and course_packages tables

ALTER TABLE courses ADD COLUMN IF NOT EXISTS image_url VARCHAR(512);
ALTER TABLE course_packages ADD COLUMN IF NOT EXISTS image_url VARCHAR(512);

