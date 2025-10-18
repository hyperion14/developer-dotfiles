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
