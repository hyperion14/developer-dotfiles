# 🚀 Claude Code Implementation: Flask Pipeline Container

**Projekt:** BHK Kanzlei RAG Hybrid-System  
**Datum:** 2025-10-29  
**Status Server:** PostgreSQL ✅ | Neo4j ✅ | Qdrant ⚠️ (unhealthy) | **Flask Pipeline ❌ FEHLT**

---

## 🎯 PRIORITÄT 1: Qdrant Health-Check beheben!

**Problem:** Dein Qdrant Container ist `unhealthy`!

### Debug-Steps (ZUERST):

```bash
# 1. Logs checken
docker logs bhk-qdrant

# 2. Health-Check Status
docker inspect bhk-qdrant | grep Health -A 10

# 3. Falls Port-Konflikt:
netstat -tulpn | grep 6333

# 4. Falls Daten korrupt:
docker-compose down
docker volume rm bhk_qdrant_data  # Achtung: löscht Daten!
docker-compose up -d qdrant
```

**Häufige Ursachen:**
- Port 6333/6334 bereits belegt
- Unvollständiger Shutdown (corrupt storage)
- Fehlende Berechtigung auf Volume

---

## 📦 Docker Compose: Flask Pipeline Container

### File: `docker-compose.yml` (Ergänzung)

```yaml
version: '3.8'

services:
  # EXISTIERENDE SERVICES (bereits laufend)
  postgres:
    image: postgres:16-alpine
    container_name: bhk-postgres
    environment:
      POSTGRES_DB: bhk_metadata
      POSTGRES_USER: bhk_user
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U bhk_user"]
      interval: 10s
      timeout: 5s
      retries: 5

  neo4j:
    image: neo4j:5.24-community
    container_name: bhk-neo4j
    environment:
      NEO4J_AUTH: neo4j/${NEO4J_PASSWORD}
      NEO4J_PLUGINS: '["apoc"]'
      NEO4J_dbms_memory_heap_max__size: 4G
    ports:
      - "7474:7474"  # Browser
      - "7687:7687"  # Bolt
    volumes:
      - neo4j_data:/data
      - neo4j_logs:/logs
      - ./neo4j_init:/var/lib/neo4j/import  # Schema-Init-Skript
    healthcheck:
      test: ["CMD-SHELL", "cypher-shell -u neo4j -p ${NEO4J_PASSWORD} 'RETURN 1'"]
      interval: 10s
      timeout: 5s
      retries: 5

  qdrant:
    image: qdrant/qdrant:v1.11.3
    container_name: bhk-qdrant
    ports:
      - "6333:6333"  # HTTP
      - "6334:6334"  # gRPC
    volumes:
      - qdrant_data:/qdrant/storage
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:6333/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5

  # NEU: FLASK PIPELINE CONTAINER
  flask-pipeline:
    build:
      context: ./flask_pipeline
      dockerfile: Dockerfile
    container_name: bhk-flask-pipeline
    environment:
      # Database Connections
      POSTGRES_HOST: bhk-postgres
      POSTGRES_PORT: 5432
      POSTGRES_DB: bhk_metadata
      POSTGRES_USER: bhk_user
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      
      NEO4J_URI: bolt://bhk-neo4j:7687
      NEO4J_USER: neo4j
      NEO4J_PASSWORD: ${NEO4J_PASSWORD}
      
      QDRANT_HOST: bhk-qdrant
      QDRANT_PORT: 6333
      
      # API Keys (aus .env)
      MISTRAL_API_KEY: ${MISTRAL_API_KEY}
      IONOS_S3_ACCESS_KEY: ${IONOS_S3_ACCESS_KEY}
      IONOS_S3_SECRET_KEY: ${IONOS_S3_SECRET_KEY}
      
      # Config
      FLASK_ENV: production
      LOG_LEVEL: INFO
      WORKERS: 4
    ports:
      - "5001:5000"  # Flask API
    volumes:
      - ./data/uploads:/app/uploads          # Temporäre PDF-Uploads
      - ./data/processing:/app/processing    # DocLing Output
      - ./logs:/app/logs                     # Application Logs
    depends_on:
      postgres:
        condition: service_healthy
      neo4j:
        condition: service_healthy
      qdrant:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:5000/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped
    networks:
      - bhk-network

networks:
  bhk-network:
    driver: bridge

volumes:
  postgres_data:
  neo4j_data:
  neo4j_logs:
  qdrant_data:
```

---

## 📂 Projektstruktur für Claude Code

### Zielstruktur (in VSCode erstellen):

