# Project Documentation for Codex — AI Code Change Orchestrator (PR Control Plane)

> **Purpose of this doc:** Provide a complete, self-contained reference for Codex to implement, refactor, and extend the system without missing key architectural context.

---

## 1. Project Overview

### Purpose
Build a **web-based AI engineering control plane** that safely converts a user’s natural-language task into a **validated GitHub Pull Request**, with:
- **Transparency** (what context was used, why, costs)
- **Control** (human approval gates)
- **Safety** (sandboxed validation)
- **Replayability** (re-run jobs with different models/policies)
- **Observability** (timeline, metrics, logs, traces)

### What it is
An **AI-driven code change orchestration platform** that sits between:
- Developer intent (UI)
- Repository + GitHub
- Sandbox execution
- LLM providers
- Auditing/observability

### What it is NOT
- Not a chatbot
- Not a CI replacement
- Not a Git provider
- Not an IDE plugin
- Not an autonomous merge bot

### Core user
Backend / platform / AI infra engineers who want controlled, auditable AI-driven PR creation.

---

## 2. Architecture Description

### Technology Stack (Must-haves)
- **Backend:** Python 3.12, FastAPI
- **Workflow Orchestration:** Temporal
- **LLM Gateway:** LiteLLM (wrapped behind internal interface)
- **Event Backbone:** Apache Kafka, Consumer Groups, Dead Letter Topic (DLQ)
- **Data Layer:** PostgreSQL, pgvector, Redis
- **Caching:** Redis (L2), In-process LRU (L1)
- **Sandbox Execution:** Docker, Kubernetes Jobs
- **K8s Infra:** Deployments, StatefulSets (Kafka/Postgres), HPA, RBAC, NetworkPolicies, Helm
- **Observability:** OpenTelemetry, Prometheus, Grafana, Loki, Tempo
- **Git Integration:** GitHub OAuth, GitHub App, GitHub REST API
- **Frontend:** Next.js, React, Tailwind CSS
- **DevOps:** Docker multi-stage builds, distroless images, GitHub Actions

### High-level component map

```

[Browser UI (Next.js)]
|
v
[API (FastAPI)]  <----->  [Postgres]  (source of truth)
|   |                [Redis]     (cache + quotas)
|   |
|   +--> publish events --> [Kafka] --> consumers (timeline/metrics/DLQ)
|
+--> start/signal workflows --> [Temporal] --> [Workers]
|
+--> [LiteLLM] (LLM calls)
|
+--> [K8s Jobs] (sandbox validation)
|
+--> [GitHub REST] (branch + PR)

```

### Design approach / patterns
- **Control plane pattern:** API handles auth/approval/gating; workers do heavy work.
- **Workflow/state machine:** job lifecycle is explicit; transitions are validated.
- **Human-in-the-loop gates:** mandatory approvals (plan + diff).
- **Separation of concerns:** orchestration (Temporal) vs events (Kafka) vs storage (Postgres).
- **Replaceable interfaces:** LLM client, retrieval/indexing, policy engine are pluggable.
- **Least privilege + isolation:** K8s Job sandbox, NetworkPolicies, GitHub App minimal scopes.

> If specific internal patterns for code organization are not decided yet, treat them as **TBD**, but keep interfaces stable and swap implementations later.

---

## 3. Data Flows

### A) Control plane request flow (sync)
```

UI -> API -> (Redis cache hit?) -> Postgres -> API -> UI

```
- SLO target: p95 < 300ms for typical reads/writes.

### B) Job execution flow (async)
```

UI -> API -> Postgres (Job CREATED)
API -> Temporal (start workflow with workflow_id = job_id)
API -> Kafka (emit job_created event)

Temporal -> Activities -> Postgres updates + Kafka events

```

### C) LLM invocation flow
```

Temporal Activity -> LLMClient interface -> LiteLLM -> Provider (OpenAI/Anthropic/etc.)
Activity persists: tokens, latency, cost, output artifact -> Postgres (+ Kafka event)

```

