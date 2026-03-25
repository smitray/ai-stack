FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY src/ /app/src/

# We will mount config/models.yaml at runtime
ENV PORT=7864
EXPOSE 7864

CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "7864", "--workers", "1"]
