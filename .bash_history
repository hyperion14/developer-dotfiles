sudo whoami
sudo reboot
# System-Updates prüfen
sudo apt update
# Python und grundlegende Tools installieren
sudo apt install -y python3-pip python3-venv git curl
# Docker installieren (für containerisierte Services)
sudo apt install -y docker.io
sudo usermod -aG docker developer
# Node.js installieren (falls benötigt)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
# Python-Versionen
python3 --version
pip3 --version
# Docker-Status
sudo systemctl status docker
docker --version
# Node.js und npm
node --version
npm --version
# Git
git --version
# Offene Ports
sudo netstat -tlnp
# SSH-Konfiguration
sudo cat /etc/ssh/sshd_config | grep -E "Port|PermitRootLogin|PasswordAuthentication"
# Aktuelle SSH-Verbindungen
who
sudo ufw status
# Systemd-Services
systemctl list-units --type=service --state=running
# Speicher- und CPU-Nutzung
htop
# oder
top
# Firewall aktivieren
sudo ufw enable
# SSH-Port erlauben (wichtig, sonst sind Sie ausgesperrt!)
sudo ufw allow 22
# Standard-Regeln setzen
sudo ufw default deny incoming
sudo ufw default allow outgoing
# Status prüfen
sudo ufw status verbose
sudo ufw allow 22
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw status verbose
# HTTP/HTTPS für Web-Interface
sudo ufw allow 80
sudo ufw allow 443
# Typische RAG/API Ports (je nach Setup)
sudo ufw allow 8000  # FastAPI
sudo ufw allow 3000  # React/Node.js
sudo ufw allow 8080  # Alternative Web-Port
# Status erneut prüfen
sudo ufw status numbered
# Fehlgeschlagene Login-Versuche überwachen
sudo apt install fail2ban
sudo systemctl enable fail2ban
chmod +x install-anythingllm.sh
sudo ./install-anythingllm.sh
# Script herunterladen und ausführen
chmod +x troubleshoot.sh
sudo ./troubleshoot.sh 3001
sudo apt update
sudo apt install -y net-tools iproute2 curl
# Container läuft?
docker ps
# Port-Mapping prüfen
docker port anythingllm
# Sollte zeigen: 3001/tcp -> 0.0.0.0:3001
# RAM prüfen
free -h
docker stats --no-stream
cd /opt/anythingllm
# 1. Logs anschauen (wichtig!)
docker logs anythingllm --tail=50
# 2. Container komplett neu starten
docker-compose down
sudo chown -R 1000:1000 data/
# 3. Mit reduzierter Konfiguration testen
docker run -d --name anythingllm-test   -p 3001:3001   -v $(pwd)/data:/app/server/storage   -e NODE_ENV=production   -e DISABLE_TELEMETRY=true   --memory="2g"   mintplexlabs/anythingllm:latest
# 4. Status überwachen
docker logs anythingllm-test -f
cd /opt/anythingllm
# 1. Container stoppen
docker rm -f anythingllm-test
# 2. Berechtigungen komplett korrigieren
sudo chown -R $(whoami):$(whoami) /opt/anythingllm/
sudo chmod -R 755 /opt/anythingllm/
sudo chmod 644 .env
# 3. Storage-Verzeichnisse erstellen
mkdir -p data/storage
sudo chown -R 1000:1000 data/
# 4. Korrigierte .env prüfen
ls -la .env
cat .env
# 5. Korrekte Container-Konfiguration
docker run -d --name anythingllm-fixed   -p 3001:3001   -v $(pwd)/data/storage:/app/server/storage   -v $(pwd)/.env:/app/server/.env:ro   -e STORAGE_DIR=/app/server/storage   -e NODE_ENV=production   -e DISABLE_TELEMETRY=true   --user 1000:1000   mintplexlabs/anythingllm:latest
# 6. Logs verfolgen
docker logs anythingllm-fixed -f
# 1. Alle AnythingLLM Container stoppen
docker stop anythingllm-test anythingllm-fixed anythingllm 2>/dev/null
docker rm anythingllm-test anythingllm-fixed anythingllm 2>/dev/null
# 2. Prüfen was Port 3001 belegt
docker ps -a
sudo ss -tlpn | grep :3001
# 3. Sauberer Neustart
cd /opt/anythingllm
docker-compose down
# 4. Jetzt sollte Port frei sein - Test
docker run -d --name anythingllm-final   -p 3001:3001   -v $(pwd)/data/storage:/app/server/storage   -e STORAGE_DIR=/app/server/storage   -e NODE_ENV=production   -e DISABLE_TELEMETRY=true   --user 1000:1000   mintplexlabs/anythingllm:latest
# 5. Logs verfolgen
docker logs anythingllm-final -f
# Zeige alle Container die Port 3001 nutzen könnten
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
# 1. Localhost-Test
curl -I http://localhost:3001
# 2. Lokale IP-Test
curl -I http://$(hostname -I | awk '{print $1}'):3001
# 3. Container-Logs prüfen (sollten gut aussehen)
docker logs anythingllm-final --tail=10
# IONOS Firewall-Port öffnen
sudo ufw allow 3001/tcp
sudo ufw reload
sudo ufw status
# Test von Server aus
curl -v http://217.160.216.231:3001
cd /opt/anythingllm
# Alte docker-compose.yml sichern
cp docker-compose.yml docker-compose.yml.backup
# Container-Konfiguration in docker-compose übernehmen
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  anythingllm:
    image: mintplexlabs/anythingllm:latest
    container_name: anythingllm
    restart: unless-stopped
    user: "1000:1000"
    ports:
      - "0.0.0.0:3001:3001"
    environment:
      - STORAGE_DIR=/app/server/storage
      - NODE_ENV=production
      - DISABLE_TELEMETRY=true
    volumes:
      - ./data/storage:/app/server/storage
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/api/ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    ports:
      - "11434:11434"
    volumes:
      - ./data/ollama:/root/.ollama
    deploy:
      resources:
        limits:
          memory: 2G
