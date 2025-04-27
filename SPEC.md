# Project Specification

**Version:** 1.0.1  
**Last Updated:** 2025-04-25

> **Note:**
> This document is a living specification. It will be revised and extended as the project evolves. All agents and contributors MUST refer to the latest version before implementing or reviewing any requirements.

**Audience:**  
- AI code assistants  
- Human developers  
- Automated reasoning tools

## RFC 2119 Compliance

This spec uses **MUST**, **SHOULD**, and **MAY** as defined by [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt).

---

## 1. Purpose

Tagline is a web application for managing photos and their metadata.

> **Note for AI Code Assistants:**
> All requirements in this document are intended to be unambiguous and machine-readable. Where possible, definitions and requirements are stated explicitly and consistently.

The name "Tagline" is provisional and subject to change. Try to avoid using it in code as much as possible.

### Key Terms

- **Blob**: A binary large object. In this context, a "blob" specifically refers to an image file (e.g., JPEG, HEIC) uploaded by a user.
- **Metadata**: Structured information describing a photo.

- Users can view photos (**blobs**) and edit associated metadata (see above for examples).
- The backend is responsible for storing both the image data (**blobs**) and its metadata.
- There is a single canonical Photo object, used for both single-photo and list responses, with the following fields:
  - `id` (UUID): Unique photo ID
  - `object_key` (string): Storage path/object key
  - `metadata` (object): Dictionary of metadata fields (at minimum: description)
  - `last_modified` (string): RFC3339/ISO8601 timestamp

---

## 2. Backend Specification

### 2.1 MVP Scope

---

#### Photo Endpoints

- `GET /photos` returns `{ total, limit, offset, items: [Photo, ...] }` where each Photo is a fully described photo object (see above).
- `GET /photos/{id}` returns a single Photo object.
- All metadata fields (including description) are inside the `metadata` dictionary, not as top-level fields.
- Example:
  ```json
  {
    "id": "<uuid>",
    "object_key": "<string>",
    "metadata": {
      "description": "A dog"
    },
    "last_modified": "<RFC3339 timestamp>"
  }
  ```

---

#### Authentication

The app uses access tokens and refresh tokens for authentication between frontend and backend.

##### Login Flow
- The frontend MUST POST user credentials to the `/login` endpoint (e.g., `{ "password": "hunter2" }`).
- On success, the backend returns `{ "detail": "Login successful" }` and sets an HTTP-only cookie containing the access token.
- Clients MUST use the cookie for all subsequent authenticated requests; the access token is not returned in the response body.
- The backend MUST verify credentials and, if valid, return:
  - `{ "detail": "Login successful" }` and set an HTTP-only cookie with the access token.
  - The access token is NOT included in the response body.
  - Clients MUST use the cookie for authentication in subsequent requests.
- If credentials are invalid, the backend MUST return HTTP 401 with an error response:
    ```json
    {
      "detail": "Invalid credentials"
    }
    ```
- The frontend MUST store the refresh token securely (preferably in an HTTP-only cookie; never in localStorage).

##### Using the Access Token
- All requests to protected endpoints MUST include:
  ```
  Authorization: Bearer <access_token>
  ```
- The backend MUST validate the access token on every request and reject expired or invalid tokens with a 401 error.

##### Refreshing the Access Token
- When the access token expires, the frontend MUST POST the refresh token to the `/refresh` endpoint to obtain a new access token (and optionally a new refresh token).
- The backend MUST validate the refresh token and, if valid, return a new access token (and optionally a new refresh token).
- If the refresh token is expired or invalid, the backend MUST return HTTP 401 with an error response:
    ```json
    {
      "detail": "Invalid or expired refresh token"
    }
    ```
- The frontend MUST prompt the user to log in again if a 401 is received.
- The backend MUST support refresh token revocation (e.g., on logout or suspicious activity).

