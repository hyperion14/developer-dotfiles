FROM python:3.11-slim

WORKDIR /app

# System Dependencies für deutsche Legal-NLP
RUN apt-get update && \
    apt-get install -y \
        curl \
        wget \
        build-essential \
        git \
        poppler-utils \
        antiword \
        unrtf \
        locales \
        locales-all && \
    sed -i '/de_DE.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen && \
    rm -rf /var/lib/apt/lists/*

# Deutsche Locale
ENV LANG=de_DE.UTF-8
ENV LANGUAGE=de_DE:de
ENV LC_ALL=de_DE.UTF-8

# IONOS Performance Optimierung
ENV OMP_NUM_THREADS=8
ENV TOKENIZERS_PARALLELISM=true

# Python Dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Deutsche Sprachmodelle herunterladen
RUN python -m spacy download de_core_news_lg

# Flair German Legal NER Model wird beim ersten Start geladen
ENV TRANSFORMERS_CACHE=/app/data/models/transformers
ENV HF_HOME=/app/data/models/huggingface

# App Code
COPY . .

# Health Check
HEALTHCHECK --interval=30s --timeout=30s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
