# Langfuse API Endpoints - Complete Reference

Comprehensive documentation for all Langfuse API endpoints with parameters, filters, and examples.

## Table of Contents

1. [Ingestion API](#ingestion-api) - Create traces, spans, events
2. [Observations API (v2)](#observations-api-v2) - Query observation data
3. [Scores API](#scores-api) - Create and update scores
4. [Metrics API (v2)](#metrics-api-v2) - Aggregated analytics
5. [Projects API](#projects-api) - List projects

---

## Ingestion API

**Endpoint**: `POST /api/public/ingestion`
**Purpose**: Create traces, spans, generations, and events in batch format

### Important Note

⚠️ **OpenTelemetry (OTLP)** is replacing this endpoint. For new integrations, use the OTLP endpoint (`/api/public/otel/v1/traces`).

### Request Format

```bash
curl -X POST https://cloud.langfuse.com/api/public/ingestion \
  -u "pk-lf-...":"sk-lf-..." \
  -H "Content-Type: application/json" \
  -d '{
    "batch": [/* array of events */],
    "metadata": {}
  }'
```

### Event Types

#### Trace Creation

```json
{
  "id": "unique-event-id",
  "timestamp": "2026-02-14T10:00:00.000Z",
  "type": "trace-create",
  "body": {
    "id": "trace-id",
    "name": "trace-name",
    "userId": "user-123",
    "sessionId": "session-456",
    "input": {"key": "value"},
    "output": {"key": "value"},
    "metadata": {"env": "production"},
    "tags": ["tag1", "tag2"],
    "release": "v1.0.0",
    "version": "1.0"
  }
}
```

#### Span Creation

```json
{
  "id": "unique-event-id",
  "timestamp": "2026-02-14T10:00:01.000Z",
  "type": "span-create",
  "body": {
    "id": "span-id",
    "traceId": "trace-id",
    "name": "span-name",
    "startTime": "2026-02-14T10:00:01.000Z",
    "endTime": "2026-02-14T10:00:02.000Z",
    "metadata": {"step": "retrieval"},
    "input": {"query": "search term"},
    "output": {"results": ["doc1", "doc2"]},
    "level": "DEFAULT",
    "statusMessage": "success"
  }
}
```

#### Generation Creation

```json
{
  "id": "unique-event-id",
  "timestamp": "2026-02-14T10:00:03.000Z",
  "type": "generation-create",
  "body": {
    "id": "gen-id",
    "traceId": "trace-id",
    "name": "llm-call",
    "startTime": "2026-02-14T10:00:03.000Z",
    "endTime": "2026-02-14T10:00:05.000Z",
    "model": "gpt-4",
    "modelParameters": {
      "temperature": 0.7,
      "maxTokens": 500
    },
    "input": {"messages": [{"role": "user", "content": "Hello"}]},
    "output": {"choices": [{"message": {"role": "assistant", "content": "Hi!"}}]},
    "usage": {
      "promptTokens": 10,
      "completionTokens": 5,
      "totalTokens": 15
    },
    "metadata": {"provider": "openai"}
  }
}
```

#### Event Creation

```json
{
  "id": "unique-event-id",
  "timestamp": "2026-02-14T10:00:06.000Z",
  "type": "event-create",
  "body": {
    "id": "event-id",
    "traceId": "trace-id",
    "name": "user-feedback",
    "startTime": "2026-02-14T10:00:06.000Z",
    "metadata": {"rating": 5},
    "input": {"feedback": "Great response!"}
  }
}
```

### Batch Example

```bash
curl -X POST https://cloud.langfuse.com/api/public/ingestion \
  -u "pk-lf-...":"sk-lf-..." \
  -H "Content-Type: application/json" \
  -d '{
    "batch": [
      {
        "id": "evt-1",
        "timestamp": "2026-02-14T10:00:00.000Z",
        "type": "trace-create",
        "body": {
          "id": "trace-123",
          "name": "chat-interaction",
          "userId": "user-456"
        }
      },
      {
        "id": "evt-2",
        "timestamp": "2026-02-14T10:00:01.000Z",
        "type": "generation-create",
        "body": {
          "id": "gen-789",
          "traceId": "trace-123",
          "name": "llm-response",
          "model": "gpt-4",
          "usage": {
            "promptTokens": 50,
            "completionTokens": 100
          }
        }
      }
    ],
    "metadata": {}
  }'
```

---

## Observations API (v2)

**Endpoint**: `GET /api/public/v2/observations`
**Purpose**: Retrieve observation data (spans, generations, events) with optimized performance

### Key Features

- **Cursor-based pagination** - More efficient than offset pagination
- **Selective field retrieval** - Specify only needed data to reduce payload size
- **Optimized performance** - Built on new events table schema

### Query Parameters

| Parameter | Type | Description | Default | Max |
|-----------|------|-------------|---------|-----|
| `fields` | string | Comma-separated field groups | `core` | - |
| `limit` | integer | Results per page | 50 | 1000 |
| `cursor` | string | Pagination cursor from previous response | - | - |
| `fromStartTime` | datetime | Filter by start time (ISO 8601) | - | - |
| `toStartTime` | datetime | Filter by start time (ISO 8601) | - | - |
| `traceId` | string | Filter by trace ID | - | - |
| `name` | string | Filter by observation name | - | - |
| `type` | string | Filter by type: `SPAN`, `GENERATION`, `EVENT` | - | - |
| `userId` | string | Filter by user ID | - | - |
| `level` | string | Filter by level: `DEBUG`, `DEFAULT`, `WARNING`, `ERROR` | - | - |
| `environment` | string | Filter by environment | - | - |
| `parseIoAsJson` | boolean | Parse input/output as JSON | false | - |

### Field Groups

| Group | Fields Included |
|-------|-----------------|
| `core` | id, traceId, startTime, endTime, projectId, type (always included) |
| `basic` | name, level, statusMessage, version, environment, userId |
| `io` | input, output |
| `metadata` | metadata object |
| `model` | model name and parameters |
| `usage` | token usage and costs |
| `prompt` | prompt details |
| `metrics` | performance metrics |

### Examples

#### Basic Query

```bash
curl -G https://cloud.langfuse.com/api/public/v2/observations \
  -u "pk-lf-...":"sk-lf-..." \
  --data-urlencode "fromStartTime=2026-01-01T00:00:00Z" \
  --data-urlencode "toStartTime=2026-02-01T00:00:00Z" \
  --data-urlencode "limit=100"
```

#### Query with Specific Fields

```bash
curl -G https://cloud.langfuse.com/api/public/v2/observations \
  -u "pk-lf-...":"sk-lf-..." \
  --data-urlencode "fields=core,basic,usage,model" \
  --data-urlencode "type=GENERATION" \
  --data-urlencode "limit=50"
```

#### Filter by Trace

```bash
curl -G https://cloud.langfuse.com/api/public/v2/observations \
  -u "pk-lf-...":"sk-lf-..." \
  --data-urlencode "traceId=trace-123" \
  --data-urlencode "fields=core,io"
```

#### Pagination with Cursor

```bash
# First request
curl -G https://cloud.langfuse.com/api/public/v2/observations \
  -u "pk-lf-...":"sk-lf-..." \
  --data-urlencode "limit=100" \
  --data-urlencode "fromStartTime=2026-01-01T00:00:00Z"

# Response includes: { "data": [...], "meta": { "cursor": "eyJsYXN0..." } }

# Next request with cursor
curl -G https://cloud.langfuse.com/api/public/v2/observations \
  -u "pk-lf-...":"sk-lf-..." \
  --data-urlencode "cursor=eyJsYXN0..." \
  --data-urlencode "limit=100"
```

### Response Format

```json
{
  "data": [
    {
      "id": "obs-123",
      "traceId": "trace-456",
      "type": "GENERATION",
      "startTime": "2026-02-14T10:00:00.000Z",
      "endTime": "2026-02-14T10:00:05.000Z",
      "name": "llm-call",
      "model": "gpt-4",
      "usage": {
        "promptTokens": 50,
        "completionTokens": 100,
        "totalTokens": 150
      }
    }
  ],
  "meta": {
    "cursor": "eyJsYXN0..."  // Present if more results available
  }
}
```

---

## Scores API

**Endpoint**: `POST /api/public/scores`
**Purpose**: Create or update evaluation scores for traces or observations

### Score Data Types

- **NUMERIC** - Floating-point values (e.g., 0.0-1.0, 0-100)
- **CATEGORICAL** - String values (e.g., "excellent", "good", "poor")
- **BOOLEAN** - Binary values (use 0 or 1 as numeric)

### Request Body Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | No | Idempotency key - updates existing score if provided |
| `traceId` | string | Yes | Associated trace ID |
| `observationId` | string | No | Specific observation ID (if scoring a span/generation) |
| `name` | string | Yes | Score name (e.g., "correctness", "quality") |
| `value` | number/string | Yes | Score value (type depends on dataType) |
| `dataType` | string | Yes | `NUMERIC`, `CATEGORICAL`, or `BOOLEAN` |
| `comment` | string | No | Optional explanation or context |
| `configId` | string | No | Validate against predefined score configuration |

### Examples

#### Numeric Score

```bash
curl -X POST https://cloud.langfuse.com/api/public/scores \
  -u "pk-lf-...":"sk-lf-..." \
  -H "Content-Type: application/json" \
  -d '{
    "traceId": "trace-123",
    "name": "correctness",
    "value": 0.95,
    "dataType": "NUMERIC",
    "comment": "Factually accurate with good detail"
  }'
```

#### Categorical Score

```bash
curl -X POST https://cloud.langfuse.com/api/public/scores \
  -u "pk-lf-...":"sk-lf-..." \
  -H "Content-Type: application/json" \
  -d '{
    "traceId": "trace-123",
    "observationId": "gen-456",
    "name": "quality",
    "value": "excellent",
    "dataType": "CATEGORICAL",
    "comment": "Clear, concise, and helpful"
  }'
```

#### Boolean Score

```bash
curl -X POST https://cloud.langfuse.com/api/public/scores \
  -u "pk-lf-...":"sk-lf-..." \
  -H "Content-Type: application/json" \
  -d '{
    "traceId": "trace-123",
    "name": "factually_correct",
    "value": 1,
    "dataType": "BOOLEAN",
    "comment": "No factual errors detected"
  }'
```

#### Idempotent Update

```bash
curl -X POST https://cloud.langfuse.com/api/public/scores \
  -u "pk-lf-...":"sk-lf-..." \
  -H "Content-Type: application/json" \
  -d '{
    "id": "score-unique-id",
    "traceId": "trace-123",
    "name": "user_satisfaction",
    "value": 4.5,
    "dataType": "NUMERIC",
    "comment": "Updated after additional feedback"
  }'
```

#### With Config Validation

```bash
curl -X POST https://cloud.langfuse.com/api/public/scores \
  -u "pk-lf-...":"sk-lf-..." \
  -H "Content-Type: application/json" \
  -d '{
    "id": "score-789",
    "traceId": "trace-123",
    "name": "quality_score",
    "value": 0.9,
    "dataType": "NUMERIC",
    "configId": "config-abc-123",
    "comment": "Validated against quality rubric"
  }'
```

---

## Metrics API (v2)

**Endpoint**: `GET /api/public/v2/metrics`
**Purpose**: Query aggregated analytics with custom dimensions, metrics, and filters
**Availability**: Cloud-only (not available for self-hosted)

### Query Structure

The query parameter is a URL-encoded JSON object with these fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `view` | string | Yes | Data view: `observations`, `scores-numeric`, `scores-categorical` |
| `metrics` | array | Yes | Metrics to aggregate (see below) |
| `dimensions` | array | No | Fields to group by |
| `filters` | array | No | Conditions to filter data |
| `timeDimension` | object | No | Time-based grouping |
| `fromTimestamp` | datetime | Yes | Start time (ISO 8601) |
| `toTimestamp` | datetime | Yes | End time (ISO 8601) |
| `orderBy` | array | No | Sort results |

### Available Views

#### Observations View

Query observation-level data with optional trace aggregations.

**Common metrics**:
- `totalCost` (sum, avg)
- `inputCost` (sum, avg)
- `outputCost` (sum, avg)
- `totalTokens` (sum, avg)
- `inputTokens` (sum, avg)
- `outputTokens` (sum, avg)
- `latency` (avg, p50, p90, p95, p99)
- `observationCount` (count)

**Common dimensions**:
- `providedModelName`
- `traceName`
- `name` (observation name)
- `type` (SPAN, GENERATION, EVENT)
- `userId`
- `environment`
- `level`

#### Scores Views

**scores-numeric**: Numeric and boolean scores
**scores-categorical**: Categorical string scores

### Metric Format

```json
{
  "measure": "totalCost",
  "aggregation": "sum"
}
```

**Aggregations**: `sum`, `avg`, `count`, `min`, `max`, `p50`, `p90`, `p95`, `p99`

### Dimension Format

```json
{
  "field": "providedModelName"
}
```

### Filter Format

```json
{
  "field": "environment",
  "operator": "equals",
  "value": "production"
}
```

**Operators**: `equals`, `notEquals`, `contains`, `notContains`, `greaterThan`, `lessThan`, `in`, `notIn`

### Examples

#### Total Cost by Model

```bash
curl -G https://cloud.langfuse.com/api/public/v2/metrics \
  -u "pk-lf-...":"sk-lf-..." \
  --data-urlencode 'query={
    "view": "observations",
    "metrics": [
      {"measure": "totalCost", "aggregation": "sum"}
    ],
    "dimensions": [
      {"field": "providedModelName"}
    ],
    "fromTimestamp": "2026-01-01T00:00:00Z",
    "toTimestamp": "2026-02-01T00:00:00Z",
    "orderBy": [
      {"field": "totalCost_sum", "direction": "desc"}
    ]
  }'
```

#### Average Latency by Trace Name

```bash
curl -G https://cloud.langfuse.com/api/public/v2/metrics \
  -u "pk-lf-...":"sk-lf-..." \
  --data-urlencode 'query={
    "view": "observations",
    "metrics": [
      {"measure": "latency", "aggregation": "avg"},
      {"measure": "latency", "aggregation": "p95"}
    ],
    "dimensions": [
      {"field": "traceName"}
    ],
    "filters": [
      {
        "field": "type",
        "operator": "equals",
        "value": "GENERATION"
      }
    ],
    "fromTimestamp": "2026-02-01T00:00:00Z",
    "toTimestamp": "2026-02-14T23:59:59Z"
  }'
```

#### Token Usage Over Time

```bash
curl -G https://cloud.langfuse.com/api/public/v2/metrics \
  -u "pk-lf-...":"sk-lf-..." \
  --data-urlencode 'query={
    "view": "observations",
    "metrics": [
      {"measure": "totalTokens", "aggregation": "sum"},
      {"measure": "observationCount", "aggregation": "count"}
    ],
    "timeDimension": {
      "field": "startTime",
      "granularity": "day"
    },
    "fromTimestamp": "2026-01-01T00:00:00Z",
    "toTimestamp": "2026-01-31T23:59:59Z"
  }'
```

#### Production Environment Costs

```bash
curl -G https://cloud.langfuse.com/api/public/v2/metrics \
  -u "pk-lf-...":"sk-lf-..." \
  --data-urlencode 'query={
    "view": "observations",
    "metrics": [
      {"measure": "totalCost", "aggregation": "sum"},
      {"measure": "totalTokens", "aggregation": "sum"}
    ],
    "dimensions": [
      {"field": "providedModelName"},
      {"field": "traceName"}
    ],
    "filters": [
      {
        "field": "environment",
        "operator": "equals",
        "value": "production"
      }
    ],
    "fromTimestamp": "2026-02-01T00:00:00Z",
    "toTimestamp": "2026-02-14T23:59:59Z",
    "orderBy": [
      {"field": "totalCost_sum", "direction": "desc"}
    ]
  }'
```

### Response Format

```json
{
  "data": [
    {
      "providedModelName": "gpt-4",
      "totalCost_sum": 125.50,
      "totalTokens_sum": 250000
    },
    {
      "providedModelName": "gpt-3.5-turbo",
      "totalCost_sum": 45.20,
      "totalTokens_sum": 500000
    }
  ],
  "meta": {
    "total": 2
  }
}
```

---

## Projects API

**Endpoint**: `GET /api/public/projects`
**Purpose**: List all projects accessible with your API keys

### Example

```bash
curl https://cloud.langfuse.com/api/public/projects \
  -u "pk-lf-...":"sk-lf-..."
```

### Response Format

```json
{
  "data": [
    {
      "id": "project-123",
      "name": "Production",
      "createdAt": "2025-01-15T10:00:00.000Z",
      "updatedAt": "2026-02-10T15:30:00.000Z"
    },
    {
      "id": "project-456",
      "name": "Staging",
      "createdAt": "2025-01-20T12:00:00.000Z",
      "updatedAt": "2026-02-12T09:15:00.000Z"
    }
  ]
}
```

---

## Common Patterns

### Error Handling

All API endpoints return standard HTTP status codes:

- **200** - Success
- **400** - Bad request (invalid parameters)
- **401** - Unauthorized (invalid credentials)
- **403** - Forbidden (insufficient permissions)
- **404** - Not found
- **429** - Rate limit exceeded
- **500** - Internal server error

```bash
# Check HTTP status code
curl -w "\nHTTP Status: %{http_code}\n" \
  -u "pk-lf-...":"sk-lf-..." \
  https://cloud.langfuse.com/api/public/projects
```

### Rate Limiting

Langfuse enforces rate limits on API endpoints. If you exceed the limit:

1. The API returns HTTP 429
2. Response includes `Retry-After` header
3. Implement exponential backoff

```bash
# Example with retry logic (pseudo-code)
for i in {1..5}; do
  response=$(curl -w "%{http_code}" -u "pk-lf-...":"sk-lf-..." \
    https://cloud.langfuse.com/api/public/observations)

  if [ "$response" == "429" ]; then
    sleep $((2**i))  # Exponential backoff
  else
    break
  fi
done
```

### Timestamps

All timestamps must be in ISO 8601 format with UTC timezone:

```bash
# Current timestamp in correct format
date -u +"%Y-%m-%dT%H:%M:%S.000Z"
# Output: 2026-02-14T10:30:45.000Z

# Use in curl
curl -X POST https://cloud.langfuse.com/api/public/ingestion \
  -u "pk-lf-...":"sk-lf-..." \
  -H "Content-Type: application/json" \
  -d '{
    "batch": [{
      "id": "evt-1",
      "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'",
      "type": "trace-create",
      "body": {"id": "trace-1", "name": "test"}
    }]
  }'
```

### URL Encoding for Query Parameters

When passing complex query objects (especially for Metrics API), use `--data-urlencode`:

```bash
# Correct - URL encodes the JSON query
curl -G https://cloud.langfuse.com/api/public/v2/metrics \
  -u "pk-lf-...":"sk-lf-..." \
  --data-urlencode 'query={"view":"observations",...}'

# Incorrect - May break on special characters
curl "https://cloud.langfuse.com/api/public/v2/metrics?query={...}"
```

---

## Additional Resources

- **Interactive API Reference**: https://api.reference.langfuse.com/
- **OpenAPI Specification**: https://cloud.langfuse.com/generated/api/openapi.yml
- **Postman Collection**: Available via Langfuse dashboard
- **Official Documentation**: https://langfuse.com/docs/api-and-data-platform/overview
