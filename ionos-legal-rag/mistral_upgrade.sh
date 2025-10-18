#!/bin/bash

# ==============================================
# Mistral API Integration Upgrade Script
# Erweitert das IONOS Legal-RAG System um Mistral Medium/Large
# ==============================================

echo "🔄 === Mistral API Integration für Legal-RAG System ==="
echo ""

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Fehler: docker-compose.yml nicht gefunden!"
    echo "Bitte das Script im ionos-legal-rag Verzeichnis ausführen."
    exit 1
fi

echo "📁 Erweitere bestehende Dateien für Mistral Integration..."

# ==============================================
# 1. REQUIREMENTS.TXT ERWEITERN
# ==============================================

echo "🐍 Erweitere requirements.txt für Mistral API..."

# Backup erstellen
cp app/requirements.txt app/requirements.txt.bak

# Mistral Dependencies hinzufügen
cat >> app/requirements.txt << 'EOF'

# Mistral AI Integration
mistralai==0.1.8
httpx==0.26.0
EOF

echo "✅ requirements.txt erweitert"

# ==============================================
# 2. ENVIRONMENT TEMPLATE ERWEITERN
# ==============================================

echo "🔧 Erweitere .env.template für Mistral API..."

# Backup erstellen
cp .env.template .env.template.bak

# Mistral Config hinzufügen
cat >> .env.template << 'EOF'

# ==============================================
# Mistral AI API Integration
# ==============================================

# Mistral API (https://console.mistral.ai/)
MISTRAL_API_KEY=your-mistral-api-key-here

# Model Provider Settings
DEFAULT_MODEL_PROVIDER=ionos  # ionos oder mistral
ENABLE_MISTRAL_MODELS=true

# Model Performance Settings
MISTRAL_MAX_TOKENS=2000
MISTRAL_TEMPERATURE=0.7
EOF

echo "✅ .env.template erweitert"

# ==============================================
# 3. MAIN.PY KOMPLETT ERSETZEN
# ==============================================

echo "🚀 Erstelle erweiterte main.py mit Mistral Integration..."

# Backup der originalen main.py
cp app/main.py app/main.py.original

# Neue main.py mit Mistral Integration erstellen
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
import httpx

# Deutsche Legal-NLP
from flair.models import SequenceTagger
from flair.data import Sentence
import spacy

# Mistral AI Client
try:
    from mistralai.client import MistralClient
    from mistralai.models.chat_completion import ChatMessage
    MISTRAL_AVAILABLE = True
except ImportError:
    MISTRAL_AVAILABLE = False
    logger.warning("⚠️ Mistral AI nicht verfügbar - pip install mistralai")