##### Token Storage Architecture (ADR 0004)
- All authentication tokens (refresh tokens, revoked tokens, etc.) MUST be stored in Redis, not in the primary RDBMS.
- In development, Redis MUST run as an in-memory service (via Docker Compose) with no persistence.
- In production, Redis MUST be a persistent or hosted service (e.g., AWS ElastiCache, Upstash, etc.) with appropriate backup and security.
- The backend MUST connect to Redis using a configurable `REDIS_URL` environment variable.
- The RDBMS remains the canonical store for all application metadata (photo descriptions, etc.).
- This approach is documented in ADR 0004 and is intended to ensure separation of concerns, performance, and operational safety.

##### Security Notes
- In production, all authentication and token exchange MUST occur over HTTPS. (HTTP is fine for development. )
- Refresh tokens MUST be stored securely and never exposed to JavaScript (use HTTP-only cookies where possible).
- Access tokens MUST be short-lived; refresh tokens MAY be long-lived but MUST be revocable.
- For MVP, a single password is sufficient. This password MUST be provided via an environment variable (e.g., `BACKEND_PASSWORD`) and MUST NOT be hardcoded.
- There is no username; authentication is password-only for MVP.
- **WARNING:** Do not use real credentials or sensitive data in development environments running over HTTP.
- **Future Considerations:**
  - Support for username/password or OAuth2 authentication
  - Multi-user support
  - Audit logging for authentication events

---

- The MVP backend MUST support multiple storage providers for photo blobs:
  - **filesystem**: Local persistent storage (MVP default for production, required for persistent data)
  - **memory**: Ephemeral in-memory storage (default for local/dev/CI)
  - **null**: Accepts all operations, stores nothing, never fails (ideal for CI/demo)
  - **dropbox**: Cloud storage (MVP requirement for production cloud deployments)
  - **s3**: Planned for future releases

| Provider    | Persistence | Intended Use         | Status      |
|------------|-------------|----------------------|-------------|
| filesystem | Persistent  | Production, real data| MVP         |
| memory     | Ephemeral   | Dev, tests, CI       | MVP         |
| null       | None        | CI, demo, dry-run    | MVP         |
| dropbox    | Persistent  | Cloud, production    | MVP         |
| s3         | Persistent  | Cloud, future        | Planned     |

**Photo Uploads (MVP):**
- File upload via the app is OUT OF SCOPE for MVP.
- Photos MUST be added directly to the backend storage (e.g., filesystem, Dropbox) using external tools or manual copy.
- The `/rescan` endpoint MUST be triggered manually by an admin or automated process after new photos are added to backend storage. There is no automatic background scan in MVP. It scans the storage location and imports any new photos into the database so they become available in the app.
- The `/rescan` endpoint MUST respond synchronously with a summary of imported photos, e.g.:
    ```json
    {
      "imported": ["uuid1", "uuid2"],
      "skipped": ["uuid3"],
      "errors": []
    }
    ```
- Future versions MAY add upload endpoints and in-app upload UX.

### 2.2 Storage Abstraction

The backend MUST implement a unified storage interface with the following methods. This interface MUST be designed for future extensibility (e.g., additional metadata fields, new storage backends). All metadata MUST be persisted in the database via the storage abstraction, regardless of the blob storage backend.

#### Photo Object Definition
A `Photo` object MUST contain at least the following fields:
```json
{
  "photo_id": "<uuid>",
  "metadata": {
    "description": "<string>"
  },
  "last_modified": "<ISO 8601 timestamp>"
}
```
The `metadata` field is a dictionary of typed key-value pairs. For MVP, only `description` is required, but the structure is explicitly designed for future extensibility (e.g., tags, author, location, etc.). All metadata fields MUST be included in the `metadata` dictionary, not as top-level fields.

#### Required Interface
- `list_photos(limit: int = 100, offset: int = 0) -> dict`
  - MUST return a paginated list of photo object UUIDs and the total count.
  - Arguments:
    - `limit` (int): Maximum number of photo IDs to return (default: 100, max: 500).
    - `offset` (int): Number of photo IDs to skip (default: 0).
  - Returns:
    ```json
    {
      "photo_ids": ["uuid1", "uuid2", ...],
      "total": 12345
    }
    ```

