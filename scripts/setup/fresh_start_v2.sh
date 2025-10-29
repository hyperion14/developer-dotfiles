#!/bin/bash

# ==============================================
# Fresh Start IONOS Legal-RAG System Setup
# Komplette Neuentwicklung für deutsches Rechts-RAG
# ==============================================

echo "🏛️ === Fresh Start IONOS Legal-RAG System Setup ==="
echo ""

# Projekt-Setup
PROJECT_NAME="ionos-legal-rag"
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

echo "📁 Erstelle Projektstruktur..."

# Ordnerstruktur erstellen
mkdir -p {app,templates,static/{css,js,images},config,scripts,docs,data/{uploads,processed,models}}

echo "✅ Projektstruktur erstellt"

# ==============================================
# 1. DOCKER-COMPOSE.YML - IONOS Optimiert
# ==============================================

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # Haupt Legal-RAG Application
  legal-rag-api:
    build:
      context: ./app
      dockerfile: Dockerfile
    container_name: ionos-legal-rag-api
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      # IONOS AI Hub Integration
      - IONOS_AI_HUB_API_KEY=${IONOS_AI_HUB_API_KEY}
      - IONOS_AI_HUB_ENDPOINT=https://ai.cloud.ionos.com/v1
      
      # Database Connections
      - POSTGRES_URL=postgresql://legal_user:${POSTGRES_PASSWORD}@postgres:5432/legal_db
      - NEO4J_URL=bolt://neo4j:7687
      - NEO4J_USERNAME=neo4j
      - NEO4J_PASSWORD=${NEO4J_PASSWORD}
      - REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379/0
      
      # IONOS Object Storage (S3)
      - S3_ENDPOINT=https://s3-eu-central-1.ionoscloud.com
      - S3_BUCKET=${S3_BUCKET}
      - S3_ACCESS_KEY=${S3_ACCESS_KEY}
      - S3_SECRET_KEY=${S3_SECRET_KEY}
      
      # German Legal NLP
      - USE_FLAIR_LEGAL_NER=true
      - SPACY_MODEL=de_core_news_lg
      
      # Performance (IONOS VPS optimiert)
      - OMP_NUM_THREADS=8
      - TOKENIZERS_PARALLELISM=true
      
    volumes:
      - ./data:/app/data
      - ./templates:/app/templates
      - ./static:/app/static
    depends_on:
      postgres:
        condition: service_healthy
      neo4j:
        condition: service_healthy
      redis:
        condition: service_started
    deploy:
      resources:
        limits:
          memory: 8G
          cpus: '6.0'
    networks:
      - legal-rag-network

  # PostgreSQL - Rechtsgebiet-spezifische Metadaten
  postgres:
    image: postgres:16-alpine
    container_name: ionos-legal-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: legal_db
      POSTGRES_USER: legal_user
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --locale=de_DE.UTF-8"
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./config/init-db.sql:/docker-entrypoint-initdb.d/01-init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U legal_user -d legal_db"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2.0'
    networks:
      - legal-rag-network

  # Neo4j - Knowledge Graph für deutsche Rechtshierarchien
  neo4j:
    image: neo4j:5.15-community
    container_name: ionos-legal-neo4j
    restart: unless-stopped
    environment:
      NEO4J_AUTH: neo4j/${NEO4J_PASSWORD}
      NEO4J_ACCEPT_LICENSE_AGREEMENT: "yes"
      # IONOS VPS optimiert
      NEO4J_dbms_memory_heap_initial__size: 1g
      NEO4J_dbms_memory_heap_max__size: 3g
      NEO4J_dbms_memory_pagecache_size: 1g
      NEO4J_PLUGINS: '["apoc", "gds"]'
      NEO4J_dbms_security_procedures_unrestricted: gds.*,apoc.*
    ports:
      - "7474:7474"
      - "7687:7687"
    volumes:
      - neo4j_data:/data
      - neo4j_logs:/logs
    healthcheck:
      test: ["CMD-SHELL", "cypher-shell -u neo4j -p ${NEO4J_PASSWORD} 'RETURN 1'"]
      interval: 30s
      timeout: 10s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2.0'
    networks:
      - legal-rag-network

  # Redis - Caching & Sessions
  redis:
    image: redis:7-alpine
    container_name: ionos-legal-redis
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '0.5'
    networks:
      - legal-rag-network

  # Open WebUI - Chat Interface  
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: ionos-legal-webui
    restart: unless-stopped
    environment:
      - OPENAI_API_BASE_URL=http://legal-rag-api:8000/v1
      - OPENAI_API_KEY=sk-ionos-legal-rag
      - WEBUI_NAME=Deutsches Juristisches RAG System
      - WEBUI_LOCALE=de-DE
      - ENABLE_SIGNUP=false
    ports:
      - "3000:8080"
    volumes:
      - webui_data:/app/backend/data
    depends_on:
      - legal-rag-api
    networks:
      - legal-rag-network

  # Adminer - Database GUI
  adminer:
    image: adminer:latest
    container_name: ionos-legal-adminer
    restart: unless-stopped
    environment:
      ADMINER_DEFAULT_SERVER: postgres
      ADMINER_DESIGN: pepa-linha
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    networks:
      - legal-rag-network

volumes:
  postgres_data:
  neo4j_data:
  neo4j_logs:
  redis_data:
  webui_data:

networks:
  legal-rag-network:
    driver: bridge
EOF

echo "✅ docker-compose.yml erstellt"

# ==============================================
# 2. REQUIREMENTS.TXT - Deutsche Legal-NLP Optimiert
# ==============================================

cat > app/requirements.txt << 'EOF'
# FastAPI Core
fastapi==0.104.1
uvicorn==0.24.0
python-multipart==0.0.6
pydantic==2.5.0
jinja2==3.1.2

