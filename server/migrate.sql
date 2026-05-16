-- Migration — colonnes manquantes dans messages
-- Exécuter sur EC2 : psql -U cryptoadv_user -d cryptoadv -f migrate.sql

ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS mac     TEXT,
  ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;