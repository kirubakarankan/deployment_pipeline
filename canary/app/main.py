"""Demo service for canary deployments.

Exposes Prometheus metrics and can inject faults (errors / latency) through
environment variables, so a "bad" release can be simulated without building
a different image.
"""

import asyncio
import os
import random
import time

from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

APP_VERSION = os.getenv("APP_VERSION", "dev")
FAULT_ERROR_RATE = float(os.getenv("FAULT_ERROR_RATE", "0"))  # 0.0 - 1.0
FAULT_LATENCY_MS = int(os.getenv("FAULT_LATENCY_MS", "0"))

REQUESTS = Counter(
    "http_requests_total", "HTTP requests", ["method", "path", "status"]
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    ["path"],
    buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5),
)

# Probes and scrapes should not count as user traffic.
UNTRACKED_PATHS = {"/healthz", "/readyz", "/metrics"}

app = FastAPI(title="canary-app", version=APP_VERSION)


@app.middleware("http")
async def record_metrics(request: Request, call_next):
    path = request.url.path
    if path in UNTRACKED_PATHS:
        return await call_next(request)

    start = time.perf_counter()
    response = await call_next(request)
    LATENCY.labels(path).observe(time.perf_counter() - start)
    REQUESTS.labels(request.method, path, str(response.status_code)).inc()
    return response


@app.get("/")
async def root():
    if FAULT_LATENCY_MS:
        await asyncio.sleep(FAULT_LATENCY_MS / 1000)
    if random.random() < FAULT_ERROR_RATE:
        return JSONResponse({"error": "injected fault", "version": APP_VERSION}, status_code=500)
    return {"message": "hello", "version": APP_VERSION}


@app.get("/healthz")
async def healthz():
    return {"status": "ok"}


@app.get("/readyz")
async def readyz():
    return {"status": "ready"}


@app.get("/metrics")
async def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