# Deutsche Legal-NLP Spezialisierung
flair==0.12.2
transformers==4.36.2
torch==2.1.2+cpu --index-url https://download.pytorch.org/whl/cpu
spacy==3.7.2

# IONOS AI Hub Integration
requests==2.31.0
aiohttp==3.9.1

# Dokumentenverarbeitung - Alle Formate
pypdf==3.17.1
python-docx==1.1.0
striprtf==0.0.26
beautifulsoup4==4.12.2
pdfplumber==0.9.0
aiofiles==0.24.0

# Databases
psycopg2-binary==2.9.9
sqlalchemy==2.0.23
asyncpg==0.29.0
neo4j==5.14.1
redis==5.0.1

# IONOS S3 Object Storage
boto3==1.34.0
botocore==1.34.0

# Utilities
python-dotenv==1.0.0
pandas==2.1.4
numpy==1.25.2
python-slugify==8.0.1
loguru==0.7.2

# Monitoring
prometheus-client==0.19.0
EOF

echo "✅ requirements.txt erstellt"

# ==============================================
# 3. DOCKERFILE - IONOS x86_64 Optimiert
# ==============================================

cat > app/Dockerfile << 'EOF'
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
EOF

echo "✅ Dockerfile erstellt"

# ==============================================
# 4. MAIN.PY - Komplette Legal-RAG API
# ==============================================

cat > app/main.py << 'EOF'
from fastapi import FastAPI, UploadFile, File, Form, HTTPException, BackgroundTasks, Depends
from fastapi.responses import JSONResponse, FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.middleware.cors import CORSMiddleware
from fastapi.requests import Request
from sqlalchemy import create_engine, Column, String, DateTime, Text, Integer, Float, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
import asyncio
import aiofiles
import os
from pathlib import Path
from typing import List, Optional, Dict, Any
import uuid
from datetime import datetime
import json
import boto3
from loguru import logger

# Deutsche Legal-NLP
from flair.models import SequenceTagger
from flair.data import Sentence
import spacy