### D) Sandbox validation flow
```

Temporal ValidationActivity -> create Kubernetes Job
K8s Job: clone @ base_sha -> apply patch -> run allowlisted commands -> exit code
Logs -> Loki
Result -> Postgres (+ Kafka event)

```

### E) GitHub PR creation flow
```

Temporal PRActivity -> GitHub REST API:
create branch -> commit -> push -> create PR
Persist pr_url, branch_name, final_sha -> Postgres (+ Kafka event)

```

> Repo storage constraint: do NOT store entire repo persistently. Use ephemeral checkout during job steps.

---

## 4. Key Modules and Interactions

### Modules / services (functional order)

- **Frontend (Next.js UI)**
  - Displays job list, job detail, timeline, plan, diff, validation results, costs.
  - Triggers actions: create job, approve plan, approve diff, create PR (if not auto after validation).

- **API Service (FastAPI) — “Gatekeeper”**
  - GitHub OAuth login
  - Tenant/RBAC enforcement
  - Job creation + reads
  - Records approvals (plan/diff)
  - Signals Temporal to continue at approval gates
  - Lightweight quota checks (hard enforcement can be in worker too)

- **PostgreSQL (source of truth)**
  - Tenants, users, repos, jobs, approvals, artifacts, costs, policies, timeline (optional)
  - Strong consistency for job state and approvals

- **pgvector (in Postgres)**
  - Embeddings for semantic retrieval of relevant code chunks for a job
  - Used primarily during ContextActivity

- **Redis**
  - L2 distributed cache for job summaries, policy lookups
  - Quota/rate limit counters
  - Short-lived tokens (if applicable)

- **Kafka (event backbone)**
  - Publishes job lifecycle events and operational events
  - Consumer groups for timeline and metrics pipelines
  - Dead-letter topic (DLQ) for poison events in consumers

- **Temporal (workflow engine)**
  - Owns durable job execution and step progression
  - Waits for approval signals
  - Retries activities with backoff/timeouts

- **Workers (Temporal activity workers)**
  - ContextActivity: repo snapshot + retrieval
  - PlanActivity: generate plan via LLM
  - PatchActivity: generate patch/diff via LLM
  - ValidationActivity: run sandbox job
  - PRActivity: create PR on GitHub

- **LLM Layer (LiteLLM adapter behind `LLMClient`)**
  - Provider routing
  - Token/cost tracking
  - Retry for transient provider failures

- **Sandbox Execution (Kubernetes Jobs)**
  - Ephemeral job per AI job validation
  - Resource limits, timeouts, restricted network
  - Emits logs to Loki

- **Observability stack**
  - OpenTelemetry instrumentation in API + workers
  - Prometheus metrics + Grafana dashboards
  - Loki logs
  - Tempo traces

#### Module Interactions (short summary)
- UI calls API; API reads/writes Postgres and Redis.
- API starts/signals Temporal workflows.
- Workers update Postgres and emit Kafka events.
- Kafka consumers build timeline/metrics and handle DLQ.
- Validation runs inside K8s Jobs; logs go to Loki; results persist in Postgres.
- PR creation uses GitHub REST with GitHub App credentials.

---

## 5. Key Assumptions and Constraints

### Assumptions
- **Tenancy model:** Multi-tenant SaaS (tenant_id applied to all data and cache keys).
- **Repo handling:** ephemeral checkout; do not persist full source code.
- **Approval gates:** mandatory plan approval and diff approval before PR creation.
- **Sandbox safety:** restricted egress by default; allow only GitHub + package registries + LLM endpoints.
- **Validation commands:** allowlisted per repo/tenant policy (not arbitrary shell execution).
- **LLM providers:** OpenAI + Anthropic first via LiteLLM; other providers later via adapter.

