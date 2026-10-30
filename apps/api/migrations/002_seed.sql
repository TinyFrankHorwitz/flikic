-- Deterministic local catalog fixtures. Draft games are intentionally excluded from the public feed.
INSERT INTO games (id, slug, title, creator_name, description, thumbnail_key, status)
VALUES
  ('demo-cube', 'demo-cube', 'Collect the Cubes', 'Example Creator', 'Runtime package proof game.', 'demo-cube/thumbnail.webp', 'draft'),
  ('demo-targets', 'demo-targets', 'Tap the Targets', 'Example Creator', 'Second feed fixture for the MVP.', 'demo-targets/thumbnail.webp', 'draft')
ON CONFLICT (id) DO NOTHING;