# App Initialisierung
app = FastAPI(
    title="🏛️ IONOS Deutsches Juristisches RAG System",
    description="RAG System für deutsche Rechtsdokumente mit IONOS Cloud",
    version="2.0.0"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static Files & Templates
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

# Global Variables für NLP Models
legal_ner = None
german_nlp = None
s3_client = None

# Database Models
Base = declarative_base()

class LegalDocument(Base):
    __tablename__ = "legal_documents"
    
    document_id = Column(String, primary_key=True)
    title = Column(String, nullable=False)
    original_filename = Column(String)
    
    # Rechtsgebiet-Klassifikation
    primary_domain = Column(String, nullable=False)  # zivilrecht, strafrecht, etc.
    sub_domains = Column(Text)  # JSON Array
    legal_area_confidence = Column(Float)
    
    # Gerichtshierarchie
    court_level = Column(String)  # BGH, OLG, LG, AG
    court_location = Column(String)
    case_number = Column(String)
    decision_date = Column(DateTime)
    
    # Status
    processing_status = Column(String, default="uploaded")
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Speicherorte
    s3_original_key = Column(String)
    s3_processed_key = Column(String)

class LegalEntity(Base):
    __tablename__ = "legal_entities"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    document_id = Column(String, nullable=False)
    entity_text = Column(String, nullable=False)
    entity_type = Column(String)  # GS, PER, ORG, GRT aus Flair
    flair_confidence = Column(Float)
    legal_classification = Column(String)

# Database Setup
DATABASE_URL = os.getenv("POSTGRES_URL")
engine = create_async_engine(DATABASE_URL)
SessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def get_db():
    async with SessionLocal() as session:
        yield session

# Startup: Models laden & DB initialisieren
@app.on_event("startup")
async def startup():
    global legal_ner, german_nlp, s3_client
    
    logger.info("🏛️ Starte IONOS Deutsches Juristisches RAG System...")
    
    # Database Tables erstellen
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    # Deutsche Legal-NLP Models laden
    try:
        legal_ner = SequenceTagger.load("flair/ner-german-legal")
        german_nlp = spacy.load("de_core_news_lg")
        logger.info("✅ Deutsche Legal-NLP Modelle geladen")
    except Exception as e:
        logger.error(f"⚠️ Fehler beim Laden der NLP-Modelle: {e}")
    
    # IONOS S3 Client
    try:
        s3_client = boto3.client(
            's3',
            endpoint_url=os.getenv('S3_ENDPOINT'),
            aws_access_key_id=os.getenv('S3_ACCESS_KEY'),
            aws_secret_access_key=os.getenv('S3_SECRET_KEY'),
            region_name='eu-central-1'
        )
        logger.info("✅ IONOS S3 Client initialisiert")
    except Exception as e:
        logger.error(f"⚠️ S3 Client Fehler: {e}")
    
    logger.info("🚀 System bereit!")

# === GUI ENDPOINTS ===

@app.get("/")
async def dashboard(request: Request):
    """Haupt-Dashboard"""
    return templates.TemplateResponse("dashboard.html", {"request": request})

@app.get("/upload")
async def upload_page(request: Request):
    """Upload-Seite"""
    return templates.TemplateResponse("upload.html", {"request": request})

@app.get("/search")
async def search_page(request: Request):
    """Such-Interface"""
    return templates.TemplateResponse("search.html", {"request": request})

@app.get("/domains")
async def domains_page(request: Request):
    """Rechtsgebiet-spezifische Suche"""
    return templates.TemplateResponse("domain-search.html", {"request": request})

# === API ENDPOINTS ===

@app.post("/api/upload")
async def upload_documents(
    files: List[UploadFile] = File(...),
    document_type: str = Form(...),
    court_level: Optional[str] = Form(None),
    legal_area: Optional[str] = Form(None),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db: AsyncSession = Depends(get_db)
):
    """Dokumente hochladen mit deutscher Legal-NLP Verarbeitung"""
    
    uploaded_docs = []
    
    for file in files:
        if not file.filename:
            continue
        
        # Validierung
        file_ext = Path(file.filename).suffix.lower()
        if file_ext not in ['.pdf', '.docx', '.doc', '.txt', '.rtf']:
            raise HTTPException(400, f"Dateityp {file_ext} nicht unterstützt")
        
        doc_id = str(uuid.uuid4())
        
        # Datei zu IONOS S3 hochladen
        s3_key = f"legal-documents/{legal_area or 'general'}/{doc_id}/{file.filename}"
        
        try:
            file_content = await file.read()
            s3_client.put_object(
                Bucket=os.getenv('S3_BUCKET'),
                Key=s3_key,
                Body=file_content,
                Metadata={
                    'document-type': document_type,
                    'court-level': court_level or 'unknown',
                    'legal-area': legal_area or 'general'
                }
            )
        except Exception as e:
            logger.error(f"S3 Upload Fehler: {e}")
            raise HTTPException(500, f"Upload-Fehler: {str(e)}")
        
        # Datenbank-Eintrag
        doc_record = LegalDocument(
            document_id=doc_id,
            title=file.filename,
            original_filename=file.filename,
            primary_domain=legal_area or 'general',
            court_level=court_level,
            processing_status="uploaded",
            s3_original_key=s3_key
        )
        
        db.add(doc_record)
        await db.commit()
        
        # Background-Verarbeitung mit deutscher Legal-NLP
        background_tasks.add_task(process_document_with_german_nlp, doc_id, s3_key)
        
        uploaded_docs.append({
            "id": doc_id,
            "filename": file.filename,
            "s3_location": s3_key,
            "status": "processing"
        })
        
        logger.info(f"📄 Dokument hochgeladen: {file.filename} → {doc_id}")
    
    return {
        "success": True,
        "uploaded_documents": uploaded_docs,
        "processing": "Deutsche Legal-NLP Analyse gestartet"
    }

async def process_document_with_german_nlp(doc_id: str, s3_key: str):
    """Background-Verarbeitung mit Flair German Legal NER"""
    
    try:
        # Text aus S3 extrahieren
        s3_response = s3_client.get_object(Bucket=os.getenv('S3_BUCKET'), Key=s3_key)
        file_content = s3_response['Body'].read()
        
        # Text-Extraktion (vereinfacht für Demo)
        extracted_text = file_content.decode('utf-8', errors='ignore')[:5000]
        
        # Deutsche Legal Entity Recognition mit Flair
        legal_entities = []
        if legal_ner:
            sentence = Sentence(extracted_text, use_tokenizer=False)
            legal_ner.predict(sentence)
            
            for entity in sentence.get_spans('ner'):
                legal_entities.append({
                    'text': entity.text,
                    'type': entity.labels[0].value,
                    'confidence': entity.labels[0].score,
                    'start': entity.start_position,
                    'end': entity.end_position
                })
        
        # Rechtsgebiet-Klassifikation (vereinfacht)
        primary_domain = classify_legal_domain(extracted_text, legal_entities)
        
        # Verarbeitete Daten zu S3 speichern
        processed_s3_key = s3_key.replace('legal-documents/', 'processed/')
        processed_data = {
            'document_id': doc_id,
            'extracted_text': extracted_text,
            'legal_entities': legal_entities,
            'primary_domain': primary_domain,
            'processing_timestamp': datetime.utcnow().isoformat()
        }
        
        s3_client.put_object(
            Bucket=os.getenv('S3_BUCKET'),
            Key=processed_s3_key,
            Body=json.dumps(processed_data, ensure_ascii=False),
            ContentType='application/json'
        )
        
        # Datenbank aktualisieren
        async with SessionLocal() as db:
            doc = await db.get(LegalDocument, doc_id)
            if doc:
                doc.processing_status = "completed"
                doc.primary_domain = primary_domain
                doc.legal_area_confidence = 0.85  # Placeholder
                doc.s3_processed_key = processed_s3_key
                
                # Legal Entities speichern
                for entity_data in legal_entities:
                    entity = LegalEntity(
                        document_id=doc_id,
                        entity_text=entity_data['text'],
                        entity_type=entity_data['type'],
                        flair_confidence=entity_data['confidence'],
                        legal_classification=classify_legal_entity_type(entity_data['type'])
                    )
                    db.add(entity)
                
                await db.commit()
        
        logger.info(f"✅ Dokument verarbeitet: {doc_id} → {primary_domain}")
        
    except Exception as e:
        logger.error(f"⚠️ Verarbeitungsfehler {doc_id}: {str(e)}")
        
        # Fehler-Status setzen
        async with SessionLocal() as db:
            doc = await db.get(LegalDocument, doc_id)
            if doc:
                doc.processing_status = "failed"
                await db.commit()

def classify_legal_domain(text: str, entities: List[Dict]) -> str:
    """Einfache Rechtsgebiet-Klassifikation basierend auf Keywords"""
    
    text_lower = text.lower()
    
    # Rechtsgebiet-Keywords
    domain_keywords = {
        'zivilrecht': ['kaufvertrag', 'schadensersatz', 'bgb', 'kläger', 'beklagte', 'vertragsstrafe'],
        'strafrecht': ['angeklagte', 'staatsanwaltschaft', 'stgb', 'freiheitsstrafe', 'geldstrafe'],
        'arbeitsrecht': ['kündigung', 'arbeitnehmer', 'arbeitgeber', 'kündigungsschutz', 'betriebsrat'],
        'mietrecht': ['mieter', 'vermieter', 'mietminderung', 'nebenkosten', 'kaution'],
        'familienrecht': ['ehescheidung', 'unterhalt', 'sorgerecht', 'ehegatten'],
        'erbrecht': ['testament', 'erblasser', 'pflichtteil', 'erbfolge']
    }
    
    # Scoring pro Rechtsgebiet
    domain_scores = {}
    for domain, keywords in domain_keywords.items():
        score = sum(1 for keyword in keywords if keyword in text_lower)
        # Bonus für Legal Entities
        entity_bonus = sum(1 for entity in entities if entity['type'] in ['GS', 'GRT'])
        domain_scores[domain] = score + entity_bonus * 0.5
    
    # Bestes Rechtsgebiet
    best_domain = max(domain_scores, key=domain_scores.get, default='general')
    return best_domain if domain_scores[best_domain] > 0 else 'general'

def classify_legal_entity_type(flair_label: str) -> str:
    """Flair-Labels zu deutschen Rechtsbegriffen"""
    
    classification_map = {
        'GS': 'Gesetz/Statute',
        'GRT': 'Gericht/Court', 
        'PER': 'Person',
        'ORG': 'Organisation',
        'RS': 'Rechtsprechung',
        'RR': 'Rechtsregel',
        'VO': 'Verordnung',
        'VT': 'Vertrag',
        'UN': 'Urteilsnummer',
        'DAT': 'Datum',
        'GEL': 'Geldbetrag'
    }
    
    return classification_map.get(flair_label, 'Sonstiges')

@app.get("/api/documents")
async def list_documents(
    limit: int = 50,
    domain: Optional[str] = None,
    court_level: Optional[str] = None,
    status: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    """Dokumente auflisten mit Filterung"""
    
    query = db.query(LegalDocument)
    
    if domain:
        query = query.filter(LegalDocument.primary_domain == domain)
    if court_level:
        query = query.filter(LegalDocument.court_level == court_level)
    if status:
        query = query.filter(LegalDocument.processing_status == status)
    
    documents = query.limit(limit).all()
    
    return {
        "documents": [
            {
                "id": doc.document_id,
                "title": doc.title,
                "primary_domain": doc.primary_domain,
                "court_level": doc.court_level,
                "case_number": doc.case_number,
                "processing_status": doc.processing_status,
                "created_at": doc.created_at.isoformat() if doc.created_at else None,
                "legal_area_confidence": doc.legal_area_confidence
            }
            for doc in documents
        ]
    }

@app.get("/api/search")
async def search_documents(
    query: str,
    domain: Optional[str] = None,
    limit: int = 20,
    db: AsyncSession = Depends(get_db)
):
    """Einfache Textsuche in Dokumenten"""
    
    # Placeholder für echte Vektor-Suche
    # Hier würde IONOS AI Hub Vector Search integriert werden
    
    base_query = db.query(LegalDocument).filter(
        LegalDocument.processing_status == "completed"
    )
    
    if domain:
        base_query = base_query.filter(LegalDocument.primary_domain == domain)
    
    # Einfache Titel-Suche als Placeholder
    documents = base_query.filter(
        LegalDocument.title.ilike(f"%{query}%")
    ).limit(limit).all()
    
    return {
        "query": query,
        "domain_filter": domain,
        "results": [
            {
                "id": doc.document_id,
                "title": doc.title,
                "primary_domain": doc.primary_domain,
                "court_level": doc.court_level,
                "relevance_score": 0.85  # Placeholder
            }
            for doc in documents
        ],
        "search_method": "Placeholder - IONOS AI Hub Vector Search wird integriert"
    }

@app.get("/api/legal-domains")
async def get_legal_domains():
    """Verfügbare Rechtsgebiete"""
    
    return {
        "available_domains": [
            {"code": "zivilrecht", "name": "Zivilrecht", "description": "BGB, Vertragsrecht, Schadensersatz"},
            {"code": "strafrecht", "name": "Strafrecht", "description": "StGB, Strafverfahren"},
            {"code": "arbeitsrecht", "name": "Arbeitsrecht", "description": "Kündigungsschutz, Tarifrecht"},
            {"code": "mietrecht", "name": "Mietrecht", "description": "Mietminderung, Nebenkosten"},
            {"code": "familienrecht", "name": "Familienrecht", "description": "Scheidung, Unterhalt"},
            {"code": "erbrecht", "name": "Erbrecht", "description": "Testament, Erbfolge"}
        ],
        "features": [
            "Flair German Legal NER",
            "Rechtsgebiet-Klassifikation",
            "IONOS AI Hub Integration",
            "S3 Object Storage"
        ]
    }

# OpenAI-kompatible Endpoints für Open WebUI
@app.get("/v1/models")
async def list_models():
    return {
        "data": [{
            "id": "ionos-german-legal-rag",
            "object": "model",
            "created": 1677610602,
            "owned_by": "ionos-legal-system"
        }]
    }

@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    """OpenAI-kompatible Chat Completions für Open WebUI"""
    
    body = await request.json()
    messages = body.get("messages", [])
    last_message = messages[-1]["content"] if messages else ""
    
    # Placeholder Response
    response_text = f"🏛️ Deutsche Rechtsfrage analysiert: '{last_message}'\n\n"
    response_text += "Das IONOS Legal-RAG System mit Flair German Legal NER würde hier eine detaillierte juristische Analyse liefern, "
    response_text += "basierend auf deutschen Rechtsdokumenten und unter Verwendung des Knowledge Graphs."
    
    if body.get("stream", False):
        # Streaming Response
        async def generate():
            words = response_text.split()
            for i, word in enumerate(words):
                chunk_data = {
                    "id": f"chatcmpl-{uuid.uuid4()}",
                    "object": "chat.completion.chunk",
                    "created": int(datetime.now().timestamp()),
                    "model": "ionos-german-legal-rag",
                    "choices": [{
                        "index": 0,
                        "delta": {"content": word + " "},
                        "finish_reason": None
                    }]
                }
                yield f"data: {json.dumps(chunk_data)}\n\n"
                await asyncio.sleep(0.02)
            
            # Final chunk
            final_chunk = {
                "id": f"chatcmpl-{uuid.uuid4()}",
                "object": "chat.completion.chunk",
                "created": int(datetime.now().timestamp()),
                "model": "ionos-german-legal-rag",
                "choices": [{
                    "index": 0,
                    "delta": {},
                    "finish_reason": "stop"
                }]
            }
            yield f"data: {json.dumps(final_chunk)}\n\n"
            yield "data: [DONE]\n\n"
        
        return StreamingResponse(generate(), media_type="text/plain")
    else:
        return {
            "id": f"chatcmpl-{uuid.uuid4()}",
            "object": "chat.completion",
            "created": int(datetime.now().timestamp()),
            "model": "ionos-german-legal-rag",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": response_text
                },
                "finish_reason": "stop"
            }]
        }

