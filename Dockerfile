# Stage Build
FROM python:3.14.10-slim-trixie AS builder
WORKDIR /swarmlab
COPY --from=ghcr.io/astral-sh/uv:0.11.7 /uv /uvx /bin/
COPY uv.lock pyproject.toml .
ENV UV_NO_DEV=1
RUN uv sync --locked

# Stage of Runtime
FROM python:3.14.10-slim-trixie AS runtime
RUN useradd app
USER app
WORKDIR /swarmlab
COPY --from=builder /swarmlab/.venv /swarmlab/.venv
COPY app ./app
HEALTHCHECK --interval=30s --timeout=3s \
CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=2)" || exit 1
CMD ["/swarmlab/.venv/bin/uvicorn","app.main:app", "--host","0.0.0.0","--port", "8000"]