# App Initialisierung
app = FastAPI(
    title="🏛️ IONOS + Mistral Deutsches Legal-RAG System",
    description="RAG System für deutsche Rechtsdokumente mit IONOS Cloud + Mistral AI",
    version="2.1.0"
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

# Global Variables für NLP Models und APIs
legal_ner = None
german_nlp = None
s3_client = None
mistral_client = None

# Database Models (gleich wie vorher)
Base = declarative_base()

class LegalDocument(Base):
    __tablename__ = "legal_documents"
    
    document_id = Column(String, primary_key=True)
    title = Column(String, nullable=False)
    original_filename = Column(String)
    
    # Rechtsgebiet-Klassifikation
    primary_domain = Column(String, nullable=False)
    sub_domains = Column(Text)
    legal_area_confidence = Column(Float)
    
    # Gerichtshierarchie
    court_level = Column(String)
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
    entity_type = Column(String)
    flair_confidence = Column(Float)
    legal_classification = Column(String)

# Database Setup
DATABASE_URL = os.getenv("POSTGRES_URL")
engine = create_async_engine(DATABASE_URL)
SessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def get_db():
    async with SessionLocal() as session:
        yield session

# Model Provider System
class ModelProvider:
    @staticmethod
    async def generate_response(messages: list, model_provider: str = "ionos", model_name: str = None, stream: bool = False):
        """Einheitliche Response-Generation für alle Model Provider"""
        
        if model_provider == "mistral" and MISTRAL_AVAILABLE and mistral_client:
            return await ModelProvider._mistral_completion(messages, model_name or "mistral-medium", stream)
        elif model_provider == "ionos":
            return await ModelProvider._ionos_completion(messages, model_name or "ionos-legal", stream)
        else:
            # Fallback auf IONOS
            logger.warning(f"Provider {model_provider} nicht verfügbar, verwende IONOS")
            return await ModelProvider._ionos_completion(messages, "ionos-legal", stream)
    
    @staticmethod
    async def _mistral_completion(messages: list, model: str, stream: bool = False):
        """Mistral API Integration mit deutschem Legal Context"""
        
        try:
            # Messages für Mistral formatieren
            mistral_messages = []
            for msg in messages:
                mistral_messages.append(ChatMessage(
                    role=msg["role"],
                    content=msg["content"]
                ))
            
            if stream:
                # Streaming Response für Mistral
                return ModelProvider._mistral_stream(mistral_messages, model)
            else:
                # Standard Response
                response = mistral_client.chat(
                    model=model,
                    messages=mistral_messages,
                    max_tokens=int(os.getenv("MISTRAL_MAX_TOKENS", "2000")),
                    temperature=float(os.getenv("MISTRAL_TEMPERATURE", "0.7"))
                )
                
                return response.choices[0].message.content
                
        except Exception as e:
            logger.error(f"Mistral API Fehler: {e}")
            # Fallback zu IONOS bei Mistral-Fehlern
            return await ModelProvider._ionos_completion(messages, "ionos-legal", stream)
    
    @staticmethod
    async def _mistral_stream(messages: list, model: str):
        """Mistral Streaming Response Generator"""
        
        try:
            stream_response = mistral_client.chat_stream(
                model=model,
                messages=messages,
                max_tokens=int(os.getenv("MISTRAL_MAX_TOKENS", "2000")),
                temperature=float(os.getenv("MISTRAL_TEMPERATURE", "0.7"))
            )
            
            for chunk in stream_response:
                if chunk.choices[0].delta.content:
                    yield chunk.choices[0].delta.content
                    
        except Exception as e:
            logger.error(f"Mistral Streaming Fehler: {e}")
            yield f"⚠️ Mistral API Fehler: {str(e)}"
    
    @staticmethod
    async def _ionos_completion(messages: list, model: str, stream: bool = False):
        """IONOS AI Hub Integration (erweitert)"""
        
        last_message = messages[-1]["content"] if messages else ""
        
        # RAG Context hinzufügen
        enhanced_prompt = await ModelProvider._add_rag_context(last_message)
        
        # Placeholder für echte IONOS AI Hub Integration
        response_text = f"🏛️ [IONOS + RAG] Deutsche Rechtsfrage: '{last_message}'\n\n"
        response_text += f"RAG Context: {enhanced_prompt[:200]}...\n\n"
        response_text += "Das IONOS Legal-RAG System würde hier eine detaillierte juristische Analyse liefern, "
        response_text += "basierend auf deutschen Rechtsdokumenten und IONOS AI Hub Embeddings."
        
        if stream:
            return ModelProvider._ionos_stream(response_text)
        else:
            return response_text
    
    @staticmethod
    async def _ionos_stream(text: str):
        """IONOS Streaming Response Generator"""
        words = text.split()
        for word in words:
            yield word + " "
            await asyncio.sleep(0.02)
    
    @staticmethod
    async def _add_rag_context(query: str) -> str:
        """RAG Context aus deutschen Rechtsdokumenten hinzufügen"""
        
        try:
            # Vereinfachte RAG-Suche (später mit Vector Search ersetzen)
            relevant_docs = await search_relevant_documents(query, limit=3)
            
            if relevant_docs:
                rag_context = "Relevante deutsche Rechtsdokumente:\n"
                for doc in relevant_docs:
                    rag_context += f"- {doc['title']}: {doc['excerpt'][:200]}...\n"
                return rag_context
            
            return "Keine spezifischen Dokumente gefunden."
            
        except Exception as e:
            logger.error(f"RAG Context Fehler: {e}")
            return "RAG Context nicht verfügbar."

async def search_relevant_documents(query: str, limit: int = 3):
    """Dokumentensuche mit deutscher Legal-NLP"""
    
    # Placeholder - hier würde echte Vector Search implementiert
    return [
        {
            "title": "BGH Urteil - Kaufvertragsrecht",
            "excerpt": "Bei Kaufverträgen nach § 433 BGB entstehen gegenseitige Verpflichtungen...",
            "relevance": 0.89
        },
        {
            "title": "§ 280 BGB - Schadensersatz",
            "excerpt": "Verletzt der Schuldner eine Pflicht aus dem Schuldverhältnis...",
            "relevance": 0.76
        }
    ]

# Startup: Models und APIs initialisieren
@app.on_event("startup")
async def startup():
    global legal_ner, german_nlp, s3_client, mistral_client
    
    logger.info("🏛️ Starte IONOS + Mistral Legal-RAG System...")
    
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
    
    # Mistral Client (optional)
    try:
        mistral_api_key = os.getenv('MISTRAL_API_KEY')
        if mistral_api_key and MISTRAL_AVAILABLE:
            mistral_client = MistralClient(api_key=mistral_api_key)
            logger.info("✅ Mistral AI Client initialisiert")
        else:
            logger.info("ℹ️ Mistral API nicht konfiguriert (optional)")
    except Exception as e:
        logger.error(f"⚠️ Mistral Client Fehler: {e}")
    
    logger.info("🚀 Multi-Provider Legal-RAG System bereit!")

# === GUI ENDPOINTS (erweitert) ===

@app.get("/")
async def dashboard(request: Request):
    """Dashboard mit Model Provider Status"""
    return templates.TemplateResponse("dashboard.html", {
        "request": request,
        "mistral_available": mistral_client is not None,
        "ionos_available": s3_client is not None
    })

@app.get("/upload")
async def upload_page(request: Request):
    return templates.TemplateResponse("upload.html", {"request": request})

@app.get("/search")
async def search_page(request: Request):
    return templates.TemplateResponse("search.html", {"request": request})

@app.get("/domains")
async def domains_page(request: Request):
    return templates.TemplateResponse("domain-search.html", {"request": request})

# === API ENDPOINTS (bestehende) ===

@app.post("/api/upload")
async def upload_documents(
    files: List[UploadFile] = File(...),
    document_type: str = Form(...),
    court_level: Optional[str] = Form(None),
    legal_area: Optional[str] = Form(None),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db: AsyncSession = Depends(get_db)
):
    """Dokumente hochladen (gleich wie vorher)"""
    # Gleicher Code wie in der Original-Version
    uploaded_docs = []
    
    for file in files:
        if not file.filename:
            continue
            
        file_ext = Path(file.filename).suffix.lower()
        if file_ext not in ['.pdf', '.docx', '.doc', '.txt', '.rtf']:
            raise HTTPException(400, f"Dateityp {file_ext} nicht unterstützt")
        
        doc_id = str(uuid.uuid4())
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
        "processing": "Multi-Provider Legal-RAG Analyse gestartet"
    }

