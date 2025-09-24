# Wave AI - Production FastAPI Docker Image
FROM python:3.10-slim

# Create non-root user
RUN useradd -m waveuser
USER waveuser

WORKDIR /app

# Copy requirements and install
COPY --chown=waveuser:waveuser requirements.txt .
# Add local bin to PATH
ENV PATH="/home/waveuser/.local/bin:$PATH"
# Suppress pip warnings
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
RUN python -m pip install --upgrade pip --user --quiet \
    && pip install --user --no-cache-dir --quiet -r requirements.txt

# Copy app files
COPY --chown=waveuser:waveuser . .

# Environment variables
ENV PYTHONWARNINGS="ignore"
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Expose the port (Cloud Run uses $PORT env var, FastAPI default is 8000)
EXPOSE 8000

# Run Wave AI with FastAPI (production-ready)
CMD uvicorn main:app \
    --host=0.0.0.0 \
    --port=${PORT:-8000} \
    --workers=1 \
    --timeout-keep-alive=30 \
    --log-level=info