- `get_photo(photo_id: UUID) -> Photo`
  - MUST retrieve a specific photo by ID, including all metadata.

- `set_metadata(photo_id: UUID, metadata: dict) -> Photo`
  - MUST update a photo's metadata fields.
  - `metadata` MUST be a JSON object.
  - For MVP, the only required field is `{"metadata": { "description": "..." }}`.
  - The interface MUST be extensible for future fields (e.g., tags, author).
  - The returned `Photo` object MUST reflect the updated metadata and the new `last_modified` timestamp.
- When updating metadata, clients SHOULD send the last known `last_modified` value as part of the request body.
- The backend MUST check that the provided `last_modified` matches the current value in the database before applying the update. If not, it MUST return HTTP 409 Conflict with an error response:
    ```json
    {
      "detail": "Photo has been modified since last retrieval"
    }
    ```
  and MUST NOT apply the update.

#### Backend Implementations
- **Filesystem Backend (MVP):**
  - Photo blobs MUST be stored in the local filesystem.
  - Metadata MUST be stored in the database via the storage abstraction.

- **Dropbox Backend (MVP):**
  - Photo blobs MUST be stored in Dropbox.
  - Metadata MUST be stored in the database via the storage abstraction.
  - Dropbox provider is a required MVP feature for cloud deployments. All Dropbox configuration and environment variables MUST be documented and tested.

- **S3 Backend (future):**
  - Photo blobs MUST be stored in S3.
  - Metadata MUST be stored in the database via the storage abstraction.

**Note:** The storage abstraction API MUST remain consistent across all backends. Implementation details MAY differ.

**Pagination Note:**
- All endpoints returning lists of photos MUST support pagination via `limit` and `offset` parameters.
- The default page size is 100; the maximum is 500.
- The response MUST include both the list of items and the total number available.
- Example paginated response:
    ```json
    {
      "photo_ids": ["uuid1", "uuid2"],
      "total": 200
    }
    ```

---

## 3. Frontend Specification

_This section describes requirements for the user interface, user experience, and frontend logic._

### 3.1 UI/UX

#### Core User Flows
- **Viewing Photos**
  - Users MUST be able to view a gallery/grid of all photos.
  - Users MUST be able to click/tap a photo to view it in detail (full-size or modal).
- **Editing Metadata**
  - Users MUST be able to view and edit the metadata for each photo.
  - For MVP, the only editable metadata field is:
    - **Description** (string): A user-editable text field of arbitrary length describing the photo.
  - Edits to metadata MUST be submitted via the UI and persisted through the backend API.
- **Navigation**
  - Users MUST be able to navigate back and forth between the gallery and individual photo views.

#### Accessibility Requirements
- The UI MUST meet WCAG 2.1 AA accessibility standards.
- All interactive elements MUST be keyboard accessible (tab/arrow navigation).
- All images MUST include alt text (photo description or “Photo” if none).
- UI components MUST use semantic HTML and ARIA attributes as appropriate.
- Color contrast MUST meet accessibility guidelines.
- Automated accessibility (a11y) checks MUST be run in CI using axe-core.
  - **Zero serious or critical accessibility violations (axe-core severity: "serious" or "critical") are allowed before merging.**

#### Required Components
- **Photo Gallery/Grid**: Displays all (or a subset of) photos with thumbnails and brief metadata.
  - MUST support pagination or infinite scroll if there are more photos than fit on one page.
  - MUST show loading indicators while fetching data.
- **Photo Detail View**: Shows the full-size photo and all associated metadata.
  - MUST allow navigation back to the gallery/grid.
  - MUST show a loading indicator while fetching photo details.
- **Metadata Editor**: Allows editing the metadata for a photo.
  - For MVP, MUST allow editing the photo description.
  - MUST validate input and display errors for invalid or empty submissions.
  - MUST show a loading indicator while saving changes.