```
bhk_rag_pipeline/
├── flask_pipeline/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py                    # Flask Hauptapp
│   ├── config/
│   │   ├── __init__.py
│   │   ├── settings.py           # Env-Variablen laden
│   │   └── logging_config.py     # Logging Setup
│   ├── pipeline/
│   │   ├── __init__.py
│   │   ├── docling_converter.py  # PDF → Markdown + doctags
│   │   ├── source_detector.py    # Quellentyp-Erkennung
│   │   ├── encoding_fixer.py     # UTF-8 Bereinigung
│   │   ├── extractors/           # Regel-basierte Extraktion
│   │   │   ├── __init__.py
│   │   │   ├── base_extractor.py
│   │   │   ├── beck_pdf.py
│   │   │   ├── juris_pdf.py
│   │   │   ├── beck_docx.py
│   │   │   └── bayoblg_pdf.py
│   │   ├── chunking/
│   │   │   ├── __init__.py
│   │   │   ├── strategies.py     # 5 Chunking-Strategien
│   │   │   └── metadata_parser.py
│   │   └── ner/
│   │       ├── __init__.py
│   │       ├── flair_extractor.py  # NER für Normen/Aktenzeichen
│   │       └── fundstellen_linker.py
│   ├── models/
│   │   ├── __init__.py
│   │   ├── database.py           # SQLAlchemy Models
│   │   ├── qdrant_schema.py      # Qdrant Collection Setup
│   │   ├── neo4j_schema.py       # Cypher Queries
│   │   └── sync_manager.py       # Qdrant ↔ Neo4j Sync
│   ├── api/
│   │   ├── __init__.py
│   │   ├── routes.py             # Flask Endpoints
│   │   ├── validators.py         # Pydantic Models
│   │   └── error_handlers.py
│   └── utils/
│       ├── __init__.py
│       ├── hash_utils.py         # SHA-256 für Dedup
│       └── s3_client.py          # IONOS S3 Upload
├── tests/
│   ├── __init__.py
│   ├── test_pipeline/
│   ├── test_models/
│   └── test_api/
├── data/
│   ├── uploads/                   # Temp Upload
│   ├── processing/                # DocLing Output
│   └── test_documents/            # Beispiel-PDFs
├── neo4j_init/
│   └── init_schema.cypher         # Schema-Initialisierung
├── logs/
├── .env.example
├── .env                           # NICHT COMMITTEN!
├── docker-compose.yml
└── README.md
```

---

## 🔧 Phase 1: Foundation (Tag 1-2)

### 1.1 Docker Setup

**File:** `flask_pipeline/Dockerfile`

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# System Dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Python Dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Application Code
COPY . .

# Create necessary directories
RUN mkdir -p /app/uploads /app/processing /app/logs

# Non-root user für Security
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose Port
EXPOSE 5000

# Health Check Endpoint
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Start Application
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--timeout", "120", "app:app"]
```

**File:** `flask_pipeline/requirements.txt`

```
# Web Framework
Flask==3.0.0
gunicorn==21.2.0
flask-cors==4.0.0

# PDF Processing
docling==0.18.0
pypdf2==3.0.1

# Vector & Graph DB
qdrant-client==1.7.0
neo4j==5.14.0
psycopg2-binary==2.9.9

# NER & Embeddings
flair==0.13.0
sentence-transformers==2.2.2

# Mistral API
mistralai==0.0.11

# S3 Storage
boto3==1.34.10

# Data Handling
pydantic==2.5.0
pydantic-settings==2.1.0
python-dotenv==1.0.0
pandas==2.1.4

# Utilities
loguru==0.7.2
tenacity==8.2.3  # Retry-Logic
tqdm==4.66.1

# Testing
pytest==7.4.3
pytest-asyncio==0.21.1
```

### 1.2 Environment Variables

**File:** `.env.example` (User kopiert zu `.env`)

```bash
# Database Credentials
POSTGRES_PASSWORD=change_me_secure_password
NEO4J_PASSWORD=change_me_neo4j_password

# API Keys
MISTRAL_API_KEY=your_mistral_api_key_here
IONOS_S3_ACCESS_KEY=your_ionos_s3_access_key
IONOS_S3_SECRET_KEY=your_ionos_s3_secret_key

# S3 Configuration
S3_BUCKET=bhk-rag-documents
S3_ENDPOINT=https://s3.de-central.io.cloud.ovh.net  # IONOS Endpoint

# Application Config
FLASK_ENV=production
LOG_LEVEL=INFO
WORKERS=4
```

### 1.3 Flask App Entry Point

**File:** `flask_pipeline/app.py`

```python
"""
Flask Application Entry Point
WICHTIG: Dies ist nur das Grundgerüst - Claude Code soll Details implementieren!
"""
from flask import Flask, jsonify
from config.settings import Settings
from config.logging_config import setup_logging
from api.routes import register_routes
from api.error_handlers import register_error_handlers
from models.database import init_db

def create_app():
    app = Flask(__name__)
    
    # Load Configuration
    settings = Settings()
    app.config.from_object(settings)
    
    # Setup Logging
    setup_logging(app.config['LOG_LEVEL'])
    
    # Initialize Database
    init_db(app)
    
    # Register Routes
    register_routes(app)
    
    # Register Error Handlers
    register_error_handlers(app)
    
    # Health Check Endpoint
    @app.route('/health', methods=['GET'])
    def health():
        return jsonify({
            'status': 'healthy',
            'version': '1.0.0',
            'services': {
                'postgres': check_postgres(),
                'neo4j': check_neo4j(),
                'qdrant': check_qdrant()
            }
        }), 200
    
    return app

if __name__ == '__main__':
    app = create_app()
    app.run(host='0.0.0.0', port=5000, debug=False)
