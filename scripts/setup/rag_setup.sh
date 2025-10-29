#!/bin/bash
# =====================================================
# BHK RAG System: Automated Setup Script
# =====================================================
# Führt alle Setup-Schritte aus 00_SETUP_COMPLETE.md automatisch aus
# Usage: ./setup_bhk_rag.sh

set -e  # Exit on error

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Header
echo "=========================================="
echo "  BHK RAG System - Automated Setup"
echo "=========================================="
echo ""

# =====================================================
# Phase 1: System Check
# =====================================================
log_info "Phase 1: System-Checks..."

# OS Check
if [[ ! -f /etc/os-release ]]; then
    log_error "OS nicht erkannt. Ubuntu 24 erforderlich!"
    exit 1
fi

source /etc/os-release
if [[ "$ID" != "ubuntu" ]]; then
    log_warning "Nicht Ubuntu erkannt. Fortfahren? (y/n)"
    read -r response
    if [[ "$response" != "y" ]]; then
        exit 1
    fi
fi

# RAM Check
total_ram=$(free -g | awk '/^Mem:/{print $2}')
if [[ $total_ram -lt 30 ]]; then
    log_error "Nicht genug RAM! Benötigt: 32GB, gefunden: ${total_ram}GB"
    exit 1
fi
log_success "RAM OK: ${total_ram}GB"

# CPU Check
cpu_cores=$(nproc)
if [[ $cpu_cores -lt 6 ]]; then
    log_warning "Nur ${cpu_cores} CPU Cores (empfohlen: 8+)"
else
    log_success "CPU OK: ${cpu_cores} Cores"
fi

# Disk Space Check
free_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [[ $free_space -lt 100 ]]; then
    log_error "Nicht genug Disk Space! Benötigt: 100GB, frei: ${free_space}GB"
    exit 1
fi
log_success "Disk Space OK: ${free_space}GB frei"

# =====================================================
# Phase 2: System Dependencies
# =====================================================
log_info "Phase 2: Installiere System-Dependencies..."

# Update Package Lists
sudo apt update -qq

# Install Core Tools
log_info "Installiere Core-Tools..."
sudo apt install -y -qq \
    build-essential \
    git \
    curl \
    wget \
    vim \
    htop \
    tree \
    python3.11 \
    python3.11-venv \
    python3-pip \
    tesseract-ocr \
    tesseract-ocr-deu \
    > /dev/null 2>&1

log_success "Core-Tools installiert"

# Docker
if ! command -v docker &> /dev/null; then
    log_info "Installiere Docker..."
    sudo apt install -y -qq docker.io docker-compose > /dev/null 2>&1
    sudo usermod -aG docker $USER
    log_success "Docker installiert (Neuanmeldung für Berechtigungen erforderlich)"
else
    log_success "Docker bereits installiert"
fi

# Poetry
if ! command -v poetry &> /dev/null; then
    log_info "Installiere Poetry..."
    curl -sSL https://install.python-poetry.org | python3 - > /dev/null 2>&1
    export PATH="$HOME/.local/bin:$PATH"
    log_success "Poetry installiert"
else
    log_success "Poetry bereits installiert"
fi

# =====================================================
# Phase 3: Projektstruktur
# =====================================================
log_info "Phase 3: Erstelle Projektstruktur..."

PROJECT_ROOT="$HOME/bhk-rag-system"

if [[ -d "$PROJECT_ROOT" ]]; then
    log_warning "Projekt existiert bereits in $PROJECT_ROOT"
    log_warning "Überschreiben? (y/n)"
    read -r response
    if [[ "$response" != "y" ]]; then
        log_info "Setup abgebrochen"
        exit 0
    fi
    log_info "Erstelle Backup..."
    mv "$PROJECT_ROOT" "${PROJECT_ROOT}_backup_$(date +%Y%m%d_%H%M%S)"
fi

mkdir -p "$PROJECT_ROOT"
cd "$PROJECT_ROOT"

