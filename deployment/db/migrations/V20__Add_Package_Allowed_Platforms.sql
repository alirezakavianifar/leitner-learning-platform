-- V20: Add allowed_platforms column to course_packages table
-- Supported platform keys: zarinpal, bazaar, myket, googleplay, ios
-- Default: 'zarinpal,bazaar,myket,googleplay,ios' (available across all targets)

ALTER TABLE course_packages 
ADD COLUMN IF NOT EXISTS allowed_platforms VARCHAR(255) DEFAULT 'zarinpal,bazaar,myket,googleplay,ios';

UPDATE course_packages 
SET allowed_platforms = 'zarinpal,bazaar,myket,googleplay,ios' 
WHERE allowed_platforms IS NULL;
