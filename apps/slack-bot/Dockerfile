# syntax=docker/dockerfile:1.7

# Stage 1: build the venv 
    FROM python:3.12-slim AS builder

    COPY --from=ghcr.io/astral-sh/uv:0.4.18 /uv /usr/local/bin/uv
    
    WORKDIR /app
    
    COPY pyproject.toml uv.lock ./
    
    ENV UV_LINK_MODE=copy \
        UV_PROJECT_ENVIRONMENT=/app/.venv
    
    RUN --mount=type=cache,target=/root/.cache/uv \
        uv sync --frozen --no-install-project --no-dev
    
    COPY src/ ./src/
    RUN --mount=type=cache,target=/root/.cache/uv \
        uv sync --frozen --no-dev
    
    
    # Stage 2: minimal runtime
    FROM python:3.12-slim AS runtime
    
    RUN apt-get update \
     && apt-get install -y --no-install-recommends tini \
     && apt-get clean \
     && rm -rf /var/lib/apt/lists/*
    
    RUN groupadd --system --gid 10001 app \
     && useradd  --system --uid 10001 --gid app --no-create-home --home /app app
    
    WORKDIR /app
    
    COPY --from=builder --chown=app:app /app/.venv /app/.venv
    COPY --from=builder --chown=app:app /app/src   /app/src
    
    ENV PATH=/app/.venv/bin:$PATH \
        PYTHONUNBUFFERED=1 \
        PYTHONDONTWRITEBYTECODE=1
    
    USER app
    
    ENTRYPOINT ["/usr/bin/tini", "--"]
    CMD ["slack-bot"]