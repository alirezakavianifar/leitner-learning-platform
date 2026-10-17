-- Add bazaar_sku column to courses and course_packages tables
-- Optional explicit SKU used when registering in-app products in Café Bazaar Developer Console
ALTER TABLE courses ADD COLUMN IF NOT EXISTS bazaar_sku VARCHAR(255) NULL;
ALTER TABLE course_packages ADD COLUMN IF NOT EXISTS bazaar_sku VARCHAR(255) NULL;

CREATE INDEX IF NOT EXISTS idx_courses_bazaar_sku ON courses(bazaar_sku);
CREATE INDEX IF NOT EXISTS idx_course_packages_bazaar_sku ON course_packages(bazaar_sku);
