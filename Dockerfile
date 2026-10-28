FROM python:3.14.10-slim-trixie
RUN useradd app
COPY --from=ghcr.io/astral-sh/uv:0.11.7 /uv /uvx /bin/
WORKDIR /swarmlab
COPY uv.lock pyproject.toml .
# Disable development dependencies
ENV UV_NO_DEV=1
# Sync the project into a new environment, asserting the lockfile is up to date
RUN uv sync --locked
USER app
COPY app ./app
CMD ["/swarmlab/.venv/bin/uvicorn","app.main:app", "--host","0.0.0.0","--port", "8000"]
