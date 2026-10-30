# Scrollable Mini-Game Platform — Feature Specification

## 1. Goal

Build a mobile app similar to TikTok, except each feed item is a playable 3D mini-game.

The app must keep one Godot engine running. Scrolling changes the active mini-game without restarting the app. The backend provides feed metadata and downloadable game packages.

This repository is a **monorepo**. Build a small working MVP first. Do not add features that are not listed here.

## 2. Required technology

- **Mobile client:** Godot 4.x, GDScript, native Android export.
- **Backend API:** TypeScript, Fastify, Node.js.
- **Database:** PostgreSQL.
- **Package storage:** Cloudflare R2 through an S3-compatible API.
- **Shared contracts:** TypeScript package containing API request/response schemas.
- **Package delivery:** API returns signed or public CDN URLs; large files must not pass through the API server.
- **Monorepo:** npm workspaces.
- **MVP platform:** Android first. Keep the design portable to iOS, but do not claim iOS support until tested on a physical device.

Use stable, mutually compatible dependency versions. Record the exact Godot version in the README. Do not invent Godot APIs; verify methods against the project's actual Godot version.

## 3. Monorepo structure

Create this structure:

```text
mini-game-feed/
├── apps/
│   ├── api/                  # Fastify backend
│   └── mobile/               # Godot project
├── packages/
│   └── contracts/            # Shared TypeScript schemas/types
├── tools/
│   └── game-packager/        # Validate and package game content
├── games/
│   └── demo-cube/            # Source for the first sample mini-game
├── infra/
│   └── docker-compose.yml    # Local PostgreSQL
├── .env.example
├── package.json
├── package-lock.json
└── README.md
```

If a tool cannot practically be managed by npm workspaces (such as Godot itself), keep its source in the monorepo but document its own run/export commands. Do not force Godot into the Node.js build.

## 4. MVP acceptance criteria

The MVP is complete only when all of these work:

1. The Android app opens into a vertically scrollable, full-screen game feed.
2. At least two demo mini-games can be loaded from downloaded packages.
3. The API returns feed items with IDs, versions, package URLs, file sizes, hashes, and thumbnails.
4. The client downloads a package, verifies its SHA-256 hash, stores it in a local cache, and displays download/loading/error states.
5. The next game begins downloading before the user reaches it, when network access is available.
6. Only one mini-game is actively processing at a time.
7. Scrolling changes games without restarting the Godot application or replacing its persistent root scene.
8. Returning to a cached game does not download the package again.
9. A failed or interrupted download can be retried. A corrupt package is rejected.
10. The app remains usable if the API or network is unavailable; cached games can still open.
11. The API and database run locally using documented commands.
12. The README explains how to build, package, upload, and test a mini-game.

## 5. Mobile app requirements

### 5.1 Persistent root

Create `AppRoot.tscn` and `AppRoot.gd`.

The root must stay alive for the entire app session. It owns:

- Feed UI and vertical swipe/scroll input.
- `ScrollSceneManager`.
- `DownloadManager`.
- `PackageCache`.
- Global app state.
- Loading, offline, and error UI.

Never change the root scene to navigate between feed games. Game scenes are children managed by `ScrollSceneManager`.

### 5.2 Feed UI

- One game occupies the usable screen at a time.
- Vertical swipe advances to the next item or returns to the previous item.
- Use a simple, deterministic paging interaction for the MVP. Do not implement infinite-scroll physics or elaborate animations yet.
- Overlay the game's title and creator name, plus Like and Play/Retry controls.
- Show a loading indicator while a game is being prepared.
- Show a readable error and Retry control if a game fails.
- Prevent rapid repeated swipes from starting multiple scene transitions simultaneously.
- Support device safe areas and portrait orientation.

The feed UI must remain responsive during downloads and game loading.

### 5.3 Game scene contract

Every mini-game must have a root `Node3D` scene and a script following a documented contract.

Required lifecycle methods:

```gdscript
func game_prepare(context: Dictionary) -> void:
    pass

func game_activate() -> void:
    pass

func game_deactivate() -> void:
    pass

func game_dispose() -> void:
    pass
```

Rules:

- `game_prepare(context)` receives immutable session information such as game ID, package version, and a limited API facade. It must not assume the game is active.
- `game_activate()` enables gameplay and processing.
- `game_deactivate()` pauses gameplay, timers, input, and game-owned audio.
- `game_dispose()` releases game-owned resources and connections before removal.
- Lifecycle calls must be idempotent where practical.
- The manager must check that the expected methods exist before calling them and display an error for invalid packages.
- Game scripts must not control feed navigation, downloads, or global app state directly. They use the provided facade/signals.

Use a clear shared base script or documented interface pattern that is compatible with GDScript. Do not assume GDScript supports interfaces like TypeScript.

### 5.4 Scene manager

Create `ScrollSceneManager.gd`.

Responsibilities:

- Track current feed index and active game ID.
- Request preparation for the next item before it is needed.
- Load only a game that is part of the validated feed response.
- Ensure only one game is active.
- Call `game_deactivate()` before deactivating the current game.
- Call `game_dispose()` before freeing an old game.
- Ignore stale asynchronous completion results if the user has scrolled to a different item.
- Avoid duplicate loads for the same game/version.
- Preserve the persistent root and feed state across transitions.
- Handle missing resources, invalid scenes, and script errors gracefully.

For the first MVP, use a bounded memory policy:
- One active game.
- At most one instantiated inactive game, only if device memory permits.
- Keep other games as downloaded package files on disk, not instantiated scene trees.
- Never keep an unbounded number of scenes or textures in memory.

### 5.5 Download manager

Create `DownloadManager.gd`.

Responsibilities:

- Download package files using Godot's supported HTTP APIs.
- Run downloads without blocking the main thread.
- Support progress, cancellation, retry, timeout, and interrupted-download cleanup.
- Limit concurrent package downloads to **two** in the MVP.
- Download to a temporary filename and atomically rename only after verification.
- Never treat an incomplete temporary file as cached.
- Verify SHA-256 against the manifest before accepting a package.
- Enforce a configurable maximum package size (default 100 MB for MVP).
- Reject unexpected redirects, invalid URLs, unsupported manifest versions, and failed hash checks.
- Do not download or execute package content from arbitrary URLs supplied by game scripts.

Do not implement custom cryptography. Use standard, supported hash utilities or a small well-maintained library if Godot does not expose the required hashing behavior for files.

### 5.6 Package cache

Create `PackageCache.gd`.

- Store packages in the app's writable user-data directory.
- Cache key: game ID + package version.
- Store a metadata record containing hash, size, and last-access timestamp.
- Check available disk space before downloading where supported.
- Keep a configurable cache size limit (default 500 MB).
- Evict least-recently-used inactive package files when over the limit.
- Never evict the package currently being loaded or used.
- Never evict the only offline fallback game bundled with the app.
- Remove partial downloads at startup.
- A version change must create a separate cache entry; never overwrite a package currently in use.

### 5.7 Loading remote Godot packages

This is a **high-risk technical requirement** and must be tested before building the whole app.

Use Godot's supported runtime PCK/resource-loading mechanisms for the exact pinned engine version. Do not assume a PCK loaded at runtime will behave identically across desktop, Android, and iOS.

Implementation requirements:

1. Build a tiny proof of concept that loads a remotely downloaded PCK containing one scene, one GDScript, one material, and one mesh.
2. Verify the correct API and resource paths using the pinned Godot documentation and a real Android build.
3. Verify whether the PCK can be loaded from a writable filesystem path on Android.
4. Verify resource dependencies and import requirements. Package assets in a form usable at runtime; do not assume editor import steps run on the phone.
5. Verify whether loading and unloading multiple PCKs with overlapping resource paths is safe. Avoid path collisions by assigning each package a unique namespace or resource path.
6. Test unloading and reloading the same package and two different package versions.
7. Test the process after app restart with cached packages.
8. Document limitations and results in `apps/mobile/README.md`.

**Stop and report a blocker** if the chosen Godot version/platform cannot safely support the intended runtime PCK flow. Do not silently substitute a fake loader or pretend downloaded files are executable.

Keep a fallback design available: the app ships a fixed runtime and games are data-driven packages that use prebuilt gameplay systems. Implement this fallback only if the PCK proof of concept fails or is not viable on the target platform.

## 6. Game package format

Create a manifest for every game package. Example:

