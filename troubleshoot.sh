#!/bin/bash

# AnythingLLM Troubleshooting Script
# Diagnose und behebe Verbindungsprobleme

set -e

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${GREEN}"
    echo "=========================================="
    echo "   AnythingLLM Troubleshooting"
    echo "=========================================="
    echo -e "${NC}"
}

# Grundlegende Systemdiagnose
check_system() {
    print_info "=== SYSTEM CHECK ==="
    
    # Hostname und IPs
    echo "Hostname: $(hostname)"
    echo "Alle IP-Adressen:"
    ip addr show | grep "inet " | awk '{print $2}' | grep -v "127.0.0.1"
    
    # Public IP prüfen
    echo ""
    echo "Public IP (falls verfügbar):"
    curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "Nicht verfügbar"
    
    echo ""
    echo "Netzwerk-Interfaces:"
    ip link show
    
    echo ""
}

# Docker-Status prüfen
check_docker() {
    print_info "=== DOCKER CHECK ==="
    
    # Docker läuft?
    if systemctl is-active --quiet docker; then
        print_success "Docker Service läuft"
    else
        print_error "Docker Service läuft NICHT"
        print_info "Starte Docker..."
        systemctl start docker
    fi
    
    # Container Status
    echo ""
    echo "Container Status:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # AnythingLLM spezifisch
    if docker ps | grep -q anythingllm; then
        print_success "AnythingLLM Container läuft"
        
        echo ""
        echo "Container-Logs (letzte 20 Zeilen):"
        docker logs --tail=20 anythingllm
        
        echo ""
        echo "Container-Gesundheit:"
        docker inspect anythingllm | grep -A5 -B5 "Health"
        
    else
        print_error "AnythingLLM Container läuft NICHT"
        
        if docker ps -a | grep -q anythingllm; then
            print_info "Container existiert aber ist gestoppt. Starte neu..."
            docker start anythingllm
        else
            print_error "Container existiert nicht!"
        fi
    fi
    
    echo ""
}

# Port und Firewall prüfen
check_network() {
    print_info "=== NETWORK CHECK ==="
    
    # Ports prüfen
    ANYTHINGLLM_PORT=${1:-3001}
    
    echo "Prüfe Port $ANYTHINGLLM_PORT..."
    
    # Port listening?
    if netstat -tlpn | grep -q ":$ANYTHINGLLM_PORT "; then
        print_success "Port $ANYTHINGLLM_PORT ist offen"
        netstat -tlpn | grep ":$ANYTHINGLLM_PORT "
    else
        print_error "Port $ANYTHINGLLM_PORT ist NICHT offen"
    fi
    
    echo ""
    echo "Alle offenen Ports:"
    netstat -tlpn | grep LISTEN
    
    # UFW Status
    echo ""
    if command -v ufw &> /dev/null; then
        echo "UFW Firewall Status:"
        ufw status verbose
        
        # Port in UFW prüfen
        if ufw status | grep -q "$ANYTHINGLLM_PORT"; then
            print_success "Port $ANYTHINGLLM_PORT ist in UFW freigegeben"
        else
            print_warning "Port $ANYTHINGLLM_PORT ist NICHT in UFW freigegeben"
            print_info "Öffne Port in UFW..."
            ufw allow $ANYTHINGLLM_PORT/tcp comment "AnythingLLM"
            ufw reload
        fi
    else
        print_info "UFW nicht installiert - keine lokale Firewall"
    fi
    
    # Iptables prüfen
    echo ""
    echo "Iptables-Regeln (INPUT):"
    iptables -L INPUT -n | head -10
    
    echo ""
}

