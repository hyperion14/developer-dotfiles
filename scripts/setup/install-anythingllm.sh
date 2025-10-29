#!/bin/bash

# AnythingLLM Installation Script für IONOS Cube
# Autor: Claude AI
# Datum: $(date)

set -e  # Exit bei Fehlern

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktionen
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${GREEN}"
    echo "=============================================="
    echo "   AnythingLLM Installation für IONOS Cube"
    echo "=============================================="
    echo -e "${NC}"
}

# Benutzer Input Funktionen
ask_yes_no() {
    local question="$1"
    local default="${2:-n}"
    local answer
    
    while true; do
        if [ "$default" = "y" ]; then
            echo -n "$question [Y/n]: "
        else
            echo -n "$question [y/N]: "
        fi
        
        read answer
        answer=${answer:-$default}
        
        case $answer in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Bitte antworten Sie mit 'y' oder 'n'.";;
        esac
    done
}

generate_random_string() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Hauptfunktionen
check_requirements() {
    print_info "Überprüfe Systemvoraussetzungen..."
    
    # Root-Rechte prüfen
    if [[ $EUID -ne 0 ]]; then
        print_error "Dieses Script muss als root ausgeführt werden!"
        print_info "Verwende: sudo $0"
        exit 1
    fi
    
    # Betriebssystem prüfen
    if [[ ! -f /etc/os-release ]]; then
        print_error "Betriebssystem nicht erkannt!"
        exit 1
    fi
    
    # Memory prüfen
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $mem_gb -lt 2 ]]; then
        print_warning "Weniger als 2GB RAM verfügbar. AnythingLLM könnte langsam laufen."
        if ! ask_yes_no "Trotzdem fortfahren?"; then
            exit 1
        fi
    fi
    
    print_success "Systemvoraussetzungen erfüllt"
}

install_docker() {
    print_info "Installiere Docker und Docker Compose..."
    
    # Prüfen ob Docker bereits installiert ist
    if command -v docker &> /dev/null; then
        print_info "Docker ist bereits installiert"
        docker --version
    else
        print_info "Installiere Docker..."
        
        # Docker's offizielle GPG-Schlüssel hinzufügen
        apt-get update
        apt-get install -y ca-certificates curl gnupg lsb-release
        
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        # Repository hinzufügen
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Docker installieren
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Docker-Service starten
        systemctl start docker
        systemctl enable docker
        
        print_success "Docker installiert"
    fi
    
    # Docker Compose prüfen
    if ! command -v docker-compose &> /dev/null; then
        print_info "Installiere Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        print_success "Docker Compose installiert"
    fi
    
    print_success "Docker-Installation abgeschlossen"
}

setup_directories() {
    print_info "Erstelle Verzeichnisstruktur..."
    
    # Hauptverzeichnis erstellen
    INSTALL_DIR="/opt/anythingllm"
    mkdir -p $INSTALL_DIR
    cd $INSTALL_DIR
    
    # Datenverzeichnisse erstellen
    mkdir -p data/storage
    mkdir -p data/models
    mkdir -p data/vector-cache
    mkdir -p data/ollama
    mkdir -p backups
    
    # Berechtigungen setzen
    chmod 755 $INSTALL_DIR
    chmod -R 755 data/
    
    print_success "Verzeichnisstruktur erstellt: $INSTALL_DIR"
}

