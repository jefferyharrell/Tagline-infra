# Product Requirements Document (PRD)

## 1. Overview

Tagline is a web application for annotating photos with metadata. The MVP enables users to browse, view, and edit photo descriptions, with robust backend storage and a modern, accessible frontend.

## 2. Goals
- Provide a simple, secure platform to organize and describe photos.
- Ensure metadata is always consistent and up-to-date.
- Prioritize accessibility and usability for all users.
- Make the system extensible for future storage and metadata enhancements.

## 3. Non-goals
- No support for advanced metadata (tags, author, location) in MVP.
- No multi-user or OAuth authentication in MVP.
- No in-app photo upload for MVP; photos are manually added to storage.
- No Dropbox/S3 support in MVP (filesystem only).

## 4. Personas & User Stories

**Persona: Individual photo archivist**
- "I want to browse my photo collection and add descriptions, so I can remember what each photo is about."
- "I want to quickly find and view any photo in my collection."
- "I want to edit a photo’s description if I make a mistake."

**Persona: Developer/Power User**
- "I want to automate adding photos to the system and trigger imports via an API."
- "I want to integrate this with other tools using a documented API."

## 5. Product Requirements (MVP)

### Backend
- Store image files (blobs) in the local filesystem.
- Store metadata (description, last_modified) in the database via a storage abstraction.
- Expose RESTful API endpoints for authentication, photo listing, retrieval, metadata update, and rescanning storage.
- Authentication via single password (env var, no username). JWT access/refresh tokens.
- Fail-fast: If storage backend is unavailable, API returns 5xx error immediately (no retries/queueing).

### Frontend
- Built with React 19, Next.js 15.3, Tailwind CSS 4.1, shadcn/ui, TypeScript.
- Gallery/grid view for browsing photos (with pagination/infinite scroll).
- Photo detail view with editable description field.
- All async operations show loading, error, and success states.
- Fully accessible (WCAG 2.1 AA, keyboard navigation, alt text, semantic HTML, ARIA, color contrast, CI a11y checks).

### Infra & Integration
- All configuration via environment variables (documented in `.env.example`).
- Frontend obtains backend API URL from env var (`NEXT_PUBLIC_API_BASE_URL`).
- Backend exposes `/api` base path. CORS enabled for frontend domain(s).
- Docker images for frontend and backend (no secrets in images).
- CI/CD via GitHub Actions: formatting, linting, type checks, unit/E2E tests, Dockerfile linting. Pre-commit hooks required.

### API Endpoints
- `POST /login` — Authenticate, get tokens
- `POST /refresh` — Get new access token
- `GET /photos` — List photo IDs (paginated)
- `GET /photos/{id}` — Get photo and metadata
- `PATCH /photos/{id}/metadata` — Update description
- `GET /photos/{id}/image` — Get image file
- `POST /rescan` — Import new photos from storage

### Data Model (MVP)
- Photo object:
  - `id` (UUID)
  - `object_key` (string)
  - `description` (string)
  - `last_modified` (RFC3339 timestamp)

### Error Handling
- All error responses are JSON with a `detail` field (e.g., `{ "detail": "Photo not found" }`).
- 409 for metadata conflicts, 5xx for storage backend failure, 401 for authentication failure.

## 6. Out of Scope (MVP)
- Advanced metadata (tags, author, etc.)
- Multi-user/OAuth authentication
- Dropbox/S3 or other non-filesystem storage
- In-app photo upload

## 7. Success Criteria
- Users can view, browse, and edit photo descriptions via the web UI.
- All endpoints and UI flows are covered by automated tests (90%+ coverage).
- System is accessible and passes automated a11y checks (axe-core, WCAG 2.1 AA).
- All CI/CD checks pass on every commit.
- System can be deployed with Docker using documented env vars.

## 8. Open Questions/Assumptions
- Will future versions require multi-user support or advanced metadata?
- Is there a need for search/filtering in the MVP?
- Are there minimum performance targets (e.g., max response time) for API endpoints?

---

*This PRD is based on the implementation-focused specification in SPEC_LLM.md. For detailed technical requirements, see that file.*
