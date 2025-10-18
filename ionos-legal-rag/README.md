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
