-- Migration: Add drive_folder_id column to categorie table
-- Run this SQL on the database to add the new column

ALTER TABLE categorie ADD COLUMN IF NOT EXISTS drive_folder_id VARCHAR(100);