- **Error/Status Messages**: Clearly communicates loading, success, and error states to the user.
  - MUST display error, success, and loading states for all async operations.
  - Error messages MUST be user-friendly and dismissible.
  - Loading indicators MUST be visible during all async operations.

### 3.2 Frontend Tech Stack
- The frontend MUST use:
  - React 18
  - Next.js 15.3
  - Tailwind CSS 4.1 for styling
  - shadcn/ui for UI components (or custom components matching their design principles)
  - TypeScript for all code
- Code formatting MUST be enforced with Prettier.
- Linting MUST be enforced with ESLint.
- All code MUST be tested with Jest and React Testing Library.
- Minimum unit test coverage MUST be 90% (statements/branches/lines/functions).
- End-to-end (E2E) tests MUST be written using Playwright and MUST cover all critical user flows.
  - "Critical user flows" are defined as all flows necessary to view, edit, and navigate photos and metadata in the MVP.
  - E2E tests MUST use representative mock or seed data.
- Automated accessibility (a11y) checks MUST be run in CI using axe-core (via Playwright or standalone). Zero serious or critical accessibility violations are allowed before merging.
- E2E tests MUST be run in Chromium, Firefox, and WebKit browsers (to ensure cross-browser compatibility).
- E2E tests MUST be integrated into the CI/CD pipeline and MUST pass before merging.
- Pre-commit hooks MUST run the formatter, linter, and tests before each commit.

### 3.3 API Integration
- The frontend MUST communicate with the backend via RESTful HTTP endpoints.
- All data exchanged between frontend and backend MUST be in JSON format.
- The frontend MUST handle all API errors gracefully and display user-friendly error messages.
  - API error responses MUST be parsed and shown to the user. Example error response:
    ```json
    {
      "detail": "Description cannot be empty."
    }
    ```
- API endpoints and data shapes MUST match the backend specification.
- If the backend API changes in a breaking way, the frontend implementation MUST be updated accordingly before release. All breaking changes MUST be documented in the spec.

---

## 4. Infra & Integration

_This section describes how the frontend and backend are wired together, deployment, environments, and CI/CD._

### 4.1 Integration

#### API Base URLs
- The frontend MUST obtain the backend API base URL from an environment variable at build time (e.g., `NEXT_PUBLIC_API_BASE_URL`).
- The backend MUST expose a stable, documented base path for all API endpoints (e.g., `/api`).
- Environment-specific values MUST be set in deployment configuration or `.env` files (e.g., `NEXT_PUBLIC_API_BASE_URL=http://localhost:8000/api` for development, `NEXT_PUBLIC_API_BASE_URL=https://api.myappisvery.cool/api` for production).

#### CORS
- The backend MUST implement CORS to allow requests from the deployed frontend’s domain(s) in all environments.
- During development, CORS MUST allow requests from `localhost` and any configured dev URLs.

#### Authentication
- For MVP, authentication is NOT required.
- If authentication is added in the future, it MUST use secure, documented mechanisms (e.g., JWT, OAuth2) and must be reflected in both backend and frontend integration.

#### Environment Variable Conventions
- All environment variables used for integration (API URLs, secrets, etc.) MUST be documented in this spec and in `.env.example` files in each repo.
  - `.env.example` files MUST be kept up to date with all required variables for each environment.
  - Each environment variable MUST be documented with:
    - Name
    - Purpose/description
    - Example value
- Frontend environment variables MUST be prefixed with `NEXT_PUBLIC_` to ensure they are available at build and runtime.
- Backend environment variables MUST NOT be exposed to the frontend.

#### Service Discovery
- The frontend MUST NOT hardcode backend URLs. All such configuration MUST come from environment variables or deployment configuration.

### 4.2 Deployment

- The frontend and backend MUST each be packaged as Docker images.
  - Docker images MUST include metadata labels (e.g., version, maintainer).
  - Docker images MUST NOT contain secrets or credentials at build time.
