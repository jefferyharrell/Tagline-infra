# Project Specification

## 1. Purpose

- Web app for managing photos and metadata.
- “Blob”: image file (e.g., JPEG, HEIC).
- “Metadata”: structured info about a photo.

---

## 2. Backend (MVP)

- **ORM:** SQLAlchemy 2.x is the official ORM and database toolkit for all backend data access. All models, sessions, and DB operations must use SQLAlchemy. See `app/db/` for implementation details.
- Store photo blobs (local filesystem).
- Store metadata in DB via storage abstraction.
- No in-app upload; add files to storage, then call `/rescan`.

### Authentication

- Single password (env var: `BACKEND_PASSWORD`), no username.
- Endpoints:
  - `POST /login` `{ "password": "hunter2" }` → `{ "access_token", "refresh_token", "token_type" }`
  - `POST /refresh` `{ "refresh_token" }` → `{ "access_token", ... }`
- All protected endpoints require `Authorization: Bearer <access_token>`.
- Access tokens: short-lived (15–60 min), refresh tokens: long-lived, revocable.

### Storage Abstraction

- Methods:
  - `list_photos(limit=100, offset=0) -> { photo_ids: [UUID], total: int }`
  - `get_photo(photo_id: UUID) -> Photo`
  - `set_metadata(photo_id: UUID, metadata: dict) -> Photo`
- Photo object:
  ```json
  {
    "photo_id": "<uuid>",
    "description": "<string>",
    "last_modified": "<ISO 8601 timestamp>"
  }
  ```
- On metadata update, client sends `last_modified`; backend checks for conflicts (409 if mismatch).
- **Fail-fast:** If the storage backend (e.g., filesystem, Dropbox, S3) is unavailable, the API MUST immediately return a 5xx error. No retries or queueing are required for MVP.

### Endpoints

| Method | Path                      | Purpose                        |
|--------|---------------------------|--------------------------------|
| POST   | /login                    | Authenticate, get tokens       |
| POST   | /refresh                  | Get new access token           |
| GET    | /photos                   | List photo IDs (paginated)     |
| GET    | /photos/{id}              | Get photo + metadata           |
| PATCH  | /photos/{id}/metadata     | Update metadata (description)  |
| GET    | /photos/{id}/image        | Get image file                 |
| POST   | /rescan                   | Scan storage, import new photos|

---

## 3. Frontend (MVP)

- Stack: React 19, Next.js 15.3, Tailwind CSS 4.1, shadcn/ui, TypeScript.
- Components:
  - Gallery/grid view (with pagination/infinite scroll).
  - Photo detail view.
  - Metadata editor (edit description).
- All async ops show loading/error/success states.
- Accessibility: WCAG 2.1 AA, keyboard nav, alt text, semantic HTML, ARIA, color contrast, CI a11y checks (axe-core).
- API: JSON, RESTful, error messages shown to user.

---

## 4. Infra & Integration

- Frontend gets backend API URL from env var (`NEXT_PUBLIC_API_BASE_URL`).
- Backend exposes `/api` base path.
- CORS enabled for frontend domain(s).
- All config via env vars (documented in `.env.example`).
- Docker images for frontend/backend; no secrets in images.
- CI: GitHub Actions, runs on every push/PR; required checks: formatting, linting, type checks, unit tests, E2E (Playwright), Dockerfile linting.
- Pre-commit hooks run formatter/linter/tests.

---

## 5. General

- All APIs documented and machine-readable.
- Design for extensibility (future metadata fields, storage backends).
- All error responses: `{ "detail": "..." }` (FastAPI style).

---

## 6. Out of Scope (MVP)

- User authentication/authorization (beyond single password)
- Advanced metadata (tags, author, etc.)
- Non-filesystem storage (Dropbox, S3)

---

## 7. Data Model

| Field         | Type      | Description                  |
|---------------|-----------|------------------------------|
| id            | UUID      | Unique photo ID              |
| object_key    | string    | Storage path/object key      |
| description   | string    | User-supplied description    |
| last_modified | string    | RFC3339 timestamp            |

---

## 8. Example Usage

- Get photo: `GET /photos/{id}` → `{ "id": "...", "object_key": "...", "description": "...", "last_modified": "..." }`
- Update description: `PATCH /photos/{id}/metadata` with `{ "description": "...", "last_modified": "..." }`
- Error: `{ "detail": "Photo not found" }` (404)

---

## 9. Environment Variables (MVP)

| Variable           | Purpose                | Example      |
|--------------------|------------------------|--------------|
| BACKEND_PASSWORD   | Backend login password | hunter2      |
| STORAGE_PROVIDER   | Storage backend        | filesystem   |
| JWT_SECRET_KEY     | JWT signing key        | (random str) |

---

## 10. Dev Practices

- TDD for all features.
- 90%+ test coverage.
- Type/lint checks required.
- No secrets hardcoded.
- Code: concise, maintainable, PEP 8/257.

---