```

---

## 🧩 Phase 2: Pipeline-Komponenten (Tag 3-7)

### 2.1 DocLing Converter

**File:** `flask_pipeline/pipeline/docling_converter.py`

**Spezifikation für Claude Code:**

```python
"""
DocLing PDF → Markdown Converter

AUFGABE:
- PDF einlesen via DocLing API
- Ausgabe: .md (Text) + .doctags (strukturierte XML-Tags)
- UTF-8 Encoding sicherstellen
- Error Handling für OCR-PDFs (>50MB)

KLASSE: DocLingConverter

METHODEN:
1. __init__(config: Dict)
   - Initialisiert DocLing Client
   - Lädt Konfiguration aus YAML

2. convert(pdf_path: str) -> Tuple[str, str]
   - Input: Pfad zur PDF
   - Output: (markdown_text, doctags_xml)
   - Raises: PDFConversionError bei Fehlern

3. _handle_ocr_pdf(pdf_path: str) -> Tuple[str, str]
   - Spezial-Handling für OCR-PDFs
   - Batch-Processing bei großen Files
   - Timeout-Management

ERROR HANDLING:
- PDFCorruptError → Warnung, Skip
- TimeoutError → OCR-Fallback
- EncodingError → UTF-8 Force

CONFIG (aus YAML):
- timeout: 120s
- ocr_threshold_mb: 50
- batch_size_ocr: 10  # Seiten pro Batch

TESTS:
- test_small_pdf_conversion (< 5MB)
- test_ocr_pdf_handling (> 50MB)
- test_encoding_validation
"""

# Claude Code: Implementiere gemäß Spezifikation!
```

### 2.2 Source Detector

**File:** `flask_pipeline/pipeline/source_detector.py`

**Spezifikation für Claude Code:**

```python
"""
Quellentyp-Erkennung für juristische Dokumente

AUFGABE:
- Analysiert .doctags und .md Content
- Bestimmt Quellentyp via Pattern-Matching
- 7 Dokumenttypen unterscheiden

ENUM: SourceType
- BECK_PDF: Beck-Online PDF (Leitsätze mit "Redaktionelle Leitsätze:")
- JURIS_PDF: Juris PDF (XML-Tag: <section_header_level_1>Leitsatz</...>)
- BECK_DOCX: Beck DOCX Export (Word-Artefakte)
- BAYOBLG_PDF: BayObLG-Entscheidungen (spezifisches Format)
- NEWSLETTER_PDF: Newsletter/Rundschreiben (unstrukturiert)
- IMAGE_ONLY: Scan ohne OCR (nur Bilder)

FUNKTION: detect_source_type(doctags: str, markdown: str) -> SourceType

PATTERN (Pseudo-Regex):
- BECK_PDF: r'Redaktionelle Leitsätze:' in doctags
- JURIS_PDF: r'>Leitsatz</section_header_level_1>' in doctags
- BECK_DOCX: r'<word-artifact>' AND kein PDF-Marker
- BAYOBLG_PDF: r'BayObLG.*Beschluss' in doctags[:1000]
- IMAGE_ONLY: len(markdown) < 100 AND '<image' in doctags

TESTS:
- 1 Testfile pro Quellentyp (7 PDFs)
- Edge Case: OCR-Artefakte im Text
- False Positive Prevention

CONFIDENCE SCORE:
- Rückgabe: (SourceType, confidence: float)
- Bei confidence < 0.7 → MANUAL_REVIEW
"""

# Claude Code: Implementiere mit Pattern-Matching!
```

### 2.3 Leitsatz-Extraktoren

**File:** `flask_pipeline/pipeline/extractors/beck_pdf.py`

**Spezifikation für Claude Code:**

```python
"""
Beck PDF Leitsatz-Extraktor (Regel-basiert)

AUFGABE:
- Extrahiert Leitsätze aus Beck-PDF-Format
- Pattern: "Redaktionelle Leitsätze:" gefolgt von nummerierten Absätzen
- Verknüpft mit Randnummern falls vorhanden

PYDANTIC MODEL: Leitsatz
```python
from pydantic import BaseModel, field_validator

class Leitsatz(BaseModel):
    nummer: int
    text: str
    randnummer_start: Optional[int] = None
    randnummer_end: Optional[int] = None
    fundstelle_id: Optional[str] = None
    quelle: str = 'beck_pdf'
    confidence: float = 1.0
    
    @field_validator('text')
    def validate_text(cls, v):
        if len(v) < 50:
            raise ValueError("Leitsatz zu kurz (< 50 Zeichen)")
        if '<' in v or '>' in v:
            raise ValueError("HTML/XML-Tags im Text")
        return v
```

REGEX-PATTERN:
```python
RANDNUMMER_PATTERN = r'\(Rn\.\s*(\d+)(?:\s*-\s*(\d+))?\)'
# Matches: "(Rn. 19 - 29)" oder "(Rn.58)"

LEITSATZ_START = r'(?:Redaktionelle\s+)?Leitsätze?:?\s*'
LEITSATZ_ITEM = r'(\d+)\.\s+(.+?)(?=\n\d+\.\s+|\Z)'
```

METHODE: extract_leitsaetze(doctags: str) -> List[Leitsatz]

WORKFLOW:
1. Finde "Redaktionelle Leitsätze:" im doctags
2. Extrahiere nummerierten Block (1. ... 2. ... 3. ...)
3. Parse Randnummern aus jeder Leitsatz-Zeile
4. Validiere Länge & Plausibilität
5. Return List[Leitsatz]

TESTS:
- BeckO_134_OCR.doctags: Erwartet 4 Leitsätze
- Randnummern: (Rn. 19 - 29) korrekt geparst
- Edge Case: Kein Leitsatz → leere Liste
"""