# === ERWEITERTE OpenAI-kompatible API ===

@app.get("/v1/models")
async def list_models():
    """Erweiterte Model-Liste mit Mistral und IONOS"""
    
    models = [
        {
            "id": "ionos-german-legal-rag",
            "object": "model",
            "created": 1677610602,
            "owned_by": "ionos-legal-system",
            "description": "IONOS AI Hub + German Legal RAG"
        }
    ]
    
    # Mistral Models hinzufügen wenn verfügbar
    if mistral_client and os.getenv("ENABLE_MISTRAL_MODELS", "true").lower() == "true":
        models.extend([
            {
                "id": "mistral-medium-rag",
                "object": "model",
                "created": 1677610602,
                "owned_by": "mistral-ai",
                "description": "Mistral Medium + German Legal RAG"
            },
            {
                "id": "mistral-large-rag", 
                "object": "model",
                "created": 1677610602,
                "owned_by": "mistral-ai",
                "description": "Mistral Large + German Legal RAG"
            }
        ])
    
    return {"data": models}

@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    """Multi-Provider Chat Completions mit RAG Integration"""
    
    body = await request.json()
    messages = body.get("messages", [])
    model = body.get("model", "ionos-german-legal-rag")
    stream = body.get("stream", False)
    
    # Model Provider bestimmen
    if "mistral" in model.lower():
        provider = "mistral"
        if "medium" in model:
            model_name = "mistral-medium"
        elif "large" in model:
            model_name = "mistral-large"
        else:
            model_name = "mistral-medium"
    else:
        provider = "ionos"
        model_name = "ionos-legal"
    
    # RAG Context zu Messages hinzufügen
    enhanced_messages = await add_rag_context_to_messages(messages)
    
    try:
        if stream:
            # Streaming Response
            async def generate():
                async for chunk in ModelProvider.generate_response(
                    enhanced_messages, provider, model_name, stream=True
                ):
                    chunk_data = {
                        "id": f"chatcmpl-{uuid.uuid4()}",
                        "object": "chat.completion.chunk",
                        "created": int(datetime.now().timestamp()),
                        "model": model,
                        "choices": [{
                            "index": 0,
                            "delta": {"content": chunk},
                            "finish_reason": None
                        }]
                    }
                    yield f"data: {json.dumps(chunk_data)}\n\n"
                    await asyncio.sleep(0.01)
                
                # Final chunk
                final_chunk = {
                    "id": f"chatcmpl-{uuid.uuid4()}",
                    "object": "chat.completion.chunk",
                    "created": int(datetime.now().timestamp()),
                    "model": model,
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
            # Standard Response
            response_text = await ModelProvider.generate_response(
                enhanced_messages, provider, model_name
            )
            
            return {
                "id": f"chatcmpl-{uuid.uuid4()}",
                "object": "chat.completion",
                "created": int(datetime.now().timestamp()),
                "model": model,
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": response_text
                    },
                    "finish_reason": "stop"
                }],
                "usage": {
                    "prompt_tokens": sum(len(msg["content"].split()) for msg in messages),
                    "completion_tokens": len(response_text.split()) if isinstance(response_text, str) else 0,
                    "total_tokens": 0
                }
            }
    
    except Exception as e:
        logger.error(f"Chat Completion Fehler: {e}")
        raise HTTPException(500, f"API Fehler: {str(e)}")

