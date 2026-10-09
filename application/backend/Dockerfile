FROM python:3.12-slim

LABEL org.opencontainers.image.title="shopflow-api" \
      org.opencontainers.image.version="1.0.0"

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Non-root user created first so later COPYs can set ownership directly
RUN useradd --create-home --uid 1000 appuser \
    && chown appuser:appuser /app

# Install deps first so this layer is cached across code-only changes
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=appuser:appuser app.py entrypoint.sh ./
RUN chmod +x entrypoint.sh

USER appuser
EXPOSE 5000

# No curl in the image (keeps it small) - use Python's stdlib instead
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health', timeout=3)" || exit 1

ENTRYPOINT ["./entrypoint.sh"]
