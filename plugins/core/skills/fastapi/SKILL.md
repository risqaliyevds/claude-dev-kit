---
name: fastapi
description: FastAPI and modern Python backend conventions. Use when writing or modifying FastAPI apps, routers, Pydantic models, SQLAlchemy code, or Python API endpoints.
user-invocable: false
---

When working on FastAPI / Python backends, follow these conventions.

**Project shape**
- Layered architecture: Router -> Service -> Repository. No DB calls inside routers; no HTTP types (Request/Response) inside services.
- Use FastAPI dependency injection (`Depends`) for sessions, auth, and config — not module-level globals.
- Configuration via pydantic-settings reading environment variables; never hardcode.

**Async and database**
- Async by default: async route handlers, `AsyncSession`, async drivers (asyncpg). Never mix a sync SQLAlchemy `Session` into async paths.
- SQLAlchemy 2.x style only: `select()` queries and `selectinload()` for eager loading — no legacy `query()` style. Watch for and prevent N+1 queries.
- Every schema change goes through an Alembic migration.

**Validation and errors**
- Pydantic v2 models for every request and response (`response_model=...`). Separate Create/Update/Read schemas; never expose ORM models directly.
- Raise `HTTPException` with correct status codes; register handlers for domain errors; never leak stack traces or internals in API responses.

**Security**
- All SQL through the ORM or bound parameters — never string-built.
- Auth as reusable OAuth2/JWT dependencies; secrets only from env; never log tokens or passwords; validate and limit file uploads.

**Tooling and tests**
- uv for environments and dependencies; ruff for lint+format; mypy or pyright strict in CI; type hints on all signatures.
- pytest + pytest-asyncio with `httpx.AsyncClient` against the app; AAA pattern; isolated test database per run.
