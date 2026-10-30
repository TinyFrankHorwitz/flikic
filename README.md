# Mini Game Feed

Scrollable Android-first feed of downloadable Godot mini-games. The repository follows [`features.md`](features.md); implementation is staged so Android runtime PCK feasibility is established before remote streaming.

## Current scaffold

- npm workspaces for the Fastify API, shared Zod contracts, and packager tooling.
- PostgreSQL 17 local service and initial schema migration.
- Godot 4.5.2-stable persistent-root project and a small runtime PCK proof of concept.

## Requirements

- Node.js 22 LTS and npm 10 or newer.
- Docker Compose.
- Godot 4.5.2-stable standard build; Android export templates for that same version for device work.

## Local setup

```sh
cp .env.example .env
 npm install
 docker compose -f infra/docker-compose.yml up -d postgres
 npm run dev:api
```

The health route is `http://localhost:3000/health`. API/database integration and migrations are not wired yet; apply `apps/api/migrations/001_initial.sql` and `002_seed.sql` to a local database before backend work. The Compose database defaults are for local development only.

For physical Android API access, set the mobile client's API base URL to the development computer's LAN IP, not `localhost`.

## Godot proof gate

See [`apps/mobile/README.md`](apps/mobile/README.md). The Android PCK feasibility proof is not yet run. Do not begin remote package streaming until it succeeds or the smallest viable fallback is documented.

## Workspace commands

```sh
npm run dev:api
npm run lint
npm run format:check
npm run typecheck
npm test
```

See [`mini-game-feed-scaffold.md`](mini-game-feed-scaffold.md) for the current implementation plan.
