---
name: langfuse
description: Interact with Langfuse LLM observability platform via curl. Use when working with Langfuse to create traces/spans/events, retrieve observations, manage scores, or query metrics. Auto-triggers on mentions of "langfuse", "trace logging", "LLM observability", or when working with Langfuse API keys.
---

# Langfuse API via curl

Interact with the Langfuse LLM observability platform using curl for trace ingestion, data retrieval, scoring, and analytics.

## Authentication

All API requests use HTTP Basic Auth:
- **Username**: Langfuse Public Key (starts with `pk-lf-`)
- **Password**: Langfuse Secret Key (starts with `sk-lf-`)
- **Location**: Keys are typically stored in `.env.local` of connected projects

```bash
curl -u "pk-lf-...":"sk-lf-..." https://cloud.langfuse.com/api/public/...
```

## Regional Endpoints

Choose the endpoint matching your Langfuse deployment:
- **Cloud EU**: `https://cloud.langfuse.com`
- **Cloud US**: `https://us.cloud.langfuse.com`
- **HIPAA US**: `https://hipaa.cloud.langfuse.com`
- **Self-hosted**: Your instance URL (e.g., `http://localhost:3000`)

## Core Operations

### 1. Trace Ingestion (Creating Traces/Spans/Events)

**Endpoint**: `POST /api/public/ingestion`

Create traces, spans, generations, and events in batch format:

```bash
curl -X POST https://cloud.langfuse.com/api/public/ingestion \
  -u "pk-lf-...":"sk-lf-..." \
  -H "Content-Type: application/json" \
  -d '{
    "batch": [
      {
        "id": "trace-1",
        "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'",
        "type": "trace-create",
        "body": {
          "id": "trace-1",
          "name": "chat-request",
          "userId": "user-123",
          "sessionId": "session-456",
          "input": {"question": "What is LangFuse?"},
          "output": {"answer": "An LLM observability platform"},
          "metadata": {"env": "production"},
          "tags": ["chat", "production"]
        }
      }
    ],
    "metadata": {}
  }'
```

**Note**: OpenTelemetry (OTLP) is replacing this endpoint. For new integrations, prefer OTLP.

### 2. Retrieve Observations (Query Traces/Spans/Events)

**Endpoint**: `GET /api/public/v2/observations` (v2 recommended)

Query observation data with cursor-based pagination and selective field retrieval:

```bash
# Basic query with date range
curl -G https://cloud.langfuse.com/api/public/v2/observations \
  -u "pk-lf-...":"sk-lf-..." \
  --data-urlencode "fromStartTime=2026-01-01T00:00:00Z" \
  --data-urlencode "limit=100"

# Filter by trace ID with specific fields
curl -G https://cloud.langfuse.com/api/public/v2/observations \
  -u "pk-lf-...":"sk-lf-..." \
  --data-urlencode "traceId=trace-1" \
  --data-urlencode "fields=core,basic,usage"

# Continue pagination with cursor
curl -G https://cloud.langfuse.com/api/public/v2/observations \
  -u "pk-lf-...":"sk-lf-..." \
  --data-urlencode "cursor=eyJsYXN0..." \
  --data-urlencode "limit=100"
```

**Available field groups**: `core` (always included), `basic`, `io`, `metadata`, `model`, `usage`, `prompt`, `metrics`

### 3. Create/Update Scores

**Endpoint**: `POST /api/public/scores`

Add evaluation scores to traces or observations:

```bash
# Numeric score
curl -X POST https://cloud.langfuse.com/api/public/scores \
  -u "pk-lf-...":"sk-lf-..." \
  -H "Content-Type: application/json" \
  -d '{
    "traceId": "trace-1",
    "name": "correctness",
    "value": 0.9,
    "dataType": "NUMERIC",
    "comment": "Factually accurate response"
  }'

# Categorical score
curl -X POST https://cloud.langfuse.com/api/public/scores \
  -u "pk-lf-...":"sk-lf-..." \
  -H "Content-Type: application/json" \
  -d '{
    "traceId": "trace-1",
    "observationId": "gen-1",
    "name": "quality",
    "value": "excellent",
    "dataType": "CATEGORICAL"
  }'

# Boolean score (use 0 or 1)
curl -X POST https://cloud.langfuse.com/api/public/scores \
  -u "pk-lf-...":"sk-lf-..." \
  -H "Content-Type: application/json" \
  -d '{
    "traceId": "trace-1",
    "name": "helpful",
    "value": 1,
    "dataType": "BOOLEAN"
  }'
```

**Idempotent updates**: Include an `id` field to update existing scores.

### 4. Query Metrics (Analytics)

**Endpoint**: `GET /api/public/v2/metrics` (v2 recommended, Cloud-only)

Retrieve aggregated analytics with custom dimensions and filters:

```bash
curl -G https://cloud.langfuse.com/api/public/v2/metrics \
  -u "pk-lf-...":"sk-lf-..." \
  --data-urlencode 'query={
    "view": "observations",
    "metrics": [{"measure": "totalCost", "aggregation": "sum"}],
    "dimensions": [{"field": "providedModelName"}],
    "fromTimestamp": "2026-01-01T00:00:00Z",
    "toTimestamp": "2026-02-01T00:00:00Z",
    "orderBy": [{"field": "totalCost_sum", "direction": "desc"}]
  }'
```

**Available views**: `observations`, `scores-numeric`, `scores-categorical`

### 5. List Projects

**Endpoint**: `GET /api/public/projects`

Retrieve all projects accessible with your API keys:

```bash
curl https://cloud.langfuse.com/api/public/projects \
  -u "pk-lf-...":"sk-lf-..."
```

## Quick Reference

| Operation | Method | Endpoint | Use Case |
|-----------|--------|----------|----------|
| Create traces/spans | POST | `/api/public/ingestion` | Log LLM interactions |
| Query observations | GET | `/api/public/v2/observations` | Retrieve trace data |
| Add scores | POST | `/api/public/scores` | Evaluation metrics |
| Analytics | GET | `/api/public/v2/metrics` | Aggregated reporting |
| List projects | GET | `/api/public/projects` | Project discovery |

## Detailed Documentation

For comprehensive endpoint documentation including all parameters, filters, and response formats, see:

**[references/api-endpoints.md](references/api-endpoints.md)** - Complete API reference with examples

## External Resources

- [Langfuse API Reference](https://api.reference.langfuse.com/) - Interactive API explorer
- [Public API Documentation](https://langfuse.com/docs/api-and-data-platform/features/public-api) - Official guide
- [OpenAPI Specification](https://cloud.langfuse.com/generated/api/openapi.yml) - Machine-readable schema