# Claude Code: Implementiere mit Regex + Pydantic!
```

### 2.4 NER Extractor (Flair)

**File:** `flask_pipeline/pipeline/ner/flair_extractor.py`

**Spezifikation für Claude Code:**

```python
"""
Named Entity Recognition für juristische Entitäten

AUFGABE:
- Extrahiert Normen (§ 97 GWB), Aktenzeichen, Gerichte
- Nutzt Flair-Modell: ner-german-legal
- Batch-Processing für Performance

KLASSE: FlairNERExtractor

METHODEN:
1. __init__()
   - Lädt Flair-Modell (lazy loading)
   - Model: ner-german-legal

2. extract_entities(text: str) -> Dict[str, List[str]]
   - Input: Markdown-Text
   - Output: {
       'normen': ['§ 97 GWB', '§ 134 BGB'],
       'aktenzeichen': ['VIII ZR 123/19'],
       'gerichte': ['BGH', 'OLG Karlsruhe']
     }

3. batch_extract(texts: List[str], batch_size: int = 32) -> List[Dict]
   - Batch-Processing für Performance
   - Nutzt Flair's BatchPredict

ENTITY TYPES (Flair-Tags):
- NORM: Gesetzesverweise (§, Art., Abs.)
- AKTENZEICHEN: Gerichts-Aktenzeichen
- GERICHT: Gerichtsname
- DATUM: Entscheidungsdatum (optional)

POST-PROCESSING:
- Deduplizierung
- Normalisierung (§97 GWB → § 97 GWB)
- Validierung (Plausibilitäts-Check)

PERFORMANCE:
- Batch-Size: 32 für Flair
- Timeout: 30s pro Dokument
- Caching für häufige Entitäten

TESTS:
- test_norm_extraction: "§ 97 GWB" erkannt
- test_aktenzeichen: "VIII ZR 123/19" korrekt
- test_batch_processing: 100 Dokumente < 60s
"""

# Claude Code: Implementiere mit Flair!
```

### 2.5 Fundstellen-Linker

**File:** `flask_pipeline/pipeline/ner/fundstellen_linker.py`

**Spezifikation für Claude Code:**

```python
"""
Verknüpft Leitsätze mit Fundstellen (Atomare Rechtsprechungsreferenzen)

KRITISCHES PRINZIP:
Fundstellen sind UNTRENNBARE Einheiten:
  "BGH, Urt. v. 01.03.2025, Az. VII ZR 736/25"
  
NIEMALS trennen zwischen: Gericht, Datum, Aktenzeichen!

AUFGABE:
- Findet Fundstellen im Text
- Erstellt Neo4j-Nodes für fehlende Referenzen
- Verknüpft Leitsätze mit Fundstellen

REGEX-PATTERN:
```python
FUNDSTELLE_PATTERN = r'''
    (?P<gericht>BGH|OLG|VK[\w\s]+)  # Gericht
    (?:,\s+)?                        # Optionales Komma
    (?P<typ>Urt\.|Beschl\.)?        # Urteil/Beschluss
    (?:\s+v\.|vom\s+)?               # "vom" oder "v."
    (?P<datum>\d{1,2}\.\d{1,2}\.\d{4})  # Datum
    \s*-?\s*                         # Trennzeichen
    (?:Az\.\s+)?                     # "Az." optional
    (?P<aktenzeichen>[\w\s]+/\d+)   # Aktenzeichen
'''
```

FUNKTION: link_fundstellen(leitsatz: Leitsatz, text: str) -> List[FundstellenLink]

WORKFLOW:
1. Finde alle Fundstellen im Text via Regex
2. Für jede Fundstelle:
   a. Check Neo4j: Existiert bereits?
   b. Falls nein: Create Node mit volltext_verfuegbar=False
   c. Inkrementiere reference_count
   d. Berechne acquisition_priority
3. Verknüpfe Leitsatz → Fundstelle (ZITIERT-Relation)

NEO4J-NODE (Missing Reference):
```cypher
CREATE (f:Fundstelle {
  id: 'bgh-2025-vii-zr-736-25',
  aktenzeichen: 'VII ZR 736/25',
  gericht: 'BGH',
  datum: date('2025-03-01'),
  volltext_verfuegbar: false,
  reference_count: 1,
  acquisition_priority: 100,  # Initial
  first_referenced: datetime()
})
```

TESTS:
- test_fundstelle_extraction: Pattern matched korrekt
- test_neo4j_node_creation: Node erstellt
- test_duplicate_handling: reference_count inkrementiert
"""