# Lokale Verbindung testen
check_local_connection() {
    print_info "=== LOCAL CONNECTION CHECK ==="
    
    ANYTHINGLLM_PORT=${1:-3001}
    
    # Localhost testen
    echo "Teste localhost:$ANYTHINGLLM_PORT..."
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$ANYTHINGLLM_PORT" | grep -q "200\|302\|401"; then
        print_success "Localhost-Verbindung erfolgreich"
    else
        print_error "Localhost-Verbindung fehlgeschlagen"
        
        # Container direkt testen
        if docker ps | grep -q anythingllm; then
            echo "Teste Container direkt..."
            docker exec anythingllm curl -f http://localhost:3001/api/ping || print_error "Container intern nicht erreichbar"
        fi
    fi
    
    # Alle lokalen IPs testen
    echo ""
    echo "Teste alle lokalen IP-Adressen:"
    for ip in $(hostname -I); do
        echo -n "Teste $ip:$ANYTHINGLLM_PORT ... "
        if timeout 5 bash -c "</dev/tcp/$ip/$ANYTHINGLLM_PORT" 2>/dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FAILED${NC}"
        fi
    done
    
    echo ""
}

# IONOS Cube spezifische Prüfungen
check_ionos_specific() {
    print_info "=== IONOS CUBE SPECIFIC CHECKS ==="
    
    # IONOS Firewall/Security Groups
    print_warning "Prüfen Sie das IONOS Control Panel:"
    echo "1. Firewall-Regeln für Port $ANYTHINGLLM_PORT"
    echo "2. Security Groups (falls verwendet)"
    echo "3. DDoS-Schutz Einstellungen"
    
    # Netzwerk-Konfiguration
    echo ""
    echo "Netzwerk-Route:"
    ip route show
    
    echo ""
    echo "DNS-Konfiguration:"
    cat /etc/resolv.conf
    
    echo ""
    echo "Netzwerk-Services:"
    systemctl status networking || systemctl status network-manager
    
    echo ""
}

# Docker Compose Konfiguration prüfen
check_docker_compose() {
    print_info "=== DOCKER COMPOSE CHECK ==="
    
    if [ -f "docker-compose.yml" ]; then
        echo "Docker Compose Datei gefunden"
        
        echo ""
        echo "Port-Mapping:"
        grep -A5 -B5 "ports:" docker-compose.yml
        
        echo ""
        echo "Environment:"
        grep -A10 "environment:" docker-compose.yml | head -15
        
        echo ""
        echo "Docker Compose Status:"
        docker-compose ps
        
        echo ""
        echo "Docker Compose Logs:"
        docker-compose logs --tail=10
        
    else
        print_error "Keine docker-compose.yml gefunden!"
    fi
    
    echo ""
}

# Automatische Reparaturversuche
fix_common_issues() {
    print_info "=== AUTOMATISCHE REPARATUR ==="
    
    ANYTHINGLLM_PORT=${1:-3001}
    
    # Docker neustarten
    print_info "Starte Docker-Services neu..."
    if [ -f "docker-compose.yml" ]; then
        docker-compose restart
    else
        docker restart anythingllm 2>/dev/null || true
    fi
    
    # Port in Firewall öffnen
    if command -v ufw &> /dev/null; then
        print_info "Öffne Port in UFW..."
        ufw allow $ANYTHINGLLM_PORT/tcp comment "AnythingLLM-Fix"
        ufw reload
    fi
    
    # Iptables-Regel hinzufügen (falls nötig)
    print_info "Prüfe iptables..."
    if ! iptables -L INPUT | grep -q "$ANYTHINGLLM_PORT"; then
        print_info "Füge iptables-Regel hinzu..."
        iptables -I INPUT -p tcp --dport $ANYTHINGLLM_PORT -j ACCEPT
    fi
    
    # Warten und erneut testen
    print_info "Warte 30 Sekunden und teste erneut..."
    sleep 30
    
    # Verbindung testen
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$ANYTHINGLLM_PORT" | grep -q "200\|302\|401"; then
        print_success "Reparatur erfolgreich - Service läuft!"
    else
        print_error "Reparatur fehlgeschlagen - manuelle Intervention nötig"
    fi
    
    echo ""
}