EOF

# Test mit docker-compose
docker rm -f anythingllm-final
docker-compose up -d
docker-compose ps
docker rm -f anythingllm-final
docker-compose up -d
docker-compose ps
chmod +x mistral_upgrade.sh
./mistral_upgrade.sh
chmod +x mistral_upgrade.sh
./mistral_upgrade.sh
cd ionos-legal-rag/
chmod +x mistral_upgrade.sh
./mistral_upgrade.sh
cd
chmod +x fresh_start_v2.sh
./fresh_start_v2.sh
# Falls du CLI bevorzugst
curl -X POST "https://api.ionos.com/cloudapi/v6/um/users/[USER-ID]/s3keys"   -H "Authorization: Bearer [TOKEN]"
curl ifconfig.me
# IONOS CLI installieren
pip install ionoscloud
# Konfigurieren
ionosctl configure
# Keys auslesen
ionosctl s3 key list
ionosctl ai hub key list
sudo snap install ionosctl
ionosctl s3 key list
# Script erstellen und ausführen
chmod +x setup-second-instance.sh
sudo ./setup-second-instance.sh
chmod +x ssl-eunomialegal.sh
sudo ./ssl-eunomialegal.sh
# Nginx stoppen
sudo systemctl stop nginx
# Fehlerhafte Konfiguration entfernen
sudo rm /etc/nginx/sites-enabled/anythingllm
sudo rm /etc/nginx/sites-enabled/anythingllm-sohn 2>/dev/null
# Korrekte Nginx-Configs manuell erstellen
chmod +x nginx-fix.sh
sudo ./nginx-fix.sh
# Erst HTTP testen, dann SSL
sudo certbot --nginx -d anythingllm.eunomialegal.de
sudo certbot --nginx -d jasper.eunomialegal.de
chmod +x complete-ssl.sh
sudo ./complete-ssl.sh
# 1. DNS-Status
echo "=== DNS TESTS ==="
nslookup anythingllm.eunomialegal.de
echo ""
nslookup jasper.eunomialegal.de
echo ""
# 2. HTTP-Status  
echo "=== HTTP TESTS ==="
curl -v http://anythingllm.eunomialegal.de
echo ""
curl -v http://jasper.eunomialegal.de
echo ""
# 3. Lokaler Test (sollte funktionieren)
curl -I http://localhost:3001
curl -I http://localhost:3002
# Test von außen auf Port 443
timeout 5 bash -c "</dev/tcp/217.160.216.231/443" && echo "Port 443 offen" || echo "Port 443 geschlossen"
# Nginx auf Port 443 lauscht bereits?
sudo ss -tlpn | grep :443
./complete-ssl.sh 
sudo ./complete-ssl.sh 
# Script ausführen
chmod +x mistral_upgrade.sh
./mistral_upgrade.sh
# Mistral API Key hinzufügen
nano .env
# → MISTRAL_API_KEY=your-mistral-key-here
# System neu bauen und starten
docker-compose build --no-cache
cd ionos-legal-rag/
chmod +x mistral_upgrade.sh
./mistral_upgrade.sh
nano .env
# → MISTRAL_API_KEY=IUaKx3avQxqSZa9ok0hLADljRsrbaBx1
cd ..
chmod +x fresh_start_v2.sh
./fresh_start_v2.sh 
cd ionos-legal-rag/
./mistral_upgrade.sh 
docker-compose up -d
pip install --upgrade pip
chmod +x setup-second-instance.sh 
pip install --upgrade
chmod +x ssl_setup.sh 
./ssl_setup.sh 
jk1406ka
sudo
sudo ./ssl_setup.sh 
# Alle laufenden Ports anzeigen
sudo netstat -tulpn | grep LISTEN
# Docker-Container und ihre Ports
docker ps
# Docker Compose Services
docker-compose ps
ls -la
cd ../
ls -la
cd developer/
cd ls
ls -a
ls -A
sudo nano /etc/nginx/sites-available/default-ssl-proxy
# Konfiguration testen
sudo nginx -t
# Wenn OK, dann neu laden
sudo systemctl reload nginx
sudo nano /etc/nginx/sites-available/default-ssl-proxy
sudo nano default-ssl-proxy 
sudo cat > /etc/nginx/sites-available/default-ssl-proxy << 'EOF'
# HTTP zu HTTPS Redirect für alle Domains
server {
    listen 80;
    server_name eunomialegal.de any1.eunomialegal.de any2.eunomialegal.de;
    return 301 https://$host$request_uri;
}

