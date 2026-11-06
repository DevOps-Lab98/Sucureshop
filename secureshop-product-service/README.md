# SecureShop — Product Service

A reference microservice for the SecureShop platform: UI + Backend + Database.
Use this as the template pattern for User Service and Order Service too.

## Stack
- **Frontend:** static HTML/CSS/JS (talks to backend via REST)
- **Backend:** Node.js + Express, PostgreSQL client (`pg`)
- **Database:** PostgreSQL

## Structure
```
secureshop-product-service/
├── backend/
│   ├── src/
│   │   ├── index.js          # server entrypoint, health checks
│   │   ├── db.js             # PostgreSQL connection pool
│   │   └── routes/
│   │       └── products.js   # CRUD endpoints
│   ├── Dockerfile            # non-root, multi-stage build
│   └── package.json
├── frontend/
│   ├── index.html
│   ├── style.css
│   └── app.js
├── db/
│   └── init.sql              # schema + seed data
├── docker-compose.yml        # local dev: db + backend + frontend
└── README.md
```

## Run locally
```bash
docker compose up --build
```
- Frontend: http://localhost:8080
- Backend API: http://localhost:3000/api/products
- Health check: http://localhost:3000/healthz
- Readiness check (verifies DB connection): http://localhost:3000/readyz

## Environment variables (backend)
| Variable | Purpose | Local default |
|---|---|---|
| `PORT` | API port | `3000` |
| `DB_HOST` | Postgres host | `db` (compose service name) |
| `DB_PORT` | Postgres port | `5432` |
| `DB_USER` | Postgres user | `secureshop_user` |
| `DB_PASSWORD` | Postgres password | set in compose for local only |
| `DB_NAME` | Database name | `secureshop` |
| `DB_SSL` | Enforce SSL on DB connection | `false` locally, `true` in Azure |
| `ALLOWED_ORIGIN` | CORS origin | frontend URL |

In AKS, `DB_PASSWORD` and other secrets are **never** set via plain env vars in
the manifest — they're mounted from Azure Key Vault via the CSI Secrets Store
Driver + Workload Identity, per the platform's secrets design.

## Notes for the DevSecOps pipeline
- `healthz` / `readyz` endpoints are wired for K8s liveness/readiness probes.
- Dockerfile runs as a non-root user and uses a multi-stage build — smaller
  attack surface for Trivy to scan.
- All SQL queries are parameterized (no string concatenation) — clean for
  SonarQube SAST.
- No secrets are committed anywhere in this repo — clean for Gitleaks.