# Create directory structure
log_info "Erstelle Verzeichnisstruktur..."
mkdir -p {src,tests,config,data,docs,scripts}
mkdir -p src/{ingestion,retrieval,orchestration,api,models}
mkdir -p src/ingestion/{docling,ner,chunking,parsers}
mkdir -p data/{raw,processed,test-docs,logs}
mkdir -p config/{qdrant,neo4j,mistral}
mkdir -p tests/{unit,integration,fixtures}
mkdir -p docker/{qdrant,neo4j,api}
mkdir -p data/test-docs/{beck_pdf,juris_pdf,beck_docx,ocr_pdf,newsletter,internal}

log_success "Projektstruktur erstellt"

# =====================================================
# Phase 4: Git Setup
# =====================================================
log_info "Phase 4: Git-Repository initialisieren..."

git init > /dev/null 2>&1

# .gitignore
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
.Python
venv/
ENV/
.venv
*.egg-info/
.pytest_cache/
.ruff_cache/

# IDEs
.vscode/
.idea/
*.swp
*.swo

# Data & Logs
data/raw/*
data/processed/*
data/logs/*
*.log

# Secrets
.env
.env.local
*.pem
*.key
config/secrets/

# Docker
docker-compose.override.yml

# OS
.DS_Store
Thumbs.db

# Project-specific
neo4j/data/
neo4j/logs/
qdrant/storage/
EOF

# README
cat > README.md << 'EOF'
# BHK RAG System

Hybrid RAG-System für juristische Dokumente (Vergaberecht, Bau-/Architektenrecht)

## Status
**Phase**: Chat 2 (DocLing & NER Pipeline Implementation)

## Quick Start
```bash
./scripts/setup_env.sh
docker-compose -f docker/docker-compose.yml up -d
poetry install
poetry shell
./scripts/test_pipeline.sh
```

## Dokumentation
Siehe `/docs` Ordner
EOF

git add .
git commit -m "feat: Initial project setup" > /dev/null 2>&1

log_success "Git-Repository initialisiert"

# =====================================================
# Phase 5: Python Environment
# =====================================================
log_info "Phase 5: Python-Environment einrichten..."

# pyproject.toml
cat > pyproject.toml << 'EOF'
[tool.poetry]
name = "bhk-rag-system"
version = "0.1.0"
description = "Hybrid RAG System für juristische Dokumente"
authors = ["BHK Team"]
readme = "README.md"
python = "^3.11"

[tool.poetry.dependencies]
python = "^3.11"
docling = "^2.0.0"
flair = "^0.13.0"
qdrant-client = "^1.11.0"
neo4j = "^5.24.0"
mistralai = "^1.2.0"
pydantic = "^2.9.0"
python-dotenv = "^1.0.0"
pyyaml = "^6.0"
spacy = "^3.7.0"
regex = "^2024.0.0"
beautifulsoup4 = "^4.12.0"
lxml = "^5.0.0"
boto3 = "^1.35.0"
psycopg2-binary = "^2.9.0"
sqlalchemy = "^2.0.0"
alembic = "^1.13.0"
loguru = "^0.7.0"
tqdm = "^4.66.0"
click = "^8.1.0"
fastapi = "^0.115.0"
uvicorn = "^0.32.0"
pytest = "^8.3.0"
pytest-cov = "^5.0.0"
pytest-asyncio = "^0.24.0"
black = "^24.0.0"
ruff = "^0.6.0"
mypy = "^1.11.0"

[tool.poetry.group.dev.dependencies]
ipython = "^8.27.0"
jupyter = "^1.1.0"

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.black]
line-length = 100
target-version = ['py311']

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
EOF

# Install Dependencies
log_info "Installiere Python-Dependencies (kann 2-3 Minuten dauern)..."
poetry install --no-interaction > /dev/null 2>&1
log_success "Python-Dependencies installiert"

# Spacy Model
log_info "Lade Spacy DE-Modell..."
poetry run python -m spacy download de_core_news_sm > /dev/null 2>&1
log_success "Spacy-Modell geladen"

# =====================================================
# Phase 6: Environment Variables
# =====================================================
log_info "Phase 6: Environment-Variablen konfigurieren..."

cat > .env.example << 'EOF'
# === Mistral API ===
MISTRAL_API_KEY=your_mistral_api_key_here

# === IONOS S3 ===
IONOS_S3_ACCESS_KEY=your_ionos_access_key
IONOS_S3_SECRET_KEY=your_ionos_secret_key
IONOS_S3_ENDPOINT=https://s3.de-central.ionos.com
IONOS_S3_BUCKET=kanzlei-rag-prod

# === Qdrant ===
QDRANT_HOST=localhost
QDRANT_PORT=6333
QDRANT_GRPC_PORT=6334
QDRANT_API_KEY=

# === Neo4j ===
NEO4J_URI=bolt://localhost:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=changeme123

# === PostgreSQL ===
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=bhk_rag
POSTGRES_USER=bhk_admin
POSTGRES_PASSWORD=changeme123

# === Logging ===
LOG_LEVEL=INFO
LOG_FILE=data/logs/pipeline.log

# === Development ===
ENV=development
DEBUG=true
EOF

cp .env.example .env

log_success "Environment-Template erstellt (.env)"
log_warning "⚠️  WICHTIG: API-Keys in .env eintragen!"

# =====================================================
# Phase 7: Docker Services
# =====================================================
log_info "Phase 7: Docker-Services konfigurieren..."

cat > docker/docker-compose.yml << 'DOCKEREOF'
version: '3.8'

services:
  qdrant:
    image: qdrant/qdrant:v1.11.3
    container_name: bhk-qdrant
    ports:
      - "6333:6333"
      - "6334:6334"
    volumes:
      - qdrant_storage:/qdrant/storage
    environment:
      - QDRANT__SERVICE__GRPC_PORT=6334
      - QDRANT__LOG_LEVEL=INFO
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6333/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 8G

  neo4j:
    image: neo4j:5.24-community
    container_name: bhk-neo4j
    ports:
      - "7474:7474"
      - "7687:7687"
    volumes:
      - neo4j_data:/data
      - neo4j_logs:/logs
    environment:
      - NEO4J_AUTH=neo4j/changeme123
      - NEO4J_PLUGINS=["apoc"]
      - NEO4J_apoc_export_file_enabled=true
      - NEO4J_apoc_import_file_enabled=true
      - NEO4J_dbms_memory_heap_initial__size=2G
      - NEO4J_dbms_memory_heap_max__size=6G
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "cypher-shell -u neo4j -p changeme123 'RETURN 1'"]
      interval: 30s
      timeout: 10s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 8G

  postgres:
    image: postgres:16-alpine
    container_name: bhk-postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=bhk_rag
      - POSTGRES_USER=bhk_admin
      - POSTGRES_PASSWORD=changeme123
      - POSTGRES_INITDB_ARGS=--encoding=UTF-8
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U bhk_admin -d bhk_rag"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 2G

volumes:
  qdrant_storage:
  neo4j_data:
  neo4j_logs:
  postgres_data:

networks:
  default:
    name: bhk-rag-network
DOCKEREOF

log_success "Docker-Compose konfiguriert"

# Start Docker Services
log_info "Starte Docker-Services (kann 1-2 Minuten dauern)..."
cd docker
docker-compose up -d > /dev/null 2>&1
cd ..

# Wait for services
log_info "Warte auf Service-Start..."
sleep 15

# Health Checks
if curl -s http://localhost:6333/ | grep -q "qdrant"; then
    log_success "✅ Qdrant läuft (http://localhost:6333)"
else
    log_error "❌ Qdrant nicht erreichbar"
fi

if docker exec bhk-neo4j cypher-shell -u neo4j -p changeme123 "RETURN 1" &> /dev/null; then
    log_success "✅ Neo4j läuft (http://localhost:7474)"
else
    log_warning "⚠️  Neo4j noch nicht bereit (braucht evtl. 30s)"
fi

if docker exec bhk-postgres pg_isready -U bhk_admin -d bhk_rag &> /dev/null; then
    log_success "✅ PostgreSQL läuft (localhost:5432)"
else
    log_warning "⚠️  PostgreSQL noch nicht bereit"
fi

# =====================================================
# Phase 8: VSCode Configuration
# =====================================================
log_info "Phase 8: VSCode-Konfiguration..."

mkdir -p .vscode

cat > .vscode/settings.json << 'EOF'
{
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
  "python.formatting.provider": "black",
  "python.linting.enabled": true,
  "python.linting.ruffEnabled": true,
  "python.testing.pytestEnabled": true,
  "editor.formatOnSave": true,
  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter",
    "editor.rulers": [100]
  }
}
EOF

cat > .vscode/extensions.json << 'EOF'
{
  "recommendations": [
    "ms-python.python",
    "ms-python.black-formatter",
    "charliermarsh.ruff",
    "GitHub.copilot",
    "eamodio.gitlens",
    "yzhang.markdown-all-in-one"
  ]
}
EOF

log_success "VSCode-Konfiguration erstellt"

# =====================================================
# Phase 9: Utility Scripts
# =====================================================
log_info "Phase 9: Utility-Scripts erstellen..."

# Start Services Script
cat > scripts/start_services.sh << 'SERVICESEOF'
#!/bin/bash
cd "$(dirname "$0")/../docker"
echo "Starte Docker-Services..."
docker-compose up -d
echo "Services gestartet!"
echo "  - Qdrant: http://localhost:6333"
echo "  - Neo4j:  http://localhost:7474"
SERVICESEOF
chmod +x scripts/start_services.sh

# Stop Services Script
cat > scripts/stop_services.sh << 'STOPEOF'
#!/bin/bash
cd "$(dirname "$0")/../docker"
echo "Stoppe Docker-Services..."
docker-compose down
echo "Services gestoppt!"
STOPEOF
chmod +x scripts/stop_services.sh

# Test Pipeline Script
cat > scripts/test_pipeline.sh << 'TESTEOF'
#!/bin/bash
set -e
cd "$(dirname "$0")/.."
source .env

echo "=== Pipeline-Test ==="
echo "1. Checking Services..."
curl -s http://localhost:6333/ | grep -q "qdrant" && echo "✅ Qdrant OK" || echo "❌ Qdrant FAIL"
docker exec bhk-neo4j cypher-shell -u neo4j -p changeme123 "RETURN 1" &> /dev/null && echo "✅ Neo4j OK" || echo "❌ Neo4j FAIL"

echo "2. Running Tests..."
poetry run pytest tests/ -v

echo "=== Pipeline-Test Complete ==="
TESTEOF
chmod +x scripts/test_pipeline.sh

log_success "Utility-Scripts erstellt"

# =====================================================
# Phase 10: Final Commit
# =====================================================
log_info "Phase 10: Finaler Git-Commit..."

git add .
git commit -m "feat: Complete automated setup" > /dev/null 2>&1

log_success "Setup abgeschlossen!"

# =====================================================
# Summary
# =====================================================
echo ""
echo "=========================================="
echo "  Setup erfolgreich abgeschlossen! ✅"
echo "=========================================="
echo ""
echo "📁 Projekt-Root: $PROJECT_ROOT"
echo ""
echo "🚀 Nächste Schritte:"
echo ""
echo "1. API-Keys eintragen:"
echo "   vim $PROJECT_ROOT/.env"
echo ""
echo "2. Test-Dokumente kopieren (aus Chat 8):"
echo "   cp ~/Downloads/*.md $PROJECT_ROOT/data/test-docs/"
echo ""
echo "3. Poetry-Shell aktivieren:"
echo "   cd $PROJECT_ROOT"
echo "   poetry shell"
echo ""
echo "4. Pipeline testen:"
echo "   ./scripts/test_pipeline.sh"
echo ""
echo "5. VSCode öffnen:"
echo "   code $PROJECT_ROOT"
echo ""
echo "🌐 Services:"
echo "   - Qdrant:     http://localhost:6333"
echo "   - Neo4j:      http://localhost:7474 (neo4j/changeme123)"
echo "   - PostgreSQL: localhost:5432 (bhk_admin/changeme123)"
echo ""
echo "📚 Dokumentation:"
echo "   - Setup-Anleitung: $PROJECT_ROOT/docs/00_SETUP_COMPLETE.md"
echo "   - Chat 2 Spec:     $PROJECT_ROOT/docs/02_CHAT2_PIPELINE_SPEC.md"
echo ""
echo "⚠️  WICHTIG:"
echo "   - .env mit echten API-Keys befüllen!"
echo "   - Test-Dokumente aus Chat 8 übertragen"
echo "   - Bei Docker-Problemen: Neuanmeldung erforderlich (usermod docker)"
echo ""
echo "Happy Coding! 🎉"