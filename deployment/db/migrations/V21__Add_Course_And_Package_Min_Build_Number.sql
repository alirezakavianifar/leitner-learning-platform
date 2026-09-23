-- V21: Add min_build_number column to courses and course_packages tables
-- Default: 0 (accessible to all client versions)

ALTER TABLE courses 
ADD COLUMN IF NOT EXISTS min_build_number INT DEFAULT 0;

ALTER TABLE course_packages 
ADD COLUMN IF NOT EXISTS min_build_number INT DEFAULT 0;

UPDATE courses 
SET min_build_number = 0 
WHERE min_build_number IS NULL;

UPDATE course_packages 
SET min_build_number = 0 
WHERE min_build_number IS NULL;
