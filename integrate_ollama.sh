# Manuelle Integration: Ollama zu bestehender AnythingLLM Installation hinzufügen

## Schritt 1: Backup erstellen
```bash
cd /opt/anythingllm
sudo cp docker-compose.yml docker-compose.yml.backup-$(date +%Y%m%d)
```

## Schritt 2: Ollama-Datenverzeichnis erstellen
```bash
sudo mkdir -p ollama_data
sudo chmod 755 ollama_data
```

## Schritt 3: docker-compose.yml erweitern

Bearbeiten Sie Ihre bestehende `docker-compose.yml` und fügen Sie den Ollama-Service hinzu:

```yaml
version: '3.8'

services:
  anythingllm:
    image: mintplexlabs/anythingllm:latest
    container_name: anythingllm
    restart: always
    ports:
      - "3001:3001"
    volumes:
      - ./anythingllm_data:/app/server/storage
    # NEU: Ollama-Verbindung hinzufügen
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    depends_on:
      - ollama
    networks:
      - anythingllm-network

  # NEU: Ollama-Service hinzufügen
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: always
    ports:
      - "11434:11434"
    volumes:
      - ./ollama_data:/root/.ollama
    networks:
      - anythingllm-network

# NEU: Netzwerk definieren
networks:
  anythingllm-network:
    driver: bridge
```

## Schritt 4: Container neu starten
```bash
# Bestehende Container stoppen
sudo docker-compose down

# Neue Konfiguration starten
sudo docker-compose up -d
```

## Schritt 5: Deutsche Embedding-Modelle installieren

```bash
# Warten bis Ollama gestartet ist
sleep 10

# Deutsches Embedding-Modell herunterladen (empfohlen)
sudo docker exec ollama ollama pull jina/jina-embeddings-v2-base-de

# Alternative deutsche Embedding-Modelle
sudo docker exec ollama ollama pull nomic-embed-text

# Verfügbare Modelle anzeigen
sudo docker exec ollama ollama list
```

## Schritt 6: AnythingLLM konfigurieren

1. **AnythingLLM öffnen**: http://IHR_SERVER_IP:3001
2. **Einstellungen** → **Embedding Preference** aufrufen
3. **Provider** auf **"Ollama"** ändern
4. **Ollama URL** einstellen: `http://ollama:11434`
5. **Modell auswählen**: `jina/jina-embeddings-v2-base-de`
6. **Einstellungen speichern**

## Schritt 7: Testen

1. Erstellen Sie einen neuen Workspace
2. Laden Sie ein deutsches Dokument hoch
3. Testen Sie die Suche und Chat-Funktionen

## Troubleshooting

### Container-Status prüfen:
```bash
sudo docker-compose ps
```

### Ollama-Logs anzeigen:
```bash
sudo docker logs ollama
```

### AnythingLLM-Logs anzeigen:
```bash
sudo docker logs anythingllm
```

### Modelle in Ollama anzeigen:
```bash
sudo docker exec ollama ollama list
```

### Bei Problemen: Vollständiger Neustart
```bash
sudo docker-compose down
sudo docker-compose up -d
```

## Empfohlene deutsche Embedding-Modelle

1. **jina/jina-embeddings-v2-base-de** (empfohlen)
   - Speziell für deutsche Texte optimiert
   - Gute Performance bei RAG-Anwendungen

2. **nomic-embed-text**
   - Mehrsprachig, funktioniert gut mit Deutsch
   - Schneller als spezialisierte Modelle

## Zusätzliche Chat-Modelle (optional)

Falls Sie auch ein deutsches Chat-Modell verwenden möchten:

```bash
# Llama 3.1 8B (gut für deutsche Gespräche)
sudo docker exec ollama ollama pull llama3.1:8b

# Oder kleineres Modell für begrenzte Ressourcen
sudo docker exec ollama ollama pull llama3.1:3b
```

## Wichtige Hinweise

- ✅ Ihre bestehenden AnythingLLM-Daten bleiben vollständig erhalten
- ✅ Das Embedding-Modell wird nur einmal heruntergeladen und lokal gespeichert
- ✅ Ollama läuft unabhängig von AnythingLLM und kann separat verwaltet werden
- ⚠️ Embedding-Modelle sind 1-2 GB groß - stellen Sie ausreichend Speicherplatz sicher