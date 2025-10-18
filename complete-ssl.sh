#!/bin/bash

# Komplette SSL-Installation für eunomialegal.de
# Certbot installieren und SSL-Zertifikate erstellen

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=== SSL-ZERTIFIKAT INSTALLATION für eunomialegal.de ==="
echo ""

# 1. Certbot installieren
print_info "Installiere Certbot..."
apt update
apt install -y certbot python3-certbot-nginx

print_success "Certbot installiert"

# 2. DNS-Tests vor SSL
print_info "Teste DNS-Auflösung..."

if nslookup anythingllm.eunomialegal.de | grep -q "217.160.216.231"; then
    print_success "DNS für anythingllm.eunomialegal.de funktioniert"
    MAIN_DNS_OK=true
else
    print_error "DNS für anythingllm.eunomialegal.de funktioniert NICHT!"
    echo "Strato DNS-Record prüfen: A-Record anythingllm → 217.160.216.231"
    MAIN_DNS_OK=false
fi

if [ -d "/opt/anythingllm-sohn" ]; then
    if nslookup jasper.eunomialegal.de | grep -q "217.160.216.231"; then
        print_success "DNS für jasper.eunomialegal.de funktioniert"
        JASPER_DNS_OK=true
    else
        print_error "DNS für jasper.eunomialegal.de funktioniert NICHT!"
        echo "Strato DNS-Record prüfen: A-Record jasper → 217.160.216.231"
        JASPER_DNS_OK=false
    fi
fi

# 3. HTTP-Tests vor SSL
print_info "Teste HTTP-Erreichbarkeit..."

if curl -s -I http://anythingllm.eunomialegal.de | grep -q "200\|302"; then
    print_success "HTTP für anythingllm.eunomialegal.de funktioniert"
    MAIN_HTTP_OK=true
else
    print_error "HTTP für anythingllm.eunomialegal.de funktioniert NICHT!"
    echo "Nginx-Status prüfen: sudo systemctl status nginx"
    MAIN_HTTP_OK=false
fi

if [ -d "/opt/anythingllm-sohn" ] && [ "$JASPER_DNS_OK" = true ]; then
    if curl -s -I http://jasper.eunomialegal.de | grep -q "200\|302"; then
        print_success "HTTP für jasper.eunomialegal.de funktioniert"
        JASPER_HTTP_OK=true
    else
        print_error "HTTP für jasper.eunomialegal.de funktioniert NICHT!"
        JASPER_HTTP_OK=false
    fi
fi

echo ""

# 4. SSL-Zertifikate nur wenn DNS und HTTP funktionieren
if [ "$MAIN_DNS_OK" = true ] && [ "$MAIN_HTTP_OK" = true ]; then
    print_info "Erstelle SSL-Zertifikat für anythingllm.eunomialegal.de..."
    
    certbot --nginx \
        -d anythingllm.eunomialegal.de \
        --non-interactive \
        --agree-tos \
        --email justus.kampp@gmail.com \
        --redirect
    
    if [ $? -eq 0 ]; then
        print_success "SSL-Zertifikat für anythingllm.eunomialegal.de erstellt!"
        MAIN_SSL_OK=true
    else
        print_error "SSL-Zertifikat für anythingllm.eunomialegal.de fehlgeschlagen!"
        MAIN_SSL_OK=false
    fi
else
    print_error "Überspringe SSL für anythingllm.eunomialegal.de - DNS oder HTTP Problem"
    MAIN_SSL_OK=false
fi

# Jasper SSL falls verfügbar und vorherige Checks OK
if [ -d "/opt/anythingllm-sohn" ] && [ "$JASPER_DNS_OK" = true ] && [ "$JASPER_HTTP_OK" = true ]; then
    print_info "Erstelle SSL-Zertifikat für jasper.eunomialegal.de..."
    
    certbot --nginx \
        -d jasper.eunomialegal.de \
        --non-interactive \
        --agree-tos \
        --email justus.kampp@gmail.com \
        --redirect
    
    if [ $? -eq 0 ]; then
        print_success "SSL-Zertifikat für jasper.eunomialegal.de erstellt!"
        JASPER_SSL_OK=true
    else
        print_error "SSL-Zertifikat für jasper.eunomialegal.de fehlgeschlagen!"
        JASPER_SSL_OK=false
    fi
else
    print_error "Überspringe SSL für jasper.eunomialegal.de - DNS oder HTTP Problem"
    JASPER_SSL_OK=false
fi

# 5. Auto-Renewal einrichten
print_info "Richte automatische Erneuerung ein..."
systemctl enable certbot.timer
systemctl start certbot.timer

# Renewal testen
certbot renew --dry-run

print_success "Auto-Renewal konfiguriert"

# 6. Zusammenfassung
echo ""
echo "========================================="
echo "           INSTALLATION ABGESCHLOSSEN"
echo "========================================="
echo ""

if [ "$MAIN_SSL_OK" = true ]; then
    echo "✅ https://anythingllm.eunomialegal.de (Hauptinstanz)"
else
    echo "❌ anythingllm.eunomialegal.de (SSL fehlgeschlagen)"
fi

if [ -d "/opt/anythingllm-sohn" ]; then
    if [ "$JASPER_SSL_OK" = true ]; then
        echo "✅ https://jasper.eunomialegal.de (Jasper-Instanz)"
    else
        echo "❌ jasper.eunomialegal.de (SSL fehlgeschlagen)"
    fi
fi

echo ""
echo "🔧 Nützliche Befehle:"
echo "   nginx -t                    # Nginx-Config testen"
echo "   systemctl reload nginx      # Nginx neu laden"
echo "   certbot certificates       # Zertifikate anzeigen"
echo "   certbot renew              # Zertifikate erneuern"
echo ""

# 7. Firewall-Hinweis
echo "🔥 IONOS Firewall-Ports prüfen:"
echo "   Port 80 (HTTP) - offen?"
echo "   Port 443 (HTTPS) - offen?"
echo ""

# 8. Status-Check
echo "🧪 Finale Tests:"
if [ "$MAIN_SSL_OK" = true ]; then
    echo "   curl -I https://anythingllm.eunomialegal.de"
fi
if [ "$JASPER_SSL_OK" = true ]; then
    echo "   curl -I https://jasper.eunomialegal.de"
fi

echo ""
echo "🎉 Setup abgeschlossen!"