```json
{
  "manifest_version": 1,
  "game_id": "demo-cube",
  "version": 1,
  "engine_version": "PINNED_GODOT_VERSION",
  "entry_scene": "res://games/demo-cube/Main.tscn",
  "package_file": "demo-cube.pck",
  "package_size_bytes": 123456,
  "sha256": "HEX_SHA256",
  "minimum_app_version": "0.1.0",
  "capabilities": ["3d", "input"]
}
```

The packager must:

- Validate required fields and types.
- Ensure game ID and version are valid.
- Verify the entry scene exists in the package source.
- Reject absolute filesystem paths and path traversal.
- Check the package's engine version compatibility.
- Produce a package file and manifest.
- Calculate file size and SHA-256 automatically.
- Fail with actionable errors if validation fails.

The client must validate the manifest before downloading. The server must validate it before publishing.

A hash verifies integrity, not publisher identity. For production, sign manifests or package metadata and verify the signature with a public key embedded in the app.

## 7. Backend API

Implement a versioned REST API under `/api/v1`.

### `GET /api/v1/feed`

Query parameters:
- `cursor` optional opaque pagination cursor.
- `limit` optional integer, default 10, maximum 20.

Response:

```json
{
  "items": [
    {
      "game_id": "demo-cube",
      "version": 1,
      "title": "Demo Cube",
      "creator_name": "Example Creator",
      "thumbnail_url": "https://cdn.example.com/demo-cube.webp",
      "manifest_url": "https://cdn.example.com/demo-cube/manifest.json",
      "package_url": "https://cdn.example.com/demo-cube/demo-cube.pck",
      "package_size_bytes": 123456,
      "sha256": "HEX_SHA256"
    }
  ],
  "next_cursor": null
}
```

- Validate query parameters.
- Return stable pagination results.
- Never return filesystem paths or storage credentials.
- Do not proxy package bytes through Fastify.
- Use cache headers where appropriate.
- Provide a deterministic seeded feed for local development.

### `GET /api/v1/games/:gameId`

Return the published metadata and current version for a game. Return 404 for unknown or unpublished games.

### `POST /api/v1/events`

Accept a small, validated set of events:
- `game_started`
- `game_completed`
- `game_failed`
- `game_liked`

Payload includes event ID, game ID, package version, event type, and timestamp. Treat events as untrusted input. Add rate limiting and basic validation. Do not collect unnecessary personal data.

### Health

`GET /health` returns a simple service status. Do not expose secrets or internal stack traces.

## 8. Database

Use PostgreSQL migrations. At minimum create:

### `games`
- `id` (text or UUID primary key)
- `slug` (unique)
- `title`
- `creator_name`
- `description`
- `thumbnail_key`
- `status` (`draft`, `published`, `disabled`)
- `created_at`
- `updated_at`

### `game_versions`
- `id`
- `game_id` foreign key
- `version`
- `manifest_key`
- `package_key`
- `package_size_bytes`
- `sha256`
- `engine_version`
- `created_at`
- unique constraint on (`game_id`, `version`)

### `game_events`
- `id` (client event ID, unique)
- `game_id`
- `version`
- `event_type`
- `occurred_at`
- `received_at`

Add indexes for feed queries and event lookups. Do not store raw package files in PostgreSQL.

## 9. Game publishing tool

Create `tools/game-packager`.

Required commands:
- `validate <game-directory>`
- `build <game-directory>`
- `manifest <package-file>`
- `publish <game-directory>`

For the MVP, `publish` may upload to R2 and call a protected backend publishing endpoint. Keep credentials in environment variables; never commit them.

The tool must:
- Check required files and manifest fields.
- Build the package using documented Godot export/packaging steps.
- Calculate SHA-256 and size.
- Upload the package and thumbnail.
- Publish metadata only after all uploads succeed.
- Avoid leaving a partially published game if an upload or database operation fails.
- Print the resulting game ID, version, manifest URL, and package URL.

Document all required Godot export templates and command-line commands. Do not guess command-line flags.

## 10. Demo mini-games

Implement two very small games to prove switching works:

### Game A: Collect the cubes
- Simple 3D environment.
- Player can rotate or move using touch controls.
- Collect 5 cubes.
- Show completion UI.
- Report a `game_completed` event through the app-provided facade.

### Game B: Tap the targets
- Simple 3D scene with floating targets.
- Tap 10 targets to finish.
- Show score and completion UI.
- Report completion through the facade.