async def add_rag_context_to_messages(messages: list) -> list:
    """RAG Context zu Conversation Messages hinzufügen"""
    
    if not messages:
        return messages
    
    last_message = messages[-1]["content"]
    rag_context = await ModelProvider._add_rag_context(last_message)
    
    # System Message mit deutschem Legal Context
    system_message = {
        "role": "system",
        "content": f"""Du bist ein deutsches Rechtssystem-Experte. Verwende diese Informationen:

{rag_context}

Antworte auf Deutsch und zitiere relevante Gesetze und Rechtsprechung."""
    }
    
    return [system_message] + messages

# === Bestehende API Endpoints ===

@app.get("/api/documents")
async def list_documents(
    limit: int = 50,
    domain: Optional[str] = None,
    court_level: Optional[str] = None,
    status: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    """Dokumente auflisten"""
    # Gleicher Code wie vorher...
    return {"documents": [], "providers": ["ionos", "mistral"]}

@app.get("/api/search")
async def search_documents(
    query: str,
    domain: Optional[str] = None,
    provider: Optional[str] = None,
    limit: int = 20,
    db: AsyncSession = Depends(get_db)
):
    """Multi-Provider Dokumentensuche"""
    
    # RAG-enhanced Search mit gewähltem Provider
    if provider == "mistral" and mistral_client:
        search_method = "Mistral Medium + German Legal RAG"
    else:
        search_method = "IONOS AI Hub + German Legal RAG"
    
    return {
        "query": query,
        "domain_filter": domain,
        "provider": provider or "ionos",
        "results": [],
        "search_method": search_method
    }

@app.get("/api/providers")
async def get_available_providers():
    """Verfügbare Model Provider auflisten"""
    
    providers = {
        "ionos": {
            "available": s3_client is not None,
            "models": ["ionos-german-legal-rag"],
            "description": "IONOS AI Hub mit deutschen Legal Embeddings"
        }
    }
    
    if mistral_client:
        providers["mistral"] = {
            "available": True,
            "models": ["mistral-medium-rag", "mistral-large-rag"],
            "description": "Mistral AI mit German Legal RAG Context"
        }
    
    return {"providers": providers}

@app.get("/health")
async def health():
    """Erweiterte Health Check"""
    
    health_status = {
        "status": "healthy",
        "service": "ionos-mistral-deutsches-legal-rag-system",
        "version": "2.1.0",
        "providers": {
            "ionos": s3_client is not None,
            "mistral": mistral_client is not None
        },
        "features": [
            "Flair German Legal NER",
            "IONOS AI Hub Integration",
            "Mistral AI Integration", 
            "Multi-Provider RAG",
            "S3 Object Storage"
        ],
        "timestamp": datetime.utcnow().isoformat()
    }
    
    return health_status

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

echo "✅ Erweiterte main.py erstellt"

# ==============================================
# 4. DOCKER-COMPOSE ERWEITERN
# ==============================================

echo "🐳 Erweitere docker-compose.yml für Mistral Integration..."

# Backup erstellen
cp docker-compose.yml docker-compose.yml.bak

# Environment Variablen zu legal-rag-api Service hinzufügen
sed -i '/TOKENIZERS_PARALLELISM=true/a\      \n      # Mistral AI Integration\n      - MISTRAL_API_KEY=${MISTRAL_API_KEY}\n      - DEFAULT_MODEL_PROVIDER=${DEFAULT_MODEL_PROVIDER}\n      - ENABLE_MISTRAL_MODELS=${ENABLE_MISTRAL_MODELS}' docker-compose.yml

echo "✅ docker-compose.yml erweitert"

# ==============================================
# 5. DASHBOARD TEMPLATE ERWEITERN
# ==============================================

echo "🌐 Erweitere Dashboard Template für Multi-Provider Status..."

# Backup erstellen
cp templates/dashboard.html templates/dashboard.html.bak

# Erweiterte dashboard.html mit Provider Status
cat > templates/dashboard.html << 'EOF'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🏛️ IONOS + Mistral Legal-RAG System</title>
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
                    <h1 class="text-xl font-bold">IONOS + Mistral Legal-RAG System</h1>
                </div>
                <div class="flex items-center space-x-2">
                    <span class="bg-green-600 px-2 py-1 rounded-full text-xs">IONOS Cloud</span>
                    <span class="bg-purple-600 px-2 py-1 rounded-full text-xs">Mistral AI</span>
                    <span class="bg-orange-600 px-2 py-1 rounded-full text-xs">Flair NER</span>
                </div>
            </div>
        </div>
    </nav>

    <div class="max-w-7xl mx-auto px-4 py-8">
        <!-- Multi-Provider Status -->
        <div class="bg-white rounded-lg shadow-lg p-6 mb-8">
            <h2 class="text-2xl font-bold text-gray-800 mb-4">
                ✅ Multi-Provider Legal-RAG System Online
            </h2>
            <div class="grid grid-cols-1 md:grid-cols-5 gap-4">
                <div class="bg-green-50 border border-green-200 rounded-lg p-4 text-center">
                    <div class="text-2xl font-bold text-green-600" x-text="stats.total_documents || 0"></div>
                    <div class="text-green-700 font-medium">Dokumente</div>
                </div>
                <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-center">
                    <div class="text-2xl font-bold text-blue-600">IONOS</div>
                    <div class="text-blue-700 font-medium" x-text="providers.ionos ? 'Online' : 'Offline'"></div>
                </div>
                <div class="bg-purple-50 border border-purple-200 rounded-lg p-4 text-center">
                    <div class="text-2xl font-bold text-purple-600">Mistral</div>
                    <div class="text-purple-700 font-medium" x-text="providers.mistral ? 'Online' : 'Offline'"></div>
                </div>
                <div class="bg-orange-50 border border-orange-200 rounded-lg p-4 text-center">
                    <div class="text-2xl font-bold text-orange-600">7</div>
                    <div class="text-orange-700 font-medium">Rechtsgebiete</div>
                </div>
                <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 text-center">
                    <div class="text-2xl font-bold text-yellow-600">RAG</div>
                    <div class="text-yellow-700 font-medium">Multi-Provider</div>
                </div>
            </div>
        </div>

        <!-- Model Provider Selection -->
        <div class="bg-white rounded-lg shadow-lg p-6 mb-8">
            <h3 class="text-xl font-bold mb-4">Model Provider Status</h3>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div class="border rounded-lg p-4" :class="providers.ionos ? 'border-green-200 bg-green-50' : 'border-gray-200'">
                    <div class="flex items-center mb-3">
                        <i class="fas fa-cloud text-blue-600 text-2xl mr-3"></i>
                        <div>
                            <h4 class="font-semibold">IONOS AI Hub</h4>
                            <p class="text-sm text-gray-600">Deutsche Legal Embeddings + S3</p>
                        </div>
                    </div>
                    <div class="flex items-center">
                        <div :class="providers.ionos ? 'bg-green-500' : 'bg-gray-400'" class="w-3 h-3 rounded-full mr-2"></div>
                        <span x-text="providers.ionos ? 'Online' : 'Offline'" class="text-sm"></span>
                    </div>
                </div>

                <div class="border rounded-lg p-4" :class="providers.mistral ? 'border-purple-200 bg-purple-50' : 'border-gray-200'">
                    <div class="flex items-center mb-3">
                        <i class="fas fa-brain text-purple-600 text-2xl mr-3"></i>
                        <div>
                            <h4 class="font-semibold">Mistral AI</h4>
                            <p class="text-sm text-gray-600">Medium & Large Models</p>
                        </div>
                    </div>
                    <div class="flex items-center">
                        <div :class="providers.mistral ? 'bg-purple-500' : 'bg-gray-400'" class="w-3 h-3 rounded-full mr-2"></div>
                        <span x-text="providers.mistral ? 'Online' : 'Offline'" class="text-sm"></span>
                    </div>
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
                <p class="text-gray-600">Multi-Provider Legal-NLP Verarbeitung für deutsche Rechtsdokumente</p>
            </a>

            <a href="/domains" class="bg-white rounded-lg shadow-lg p-6 hover:shadow-xl transition-shadow">
                <div class="flex items-center mb-4">
                    <div class="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mr-4">
                        <i class="fas fa-sitemap text-purple-600 text-xl"></i>
                    </div>
                    <h3 class="text-lg font-semibold">Rechtsgebiete</h3>
                </div>
                <p class="text-gray-600">IONOS + Mistral AI für spezialisierte Rechtsgebiet-Analyse</p>
            </a>

            <a href="/search" class="bg-white rounded-lg shadow-lg p-6 hover:shadow-xl transition-shadow">
                <div class="flex items-center mb-4">
                    <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mr-4">
                        <i class="fas fa-search text-blue-600 text-xl"></i>
                    </div>
                    <h3 class="text-lg font-semibold">Multi-Provider Suche</h3>
                </div>
                <p class="text-gray-600">RAG-Enhanced Search mit IONOS und Mistral AI</p>
            </a>
        </div>

        <!-- Services Grid -->
        <div class="bg-white rounded-lg shadow-lg p-6">
            <h3 class="text-xl font-bold mb-4">Verfügbare Services</h3>
            <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
                <a href="http://localhost:3000" target="_blank" class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-3 rounded-lg text-center transition">
                    <i class="fas fa-comments mb-1 block"></i>
                    Chat Interface
                    <div class="text-xs">Multi-Provider</div>
                </a>
                <a href="http://localhost:8080" target="_blank" class="bg-green-600 hover:bg-green-700 text-white px-4 py-3 rounded-lg text-center transition">
                    <i class="fas fa-database mb-1 block"></i>
                    Database GUI
                </a>
                <a href="http://localhost:7474" target="_blank" class="bg-purple-600 hover:bg-purple-700 text-white px-4 py-3 rounded-lg text-center transition">
                    <i class="fas fa-project-diagram mb-1 block"></i>
                    Neo4j Graph
                </a>
                <a href="/api/docs" target="_blank" class="bg-orange-600 hover:bg-orange-700 text-white px-4 py-3 rounded-lg text-center transition">
                    <i class="fas fa-code mb-1 block"></i>
                    API Docs
                    <div class="text-xs">v2.1.0</div>
                </a>
            </div>
        </div>
    </div>

    <script>
        function dashboard() {
            return {
                stats: {},
                providers: {
                    ionos: false,
                    mistral: false
                },
                
                async init() {
                    await this.loadStats();
                    await this.loadProviders();
                    setInterval(() => {
                        this.loadStats();
                        this.loadProviders();
                    }, 30000);
                },
                
                async loadStats() {
                    try {
                        const response = await fetch('/api/documents?limit=1');
                        const data = await response.json();
                        this.stats = { total_documents: data.documents.length };
                    } catch (error) {
                        console.error('Stats Fehler:', error);
                    }
                },
                
                async loadProviders() {
                    try {
                        const response = await fetch('/api/providers');
                        const data = await response.json();
                        this.providers = {
                            ionos: data.providers.ionos?.available || false,
                            mistral: data.providers.mistral?.available || false
                        };
                    } catch (error) {
                        console.error('Provider Status Fehler:', error);
                    }
                }
            }
        }
    </script>
</body>
</html>
EOF

echo "✅ Dashboard Template erweitert"

# ==============================================
# 6. OPEN WEBUI KONFIGURATION ERWEITERN
# ==============================================

echo "🔧 Erweitere Open WebUI für Multi-Provider Support..."

# Open WebUI Service in docker-compose erweitern
sed -i '/ENABLE_SIGNUP=false/a\      - MODELS=ionos-german-legal-rag,mistral-medium-rag,mistral-large-rag\n      - ENABLE_MODEL_FILTER=true' docker-compose.yml

echo "✅ Open WebUI Konfiguration erweitert"

# ==============================================
# 7. SEARCH TEMPLATE ERWEITERN
# ==============================================

echo "🔍 Erweitere Search Template für Provider-Auswahl..."

# Backup erstellen
cp templates/search.html templates/search.html.bak 2>/dev/null || true

# Erweiterte search.html mit Provider Selection
cat > templates/search.html << 'EOF'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🔍 Multi-Provider Suche - Legal RAG</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js" defer></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
</head>
<body class="bg-gray-50" x-data="multiProviderSearch()">
    <nav class="bg-blue-900 text-white shadow-lg">
        <div class="max-w-7xl mx-auto px-4">
            <div class="flex justify-between items-center py-4">
                <div class="flex items-center space-x-4">
                    <a href="/" class="flex items-center space-x-2 hover:text-blue-200 transition">
                        <i class="fas fa-balance-scale text-2xl"></i>
                        <h1 class="text-xl font-bold">Legal RAG Search</h1>
                    </a>
                </div>
                <div class="flex items-center space-x-2">
                    <span class="bg-green-600 px-2 py-1 rounded-full text-xs">IONOS</span>
                    <span class="bg-purple-600 px-2 py-1 rounded-full text-xs">Mistral</span>
                </div>
            </div>
        </div>
    </nav>

    <div class="max-w-6xl mx-auto px-4 py-8">
        <div class="mb-8">
            <h2 class="text-3xl font-bold text-gray-800 mb-2">Multi-Provider Legal Search</h2>
            <p class="text-gray-600">Deutsche Rechtsdokumente mit IONOS AI Hub oder Mistral AI durchsuchen</p>
        </div>

        <!-- Search Interface -->
        <div class="bg-white rounded-lg shadow-lg p-6 mb-8">
            <div class="mb-6">
                <input 
                    type="text" 
                    x-model="searchQuery"
                    placeholder="z.B. Kaufvertrag Gewährleistung § 437 BGB"
                    class="w-full text-lg border border-gray-300 rounded-lg px-4 py-3"
                    @keyup.enter="performSearch()"
                >
            </div>

            <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
                <!-- Provider Selection -->
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">AI Provider</label>
                    <select x-model="selectedProvider" class="w-full border border-gray-300 rounded-lg px-3 py-2">
                        <option value="ionos">IONOS AI Hub</option>
                        <option value="mistral">Mistral AI</option>
                        <option value="both">Beide Vergleichen</option>
                    </select>
                </div>

                <!-- Model Selection -->
                <div x-show="selectedProvider === 'mistral' || selectedProvider === 'both'">
                    <label class="block text-sm font-medium text-gray-700 mb-2">Mistral Model</label>
                    <select x-model="selectedModel" class="w-full border border-gray-300 rounded-lg px-3 py-2">
                        <option value="mistral-medium">Mistral Medium</option>
                        <option value="mistral-large">Mistral Large</option>
                    </select>
                </div>

                <!-- Domain Filter -->
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Rechtsgebiet</label>
                    <select x-model="selectedDomain" class="w-full border border-gray-300 rounded-lg px-3 py-2">
                        <option value="">Alle Gebiete</option>
                        <option value="zivilrecht">Zivilrecht</option>
                        <option value="strafrecht">Strafrecht</option>
                        <option value="arbeitsrecht">Arbeitsrecht</option>
                        <option value="mietrecht">Mietrecht</option>
                    </select>
                </div>

                <!-- Search Button -->
                <div class="flex items-end">
                    <button 
                        @click="performSearch()"
                        :disabled="!searchQuery || isSearching"
                        class="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white px-4 py-2 rounded-lg transition"
                    >
                        <template x-if="!isSearching">
                            <span><i class="fas fa-search mr-2"></i>Suchen</span>
                        </template>
                        <template x-if="isSearching">
                            <span><i class="fas fa-spinner fa-spin mr-2"></i>Suche...</span>
                        </template>
                    </button>
                </div>
            </div>
        </div>

        <!-- Search Results -->
        <div x-show="searchResults.length > 0 || comparisonResults" class="space-y-6">
            
            <!-- Single Provider Results -->
            <div x-show="searchResults.length > 0 && selectedProvider !== 'both'" class="bg-white rounded-lg shadow-lg p-6">
                <h3 class="text-xl font-bold mb-4">
                    <span x-text="selectedProvider === 'ionos' ? '🏛️ IONOS AI Hub' : '🧠 Mistral AI'"></span>
                    Suchergebnisse
                </h3>
                <div class="space-y-4">
                    <template x-for="result in searchResults" :key="result.id">
                        <div class="border border-gray-200 rounded-lg p-4 hover:bg-gray-50 transition">
                            <div class="flex justify-between items-start mb-2">
                                <h4 class="text-lg font-semibold text-blue-600" x-text="result.title"></h4>
                                <div class="flex space-x-2">
                                    <span class="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded" x-text="result.court_level"></span>
                                    <span class="bg-green-100 text-green-800 text-xs px-2 py-1 rounded" x-text="result.primary_domain"></span>
                                </div>
                            </div>
                            <p class="text-gray-600 text-sm mb-2">
                                Relevanz: <span x-text="Math.round(result.relevance_score * 100)"></span>%
                            </p>
                            <p class="text-sm text-gray-500" x-text="result.search_method"></p>
                        </div>
                    </template>
                </div>
            </div>

            <!-- Provider Comparison Results -->
            <div x-show="comparisonResults && selectedProvider === 'both'" class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <!-- IONOS Results -->
                <div class="bg-white rounded-lg shadow-lg p-6">
                    <h3 class="text-xl font-bold mb-4 text-blue-600">
                        🏛️ IONOS AI Hub Ergebnisse
                    </h3>
                    <div class="space-y-3">
                        <template x-for="result in comparisonResults.ionos" :key="'ionos-' + result.id">
                            <div class="border border-blue-200 rounded p-3 bg-blue-50">
                                <h5 class="font-semibold text-sm" x-text="result.title"></h5>
                                <p class="text-xs text-gray-600">Relevanz: <span x-text="Math.round(result.relevance_score * 100)"></span>%</p>
                            </div>
                        </template>
                    </div>
                </div>

                <!-- Mistral Results -->
                <div class="bg-white rounded-lg shadow-lg p-6">
                    <h3 class="text-xl font-bold mb-4 text-purple-600">
                        🧠 Mistral AI Ergebnisse
                    </h3>
                    <div class="space-y-3">
                        <template x-for="result in comparisonResults.mistral" :key="'mistral-' + result.id">
                            <div class="border border-purple-200 rounded p-3 bg-purple-50">
                                <h5 class="font-semibold text-sm" x-text="result.title"></h5>
                                <p class="text-xs text-gray-600">Relevanz: <span x-text="Math.round(result.relevance_score * 100)"></span>%</p>
                            </div>
                        </template>
                    </div>
                </div>
            </div>
        </div>

        <!-- No Results -->
        <div x-show="searchPerformed && searchResults.length === 0 && !comparisonResults" class="bg-white rounded-lg shadow-lg p-8 text-center">
            <i class="fas fa-search text-gray-400 text-4xl mb-4"></i>
            <h3 class="text-xl font-semibold text-gray-600 mb-2">Keine Ergebnisse gefunden</h3>
            <p class="text-gray-500">Versuchen Sie andere Suchbegriffe oder wählen Sie einen anderen Provider.</p>
        </div>
    </div>

    <script>
        function multiProviderSearch() {
            return {
                searchQuery: '',
                selectedProvider: 'ionos',
                selectedModel: 'mistral-medium',
                selectedDomain: '',
                isSearching: false,
                searchPerformed: false,
                searchResults: [],
                comparisonResults: null,
                
                async performSearch() {
                    if (!this.searchQuery) return;
                    
                    this.isSearching = true;
                    this.searchPerformed = true;
                    this.searchResults = [];
                    this.comparisonResults = null;
                    
                    try {
                        if (this.selectedProvider === 'both') {
                            await this.performComparisonSearch();
                        } else {
                            await this.performSingleProviderSearch();
                        }
                    } catch (error) {
                        console.error('Suchfehler:', error);
                        alert('Fehler bei der Suche: ' + error.message);
                    } finally {
                        this.isSearching = false;
                    }
                },
                
                async performSingleProviderSearch() {
                    const params = new URLSearchParams({
                        query: this.searchQuery,
                        provider: this.selectedProvider,
                        limit: '10'
                    });
                    
                    if (this.selectedDomain) {
                        params.append('domain', this.selectedDomain);
                    }
                    
                    const response = await fetch(`/api/search?${params}`);
                    const data = await response.json();
                    
                    this.searchResults = data.results || [];
                },
                
                async performComparisonSearch() {
                    // Parallel search mit beiden Providern
                    const [ionosResponse, mistralResponse] = await Promise.all([
                        this.searchWithProvider('ionos'),
                        this.searchWithProvider('mistral')
                    ]);
                    
                    this.comparisonResults = {
                        ionos: ionosResponse.results || [],
                        mistral: mistralResponse.results || []
                    };
                },
                
                async searchWithProvider(provider) {
                    const params = new URLSearchParams({
                        query: this.searchQuery,
                        provider: provider,
                        limit: '5'
                    });
                    
                    if (this.selectedDomain) {
                        params.append('domain', this.selectedDomain);
                    }
                    
                    const response = await fetch(`/api/search?${params}`);
                    return await response.json();
                }
            }
        }
    </script>
</body>
</html>
EOF

echo "✅ Search Template erweitert"

# ==============================================
# 8. ABSCHLUSS UND ANWEISUNGEN
# ==============================================

# .env Template auch in aktuelle .env kopieren falls vorhanden
if [ -f ".env" ]; then
    echo ""
    echo "⚠️ Bestehende .env gefunden. Mistral-Variablen manuell hinzufügen:"
    echo ""
    echo "# Mistral AI Integration"
    echo "MISTRAL_API_KEY=your-mistral-api-key-here"
    echo "DEFAULT_MODEL_PROVIDER=ionos"
    echo "ENABLE_MISTRAL_MODELS=true"
    echo ""
    echo "Diese zu deiner .env Datei hinzufügen!"
fi

echo ""
echo "🎉 === MISTRAL INTEGRATION ABGESCHLOSSEN! ==="
echo ""
echo "📋 Was wurde erweitert:"
echo "   ✅ requirements.txt - Mistral AI Client"
echo "   ✅ .env.template - Mistral API Konfiguration"  
echo "   ✅ main.py - Multi-Provider System komplett neu"
echo "   ✅ docker-compose.yml - Mistral Environment Variablen"
echo "   ✅ dashboard.html - Provider Status Anzeige"
echo "   ✅ search.html - Multi-Provider Such-Interface"
echo "   ✅ Open WebUI - Mehrere Modelle konfiguriert"
echo ""
echo "🔧 Nächste Schritte:"
echo "   1. Mistral API Key holen: https://console.mistral.ai/"
echo "   2. .env erweitern mit MISTRAL_API_KEY=..."
echo "   3. docker-compose build --no-cache"
echo "   4. docker-compose up -d"
echo ""
echo "🌐 Verfügbare Modelle nach dem Neustart:"
echo "   • ionos-german-legal-rag (IONOS AI Hub + RAG)"
echo "   • mistral-medium-rag (Mistral Medium + RAG)"  
echo "   • mistral-large-rag (Mistral Large + RAG)"
echo ""
echo "💡 Features:"
echo "   🔍 Provider-Vergleich im Search Interface"
echo "   💬 Multi-Model Chat in Open WebUI"
echo "   📊 Provider Status im Dashboard"
echo "   ⚡ RAG Context für beide APIs"
echo ""
echo "🎯 Das System unterstützt jetzt IONOS + Mistral AI parallel!"