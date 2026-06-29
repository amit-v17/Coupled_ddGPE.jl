# Coupled ddGPE REST API Reference

## Overview

This REST API allows clients to launch coupled ddGPE simulations and poll for job completion.
Simulation execution is asynchronous: clients create a job, then poll status by job id.

Base URL (example):
- http://localhost:8000

OpenAPI and Swagger UI:
- OpenAPI JSON: /openapi.json
- Swagger UI: /docs
- ReDoc: /redoc

## Authentication

Protected endpoints require an API key passed in the request header:

- Header name: api-key
- Header value: one valid API key configured on the server

Auth flow:
1. Obtain an API key from the service owner.
2. Include api-key on each protected request.
3. Handle 401 Unauthorized responses when key is missing or invalid.

Example with curl:

curl -X POST "http://localhost:8000/run_simulation" \
  -H "Content-Type: application/json" \
  -H "api-key: YOUR_API_KEY" \
  -d '{}'

## Error Model

All API errors use a consistent shape:

- error_code: stable machine-readable code
- message: human-readable summary
- details: optional array of field-level items

Validation errors (422) use a custom shape, not the default FastAPI validation payload.

Example 422 response:

{
  "error_code": "VALIDATION_ERROR",
  "message": "Request validation failed",
  "details": [
    {
      "field": "body.hbar_Omega",
      "message": "Input should be greater than 0",
      "type": "greater_than"
    }
  ]
}

## Endpoints

### GET /

Purpose:
- Readiness check for API availability.

Auth:
- Not required.

Success response 200:

{
  "engine": "Julia",
  "ready": true
}

### POST /run_simulation

Purpose:
- Create a simulation job and run it in the background.

Auth:
- Required header: api-key

Request body:
- JSON object with simulation parameters.
- All fields have defaults; sending {} is valid.

Minimal request example:

{}

Success response 200:

{
  "job_id": 42,
  "status": "running",
  "message": "Simulation started. Check status with /simulation_status/{job_id}"
}

Error responses:
- 401 Unauthorized: missing or invalid api-key.
- 422 Validation Error: custom validation payload.
- 500 Internal Error: dependency or server failure.

### GET /simulation_status/{sim_id}

Purpose:
- Query a simulation job status and optional output points.

Auth:
- Not currently required.

Path parameters:
- sim_id (integer, >= 1): simulation id.

Query parameters:
- include_data_points (boolean, default false): include the full data_points array.

Success response 200 (running):

{
  "job_id": 42,
  "status": "running",
  "message": "Data points pending"
}

Success response 200 (completed with points):

{
  "job_id": 42,
  "status": "completed",
  "message": "Successfully finished the job",
  "data_points": [
    {
      "Energy": 1.0,
      "Transmission": 0.2
    }
  ]
}

Error responses:
- 404 Not Found: simulation id does not exist.
- 422 Validation Error: custom validation payload for invalid path/query values.
- 500 Internal Error: dependency or server failure.

## Rate Limits

No server-side rate limiting is currently enforced.

Client guidance:
- Apply exponential backoff when polling status.
- Avoid high-frequency polling bursts.

## Pagination

There is currently no pagination on returned data_points.

Behavior:
- include_data_points=false: response excludes data_points.
- include_data_points=true: response includes all data points in a single payload.

## Polling Recommendations

Suggested polling strategy after creating a job:
1. Start polling after 500 ms to 1 s.
2. Poll every 1 to 2 s with jitter.
3. Stop when status is completed or failed.
4. Use include_data_points=true on the final poll if you only need data once.

## Common Integration Pitfalls

- Missing api-key header on protected endpoints.
- Assuming default FastAPI 422 shape instead of custom error schema.
- Polling too aggressively without client-side backoff.
- Assuming pagination exists for data_points.
