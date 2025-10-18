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
