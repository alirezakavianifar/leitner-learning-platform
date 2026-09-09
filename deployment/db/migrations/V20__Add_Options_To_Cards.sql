-- Migration V20: Add options column to cards table for multiple-choice questions
ALTER TABLE cards ADD COLUMN IF NOT EXISTS options TEXT;
