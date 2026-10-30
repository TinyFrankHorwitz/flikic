CREATE TYPE game_status AS ENUM ('draft', 'published', 'disabled');
CREATE TYPE game_event_type AS ENUM ('game_started', 'game_completed', 'game_failed', 'game_liked');

CREATE TABLE games (
  id text PRIMARY KEY,
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  creator_name text NOT NULL,
  description text NOT NULL DEFAULT '',
  thumbnail_key text NOT NULL,
  status game_status NOT NULL DEFAULT 'draft',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE game_versions (
  id bigserial PRIMARY KEY,
  game_id text NOT NULL REFERENCES games(id),
  version integer NOT NULL CHECK (version > 0),
  manifest_key text NOT NULL,
  package_key text NOT NULL,
  package_size_bytes bigint NOT NULL CHECK (package_size_bytes > 0),
  sha256 char(64) NOT NULL,
  engine_version text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (game_id, version)
);

CREATE TABLE game_events (
  id uuid PRIMARY KEY,
  game_id text NOT NULL REFERENCES games(id),
  version integer NOT NULL,
  event_type game_event_type NOT NULL,
  occurred_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX games_feed_idx ON games (status, created_at DESC, id);
CREATE INDEX game_events_game_received_idx ON game_events (game_id, received_at DESC);