- All configuration (API URLs, secrets, etc.) MUST be provided via environment variables at container runtime.
- Docker Compose (or equivalent) SHOULD be used to orchestrate local development and multi-container deployments.
- Dockerfiles and Compose files MUST be linted and validated in CI (e.g., using `hadolint` or similar tools).
- The application MUST NOT depend on features unique to any single cloud provider or platform.

### 4.3 CI/CD

- **CI Provider:** GitHub Actions MUST be used for all continuous integration and delivery workflows.
- **Required Checks:**
  - CI MUST run on every push to main and every push to a branch with an open pull request.
  - Every run MUST pass:
    - Code formatting (Prettier for frontend, Black for backend)
    - Linting (ESLint for frontend, Ruff for backend)
    - Type checks (TypeScript for frontend, Pyright for backend)
    - Unit tests (Jest/React Testing Library for frontend, pytest for backend)
    - End-to-end (E2E) tests (Playwright, in Chromium, Firefox, and WebKit)
    - Dockerfile and Compose file linting/validation
- **Pre-commit:** Pre-commit hooks MUST enforce formatting, linting, and type checking locally before every commit.
- **CI Configuration:**
  - All CI configuration files (e.g., `.github/workflows/*`) MUST be version controlled and reviewed in pull requests.
  - Test and lint results MUST be visible in pull requests.
- **Merge Policy:**
  - No code may be merged unless all required checks pass.
  - Manual overrides to force-merge failing checks are NOT permitted.
  - If the robots aren’t happy, the humans don’t get to merge.

---

## 5. General Requirements

- All APIs MUST be documented and machine-readable.
- The system MUST be testable via automated tests.
- Future extensibility (e.g., additional metadata fields, new storage backends) MUST be considered in all designs.

---

## 6. Out of Scope (for MVP)

- User authentication and authorization
- Advanced metadata (beyond “description”)
- Non-filesystem storage backends (Dropbox, S3)

---

## 7. Terminology

- **Blob**: The raw image file.
- **Metadata**: JSON describing the photo (e.g., description, tags).
- **Photo**: An object containing both blob and metadata.

---

## 8. Appendix: RFC 2119 Keywords

See [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt) for definitions of **MUST**, **SHOULD**, **MAY**, etc.

- The backend MUST expose a storage abstraction with the following interface:
  - `list_photos() -> list[UUID]`: MUST list all available photo object IDs
  - `get_photo(photo_id: UUID) -> Photo`: MUST retrieve a specific photo by ID, including metadata
  - `set_metadata(photo_id: UUID, metadata: dict) -> Photo`: MUST update a photo's metadata fields. The `metadata` argument MUST be a JSON object. For MVP, this object will only contain `{"metadata": { "description": "..." }}`, but the interface is designed for future extensibility (e.g., additional fields such as tags, author, etc.). The returned `Photo` object MUST reflect the updated metadata.
- **Backend-specific behavior:**
  - **Filesystem backend:**
    - Blobs MUST be stored in local filesystem
    - Descriptions MUST be stored in the database via the storage abstraction
  - **Dropbox backend (future but soon):**
    - Blobs MUST be stored in Dropbox
    - Descriptions MUST be stored in the database via the storage abstraction
  - **S3 backend (future):**
    - Blobs MUST be stored in S3
    - Descriptions MUST be stored in the database via the storage abstraction
- The API and abstraction MUST be unified; implementation MAY vary by backend.