# Claude Code: Implementiere mit Neo4j!
```

---

## 🗄️ Phase 3: Datenbank-Integration (Tag 8-10)

### 3.1 Qdrant Schema Setup

**File:** `flask_pipeline/models/qdrant_schema.py`

**Spezifikation für Claude Code:**

```python
"""
Qdrant Collection Setup & Management

AUFGABE:
- Erstellt Qdrant Collection mit korrektem Schema
- Payload-Struktur gemäß Datenschicht-Strategie
- Batch-Upsert für Performance

COLLECTION CONFIG:
- Name: 'vergaberecht_leitsaetze' (initial, später mehr Collections)
- Vector Size: 1024 (Mistral Embed)
- Distance: COSINE
- Optimizers: High Performance Config

PAYLOAD STRUCTURE:
```json
{
  "chunk_id": "uuid-v4",
  "chunk_text": "Leitsatz-Text hier...",
  "chunk_type": "leitsatz",
  "metadata": {
    "gericht": "BGH",
    "datum": "2025-03-01",
    "aktenzeichen": "VII ZR 736/25",
    "normen": ["§ 97 GWB", "§ 134 BGB"],
    "rechtsgebiet": "vergaberecht",
    "teilrechtsgebiet": ["baurecht"],
    "leitsatz_nummer": 1,
    "randnummer_start": 19,
    "randnummer_end": 29,
    "fundstelle_id": "bgh-2025-vii-zr-736-25",
    "source_file": "urteil_bgh_2025.pdf"
  }
}
```

METHODEN:
1. create_collection(collection_name: str)
   - Erstellt Collection mit Config
   - Idempotent (skip if exists)

2. upsert_chunks(chunks: List[Dict], embeddings: List[List[float]])
   - Batch-Upsert (100 Chunks/Request)
   - Error Handling: Partial Success

3. search(query_vector: List[float], filters: Dict, limit: int = 10)
   - Hybrid Search (Vector + Metadata Filter)
   - Example Filter:
     ```python
     filters = {
         "must": [
             {"key": "metadata.gericht", "match": {"value": "BGH"}},
             {"key": "metadata.datum", "range": {"gte": "2020-01-01"}}
         ]
     }
     ```

TESTS:
- test_collection_creation: Collection existiert
- test_upsert: 100 Chunks eingefügt
- test_hybrid_search: Filter + Vector funktioniert
"""

# Claude Code: Implementiere mit Qdrant Client!
```

### 3.2 Neo4j Schema Initialisierung

**File:** `neo4j_init/init_schema.cypher`

**Spezifikation für Claude Code:**

```cypher
// ========================================
// Neo4j Schema-Initialisierung
// Ausführen: cypher-shell -f init_schema.cypher
// ========================================

// 1. CONSTRAINTS (Unique IDs)
CREATE CONSTRAINT fundstelle_id IF NOT EXISTS
FOR (f:Fundstelle) REQUIRE f.id IS UNIQUE;

CREATE CONSTRAINT leitsatz_chunk_id IF NOT EXISTS
FOR (c:LeitsatzChunk) REQUIRE c.chunk_id IS UNIQUE;

CREATE CONSTRAINT norm_id IF NOT EXISTS
FOR (n:Norm) REQUIRE n.id IS UNIQUE;

// 2. INDICES (Performance)
CREATE INDEX fundstelle_datum IF NOT EXISTS
FOR (f:Fundstelle) ON (f.datum);

CREATE INDEX fundstelle_gericht IF NOT EXISTS
FOR (f:Fundstelle) ON (f.gericht);

CREATE INDEX chunk_type IF NOT EXISTS
FOR (c:LeitsatzChunk) ON (c.chunk_type);

CREATE INDEX norm_text IF NOT EXISTS
FOR (n:Norm) ON (n.text);

// 3. FULLTEXT SEARCH INDEX
CREATE FULLTEXT INDEX leitsatz_fulltext IF NOT EXISTS
FOR (c:LeitsatzChunk)
ON EACH [c.chunk_text];

// 4. EXAMPLE NODES (für Testing)
// Fundstelle mit Volltext
MERGE (f1:Fundstelle {
  id: 'bgh-2020-vii-zr-123-19',
  aktenzeichen: 'VII ZR 123/19',
  gericht: 'BGH',
  datum: date('2020-03-15'),
  volltext_verfuegbar: true,
  reference_count: 0,
  acquisition_priority: 0
});

// Fundstelle ohne Volltext (Missing Reference)
MERGE (f2:Fundstelle {
  id: 'olg-karlsruhe-2025-15-verg-9-25',
  aktenzeichen: '15 Verg 9/25',
  gericht: 'OLG Karlsruhe',
  datum: date('2025-07-31'),
  volltext_verfuegbar: false,
  reference_count: 3,  // Wird von 3 Leitsätzen zitiert
  acquisition_priority: 300  // Hohe Priorität!
});

// Norm-Node
MERGE (n1:Norm {
  id: 'gwb-97',
  text: '§ 97 GWB',
  gesetz: 'GWB',
  paragraph: '97'
});

// ========================================
// BEISPIEL QUERY: Top Missing References
// ========================================
// Findet die 10 am häufigsten zitierten fehlenden Urteile
MATCH (f:Fundstelle)
WHERE f.volltext_verfuegbar = false
  AND f.reference_count > 0