Both games must:
- Implement the lifecycle contract.
- Avoid modifying the persistent root.
- Avoid creating their own global singletons.
- Clean up signals, timers, audio, and resources when deactivated/disposed.
- Be separately packaged and downloadable.

## 11. Reliability and security

- Use environment variables for all secrets.
- Commit `.env.example` with placeholders only.
- Validate all API input and all remote manifests.
- Use HTTPS outside local development.
- Enforce package size limits.
- Verify SHA-256 and, for production, signed metadata.
- Rate-limit event and publishing endpoints.
- Protect publishing endpoints with authentication.
- Do not expose R2 keys to the mobile client.
- Do not accept package URLs from arbitrary game scripts.
- Treat mini-games as untrusted content even if published by the platform.
- Do not claim arbitrary third-party games are sandboxed. Godot scripts loaded into the same process may have broad engine access.
- Do not implement login, payments, ads, comments, creator uploads, recommendation ML, or social features in this MVP.

## 12. Local development

Provide:
- Root npm scripts for installing dependencies, running API dev mode, linting, type checking, and tests.
- Docker Compose for PostgreSQL only.
- SQL migrations and deterministic seed data.
- A local storage adapter or mock mode so the API can run without R2 credentials.
- `.env.example`.
- Clear instructions for running the Godot client against a local API.
- A configurable API base URL. Do not hardcode localhost for a physical phone; document using the computer's LAN IP for device testing.
- Unit tests for schemas, manifest validation, cache policy, feed pagination, and event validation.
- A device test checklist for downloads, interrupted network, hash mismatch, fast scrolling, cached revisits, and low-memory behavior.

## 13. Implementation order

Work in this exact order. Keep each phase buildable and tested.

### Phase 1 — Repository foundation
1. Create monorepo folders and npm workspaces.
2. Add TypeScript strict configuration, linting, formatting, and test runner.
3. Add PostgreSQL Docker Compose and migrations.
4. Add `.env.example` and root README.

### Phase 2 — Critical Godot runtime proof
1. Pin the Godot version.
2. Create a persistent root and a minimal local scene switcher.
3. Build a PCK containing a test scene, script, material, and mesh.
4. Load that PCK at runtime on an actual Android device.
5. Verify resource paths, activation/deactivation, unloading, and reloading.
6. Write down the test results and any platform limitations.

Do not proceed to remote streaming until this phase passes or a documented fallback is selected.

### Phase 3 — API and contracts
1. Implement shared schemas.
2. Implement health and feed endpoints.
3. Add database seed data for two demo games.
4. Add API tests.

### Phase 4 — Package pipeline
1. Implement manifest validation and packager commands.
2. Implement local/mock storage.
3. Implement R2 adapter.
4. Implement protected publishing endpoint.
5. Test a complete publish-to-feed flow.

### Phase 5 — Mobile streaming
1. Implement feed UI and paging.
2. Implement download manager and SHA-256 validation.
3. Implement package cache and eviction.
4. Implement asynchronous preloading.
5. Implement active scene transitions and lifecycle contract.
6. Implement loading, retry, offline, and error states.

### Phase 6 — Demo games and QA
1. Implement both demo games.
2. Publish both through the packager.
3. Verify they appear in the feed and download on Android.
4. Test rapid scrolling, repeated visits, app restarts, failed downloads, and memory limits.
5. Document known limitations.

## 14. Definition of done

Do not mark the project complete until:
- The API returns the two published demo games.
- A physical Android device downloads and verifies both packages.
- The app switches between both games without restarting the engine.
- The next game preloads while the current game remains responsive.
- A cached game opens without a network request for its package.
- Interrupted and corrupted downloads are handled correctly.
- Old scenes are deactivated and freed without unbounded memory growth.
- The backend tests and manifest/packager tests pass.
- The README contains exact commands and actual test results.

## 15. Agent rules

- Work one phase at a time; do not skip the runtime proof of concept.
- Before using any Godot API, verify it exists in the pinned version.
- Never fake a completed integration with placeholder code that always reports success.
- Do not silently replace runtime PCK loading with a different architecture.
- If a platform restriction blocks the design, stop, explain the exact blocker, and propose the smallest viable fallback.
- Keep functions small and names explicit.
- Avoid unnecessary abstractions and dependencies.
- Do not implement features outside this specification.
- At the end of each phase, run relevant tests and report: files changed, commands run, results, and remaining blockers.
