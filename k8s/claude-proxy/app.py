"""
Robo Stack — Claude API Proxy
Lightweight proxy for Claude API with rate limiting, logging, and health checks.
Deployed on K3s as part of Sprint 2 (S2.3).
"""

import os
import time
import json
import logging
from datetime import datetime
from collections import defaultdict
from functools import wraps

from fastapi import FastAPI, Request, Response, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import httpx

# ── Configuration ──────────────────────────────────────────────────────────

ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "")
ANTHROPIC_API_URL = os.environ.get("ANTHROPIC_API_URL", "https://api.anthropic.com")
RATE_LIMIT_RPM = int(os.environ.get("RATE_LIMIT_RPM", "10"))
MAX_RETRIES = int(os.environ.get("MAX_RETRIES", "3"))
PROXY_VERSION = "0.1.0"

# ── Logging ────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%dT%H:%M:%S'
)
logger = logging.getLogger("claude-proxy")

# ── Rate Limiter ───────────────────────────────────────────────────────────

class RateLimiter:
    """Simple sliding window rate limiter."""

    def __init__(self, max_requests: int = 10, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window = window_seconds
        self.requests: dict[str, list[float]] = defaultdict(list)

    def is_allowed(self, client_id: str = "default") -> bool:
        now = time.time()
        window_start = now - self.window
        # Clean old entries
        self.requests[client_id] = [
            t for t in self.requests[client_id] if t > window_start
        ]
        if len(self.requests[client_id]) >= self.max_requests:
            return False
        self.requests[client_id].append(now)
        return True

    def remaining(self, client_id: str = "default") -> int:
        now = time.time()
        window_start = now - self.window
        active = [t for t in self.requests[client_id] if t > window_start]
        return max(0, self.max_requests - len(active))


rate_limiter = RateLimiter(max_requests=RATE_LIMIT_RPM, window_seconds=60)

# ── App ────────────────────────────────────────────────────────────────────

app = FastAPI(
    title="Robo Stack Claude Proxy",
    version=PROXY_VERSION,
    description="Lightweight Claude API proxy with rate limiting and logging"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Request/Response Models ────────────────────────────────────────────────

class MessageRequest(BaseModel):
    model: str = Field(default="claude-sonnet-4-20250514", description="Claude model to use")
    max_tokens: int = Field(default=1024, ge=1, le=128000)
    messages: list[dict] = Field(..., description="Message history")
    system: str | None = Field(default=None, description="System prompt")
    temperature: float | None = Field(default=None, ge=0, le=1)
    stream: bool = Field(default=False)


class HealthResponse(BaseModel):
    status: str
    version: str
    timestamp: str
    rate_limit_remaining: int
    api_configured: bool


# ── Metrics ────────────────────────────────────────────────────────────────

metrics = {
    "total_requests": 0,
    "successful_requests": 0,
    "failed_requests": 0,
    "rate_limited_requests": 0,
    "total_input_tokens": 0,
    "total_output_tokens": 0,
    "start_time": datetime.utcnow().isoformat(),
}

# ── Endpoints ──────────────────────────────────────────────────────────────

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint for K8s liveness/readiness probes."""
    return HealthResponse(
        status="healthy",
        version=PROXY_VERSION,
        timestamp=datetime.utcnow().isoformat(),
        rate_limit_remaining=rate_limiter.remaining(),
        api_configured=bool(ANTHROPIC_API_KEY),
    )


@app.get("/metrics")
async def get_metrics():
    """Return proxy usage metrics."""
    return {**metrics, "uptime_since": metrics["start_time"]}


@app.post("/v1/messages")
async def proxy_messages(request: MessageRequest, raw_request: Request):
    """
    Proxy requests to the Claude API with rate limiting and retries.
    """
    metrics["total_requests"] += 1

    # Rate limit check
    client_ip = raw_request.client.host if raw_request.client else "unknown"
    if not rate_limiter.is_allowed(client_ip):
        metrics["rate_limited_requests"] += 1
        logger.warning(f"Rate limited: {client_ip}")
        raise HTTPException(
            status_code=429,
            detail=f"Rate limit exceeded. Max {RATE_LIMIT_RPM} requests per minute."
        )

    if not ANTHROPIC_API_KEY:
        raise HTTPException(status_code=503, detail="ANTHROPIC_API_KEY not configured")

    # Build request payload
    payload = {
        "model": request.model,
        "max_tokens": request.max_tokens,
        "messages": request.messages,
    }
    if request.system:
        payload["system"] = request.system
    if request.temperature is not None:
        payload["temperature"] = request.temperature

    headers = {
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    }

    # Retry with exponential backoff
    last_error = None
    for attempt in range(MAX_RETRIES):
        try:
            logger.info(
                f"Request: model={request.model} messages={len(request.messages)} "
                f"max_tokens={request.max_tokens} attempt={attempt + 1}"
            )

            async with httpx.AsyncClient(timeout=120.0) as client:
                response = await client.post(
                    f"{ANTHROPIC_API_URL}/v1/messages",
                    json=payload,
                    headers=headers,
                )

            if response.status_code == 200:
                data = response.json()
                # Track token usage
                usage = data.get("usage", {})
                metrics["total_input_tokens"] += usage.get("input_tokens", 0)
                metrics["total_output_tokens"] += usage.get("output_tokens", 0)
                metrics["successful_requests"] += 1

                logger.info(
                    f"Response: status=200 input_tokens={usage.get('input_tokens', 0)} "
                    f"output_tokens={usage.get('output_tokens', 0)}"
                )
                return data

            elif response.status_code == 429:
                # Rate limited by Anthropic — wait and retry
                wait_time = (2 ** attempt) * 1
                logger.warning(f"Anthropic rate limit, retrying in {wait_time}s")
                time.sleep(wait_time)
                last_error = f"Anthropic rate limit (429)"
                continue

            elif response.status_code >= 500:
                # Server error — retry
                wait_time = (2 ** attempt) * 1
                logger.warning(f"Anthropic server error {response.status_code}, retrying in {wait_time}s")
                time.sleep(wait_time)
                last_error = f"Anthropic server error ({response.status_code})"
                continue

            else:
                # Client error — don't retry
                metrics["failed_requests"] += 1
                error_body = response.text
                logger.error(f"Anthropic API error: {response.status_code} - {error_body}")
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"Claude API error: {error_body}"
                )

        except httpx.TimeoutException:
            wait_time = (2 ** attempt) * 2
            logger.warning(f"Request timeout, retrying in {wait_time}s")
            time.sleep(wait_time)
            last_error = "Request timeout"
            continue

        except HTTPException:
            raise

        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            last_error = str(e)
            break

    # All retries exhausted
    metrics["failed_requests"] += 1
    logger.error(f"All retries exhausted: {last_error}")
    raise HTTPException(status_code=502, detail=f"Claude API unavailable after {MAX_RETRIES} retries: {last_error}")


# ── Main ───────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port)
