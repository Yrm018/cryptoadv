-- CryptoAdv — Schéma PostgreSQL
-- Exécuter : psql -U postgres -d cryptoadv -f setup.sql

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Utilisateurs ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         VARCHAR(255) UNIQUE NOT NULL,
  username      VARCHAR(100) UNIQUE NOT NULL,
  first_name    VARCHAR(100) NOT NULL,
  last_name     VARCHAR(100) NOT NULL,
  password_hash TEXT NOT NULL,
  photo_base64  TEXT,
  public_key    TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── Conversations ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS conversations (
  id         VARCHAR(255) PRIMARY KEY,  -- "{uid1}_{uid2}" trié
  user1_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user2_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Messages ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS messages (
  id                VARCHAR(255) PRIMARY KEY,
  conversation_id   VARCHAR(255) NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  cipher_text       TEXT NOT NULL,
  mode              VARCHAR(20)  NOT NULL DEFAULT 'sym',   -- 'sym' | 'asym'
  algorithm         VARCHAR(50)  NOT NULL DEFAULT 'AES',
  type              VARCHAR(20)  NOT NULL DEFAULT 'text',  -- 'text'|'image'|'audio'|'video'|'file'
  file_name         VARCHAR(255),
  file_size         BIGINT,
  encrypted_aes_key TEXT,   -- pour mode asym ET sym (clé AES chiffrée avec RSA du destinataire)
  iv                TEXT,
  mac               TEXT,   -- tag d'authentification AES-GCM
  signature         TEXT,
  read_at           TIMESTAMPTZ,  -- date de lecture par le destinataire
  timestamp         TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(conversation_id, timestamp);

-- ── Appels (signaling WebRTC) ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS calls (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  caller_id    UUID NOT NULL REFERENCES users(id),
  callee_id    UUID NOT NULL REFERENCES users(id),
  type         VARCHAR(10) NOT NULL DEFAULT 'audio',  -- 'audio' | 'video'
  status       VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending'|'active'|'ended'|'missed'
  started_at   TIMESTAMPTZ DEFAULT NOW(),
  ended_at     TIMESTAMPTZ
);
