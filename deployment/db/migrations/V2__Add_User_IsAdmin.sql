-- V2__Add_User_IsAdmin.sql
-- Add is_admin column to users table and seed default admin user

ALTER TABLE users ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT false;

-- Seed default admin user (OTP bypass code 12345 can be used)
INSERT INTO users (id, username, mobile_number, is_admin)
VALUES ('00000000-0000-0000-0000-000000000000', 'admin', '+989120000000', true)
ON CONFLICT (mobile_number) DO UPDATE SET is_admin = true;