RETURN f.aktenzeichen, f.gericht, f.datum, f.reference_count, f.acquisition_priority
ORDER BY f.acquisition_priority DESC
LIMIT 10;
```

### 3.3 Sync Manager (Qdrant ↔ Neo4j)

**File:** `flask_pipeline/models/sync_manager.py`

**Spezifikation für Claude Code:**

```python
"""
Synchronisiert Daten zwischen Qdrant und Neo4j

AUFGABE:
- Bidirektionaler Sync (Qdrant → Neo4j, Neo4j → Qdrant)
- Transaktionale Sicherheit (Rollback bei Fehler)
- Idempotenz (doppelte Ausführung safe)

KLASSE: SyncManager

METHODEN:
1. __init__(qdrant_client, neo4j_driver)
   - Initialisiert beide Clients

2. sync_leitsatz_to_both(
     leitsatz: Leitsatz, 
     embedding: List[float]
   ) -> SyncResult
   
   WORKFLOW:
   a. START TRANSACTION
   b. Upsert in Qdrant (chunk_id, vector, payload)
   c. Create in Neo4j:
      - LeitsatzChunk-Node
      - Fundstelle-Node (falls nicht existiert)
      - ZITIERT-Relation
      - ENTHAELT_NORM-Relationen
   d. COMMIT oder ROLLBACK
   
   ERROR HANDLING:
   - QdrantError → Rollback Neo4j
   - Neo4jError → Delete aus Qdrant
   - Partial Success → Retry-Queue

3. verify_sync(chunk_id: str) -> bool
   - Check: Existiert in beiden DBs?
   - Check: Payload konsistent?

TRANSAKTIONS-LOGIK:
```python
def sync_leitsatz_to_both(self, leitsatz, embedding):
    qdrant_success = False
    neo4j_session = None
    
    try:
        # 1. Qdrant Upsert
        self.qdrant.upsert(...)
        qdrant_success = True
        
        # 2. Neo4j Transaction
        with self.neo4j.session() as session:
            neo4j_session = session
            session.write_transaction(create_leitsatz_node, leitsatz)
            session.write_transaction(link_to_fundstelle, leitsatz)
        
        return SyncResult(success=True, chunk_id=leitsatz.chunk_id)
    
    except QdrantException as e:
        # Neo4j noch nicht gestartet → sicher
        raise SyncError(f"Qdrant failed: {e}")
    
    except Neo4jException as e:
        # Rollback: Lösche aus Qdrant
        if qdrant_success:
            self.qdrant.delete(points=[leitsatz.chunk_id])
        raise SyncError(f"Neo4j failed, Qdrant rolled back: {e}")
```

TESTS:
- test_successful_sync: Beide DBs enthalten Daten
- test_qdrant_failure_rollback: Neo4j nicht betroffen
- test_neo4j_failure_rollback: Qdrant cleaned up
"""

# Claude Code: Implementiere transaktional!
```

---

## 🌐 Phase 4: Flask API Endpoints (Tag 11-12)

### 4.1 API Routes

**File:** `flask_pipeline/api/routes.py`

**Spezifikation für Claude Code:**

```python
"""
Flask REST API Endpoints

ENDPOINTS:
1. POST /api/v1/upload
   - Upload PDF für Processing
   - Returns: job_id (async processing)

2. GET /api/v1/status/{job_id}
   - Check Processing Status
   - Returns: {status, progress, errors}

3. POST /api/v1/search
   - Hybrid RAG Search
   - Body: {query, filters, limit}
   - Returns: {results: [chunks], metadata}

4. GET /api/v1/missing-references
   - Top N fehlende Fundstellen
   - Query Params: ?limit=10&min_references=3
   - Returns: {fundstellen: [{aktenzeichen, reference_count, priority}]}

5. GET /api/v1/health
   - Health Check (bereits in app.py)
   - Returns: {status, services}

BEISPIEL IMPLEMENTATION:

@app.route('/api/v1/upload', methods=['POST'])
def upload_document():
    '''
    Upload PDF und starte async Processing
    '''
    if 'file' not in request.files:
        return jsonify({'error': 'No file uploaded'}), 400
    
    file = request.files['file']
    if not file.filename.endswith('.pdf'):
        return jsonify({'error': 'Only PDF files allowed'}), 400
    
    # Save temporarily
    upload_path = os.path.join(app.config['UPLOAD_FOLDER'], file.filename)
    file.save(upload_path)
    
    # Start async processing
    job_id = str(uuid.uuid4())
    process_pipeline.delay(job_id, upload_path)  # Celery Task
    
    return jsonify({
        'job_id': job_id,
        'status': 'processing',
        'filename': file.filename
    }), 202


@app.route('/api/v1/search', methods=['POST'])
def search():
    '''
    Hybrid RAG Search in Qdrant + Neo4j
    '''
    data = request.get_json()
    query = data.get('query')
    filters = data.get('filters', {})
    limit = data.get('limit', 10)
    
    # Validate Input
    if not query:
        return jsonify({'error': 'Query required'}), 400
    
    # Embed Query
    embedding = mistral_client.embed(query)
    
    # Qdrant Search
    qdrant_results = qdrant_client.search(
        collection_name='vergaberecht_leitsaetze',
        query_vector=embedding,
        query_filter=filters,
        limit=limit
    )
    
    # Neo4j Context Enrichment
    enriched_results = []
    for result in qdrant_results:
        fundstelle = neo4j_get_fundstelle(result.payload['metadata']['fundstelle_id'])
        enriched_results.append({
            'text': result.payload['chunk_text'],
            'score': result.score,
            'metadata': result.payload['metadata'],
            'fundstelle': fundstelle,
            'related_normen': neo4j_get_related_normen(fundstelle['id'])
        })
    
    return jsonify({
        'results': enriched_results,
        'total': len(enriched_results)
    }), 200
```

TESTS:
- test_upload_pdf: File gespeichert, job_id returned
- test_search_hybrid: Qdrant + Neo4j Daten kombiniert
- test_missing_references: Top 10 korrekt sortiert
"""

