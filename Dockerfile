FROM python:3.11-slim
RUN apt-get update && apt-get install -y curl
RUN curl -fsSL https://install.julialang.org | sh -s -- -y --default-channel=1.11.5
ENV PATH="/root/.juliaup/bin:$PATH"
COPY api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["gunicorn", "api.app:app", "--workers", "4", "--worker-class", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8000"]