# Detaillierte Empfehlungen
provide_recommendations() {
    print_info "=== EMPFEHLUNGEN ==="
    
    echo "1. IONOS Control Panel prüfen:"
    echo "   - Firewall-Regeln für Port $ANYTHINGLLM_PORT"
    echo "   - Security Groups konfigurieren"
    echo "   - DDoS-Schutz temporär deaktivieren zum Test"
    echo ""
    
    echo "2. Alternative Ports testen:"
    echo "   - Port 8080, 8081, 9000 versuchen"
    echo "   - In docker-compose.yml Port ändern"
    echo ""
    
    echo "3. Netzwerk-Binding prüfen:"
    echo "   - Container auf 0.0.0.0:3001 statt 127.0.0.1:3001"
    echo "   - Docker-Compose ports: '0.0.0.0:3001:3001'"
    echo ""
    
    echo "4. Logs analysieren:"
    echo "   - docker logs anythingllm -f"
    echo "   - journalctl -u docker -f"
    echo ""
    
    echo "5. Direkte Container-IP verwenden:"
    CONTAINER_IP=$(docker inspect anythingllm | grep '"IPAddress"' | head -1 | awk -F'"' '{print $4}' 2>/dev/null)
    if [ -n "$CONTAINER_IP" ]; then
        echo "   - Container-IP: http://$CONTAINER_IP:3001"
    fi
    
    echo ""
}

# Alternative docker-compose.yml generieren
generate_fixed_compose() {
    print_info "Generiere reparierte docker-compose.yml..."
    
    ANYTHINGLLM_PORT=${1:-3001}
    
    cat > docker-compose-fixed.yml << EOF
version: '3.8'

services:
  anythingllm:
    image: mintplexlabs/anythingllm:latest
    container_name: anythingllm
    restart: unless-stopped
    ports:
      - "0.0.0.0:${ANYTHINGLLM_PORT}:3001"  # Explizit auf alle Interfaces binden
    environment:
      - NODE_ENV=production
      - STORAGE_DIR=/app/server/storage
      - VECTOR_DB=lancedb
      - WHISPER_PROVIDER=local
      - TTS_PROVIDER=native
      - DISABLE_TELEMETRY=true
      - SERVER_PORT=3001
      - INNGEST_DISABLE_DEV_SERVER=true
    volumes:
      - ./data/storage:/app/server/storage
      - ./data/models:/app/server/storage/models
      - ./data/vector-cache:/app/server/storage/vector-cache
    networks:
      - anythingllm-network
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
      start_period: 60s

networks:
  anythingllm-network:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.host_binding_ipv4: "0.0.0.0"
EOF

    print_success "Reparierte docker-compose-fixed.yml erstellt"
    echo "Verwenden mit: docker-compose -f docker-compose-fixed.yml up -d"
    echo ""
}

# Hauptfunktion
main() {
    print_header
    
    ANYTHINGLLM_PORT=${1:-3001}
    
    # Alle Prüfungen durchführen
    check_system
    check_docker
    check_network "$ANYTHINGLLM_PORT"
    check_local_connection "$ANYTHINGLLM_PORT"
    check_ionos_specific "$ANYTHINGLLM_PORT"
    check_docker_compose
    
    # Reparaturversuche
    echo ""
    read -p "Soll eine automatische Reparatur versucht werden? [y/N]: " AUTO_FIX
    if [[ $AUTO_FIX =~ ^[Yy]$ ]]; then
        fix_common_issues "$ANYTHINGLLM_PORT"
    fi
    
    # Empfehlungen
    provide_recommendations "$ANYTHINGLLM_PORT"
    
    # Alternative Compose-Datei
    echo ""
    read -p "Soll eine reparierte docker-compose.yml generiert werden? [y/N]: " GEN_COMPOSE
    if [[ $GEN_COMPOSE =~ ^[Yy]$ ]]; then
        generate_fixed_compose "$ANYTHINGLLM_PORT"
    fi
    
    print_success "Troubleshooting abgeschlossen!"
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi