# =============================================================================
# Multi-stage build for the health-check service.
# Build args let the pipeline stamp in version/commit metadata without
# baking secrets or environment-specific values into the image.
# =============================================================================
FROM python:3.12-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.12-slim

ARG BUILD_VERSION=dev
ARG GIT_COMMIT=unknown

ENV BUILD_VERSION=${BUILD_VERSION} \
    GIT_COMMIT=${GIT_COMMIT} \
    PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1

# Run as a non-root user
RUN useradd --create-home --shell /bin/bash appuser
WORKDIR /app

COPY --from=builder /root/.local /home/appuser/.local
COPY app.py .

RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz').read()" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--access-logfile", "-", "app:app"]
