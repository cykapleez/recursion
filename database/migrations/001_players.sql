-- 001_players.sql
-- Base player table. Keyed on Discord user ID.
-- Rollback: DROP TABLE players;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE players (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  discord_id   TEXT        NOT NULL UNIQUE,
  username     TEXT        NOT NULL,
  class_id     VARCHAR(64) NOT NULL DEFAULT 'class-warrior',
  level        INTEGER     NOT NULL DEFAULT 1 CHECK (level >= 1),
  xp           INTEGER     NOT NULL DEFAULT 0 CHECK (xp >= 0),
  strength     INTEGER     NOT NULL DEFAULT 10 CHECK (strength >= 1),
  dexterity    INTEGER     NOT NULL DEFAULT 10 CHECK (dexterity >= 1),
  intelligence INTEGER     NOT NULL DEFAULT 10 CHECK (intelligence >= 1),
  vitality     INTEGER     NOT NULL DEFAULT 10 CHECK (vitality >= 1),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_players_discord_id ON players(discord_id);
