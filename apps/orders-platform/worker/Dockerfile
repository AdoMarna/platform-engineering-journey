FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app

COPY requirements.txt .
# pip is only needed to install: removing it drops its vendored dependencies (and their CVEs).
RUN pip install --no-cache-dir -r requirements.txt \
 && pip uninstall -y pip

COPY worker.py .

RUN useradd --system --uid 10001 worker
USER 10001
CMD ["python", "worker.py"]