### Constraints
- API must remain fast (avoid long-running operations in API).
- Job state must be deterministic and auditable.
- No direct commits to main branch.
- Store minimal sensitive data; avoid logging secrets or full prompts/raw code.
- Pluggable placeholders allowed if needed (e.g., policy engine, indexer), but interfaces must remain stable.

---

## 6. Example Workflows

### 1) Create Job → Plan → Diff → Validate → PR (Happy Path)

1. **User (UI):** selects repo + describes task.
2. **API:** creates Job row in Postgres:
   - status = `CREATED`
   - base_sha pinned (current default branch head at time of job)
3. **API:** starts Temporal workflow:
   - `workflow_id = job_id` (dedupe)
4. **Workflow:** `ContextActivity`
   - clone repo at base_sha (ephemeral)
   - build semantic context (pgvector) and store context snapshot (paths + chunk ids)
   - status -> `CONTEXT_BUILT`
5. **Workflow:** `PlanActivity`
   - LLM call to generate structured plan (JSON)
   - persist plan artifact, tokens, cost
   - status -> `PLAN_READY`
6. **Workflow waits** for plan approval signal.
7. **User (UI):** reviews plan, clicks approve.
8. **API:** records approval and signals Temporal `plan_approved`.
9. **Workflow:** `PatchActivity`
   - LLM generates patch/diff
   - persist patch artifact
   - status -> `PATCH_READY`
10. **Workflow waits** for diff approval signal.
11. **User (UI):** reviews diff, clicks approve.
12. **API:** records approval and signals Temporal `patch_approved`.
13. **Workflow:** `ValidationActivity`
   - create Kubernetes Job
   - clone repo @ base_sha, apply patch, run allowlisted commands
   - store result, link logs (Loki), status -> `VALIDATED` or `FAILED_VALIDATION`
14. **If validated:** `PRActivity`
   - create branch, commit, push, create PR
   - persist `pr_url`, final_sha
   - status -> `COMPLETED`

Outputs:
- PR URL, diff, plan, logs, cost, timeline.

---

### 2) Validation Fails (Stop, No PR)

Steps same as above until ValidationActivity.
- Sandbox returns non-zero exit (tests fail).
- Workflow sets status -> `FAILED_VALIDATION`.
- Emit failure event.
- UI shows logs + failure reason.
- No PR is created.

---

### 3) LLM transient failure (Retry)

During PlanActivity / PatchActivity:
- Provider returns 429/5xx.
- Activity retries with exponential backoff (Temporal retry policy).
- If retry exhausted:
  - status -> `FAILED_LLM`
  - store error code and timestamps
  - UI shows failure.

---

### 4) Prevent duplicate PR creation (idempotency)

Before PR creation:
- PRActivity checks Postgres:
  - if `job.pr_url` exists => skip PR creation (already done).
- Ensures workflow retry does not duplicate PRs.

---

## 7. Reference Materials

- Not available (no external links provided in this conversation).
- Suggested internal references to create later (TBD):
  - `docs/architecture/diagrams.md` (system diagrams)
  - `docs/api/openapi.md` (OpenAPI export)
  - `docs/policies/policy-model.md` (allowlists/quotas)
  - `docs/workflows/temporal-workflows.md` (workflow definitions)
  - `docs/data-model/schema.md` (Postgres + pgvector schema)
  - `docs/security/threat-model.md` (high-level threat model)

---

## Completeness Check for Codex

This document includes:
- Project purpose + scope boundaries ✅
- Full architecture and stack ✅
- Data flows (sync + async + LLM + sandbox + PR) ✅
- Module list + interactions ✅
- Assumptions/constraints ✅
- Example workflows (happy + failure + retry + idempotency) ✅
- References section with placeholders ✅

If you want deeper implementation detail, add (TBD):
- Concrete Postgres schema (tables/columns/indexes)
- Temporal workflow code skeletons (names, signals)
- Kafka topic names + event schemas
- Security policies (NetworkPolicy templates, RBAC roles)
```
