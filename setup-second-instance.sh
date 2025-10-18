#!/bin/bash

# Zweite AnythingLLM Instanz für Sohn einrichten
# Komplett getrennte Daten und Konfiguration

set -e

# Farben
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

print_info "=== Zweite AnythingLLM Instanz Setup ==="

# 1. Verzeichnis für zweite Instanz
SECOND_DIR="/opt/anythingllm-sohn"
print_info "Erstelle Verzeichnis: $SECOND_DIR"

sudo mkdir -p $SECOND_DIR
cd $SECOND_DIR

# 2. Datenverzeichnisse erstellen
print_info "Erstelle separate Datenverzeichnisse..."
sudo mkdir -p data/storage
sudo mkdir -p data/models
sudo mkdir -p data/vector-cache
sudo mkdir -p data/ollama
sudo mkdir -p backups

# Berechtigungen setzen
sudo chown -R $(whoami):$(whoami) $SECOND_DIR
sudo chown -R 1000:1000 data/

# 3. Separate .env für Sohn
print_info "Erstelle separate Konfiguration..."

# JWT Secret generieren
JWT_SECRET_SOHN=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

cat > .env << EOF
# AnythingLLM Sohn - Separate Instanz
JWT_SECRET=$JWT_SECRET_SOHN
ADMIN_EMAIL=sohn@beispiel.de
ADMIN_PASSWORD=sicheres-sohn-passwort
ANYTHINGLLM_PORT=3002
OLLAMA_PORT=11435
STORAGE_DIR=/app/server/storage
NODE_ENV=production
DISABLE_TELEMETRY=true
EOF

chmod 600 .env

# 4. Docker Compose für zweite Instanz
print_info "Erstelle docker-compose.yml für zweite Instanz..."

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  anythingllm-sohn:
    image: mintplexlabs/anythingllm:latest
    container_name: anythingllm-sohn
    restart: unless-stopped
    user: "1000:1000"
    ports:
      - "0.0.0.0:3002:3001"  # Port 3002 für Sohn
    environment:
      - STORAGE_DIR=/app/server/storage
      - NODE_ENV=production
      - DISABLE_TELEMETRY=true
    volumes:
      - ./data/storage:/app/server/storage
    networks:
      - anythingllm-sohn-network
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 512M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/api/ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  ollama-sohn:
    image: ollama/ollama:latest
    container_name: ollama-sohn
    restart: unless-stopped
    ports:
      - "11435:11434"  # Port 11435 für Sohn
    volumes:
      - ./data/ollama:/root/.ollama
    networks:
      - anythingllm-sohn-network
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 512M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434/api/version"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

networks:
  anythingllm-sohn-network:
    driver: bridge
    name: anythingllm_sohn_network
EOF

# 5. Management Scripts für zweite Instanz
print_info "Erstelle Management-Scripts..."

# Backup-Script
cat > backup.sh << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "Starte Backup für AnythingLLM-Sohn..."

mkdir -p $BACKUP_DIR
cd $SCRIPT_DIR

docker-compose stop
tar -czf $BACKUP_DIR/anythingllm_sohn_backup_$DATE.tar.gz data/ .env docker-compose.yml *.sh
docker-compose start

echo "Backup erstellt: $BACKUP_DIR/anythingllm_sohn_backup_$DATE.tar.gz"
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete
EOF

# Update-Script
cat > update.sh << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR

echo "Starte Update für AnythingLLM-Sohn..."
./backup.sh
docker-compose pull
docker-compose up -d
echo "Update abgeschlossen!"
EOF

# Status-Script
cat > status.sh << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR

echo "=== AnythingLLM-Sohn Status ==="
echo "Container Status:"
docker-compose ps
echo ""
echo "Logs (letzte 10 Zeilen):"
docker-compose logs --tail=10
echo ""
echo "Disk Usage:"
du -sh data/
EOF

chmod +x backup.sh update.sh status.sh

# 6. Services starten
print_info "Starte zweite AnythingLLM-Instanz..."
docker-compose up -d

# 7. Warten auf Services
print_info "Warte auf Services..."
sleep 30

# 8. Status prüfen
if docker-compose ps | grep -q "Up"; then
    print_success "Zweite Instanz erfolgreich gestartet!"
    
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "================================"
    echo "  Zweite Instanz bereit!"
    echo "================================"
    echo ""
    echo "AnythingLLM Sohn erreichbar unter:"
    echo "  http://$SERVER_IP:3002"
    echo "  http://217.160.216.231:3002"
    echo ""
    echo "Ollama Sohn erreichbar unter:"
    echo "  http://$SERVER_IP:11435"
    echo ""
    echo "Verwaltung:"
    echo "  Verzeichnis: $SECOND_DIR"
    echo "  Status: ./status.sh"
    echo "  Backup: ./backup.sh"
    echo "  Update: ./update.sh"
    echo ""
    echo "WICHTIG: Port 3002 in IONOS Firewall öffnen!"
    echo ""
else
    echo "❌ Fehler beim Starten - prüfe Logs:"
    docker-compose logs
fi