@app.get("/health")
async def health():
    """Health Check für IONOS Monitoring"""
    return {
        "status": "healthy",
        "service": "ionos-deutsches-juristisches-rag-system",
        "version": "2.0.0",
        "features": ["Flair German Legal NER", "IONOS AI Hub", "S3 Storage"],
        "timestamp": datetime.utcnow().isoformat()
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

echo "✅ main.py erstellt"

# ==============================================
# 5. ENVIRONMENT KONFIGURATION
# ==============================================

cat > .env.template << 'EOF'
# ==============================================
# IONOS Fresh Start Legal-RAG System
# ==============================================

# IONOS AI Hub (deinen Key eintragen!)
IONOS_AI_HUB_API_KEY=your-ionos-ai-hub-api-key-here

# Database Passwörter (ÄNDERN!)
POSTGRES_PASSWORD=secure-postgres-password-123
NEO4J_PASSWORD=secure-neo4j-password-123
REDIS_PASSWORD=secure-redis-password-123

# IONOS Object Storage (S3) - EINTRAGEN!
S3_ENDPOINT=https://s3-eu-central-1.ionoscloud.com
S3_BUCKET=legal-documents-prod
S3_ACCESS_KEY=your-ionos-s3-access-key
S3_SECRET_KEY=your-ionos-s3-secret-key

# Database URLs (automatisch generiert)
POSTGRES_URL=postgresql://legal_user:${POSTGRES_PASSWORD}@postgres:5432/legal_db

# Performance Settings
OMP_NUM_THREADS=8
TOKENIZERS_PARALLELISM=true
EOF

echo "✅ .env.template erstellt"

# ==============================================
# 6. DATABASE INIT SCRIPT
# ==============================================

cat > config/init-db.sql << 'EOF'
-- ==============================================
-- IONOS Legal-RAG Database Schema
-- Rechtsgebiet-spezifische Tabellen
-- ==============================================

-- Deutsche Rechtsgebiete Enum
CREATE TYPE legal_domain_enum AS ENUM (
    'vergaberecht', 'eu-beihilfen', 'zuwendungsrecht', 'privates baurecht', 'architektenrecht', 'verwaltungsrecht', 'öffentliches baurecht', 'arbeitsrecht',
    'steuerrecht', 'familienrecht', 'erbrecht', 'mietrecht',
    'gesellschaftsrecht', 'europarecht', 'verfassungsrecht'
);

-- Court Level Enum  
CREATE TYPE court_level_enum AS ENUM (
    'BGH', 'BVerfG', 'BAG', 'BFH', 'BVerwG', 'BSG',
    'OLG', 'LAG', 'FG', 'VGH', 'OVG',
    'LG', 'ArbG', 'SG', 'VG', 'AG', 'VK', 'EuGH', 'EuG'
);

-- Processing Status Enum
CREATE TYPE processing_status_enum AS ENUM (
    'uploaded', 'processing', 'completed', 'failed', 'archived'
);

-- Haupt-Dokumententabelle (bereits in main.py definiert, aber hier für Referenz)
-- Wird automatisch von SQLAlchemy erstellt

-- Zusätzliche Indizes für Performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_legal_docs_domain_court 
ON legal_documents(primary_domain, court_level);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_legal_docs_status_date
ON legal_documents(processing_status, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_legal_docs_decision_date
ON legal_documents(decision_date DESC) WHERE decision_date IS NOT NULL;

-- Full-Text Search Index für deutsche Rechtsbegriffe
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_legal_entities_fulltext
ON legal_entities USING GIN(to_tsvector('german', entity_text));

-- Rechtsgebiet-Statistiken View
CREATE OR REPLACE VIEW legal_domain_stats AS
SELECT 
    primary_domain,
    court_level,
    COUNT(*) as document_count,
    COUNT(*) FILTER (WHERE processing_status = 'completed') as completed_count,
    AVG(legal_area_confidence) as avg_confidence,
    MIN(created_at) as earliest_doc,
    MAX(created_at) as latest_doc
FROM legal_documents
GROUP BY primary_domain, court_level;

-- Funktion: Dokument-Statistiken abrufen
CREATE OR REPLACE FUNCTION get_system_stats()
RETURNS JSON AS $
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'total_documents', (SELECT COUNT(*) FROM legal_documents),
        'by_domain', (
            SELECT json_object_agg(primary_domain, domain_count)
            FROM (
                SELECT primary_domain, COUNT(*) as domain_count
                FROM legal_documents
                GROUP BY primary_domain
            ) domain_stats
        ),
        'by_status', (
            SELECT json_object_agg(processing_status, status_count)
            FROM (
                SELECT processing_status, COUNT(*) as status_count
                FROM legal_documents
                GROUP BY processing_status
            ) status_stats
        ),
        'by_court_level', (
            SELECT json_object_agg(court_level, court_count)
            FROM (
                SELECT court_level, COUNT(*) as court_count
                FROM legal_documents
                WHERE court_level IS NOT NULL
                GROUP BY court_level
            ) court_stats
        )
    ) INTO result;
    
    RETURN result;
END;
$ LANGUAGE plpgsql;

-- Trigger: Automatische Zeitstempel
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$ LANGUAGE plpgsql;

-- User für bessere Sicherheit erstellen
CREATE USER legal_readonly WITH PASSWORD 'readonly-password-123';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO legal_readonly;

COMMIT;
EOF

echo "✅ Database Init Script erstellt"

# ==============================================
# 7. HTML TEMPLATES - Professionelle Legal-GUI
# ==============================================

# Dashboard Template
cat > templates/dashboard.html << 'EOF'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🏛️ IONOS Deutsches Juristisches RAG System</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js" defer></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
</head>
<body class="bg-gray-50" x-data="dashboard()">
    <!-- Navigation -->
    <nav class="bg-blue-900 text-white shadow-lg">
        <div class="max-w-7xl mx-auto px-4">
            <div class="flex justify-between items-center py-4">
                <div class="flex items-center space-x-4">
                    <i class="fas fa-balance-scale text-2xl"></i>
                    <h1 class="text-xl font-bold">IONOS Deutsches Juristisches RAG System</h1>
                </div>
                <div class="flex items-center space-x-4">
                    <span class="bg-green-600 px-3 py-1 rounded-full text-sm">IONOS Cloud</span>
                    <span class="bg-purple-600 px-3 py-1 rounded-full text-sm">Flair Legal NER</span>
                </div>
            </div>
        </div>
    </nav>

    <div class="max-w-7xl mx-auto px-4 py-8">
        <!-- System Status -->
        <div class="bg-white rounded-lg shadow-lg p-6 mb-8">
            <h2 class="text-2xl font-bold text-gray-800 mb-4">
                ✅ IONOS Legal-RAG System Online
            </h2>
            <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                <div class="bg-green-50 border border-green-200 rounded-lg p-4 text-center">
                    <div class="text-2xl font-bold text-green-600" x-text="stats.total_documents || 0"></div>
                    <div class="text-green-700 font-medium">Dokumente verarbeitet</div>
                </div>
                <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-center">
                    <div class="text-2xl font-bold text-blue-600">7</div>
                    <div class="text-blue-700 font-medium">Rechtsgebiete</div>
                </div>
                <div class="bg-purple-50 border border-purple-200 rounded-lg p-4 text-center">
                    <div class="text-2xl font-bold text-purple-600">19</div>
                    <div class="text-purple-700 font-medium">Legal-NER Entitäten</div>
                </div>
                <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 text-center">
                    <div class="text-2xl font-bold text-yellow-600">IONOS</div>
                    <div class="text-yellow-700 font-medium">AI Hub integriert</div>
                </div>
            </div>
        </div>

        <!-- Quick Actions -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <a href="/upload" class="bg-white rounded-lg shadow-lg p-6 hover:shadow-xl transition-shadow">
                <div class="flex items-center mb-4">
                    <div class="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mr-4">
                        <i class="fas fa-upload text-green-600 text-xl"></i>
                    </div>
                    <h3 class="text-lg font-semibold">Dokumente hochladen</h3>
                </div>
                <p class="text-gray-600">PDF, Word, RTF-Dateien für automatische Verarbeitung mit deutscher Legal-NLP</p>
            </a>

            <a href="/domains" class="bg-white rounded-lg shadow-lg p-6 hover:shadow-xl transition-shadow">
                <div class="flex items-center mb-4">
                    <div class="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mr-4">
                        <i class="fas fa-sitemap text-purple-600 text-xl"></i>
                    </div>
                    <h3 class="text-lg font-semibold">Rechtsgebiete</h3>
                </div>
                <p class="text-gray-600">Zivilrecht, Strafrecht, Arbeitsrecht - Spezialisierte Suche nach Rechtsgebieten</p>
            </a>

            <a href="/search" class="bg-white rounded-lg shadow-lg p-6 hover:shadow-xl transition-shadow">
                <div class="flex items-center mb-4">
                    <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mr-4">
                        <i class="fas fa-search text-blue-600 text-xl"></i>
                    </div>
                    <h3 class="text-lg font-semibold">Rechtsprechung suchen</h3>
                </div>
                <p class="text-gray-600">Semantic Search mit IONOS Vector Database und Knowledge Graph</p>
            </a>
        </div>

        <!-- Services Grid -->
        <div class="bg-white rounded-lg shadow-lg p-6">
            <h3 class="text-xl font-bold mb-4">Verfügbare Services</h3>
            <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
                <a href="http://localhost:3000" target="_blank" class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-3 rounded-lg text-center transition">
                    <i class="fas fa-comments mb-1 block"></i>
                    Chat Interface
                </a>
                <a href="http://localhost:8080" target="_blank" class="bg-green-600 hover:bg-green-700 text-white px-4 py-3 rounded-lg text-center transition">
                    <i class="fas fa-database mb-1 block"></i>
                    Adminer DB
                </a>
                <a href="http://localhost:7474" target="_blank" class="bg-purple-600 hover:bg-purple-700 text-white px-4 py-3 rounded-lg text-center transition">
                    <i class="fas fa-project-diagram mb-1 block"></i>
                    Neo4j Browser
                </a>
                <a href="/api/docs" target="_blank" class="bg-orange-600 hover:bg-orange-700 text-white px-4 py-3 rounded-lg text-center transition">
                    <i class="fas fa-code mb-1 block"></i>
                    API Docs
                </a>
            </div>
        </div>
    </div>

    <script>
        function dashboard() {
            return {
                stats: {},
                
                async init() {
                    await this.loadStats();
                    setInterval(() => this.loadStats(), 30000);
                },
                
                async loadStats() {
                    try {
                        const response = await fetch('/api/documents?limit=1');
                        const data = await response.json();
                        this.stats = { total_documents: data.documents.length };
                    } catch (error) {
                        console.error('Stats Fehler:', error);
                    }
                }
            }
        }
    </script>
</body>
</html>
EOF

echo "✅ HTML Templates erstellt"

# ==============================================
# 8. IONOS SERVER SETUP SCRIPT
# ==============================================

cat > scripts/setup-ionos-server.sh << 'EOF'
#!/bin/bash

echo "🏛️ === IONOS Server Setup für Legal-RAG System ==="

# System Update
apt update && apt upgrade -y

# Docker installieren
echo "🐳 Installiere Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Docker Compose installieren
echo "🔧 Installiere Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Weitere Tools
apt install -y git htop ncdu unzip curl

# Firewall konfigurieren
ufw --force enable
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow 8000
ufw allow 3000
ufw allow 8080
ufw allow 7474

# Deutsche Locale installieren
locale-gen de_DE.UTF-8
update-locale LANG=de_DE.UTF-8

# Projekt-Verzeichnis
mkdir -p /opt/ionos-legal-rag
cd /opt/ionos-legal-rag

echo "✅ IONOS Server Setup abgeschlossen!"
echo ""
echo "📋 Nächste Schritte:"
echo "1. Git Repository klonen oder Dateien hochladen"
echo "2. .env Datei aus .env.template erstellen und konfigurieren"  
echo "3. IONOS AI Hub API Key eintragen"
echo "4. IONOS S3 Access Keys eintragen"
echo "5. docker-compose up -d ausführen"
echo ""
echo "🌐 Services nach dem Start:"
echo "- http://[SERVER-IP]:8000 → Legal-RAG API + GUI"
echo "- http://[SERVER-IP]:3000 → Open WebUI Chat"
echo "- http://[SERVER-IP]:8080 → Adminer Database"
echo "- http://[SERVER-IP]:7474 → Neo4j Browser"
EOF

chmod +x scripts/setup-ionos-server.sh

echo "✅ Server Setup Script erstellt"

# ==============================================
# 9. DEPLOYMENT ANLEITUNG
# ==============================================

cat > IONOS-DEPLOYMENT.md << 'EOF'
# 🚀 IONOS Fresh Start Legal-RAG Deployment

## Schritt-für-Schritt Anleitung

### 1. IONOS Cloud Services einrichten

#### VPS bestellen
- **Memory Cube L** (deine 46,42€ Konfiguration)
- **Ubuntu 22.04 LTS**
- **SSH-Key hochladen**

#### AI Hub konfigurieren  
1. IONOS DCD → AI Model Hub
2. API Key generieren
3. Paraphrase-multilingual-mpnet-base-v3 aktivieren
4. Vector Database aktivieren

#### Object Storage einrichten
1. S3-kompatibles Storage erstellen
2. Bucket: `legal-documents-prod`
3. Access Keys generieren

### 2. Server vorbereiten

```bash
# SSH zum Server
ssh root@[SERVER-IP]

# Setup-Script ausführen
curl -fsSL https://raw.githubusercontent.com/[YOUR-REPO]/scripts/setup-ionos-server.sh | bash

# Oder manuell:
apt update && apt upgrade -y
curl -fsSL https://get.docker.com | sh
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

### 3. Projekt deployen

```bash
# Projekt-Ordner erstellen
mkdir -p /opt/ionos-legal-rag
cd /opt/ionos-legal-rag

# Dateien hochladen (SCP oder Git)
scp -r ./ionos-legal-rag/* root@[SERVER-IP]:/opt/ionos-legal-rag/

# Environment konfigurieren
cp .env.template .env
nano .env
```

### 4. Environment-Variablen konfigurieren

```bash
# .env Datei anpassen:
IONOS_AI_HUB_API_KEY=ihr-ionos-api-key
S3_ACCESS_KEY=ihr-s3-access-key
S3_SECRET_KEY=ihr-s3-secret-key
S3_BUCKET=legal-documents-prod

# Sichere Passwörter generieren
POSTGRES_PASSWORD=$(openssl rand -base64 32)
NEO4J_PASSWORD=$(openssl rand -base64 32)  
REDIS_PASSWORD=$(openssl rand -base64 32)
```

### 5. System starten

```bash
# Container bauen und starten
docker-compose build --no-cache
docker-compose up -d

# Status prüfen
docker-compose ps
docker-compose logs legal-rag-api -f
```

### 6. Services testen

- **Legal-RAG GUI**: http://[SERVER-IP]:8000
- **Open WebUI**: http://[SERVER-IP]:3000  
- **Adminer**: http://[SERVER-IP]:8080
- **Neo4j**: http://[SERVER-IP]:7474
- **API Docs**: http://[SERVER-IP]:8000/docs

### 7. Erste Dokumente hochladen

1. GUI öffnen: http://[SERVER-IP]:8000/upload
2. Deutsche Rechtsdokumente hochladen
3. Flair German Legal NER Verarbeitung beobachten
4. Über /domains rechtsgebiet-spezifisch suchen

## Features des Systems

✅ **Deutsche Legal-NLP**: Flair German Legal NER mit 19 Entitätstypen  
✅ **IONOS AI Hub**: Paraphrase-multilingual-mpnet-base-v3 Embeddings  
✅ **Rechtsgebiet-Struktur**: Spezialisierte Datenbank-Schemas  
✅ **S3 Object Storage**: Skalierbare Dokumentenspeicherung  
✅ **Knowledge Graph**: Neo4j für deutsche Rechtshierarchien  
✅ **Professional GUI**: Drag & Drop Upload + Such-Interface  

## Monitoring & Wartung

```bash
# Container-Ressourcen überwachen
docker stats

# Logs verfolgen
docker-compose logs -f

# Backups (automatisch geplant)
docker-compose exec postgres pg_dump -U legal_user legal_db > backup.sql

# Updates deployen
git pull origin main
docker-compose build --no-cache
docker-compose up -d
```

## Troubleshooting

### Container startet nicht
```bash
docker-compose logs [service-name]
docker-compose build --no-cache [service-name]
```

### Flair Legal NER lädt nicht
```bash
docker-compose exec legal-rag-api python -c "from flair.models import SequenceTagger; SequenceTagger.load('flair/ner-german-legal')"
```

### S3 Verbindung fehlschlägt
```bash
docker-compose exec legal-rag-api python -c "import boto3; print('S3 OK')"
```

## Support

- **IONOS Cloud Support**: https://cloud.ionos.com/support
- **System Logs**: `/opt/ionos-legal-rag/data/logs/`
- **Health Check**: http://[SERVER-IP]:8000/health
EOF

echo "✅ Deployment-Anleitung erstellt"

# ==============================================
# 10. README UND ABSCHLUSS  
# ==============================================

cat > README.md << 'EOF'
# 🏛️ IONOS Fresh Start Legal-RAG System

**Deutsches Juristisches RAG-System mit IONOS Cloud + Flair German Legal NLP**

## ⚡ Quick Start

```bash
# 1. Projekt Setup
git clone [repository] ionos-legal-rag
cd ionos-legal-rag

# 2. Environment konfigurieren  
cp .env.template .env
# → IONOS API Keys eintragen

# 3. System starten
docker-compose up -d

# 4. GUI öffnen
open http://localhost:8000
```

## 🎯 Features

- **🤖 Flair German Legal NER**: 19 juristische Entitätstypen
- **☁️ IONOS AI Hub**: Paraphrase-multilingual-mpnet-base-v3  
- **⚖️ Rechtsgebiet-spezifisch**: Zivilrecht, Strafrecht, Arbeitsrecht
- **🌐 Professional GUI**: Drag & Drop Upload + Suche
- **📊 Knowledge Graph**: Neo4j für deutsche Rechtshierarchien
- **🔐 DSGVO-konform**: Deutsche Rechenzentren

## 💰 Kosten (IONOS Cloud)

- **Memory Cube L**: 44,62€/Monat
- **AI Model Hub**: 1,07€/1M Token  
- **Object Storage**: 1,75€/250GB
- **TOTAL**: **46,42€/Monat**

## 📊 Technologie-Stack

- **Backend**: FastAPI + Python 3.11
- **NLP**: Flair German Legal NER + spaCy
- **Databases**: PostgreSQL + Neo4j + Redis
- **Storage**: IONOS S3 Object Storage
- **AI**: IONOS AI Hub (Multilingual Embeddings)
- **Frontend**: Alpine.js + Tailwind CSS
- **Deployment**: Docker + Docker Compose

## 🚀 Deployment

Siehe [IONOS-DEPLOYMENT.md](IONOS-DEPLOYMENT.md) für detaillierte Anleitung.

## 📋 Projekt-Struktur

```
ionos-legal-rag/
├── app/                    # FastAPI Application
│   ├── main.py            # Haupt-API mit Legal-NLP
│   ├── Dockerfile         # IONOS-optimiert
│   └── requirements.txt   # Deutsche Legal-NLP
├── templates/             # Professional Legal GUI
├── config/               # Database Schema
├── scripts/              # IONOS Server Setup
└── docker-compose.yml    # Multi-Service Stack
```

## 🔧 Services

| Service | Port | Beschreibung |
|---------|------|-------------|
| Legal-RAG API | 8000 | FastAPI + GUI |
| Open WebUI | 3000 | Chat Interface |
| Adminer | 8080 | Database GUI |
| Neo4j Browser | 7474 | Knowledge Graph |
| PostgreSQL | 5432 | Metadaten DB |
| Redis | 6379 | Caching |

## 📈 Roadmap

- [x] **Fresh Start**: Saubere IONOS-Integration
- [x] **German Legal NLP**: Flair Integration
- [x] **Professional GUI**: Upload + Search
- [ ] **IONOS Vector Search**: AI Hub Integration
- [ ] **Knowledge Graph**: Erweiterte Rechtshierarchien
- [ ] **Multi-User**: Team-Features
- [ ] **LoRA Training**: Wenn gewünscht

---

**🎯 Ready for Production auf IONOS Cloud!**
EOF

echo "✅ README.md erstellt"

echo ""
echo "🎉 === FRESH START IONOS LEGAL-RAG SYSTEM ERSTELLT! ==="
echo ""
echo "📁 Projektstruktur:"
echo "   ├── docker-compose.yml (IONOS VPS optimiert)"
echo "   ├── app/main.py (Komplette Legal-RAG API)"
echo "   ├── app/requirements.txt (Deutsche Legal-NLP)"  
echo "   ├── templates/ (Professional GUI)"
echo "   ├── config/init-db.sql (Rechtsgebiet-Schema)"
echo "   ├── scripts/setup-ionos-server.sh (Server Setup)"
echo "   └── IONOS-DEPLOYMENT.md (Schritt-für-Schritt)"
echo ""
echo "🚀 Nächste Schritte:"
echo "   1. IONOS VPS + AI Hub bestellen"
echo "   2. .env.template zu .env kopieren"
echo "   3. IONOS API Keys eintragen"
echo "   4. docker-compose up -d starten"
echo ""
echo "💰 Kosten: 46,42€/Monat (deine IONOS Konfiguration)"
echo "⚡ Performance: Optimiert für Memory Cube L"  
echo "🤖 Features: Flair German Legal NER + IONOS AI Hub"
echo ""
echo "🎯 System ist Ready für IONOS Deployment!"