## 9. API Endpoints
| Method | Path                        | Purpose                  | Request Example                  | Response Example                |
|--------|-----------------------------|--------------------------|----------------------------------|---------------------------------|
| POST   | /login                      | Authenticate user and set access token cookie | `{ "password": "hunter2" }`         | `{ "detail": "Login successful" }` (sets HTTP-only cookie with access token)           |
| POST   | /refresh                    | Obtain a new access token using a refresh token | `{ "refresh_token": "<opaque>" }` | `{ "access_token": "<jwt>", "refresh_token": "<opaque>", "token_type": "bearer" }` |
| GET    | /photos?limit=100&offset=0  | List photo IDs (paginated) |                                  | `{ "photo_ids": ["uuid1", "uuid2"], "total": 12345 }`      |
| GET    | /photos/{id}                | Get photo data and all metadata fields |                                  | `{ "id": "6d5e4b8a-2e3c-4f1d-9e7a-5c8b2e1f2a3b", "object_key": "photos/foo.jpg", "metadata": { "description": "A dog" } }`              |
| PATCH  | /photos/{id}/metadata    | Update photo metadata (currently only `description`) | `{ "metadata": { "description": "Nice" }, "last_modified": "2025-04-22T12:00:00Z" }` | `{ "id": "6d5e4b8a-2e3c-4f1d-9e7a-5c8b2e1f2a3b", "metadata": { "description": "Nice" }, "last_modified": "2025-04-22T12:01:00Z"}` |
| GET    | /photos/{id}/image          | Get image file           |                                  | (binary image)                  |
| POST   | /rescan                     | Discover and sync photos from storage (see note) |                                  | `{ "status": "ok" }`            |

> **Note:** The `/rescan` endpoint scans the backend storage for new photos and imports them into the app database. File upload via the app is not supported in MVP—add new photos directly to storage, then call `/rescan` to sync.

- All protected endpoints (except `/login` and `/refresh`) MUST require the access token cookie for authentication. The `Authorization` header is NOT used for cookie-based auth.
- Access tokens MUST expire after a short period (default: 15–60 minutes).
- Refresh tokens MUST be securely stored and used only for obtaining new access tokens via `/refresh`.
- The `/photos/{id}` and `/photos/{id}/metadata` endpoints MUST source and persist metadata via the storage abstraction (i.e., use the database).

## 10. Data Model
| Field         | Type      | Description                                                                    |
|--------------|-----------|--------------------------------------------------------------------------------|
| id           | UUID      | Unique photo ID (universally unique identifier, e.g., `6d5e4b8a-2e3c-4f1d-9e7a-5c8b2e1f2a3b`) |
| object_key   | string    | Storage path or object key (Dropbox path or S3 key)                             |
| metadata     | object    | Dictionary of metadata fields (at minimum: description) |(stored in the database via the storage abstraction)   |
| last_modified| string (RFC3339 timestamp) | Last modification time of photo metadata (set by backend)                |

> **Note:** The GET `/photos/{id}` endpoint returns both photo data and all metadata fields as a single JSON object. Additional metadata fields MAY be supported in the future.

## Photo Object Definition

The `Photo` object represents an image record and its associated metadata. All API responses and storage abstraction methods referencing a `Photo` MUST conform to the following structure:

```json
{
  "id": "6d5e4b8a-2e3c-4f1d-9e7a-5c8b2e1f2a3b",
  "object_key": "photos/foo.jpg",
  "metadata": { "description": "A dog" },
  "last_modified": "2025-04-22T12:00:00Z"
}
```

- `id` (UUID string): Unique photo ID (universally unique identifier, e.g., `6d5e4b8a-2e3c-4f1d-9e7a-5c8b2e1f2a3b`).
- `object_key` (string): Storage path or object key (Dropbox path or S3 key).
- `metadata` (object): Dictionary of key-value pairs describing the photo. For MVP, MUST include `description` (string), but is designed for extensibility (e.g., tags, author, etc.).

> **Note:** Additional fields MAY be added to the `Photo` object in future, post-MVP versions. All clients and integrations MUST ignore unknown fields.

## 11. Configuration (Environment Variables)

### All configurations

| Variable                | Purpose                        | Type    | Required | Example Value           |
|-------------------------|--------------------------------|---------|----------|------------------------|
| BACKEND_PASSWORD        | Backend login password         | string  | Yes      | hunter2                |
| STORAGE_PROVIDER        | Photo storage backend          | string  | No       | dropbox                |

### Dropbox storage provider

