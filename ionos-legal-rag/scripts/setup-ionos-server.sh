#!/bin/bash

echo "🏛️ === IONOS Server Setup für Legal-RAG System ==="

# System Update
apt update && apt upgrade -y

# Docker installieren
echo "🐳 Installiere Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Docker Compose installieren
echo "🔧 Installiere Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Weitere Tools
apt install -y git htop ncdu unzip curl

# Firewall konfigurieren
ufw --force enable
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow 8000
ufw allow 3000
ufw allow 8080
ufw allow 7474

# Deutsche Locale installieren
locale-gen de_DE.UTF-8
update-locale LANG=de_DE.UTF-8

# Projekt-Verzeichnis
mkdir -p /opt/ionos-legal-rag
cd /opt/ionos-legal-rag

echo "✅ IONOS Server Setup abgeschlossen!"
echo ""
echo "📋 Nächste Schritte:"
echo "1. Git Repository klonen oder Dateien hochladen"
echo "2. .env Datei aus .env.template erstellen und konfigurieren"  
echo "3. IONOS AI Hub API Key eintragen"
echo "4. IONOS S3 Access Keys eintragen"
echo "5. docker-compose up -d ausführen"
echo ""
echo "🌐 Services nach dem Start:"
echo "- http://[SERVER-IP]:8000 → Legal-RAG API + GUI"
echo "- http://[SERVER-IP]:3000 → Open WebUI Chat"
echo "- http://[SERVER-IP]:8080 → Adminer Database"
echo "- http://[SERVER-IP]:7474 → Neo4j Browser"