# Hauptdomain - Port 3001
server {
    listen 443 ssl http2;
    server_name eunomialegal.de;
    
    # Security Headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubdomains; preload" always;
    
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
        client_max_body_size 200M;
    }
}

# any1 Subdomain - Port 3001
server {
    listen 443 ssl http2;
    server_name any1.eunomialegal.de;
    
    # Security Headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubdomains; preload" always;
    
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
        client_max_body_size 200M;
    }
}

# any2 Subdomain - Port 3002  
server {
    listen 443 ssl http2;
    server_name any2.eunomialegal.de;
    
    # Security Headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubdomains; preload" always;
    
    location / {
        proxy_pass http://127.0.0.1:3002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
        client_max_body_size 200M;
    }
}
EOF

# Konfiguration testen
sudo nginx -t
# Wenn OK, dann SSL-Zertifikate erneut hinzufügen
sudo certbot --nginx -d eunomialegal.de -d any1.eunomialegal.de -d any2.eunomialegal.de
# Nginx neu laden
sudo systemctl reload nginx
# Alte Datei löschen
sudo rm /etc/nginx/sites-available/default-ssl-proxy
# Neue Datei erstellen
sudo nano /etc/nginx/sites-available/default-ssl-proxy
sudo systemctl reload nginx# Konfiguration testen
sudo nginx -t
# Wenn OK, dann SSL-Zertifikate erneut hinzufügen
sudo certbot --nginx -d eunomialegal.de -d any1.eunomialegal.de -d any2.eunomialegal.de
# Nginx neu laden
sudo systemctl reload nginx
# Den Tippfehler korrigieren
sudo sed -i 's/proxy_Set_header/proxy_set_header/g' /etc/nginx/sites-available/default-ssl-proxy
# Testen
sudo nginx -t
# 1. Konfiguration testen
sudo nginx -t
# 2. SSL-Zertifikate hinzufügen (nur wenn nginx -t OK ist)
sudo certbot --nginx -d eunomialegal.de -d any1.eunomialegal.de -d any2.eunomialegal.de
# 3. Nginx neu laden (nur wenn certbot erfolgreich war)
sudo systemctl reload nginx
# Nginx-Status
sudo systemctl status nginx
# Ports prüfen
sudo netstat -tlnp | grep -E ':80|:443'
sudo nginx -t
sudo certbot --nginx -d eunomialegal.de -d any1.eunomialegal.de -d any2.eunomialegal.de
sudo nginx -t
sudo systemctl reload nginx
curl -I https://any2.eunomialegal.de
curl -I https://any1.eunomialegal.de
curl -I https://anythingllm.eunomialegal.de
ls -la
chmod +x integrate_ollama.sh
sudo ./integrate_ollama.sh 
cd /
ls -a
cd opt/anythingllm
ls -la
cd ..
cd /home/developer/
chmod +x integrate_ollama.sh
sudo ./integrate_ollama.sh 
# Container-Status prüfen
sudo docker-compose ps
# Wenn Container laufen, stoppen Sie sie
sudo docker-compose down
cd /opt/anythingllm
sudo docker-compose down
chmod +x /home/developer/integrate_ollama.sh 
sudo /home/developer/integrate_ollama.sh 
# Container starten
sudo docker-compose up -d
# Warten bis Ollama bereit ist (10-15 Sekunden)
sleep 15
# Status prüfen
sudo docker-compose ps
# Deutsches Embedding-Modell herunterladen
sudo docker exec ollama ollama pull jina/jina-embeddings-v2-base-de
# Optional: Alternatives Embedding-Modell
sudo docker exec ollama ollama pull nomic-embed-text
# Verfügbare Modelle anzeigen
sudo docker exec ollama ollama list
# Container-Status prüfen
sudo docker-compose ps
# Logs anschauen
sudo docker logs anythingllm
sudo docker logs ollama
# Prozesse auf Port 3001 prüfen
sudo netstat -tlnp | grep 3001
docker cd /opt/anythingllm
sudo docker-compose down
sudo docker-compose up -d
# 30 Sekunden warten, dann Status prüfen
sleep 30
sudo docker-compose ps
# nginx-Konfiguration für AnythingLLM finden
sudo find /etc/nginx -name "*.conf" -exec grep -l "anythingllm\|3001" {} \;
# Oder direkt checken
sudo nginx -t
sudo systemctl reload nginx
# Testen Sie direkt auf Port 3001
curl -I http://localhost:3001
docker-compose ps
sudo docker logs anythingllm
sudo docker logs ollama
# AnythingLLM-Logs prüfen
sudo docker logs anythingllm --tail 50
# Container-Status anzeigen
sudo docker-compose ps
sudo docker logs anythingllm --tail 50
# Container mit neuer Konfiguration starten
sudo docker-compose up -d
# Logs in real-time verfolgen
sudo docker logs anythingllm -f
# Container stoppen
sudo docker-compose down
# Berechtigungen für das Datenverzeichnis korrigieren
sudo chown -R 1000:1000 anythingllm_data/
sudo chmod -R 755 anythingllm_data/
# Container neu starten
sudo docker-compose up -d
# Logs verfolgen
sudo docker logs anythingllm -f
# Prüfen Sie, ob Backup-Dateien existieren
ls -la /opt/anythingllm/
# Schauen Sie nach Backup-Verzeichnissen oder .bak Dateien
ls -la *.bak*
ls -la *backup*
ls -la backups
ls -la anythingllm_data/
# Container stoppen
sudo docker-compose down
# Berechtigungen korrigieren
sudo chown -R 1000:1000 anythingllm_data/
sudo chmod -R 755 anythingllm_data/
# Container neu starten
sudo docker-compose up -d
# Prüfen, ob AnythingLLM die richtige DB findet
sudo docker exec anythingllm ls -la /app/server/storage/
sudo docker exec anythingllm cat /app/server/storage/anythingllm.db > /dev/null && echo "DB lesbar" || echo "DB nicht lesbar"
# Tabellen in der Datenbank anzeigen
sudo docker exec anythingllm sqlite3 /app/server/storage/anythingllm.db ".tables"
# Workspaces prüfen
sudo docker exec anythingllm sqlite3 /app/server/storage/anythingllm.db "SELECT name, createdAt FROM workspaces;"
# User prüfen
sudo docker exec anythingllm sqlite3 /app/server/storage/anythingllm.db "SELECT username, role FROM users;"
# Dokumente prüfen
sudo docker exec anythingllm sqlite3 /app/server/storage/anythingllm.db "SELECT filename, location FROM document_vectors LIMIT 5;"
# DB-Kopie erstellen
cp anythingllm_data/anythingllm.db /tmp/anythingllm_check.db
# Prüfen
sqlite3 /tmp/anythingllm_check.db ".tables"
sqlite3 /tmp/anythingllm_check.db "SELECT count(*) as workspace_count FROM workspaces;"
sudo apt install sqlite3
cp anythingllm_data/anythingllm.db /tmp/anythingllm_check.db
sqlite3 /tmp/anythingllm_check.db "SELECT count(*) as workspace_count FROM workspaces;"
sqlite3 /tmp/anythingllm_check.db ".tables"
sqlite3 /tmp/anythingllm_check.db "SELECT count(*) as workspace_count FROM workspaces;"
# User anzeigen
sqlite3 /tmp/anythingllm_check.db "SELECT username, role, createdAt FROM users;"
# Anzahl der User
sqlite3 /tmp/anythingllm_check.db "SELECT count(*) as user_count FROM users;"
# Prüfen ob andere wichtige Tabellen Daten haben
sqlite3 /tmp/anythingllm_check.db "SELECT count(*) FROM workspaces;"
sqlite3 /tmp/anythingllm_check.db "SELECT count(*) FROM workspace_chats;"
sqlite3 /tmp/anythingllm_check.db "SELECT count(*) FROM document_vectors;"
# Prüfen ob es ein Backup oder ältere DB-Version gibt
ls -la /opt/anythingllm/*.db*
ls -la /opt/anythingllm/*backup*
# System-weite Suche nach AnythingLLM-Backups
sudo find / -name "anythingllm*.db*" -type f 2>/dev/null
# Die alte Installation prüfen
sqlite3 /opt/anythingllm/data/storage/anythingllm.db "SELECT username, role, createdAt FROM users;"
# Die "-sohn" Installation prüfen  
sqlite3 /opt/anythingllm-sohn/data/storage/anythingllm.db "SELECT username, role, createdAt FROM users;"
# Dateigröße vergleichen
ls -la /opt/anythingllm/data/storage/anythingllm.db
ls -la /opt/anythingllm-sohn/data/storage/anythingllm.db
ls -la /opt/anythingllm/anythingllm_data/anythingllm.db
# Prüfen ob AnythingLLM wirklich die richtige DB verwendet
sudo docker exec anythingllm ls -la /app/server/storage/anythingllm.db
# Prüfen ob der Pfad stimmt
sudo docker exec anythingllm sqlite3 /app/server/storage/anythingllm.db "SELECT username FROM users;" 2>/dev/null || echo "Fehler beim DB-Zugriff"
# Prüfen ob alle erwarteten Spalten da sind
sqlite3 /opt/anythingllm/anythingllm_data/anythingllm.db ".schema users"
# Migration-Status prüfen
sqlite3 /opt/anythingllm/anythingllm_data/anythingllm.db "SELECT * FROM _prisma_migrations ORDER BY finished_at DESC LIMIT 3;"
current_time=$(date +%s)000
# Aktuelle Zeit als Timestamp (in Millisekunden)
current_time=$(date +%s)000
# User-Timestamps auf jetzt setzen
sqlite3 /opt/anythingllm/anythingllm_data/anythingllm.db "UPDATE users SET createdAt = $current_time, lastUpdatedAt = $current_time;"
# Prüfen
sqlite3 /opt/anythingllm/anythingllm_data/anythingllm.db "SELECT username, createdAt FROM users;"
# Container neu starten
sudo docker-compose restart anythingllm
# Von AnythingLLM-Container aus Ollama testen
sudo docker exec anythingllm curl -s http://ollama:11434/api/version
# Als root ausführen:
usermod -a -G www-data,sudo developer
sudo usermod -a -G www-data,sudo developer
# Beispiel für ein Web-Verzeichnis
chown -R developer:www-data /var/www/
chmod -R 755 /var/www/
sudo # Beispiel für ein Web-Verzeichnis
chown -R developer:www-data /var/www/
chmod -R 755 /var/www/
sudo chown -R developer:www-data /var/www/
sudo chown -R 755 /var/www/
sudo visudo
./backup.sh
docker-compose ps
docker exec anythingllm
docker exec --help
docker exec -d anythingllm
docker exec --help
docker exec -it anythingllm sh
sudo apt update
sudo apt upgrade
ls -la
exit
ls -la
git init
git add *
git commit -m "first commit"
git commit -m 'Initial project version'
git config --global justus.kampp@gmail.com
git commit -m 'Initial project version'
git config --global user.email "justus.kampp@gmail.com"
git commit -m 'Initial project version'
git remote add origin git@github.com:hyperion14/anythingLLL4legal.git
git push --force origin main
git remote set-url origin git@github.com:hyperion14/anythingLLL4legal.git
git push --force origin main
git branch
git push --force origin master
git add .
git commit -m "Initial commit"
git push --force origin master
cd .git
ls -la
cd branches/
ls 
ls -la
nano config
cd ..
nano COMMIT_EDITMSG
nano config
nano index 
sudo systemctl restart ssh
cd ./opt
ls -la
cd ../opt
cd ..
ls -ls
ls- la
ls -la
cd developer/
ls -la
cd ..
cd opt/
ls 
ls -la
sudo apt update
sudo apt upgrade
# System aktualisieren
sudo apt update && sudo apt upgrade -y
# Basis-Tools
sudo apt install -y     build-essential     git     curl     wget     vim     htop     tree     python3.11     python3.11-venv     python3-pip     docker.io     docker-compose
# Docker-User-Rechte
sudo usermod -aG docker $USER
newgrp docker  # Oder neu einloggen
# RAM-Check
free -h
# ✅ Erwartung: Total ~32GB, Available ~28GB
# CPU-Check
lscpu | grep "CPU(s)"
# ✅ Erwartung: 8 Cores
# Disk-Space
df -h
# ✅ Erwartung: >100GB frei (für Dokumente + Docker Images)
# Hauptprojekt
mkdir -p ~/bhk-rag-system
cd ~/bhk-rag-system
# Projekt-Sub-Struktur
mkdir -p {src,tests,config,data,docs,scripts}
mkdir -p src/{ingestion,retrieval,orchestration,api,models}
mkdir -p src/ingestion/{docling,ner,chunking,parsers}
mkdir -p data/{raw,processed,test-docs,logs}
mkdir -p config/{qdrant,neo4j,mistral}
mkdir -p tests/{unit,integration,fixtures}
# Docker-Konfigurationen
mkdir -p docker/{qdrant,neo4j,api}
# Git-Ignore vorbereiten
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

cd ~/bhk-rag-system
# Git init
git init
git config user.name "hpyerionn14"
git config user.email "justus.kampp@gmail.com"
# Erste README
cat > README.md << 'EOF'
# BHK RAG System

Hybrid RAG-System für juristische Dokumente (Vergaberecht, Bau-/Architektenrecht)

## Tech-Stack
- **Vector DB**: Qdrant (Hybrid Search)
- **Graph DB**: Neo4j 5.x
- **LLM**: Mistral Le Platform
- **NER**: Flair (ner-german-legal)
- **Pipeline**: DocLing + Python 3.11

## Status
**Phase**: Chat 2 (DocLing & NER Pipeline Implementation)

## Quick Start
```bash
./scripts/setup_env.sh
docker-compose up -d
poetry install
poetry run pytest
```

## Dokumentation
Siehe `/docs` Ordner
EOF

# Initial Commit
git add .
git commit -m "feat: Initial project structure and setup"
git config user.name "Ihr Name"
git config user.email "ihre@email.de"
git add .
git commit -m "feat: Initial project structure and setup"
git remote add origin https://github.com/ihr-username/bhk-rag-system.git
git branch -M main
git push -u origin main
git remote add origin https://github.com/hyperion14/bhk-rag-system.git
git branch -M main
git push -u origin main
git remote add origin https://github.com/hyperion14/bhk-rag-system.git
git branch -M main
git push -u origin main
git remote add origin https://github.com/hyperion14/bhk-rag-system.git
git branch -M main
git push -u origin main
cat > pyproject.toml << 'EOF'
[tool.poetry]
name = "bhk-rag-system"
version = "0.1.0"
description = "Hybrid RAG System für juristische Dokumente"
authors = ["Ihr Name <ihre@email.de>"]
readme = "README.md"
python = "^3.11"

[tool.poetry.dependencies]
python = "^3.11"
# Core Dependencies
docling = "^2.0.0"
flair = "^0.13.0"
qdrant-client = "^1.11.0"
neo4j = "^5.24.0"
mistralai = "^1.2.0"
pydantic = "^2.9.0"
python-dotenv = "^1.0.0"
pyyaml = "^6.0"
# NLP & Text Processing
spacy = "^3.7.0"
regex = "^2024.0.0"
beautifulsoup4 = "^4.12.0"
lxml = "^5.0.0"
# Storage & I/O
boto3 = "^1.35.0"  # IONOS S3
psycopg2-binary = "^2.9.0"  # PostgreSQL
sqlalchemy = "^2.0.0"  # ORM für Postgres
alembic = "^1.13.0"  # DB Migrations
# Utils
loguru = "^0.7.0"
tqdm = "^4.66.0"
click = "^8.1.0"
# API (später)
fastapi = "^0.115.0"
uvicorn = "^0.32.0"
# Testing
pytest = "^8.3.0"
pytest-cov = "^5.0.0"
pytest-asyncio = "^0.24.0"
# Development
black = "^24.0.0"
ruff = "^0.6.0"
mypy = "^1.11.0"
pre-commit = "^3.8.0"

[tool.poetry.group.dev.dependencies]
ipython = "^8.27.0"
jupyter = "^1.1.0"

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.black]
line-length = 100
target-version = ['py311']

[tool.mypy]
python_version = "3.11"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
EOF

# Dependencies installieren
poetry install
# Virtual Environment aktivieren
poetry shell
# Spacy DE-Modell laden (für Flair-Preprocessing)
python -m spacy download de_core_news_sm
cat > pyproject.toml << 'EOF'
[tool.poetry]
name = "bhk-rag-system"
version = "0.1.0"
description = "Hybrid RAG System für juristische Dokumente"
authors = ["Ihr Name <ihre@email.de>"]
readme = "README.md"
python = "^3.11"


poetry init
sudo apt install python3-poetry
# Oder direkt pyproject.toml erstellen:
cat > pyproject.toml << 'EOF'
[tool.poetry]
name = "bhk-rag-system"
version = "0.1.0"
description = "Hybrid RAG System für juristische Dokumente"
authors = ["Ihr Name <ihre@email.de>"]
readme = "README.md"
python = "^3.11"

[tool.poetry.dependencies]
python = "^3.11"
# Core Dependencies
docling = "^2.0.0"
flair = "^0.13.0"
qdrant-client = "^1.11.0"
neo4j = "^5.24.0"
mistralai = "^1.2.0"
pydantic = "^2.9.0"
python-dotenv = "^1.0.0"
pyyaml = "^6.0"
# NLP & Text Processing
spacy = "^3.7.0"
regex = "^2024.0.0"
beautifulsoup4 = "^4.12.0"
lxml = "^5.0.0"
# Storage & I/O
boto3 = "^1.35.0"  # IONOS S3
psycopg2-binary = "^2.9.0"  # PostgreSQL
sqlalchemy = "^2.0.0"  # ORM für Postgres
alembic = "^1.13.0"  # DB Migrations
# Utils
loguru = "^0.7.0"
tqdm = "^4.66.0"
click = "^8.1.0"
# API (später)
fastapi = "^0.115.0"
uvicorn = "^0.32.0"
# Testing
pytest = "^8.3.0"
pytest-cov = "^5.0.0"
pytest-asyncio = "^0.24.0"
# Development
black = "^24.0.0"
ruff = "^0.6.0"
mypy = "^1.11.0"
pre-commit = "^3.8.0"

[tool.poetry.group.dev.dependencies]
ipython = "^8.27.0"
jupyter = "^1.1.0"

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.black]
line-length = 100
target-version = ['py311']

[tool.mypy]
python_version = "3.11"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
EOF

# Dependencies installieren
poetry install
# Virtual Environment aktivieren
poetry shell
# Spacy DE-Modell laden (für Flair-Preprocessing)
python -m spacy download de_core_news_sm
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
QDRANT_API_KEY=  # Leer für lokales Deployment

# === Neo4j ===
NEO4J_URI=bolt://localhost:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=your_secure_password_here

# === PostgreSQL (User-Logs, Audit-Trail) ===
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=bhk_rag
POSTGRES_USER=bhk_admin
POSTGRES_PASSWORD=your_postgres_password_here

# === DocLing ===
DOCLING_CACHE_DIR=/tmp/docling_cache
DOCLING_OCR_ENGINE=tesseract  # oder: easyocr, paddleocr

# === Logging ===
LOG_LEVEL=INFO
LOG_FILE=data/logs/pipeline.log

# === Development ===
ENV=development  # oder: production
DEBUG=true
EOF

# Kopieren für lokale Entwicklung
cp .env.example .env
# WICHTIG: API-Keys eintragen!
vim .env  # Oder VSCode
# System aktualisieren
sudo apt update && sudo apt upgrade -y
# Basis-Tools
sudo apt install -y     build-essential     git     curl     wget     vim     htop     tree     python3.11     python3.11-venv     python3-pip     docker.io     docker-compose
# Docker-User-Rechte
sudo usermod -aG docker $USER
newgrp docker  # Oder neu einloggen
# Python Poetry (Package Manager)
curl -sSL https://install.python-poetry.org | python3 -
# Tesseract OCR (für DocLing-Fallback)
sudo apt install -y tesseract-ocr tesseract-ocr-deu