# Claude Code: Implementiere REST API!
```

---

## 🧪 Phase 5: Testing & Validation (Tag 13-14)

### 5.1 Unit Tests

**File:** `tests/test_pipeline/test_docling_converter.py`

```python
"""
Unit Tests für DocLing Converter

pytest tests/test_pipeline/test_docling_converter.py -v
"""
import pytest
from pipeline.docling_converter import DocLingConverter

@pytest.fixture
def converter():
    return DocLingConverter(config={'timeout': 60})

def test_small_pdf_conversion(converter):
    """Test: Kleine PDF (<5MB) konvertiert korrekt"""
    md, doctags = converter.convert('data/test_documents/small_urteil.pdf')
    
    assert len(md) > 100
    assert '<section_header' in doctags
    assert 'Leitsatz' in md or 'Leitsatz' in doctags

def test_ocr_pdf_handling(converter):
    """Test: OCR-PDF mit Timeout-Handling"""
    md, doctags = converter.convert('data/test_documents/large_ocr.pdf')
    
    # Falls Timeout: Fallback aktiv
    assert md is not None
    # Kann kürzer sein bei OCR-Problemen

def test_encoding_validation(converter):
    """Test: UTF-8 Encoding korrekt"""
    md, doctags = converter.convert('data/test_documents/umlaute.pdf')
    
    assert 'ä' in md or 'ö' in md or 'ü' in md  # Umlaute erhalten
    assert '\\x' not in md  # Keine Hex-Escapes
```

### 5.2 Integration Tests

**File:** `tests/test_integration/test_full_pipeline.py`

```python
"""
End-to-End Pipeline Test

pytest tests/test_integration/test_full_pipeline.py -v
"""
import pytest
from pipeline.docling_converter import DocLingConverter
from pipeline.source_detector import detect_source_type, SourceType
from pipeline.extractors.beck_pdf import BeckPDFExtractor
from models.sync_manager import SyncManager

def test_full_pipeline_beck_pdf():
    """Test: Vollständiger Durchlauf Beck-PDF → Qdrant/Neo4j"""
    
    # 1. Convert
    converter = DocLingConverter()
    md, doctags = converter.convert('data/test_documents/BeckO_134_OCR.pdf')
    
    # 2. Detect Source
    source_type, confidence = detect_source_type(doctags, md)
    assert source_type == SourceType.BECK_PDF
    assert confidence > 0.9
    
    # 3. Extract Leitsätze
    extractor = BeckPDFExtractor()
    leitsaetze = extractor.extract_leitsaetze(doctags)
    assert len(leitsaetze) == 4  # Erwartete Anzahl
    
    # 4. NER Extraction
    from pipeline.ner.flair_extractor import FlairNERExtractor
    ner = FlairNERExtractor()
    entities = ner.extract_entities(md)
    assert len(entities['normen']) > 0
    
    # 5. Fundstellen-Linking
    from pipeline.ner.fundstellen_linker import link_fundstellen
    links = link_fundstellen(leitsaetze[0], md)
    assert len(links) > 0
    
    # 6. Embedding
    from mistralai.client import MistralClient
    mistral = MistralClient(api_key=os.getenv('MISTRAL_API_KEY'))
    embedding = mistral.embeddings(
        model='mistral-embed',
        input=[leitsaetze[0].text]
    ).data[0].embedding
    
    # 7. Sync zu Qdrant + Neo4j
    sync = SyncManager(qdrant_client, neo4j_driver)
    result = sync.sync_leitsatz_to_both(leitsaetze[0], embedding)
    assert result.success
    
    # 8. Verify Sync
    assert sync.verify_sync(leitsaetze[0].chunk_id)
```

---

## 🚀 Deployment & Startup

### Schritt 1: Qdrant Health fixen (ZUERST!)

```bash
# Logs checken
docker logs bhk-qdrant

# Neustart mit Clean Slate
docker-compose down
docker volume rm bhk_qdrant_data  # ACHTUNG: Löscht Daten!
docker-compose up -d qdrant

# Health Check warten (30s)
watch -n 2 'docker ps --filter name=bhk-qdrant'
```

### Schritt 2: Build Flask Container

```bash
# In Projektordner
cd bhk_rag_pipeline

# Environment Variables setzen
cp .env.example .env
# WICHTIG: .env editieren mit echten Credentials!

# Docker Image bauen
docker-compose build flask-pipeline

# Starten
docker-compose up -d flask-pipeline

