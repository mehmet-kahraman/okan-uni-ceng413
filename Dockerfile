# VERSION 2 - the improved Dockerfile (quality checklist applied).
# 1. Pinned, small base image          -> reproducible, smaller, fewer CVEs
# 2. Dependencies before code          -> build cache works
# 3. Non-root user                     -> limits damage if compromised
# 4. Data directory owned by that user -> the volume in the lab is writable
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Create an unprivileged user and a data folder it may write to.
RUN useradd --create-home --uid 10001 appuser \
    && mkdir -p /data \
    && chown appuser:appuser /data
USER appuser

ENV DATA_DIR=/data
EXPOSE 8000
CMD ["gunicorn", "-b", "0.0.0.0:8000", "app:app"]