create_config_files() {
    print_info "Erstelle Konfigurationsdateien..."
    
    # JWT Secret generieren
    JWT_SECRET=$(generate_random_string)
    
    # Admin-Daten abfragen
    echo ""
    echo "=== Admin-Konfiguration ==="
    read -p "Admin E-Mail: " ADMIN_EMAIL
    while [[ -z "$ADMIN_EMAIL" ]]; do
        read -p "Bitte geben Sie eine E-Mail-Adresse ein: " ADMIN_EMAIL
    done
    
    read -s -p "Admin Passwort: " ADMIN_PASSWORD
    echo ""
    while [[ ${#ADMIN_PASSWORD} -lt 8 ]]; do
        echo "Passwort muss mindestens 8 Zeichen lang sein!"
        read -s -p "Admin Passwort: " ADMIN_PASSWORD
        echo ""
    done
    
    # Port-Konfiguration
    echo ""
    echo "=== Port-Konfiguration ==="
    read -p "AnythingLLM Port [3001]: " ANYTHINGLLM_PORT
    ANYTHINGLLM_PORT=${ANYTHINGLLM_PORT:-3001}
    
    read -p "Ollama Port [11434]: " OLLAMA_PORT
    OLLAMA_PORT=${OLLAMA_PORT:-11434}
    
    # Ollama Installation fragen
    INSTALL_OLLAMA=false
    if ask_yes_no "Möchten Sie Ollama für lokale LLM-Modelle installieren?" "y"; then
        INSTALL_OLLAMA=true
    fi
    
    # .env Datei erstellen
    cat > .env << EOF
# AnythingLLM Umgebungsvariablen
JWT_SECRET=$JWT_SECRET
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD=$ADMIN_PASSWORD
ANYTHINGLLM_PORT=$ANYTHINGLLM_PORT
OLLAMA_PORT=$OLLAMA_PORT
EOF
    
    # Docker Compose Datei erstellen
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  anythingllm:
    image: mintplexlabs/anythingllm:latest
    container_name: anythingllm
    restart: unless-stopped
    ports:
      - "\${ANYTHINGLLM_PORT}:3001"
    environment:
      # Basis-Konfiguration
      - NODE_ENV=production
      - STORAGE_DIR=/app/server/storage
      - VECTOR_DB=lancedb
      - WHISPER_PROVIDER=local
      - TTS_PROVIDER=native
      
      # Sicherheit
      - JWT_SECRET=\${JWT_SECRET}
      - PASSWORDMINIFY=false
      
      # Admin-Konfiguration (nur beim ersten Start)
      - ADMIN_EMAIL=\${ADMIN_EMAIL}
      - ADMIN_PASSWORD=\${ADMIN_PASSWORD}
      
      # Datenschutz & Telemetrie
      - DISABLE_TELEMETRY=true
      
    volumes:
      # Persistente Datenverzeichnisse
      - ./data/storage:/app/server/storage
      - ./data/models:/app/server/storage/models
      - ./data/vector-cache:/app/server/storage/vector-cache
      
    networks:
      - anythingllm-network
    
    # Ressourcen-Limits für IONOS Cube
    deploy:
      resources:
        limits:
          memory: 3G
        reservations:
          memory: 1G
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/api/ping"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

    # Ollama Service hinzufügen falls gewünscht
    if [ "$INSTALL_OLLAMA" = true ]; then
        cat >> docker-compose.yml << EOF

  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    ports:
      - "\${OLLAMA_PORT}:11434"
    volumes:
      - ./data/ollama:/root/.ollama
    networks:
      - anythingllm-network
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
EOF
    fi

    # Networks-Sektion hinzufügen
    cat >> docker-compose.yml << EOF

networks:
  anythingllm-network:
    driver: bridge
EOF

    # Berechtigungen setzen
    chmod 600 .env
    chmod 644 docker-compose.yml
    
    print_success "Konfigurationsdateien erstellt"
}

create_management_scripts() {
    print_info "Erstelle Management-Scripts..."
    
    # Backup-Script
    cat > backup.sh << 'EOF'
#!/bin/bash
# AnythingLLM Backup Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "Starte Backup..."

mkdir -p $BACKUP_DIR
cd $SCRIPT_DIR

# Services stoppen
echo "Stoppe Services..."
docker-compose stop

# Backup erstellen
echo "Erstelle Backup..."
tar -czf $BACKUP_DIR/anythingllm_backup_$DATE.tar.gz data/ .env docker-compose.yml

# Services wieder starten
echo "Starte Services..."
docker-compose start

echo "Backup erstellt: $BACKUP_DIR/anythingllm_backup_$DATE.tar.gz"

# Alte Backups löschen (älter als 30 Tage)
find $BACKUP_DIR -name "anythingllm_backup_*.tar.gz" -mtime +30 -delete

echo "Backup abgeschlossen!"
EOF

    # Update-Script
    cat > update.sh << 'EOF'
#!/bin/bash
# AnythingLLM Update Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR

echo "Starte Update..."

# Backup vor Update
./backup.sh

# Images aktualisieren
echo "Lade neue Images..."
docker-compose pull

# Services neu starten
echo "Starte Services neu..."
docker-compose up -d

echo "Update abgeschlossen!"
EOF

    # Status-Script
    cat > status.sh << 'EOF'
#!/bin/bash
# AnythingLLM Status Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR

echo "=== AnythingLLM Status ==="
echo ""

echo "Container Status:"
docker-compose ps

echo ""
echo "Logs (letzte 10 Zeilen):"
docker-compose logs --tail=10

echo ""
echo "Ressourcen-Verbrauch:"
docker stats --no-stream

echo ""
echo "Disk Usage:"
du -sh data/
EOF

    # Scripts ausführbar machen
    chmod +x backup.sh update.sh status.sh
    
    print_success "Management-Scripts erstellt"
}

configure_firewall() {
    print_info "Konfiguriere Firewall..."
    
    # Prüfen ob ufw installiert ist
    if command -v ufw &> /dev/null; then
        # Ports öffnen
        ufw allow $ANYTHINGLLM_PORT/tcp comment "AnythingLLM"
        
        if [ "$INSTALL_OLLAMA" = true ]; then
            ufw allow $OLLAMA_PORT/tcp comment "Ollama"
        fi
        
        ufw reload
        print_success "Firewall konfiguriert"
    else
        print_warning "UFW nicht installiert - Firewall-Konfiguration übersprungen"
    fi
}

start_services() {
    print_info "Starte AnythingLLM Services..."
    
    # Docker Images herunterladen
    docker-compose pull
    
    # Services starten
    docker-compose up -d
    
    # Warten auf Services
    print_info "Warte auf Services..."
    sleep 30
    
    # Status prüfen
    if docker-compose ps | grep -q "Up"; then
        print_success "Services erfolgreich gestartet!"
        
        # Server-IP ermitteln
        SERVER_IP=$(hostname -I | awk '{print $1}')
        
        echo ""
        echo "================================"
        echo "  Installation abgeschlossen!"
        echo "================================"
        echo ""
        echo "AnythingLLM ist erreichbar unter:"
        echo "  http://$SERVER_IP:$ANYTHINGLLM_PORT"
        echo "  http://localhost:$ANYTHINGLLM_PORT"
        echo ""
        echo "Admin-Zugangsdaten:"
        echo "  E-Mail: $ADMIN_EMAIL"
        echo "  Passwort: [siehe .env Datei]"
        echo ""
        
        if [ "$INSTALL_OLLAMA" = true ]; then
            echo "Ollama ist erreichbar unter:"
            echo "  http://$SERVER_IP:$OLLAMA_PORT"
            echo ""
        fi
        
        echo "Management-Commands:"
        echo "  Status: ./status.sh"
        echo "  Backup: ./backup.sh"
        echo "  Update: ./update.sh"
        echo ""
        echo "Installation-Verzeichnis: $INSTALL_DIR"
        echo ""
    else
        print_error "Fehler beim Starten der Services!"
        echo "Führen Sie 'docker-compose logs' aus für weitere Details"
        exit 1
    fi
}

create_systemd_service() {
    if ask_yes_no "Möchten Sie einen systemd Service erstellen (Auto-Start beim Boot)?" "y"; then
        print_info "Erstelle systemd Service..."
        
        cat > /etc/systemd/system/anythingllm.service << EOF
[Unit]
Description=AnythingLLM Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable anythingllm.service
        
        print_success "systemd Service erstellt und aktiviert"
    fi
}

setup_cron_backup() {
    if ask_yes_no "Möchten Sie automatische tägliche Backups einrichten?" "y"; then
        print_info "Richte Cron-Job für Backups ein..."
        
        # Cron-Job für tägliches Backup um 02:00 Uhr
        (crontab -l 2>/dev/null; echo "0 2 * * * cd $INSTALL_DIR && ./backup.sh >> $INSTALL_DIR/backup.log 2>&1") | crontab -
        
        print_success "Automatische Backups eingerichtet (täglich 02:00 Uhr)"
    fi
}

# Hauptprogramm
main() {
    print_header
    
    print_info "Starte AnythingLLM Installation..."
    
    check_requirements
    install_docker
    setup_directories
    create_config_files
    create_management_scripts
    configure_firewall
    start_services
    create_systemd_service
    setup_cron_backup
    
    print_success "Installation erfolgreich abgeschlossen!"
}

# Script-Ausführung
main "$@"