# Logs verfolgen
docker-compose logs -f flask-pipeline
```

### Schritt 3: Health Check

```bash
# API Health Check
curl http://localhost:5001/health

# Erwartete Antwort:
{
  "status": "healthy",
  "version": "1.0.0",
  "services": {
    "postgres": "ok",
    "neo4j": "ok",
    "qdrant": "ok"
  }
}
```

### Schritt 4: Test mit Beispiel-PDF

```bash
# Upload via API
curl -X POST http://localhost:5001/api/v1/upload \
  -F "file=@data/test_documents/test_urteil.pdf"

# Response:
{
  "job_id": "abc-123-def",
  "status": "processing",
  "filename": "test_urteil.pdf"
}

# Status abfragen
curl http://localhost:5001/api/v1/status/abc-123-def
```

---

## 📊 Monitoring & Debugging

### Logs anschauen

```bash
# Flask App Logs
docker-compose logs -f flask-pipeline

# Qdrant Logs
docker-compose logs -f qdrant

# Neo4j Logs
docker-compose logs -f neo4j

# Alle Logs
docker-compose logs -f
```

### Performance Metrics

```bash
# Container Stats
docker stats bhk-flask-pipeline bhk-qdrant bhk-neo4j

# Qdrant Metrics
curl http://localhost:6333/metrics

# Neo4j Metrics (Browser)
# http://localhost:7474/browser/
```

---

## ✅ Success Criteria

### Phase 1: Foundation ✅
- [ ] Docker Containers alle healthy
- [ ] Flask API erreichbar (Port 5001)
- [ ] Health Endpoint liefert alle Services OK

### Phase 2: Pipeline ✅
- [ ] 5 Test-PDFs erfolgreich konvertiert (DocLing)
- [ ] Quellentyp-Erkennung 100% korrekt (7 Typen)
- [ ] Leitsätze korrekt extrahiert (Beck, Juris, BayObLG)
- [ ] NER erkennt Normen mit >95% Precision
- [ ] Fundstellen-Linking funktioniert

### Phase 3: Datenbanken ✅
- [ ] Qdrant Collection erstellt, 50+ Chunks eingefügt
- [ ] Neo4j Schema initialisiert, Constraints aktiv
- [ ] Sync funktioniert (Qdrant ↔ Neo4j konsistent)
- [ ] Missing References Tracking aktiv (10+ Nodes)

### Phase 4: API ✅
- [ ] Upload-Endpoint nimmt PDFs an
- [ ] Search-Endpoint liefert hybride Ergebnisse
- [ ] Missing References Endpoint zeigt Top 10
- [ ] Error Handling funktioniert (400, 500 Codes)

### Phase 5: Testing ✅
- [ ] 20+ Unit Tests (alle grün)
- [ ] 5+ Integration Tests (End-to-End)
- [ ] Performance: 1 PDF in <10s
- [ ] Keine Memory Leaks (12h Dauerbetrieb)

---

## 🎯 NÄCHSTE SCHRITTE FÜR CLAUDE CODE

### 🔴 PRIORITÄT 1: Qdrant Health fixen
1. Logs analysieren
2. Port-Konflikte prüfen
3. Volume zurücksetzen falls nötig

### 🟠 PRIORITÄT 2: Docker Setup
1. `docker-compose.yml` ergänzen (Flask Container)
2. `Dockerfile` erstellen
3. `requirements.txt` finalisieren
4. `.env` Template erstellen

### 🟡 PRIORITÄT 3: Pipeline Foundation
1. `app.py` - Flask Entry Point
2. `config/settings.py` - Environment Loading
3. `pipeline/docling_converter.py`
4. `pipeline/source_detector.py`

### 🟢 PRIORITÄT 4: Extraktoren
1. `extractors/beck_pdf.py`
2. `extractors/juris_pdf.py`
3. `ner/flair_extractor.py`
4. `ner/fundstellen_linker.py`

### 🔵 PRIORITÄT 5: Datenbanken & API
1. `models/qdrant_schema.py`
2. `models/neo4j_schema.py` + `init_schema.cypher`
3. `models/sync_manager.py`
4. `api/routes.py`

### ⚪ PRIORITÄT 6: Testing
1. Unit Tests (alle Komponenten)
2. Integration Tests (End-to-End)
3. Performance Tests (Batch Processing)

---

## 📚 Referenz-Dokumente im Projektspeicher

- `SYSTEM_PROMPT_BHK_RAG.md` - Arbeitsweise & Prinzipien
- `03_Implementierungsanweisungen.md` - Detaillierte Specs
- `Adaptive_Chunking__Strategien___Implementierungsplan.md` - Chunking-Logik
- `Sync-Strategie__Qdrant___Neo4j.md` - Sync-Details
- `Neo4j_Cypher_Schema-Initialisierung.txt` - Cypher-Queries
- `ner_extractor_SPEC.py` - NER-Spezifikation
- `Datenschicht-Strategie__Rechtsgebiete___Architektur.txt` - Schema-Design

---

**Status:** 📋 READY FOR IMPLEMENTATION  
**Ziel:** 15 Tage bis Produktionsreife  
**Kontakt:** Bei Fragen zurück zum Chat, nicht alles im Code lösen!

**LOS GEHT'S! 🚀**