| Variable                | Purpose                        | Type    | Required | Example Value           |
|-------------------------|--------------------------------|---------|----------|------------------------|
| DROPBOX_APP_KEY         | Dropbox API app key            | string  | Yes*     | your_app_key           |
| DROPBOX_APP_SECRET      | Dropbox API app secret         | string  | Yes*     | your_app_secret        |
| DROPBOX_REFRESH_TOKEN   | Dropbox OAuth 2.0 refresh token| string  | Yes*     | your_refresh_token     |
| JWT_SECRET_KEY          | JWT signing key                | string  | Yes*     | (long random string)   |

*Required for Dropbox backend only.

## 12. Error Codes

> **Error Response Format:**
> All error responses MUST be JSON objects with a `detail` field, e.g. `{ "detail": "Error message" }`. This matches FastAPI's default behavior and ensures consistency for clients.

| Status | Meaning         | Example Scenario                                |
|--------|----------------|-------------------------------------------------|
| 400    | Bad Request    | Malformed request, invalid parameters           |
| 401    | Unauthorized   | Invalid or missing authentication               |
| 403    | Forbidden      | Authenticated but not allowed                   |
| 404    | Not Found      | Resource does not exist (e.g., photo ID)        |
| 409    | Conflict       | Duplicate resource (e.g., same photo hash)      |
| 422    | Unprocessable  | Semantically invalid (e.g., bad description)        |
| 500    | Server Error   | Unexpected backend/server error                 |

## 13. Development Practices
- Test-driven development (TDD) MUST be followed for all new features.
- All backend endpoints (including authentication, photo retrieval, and metadata update) MUST be covered by automated tests.
- The backend MUST maintain high test coverage (target: 90%+ for all new code).
- All code MUST pass type checking (Pyright) and linting (Ruff) before merging.
- All secrets/configuration (including admin password, JWT secret, etc.) MUST be provided via environment variables and MUST NEVER be hardcoded.
- CI/CD MUST enforce tests, linting, and type checks.
- Code MUST be concise, maintainable, and PEP 8/257 compliant.

## 14. Glossary
| Term        | Definition                                                        |
|-------------|-------------------------------------------------------------------|
| Photo       | An image record (blob + metadata). The unique photo ID is always a UUID. |
| Description     | User-supplied text describing a photo (stored in the database via the storage abstraction; see Section 3) |
| Object Key  | Storage path (Dropbox) or S3 object key                           |
| LRU         | Least Recently Used cache for thumbnails                          |

## 15. Example Usage
### Get photo metadata
Request: `GET /photos/6d5e4b8a-2e3c-4f1d-9e7a-5c8b2e1f2a3b`
Response: `{ "id": "6d5e4b8a-2e3c-4f1d-9e7a-5c8b2e1f2a3b", "object_key": "photos/foo.jpg", "metadata": { "description": "A dog" } }`

### Update description
Request: `PATCH /photos/6d5e4b8a-2e3c-4f1d-9e7a-5c8b2e1f2a3b/metadata` with `{ "metadata": { "description": "A better description" }, "last_modified": "2025-04-22T12:00:00Z" }`
Response: `{ "id": "6d5e4b8a-2e3c-4f1d-9e7a-5c8b2e1f2a3b", "metadata": { "description": "A better description" }, "last_modified": "2025-04-22T12:01:00Z" }`

### Error response
Response: `{ "detail": "Photo not found" }` (404)

> **Note:** All error responses from the backend MUST be JSON objects containing a **`detail`** field, following FastAPI best practices. Additional fields (such as `code` or `errors`) MAY be included in the future, but **`detail`** MUST always be present.

---

## AI Guidance
- When generating or reviewing code, you MUST check which backend is in use and apply the correct metadata storage mechanism.
- For all backends (filesystem, Dropbox, S3), all description CRUD MUST use the storage abstraction to persist metadata in the database.
- The storage abstraction MUST use a fail-fast approach for all metadata CRUD operations: if the storage backend (e.g., Dropbox, S3) is unavailable, the API MUST return an error immediately (5xx). No retries or queueing are required for MVP. Retries or queueing MAY be considered for future releases if higher availability is needed.
- All endpoint behaviors, error codes, and data model fields MUST match this spec.
