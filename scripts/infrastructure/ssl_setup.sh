#!/bin/bash

# Generisches SSL-Zertifikat Setup
# Let's Encrypt + Nginx Reverse Proxy
# Das Skript erstellt Zertifikate für beliebige Hauptdomains und deren Subdomains.

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${GREEN}"
    echo "============================================"
    echo "  Generisches SSL-Zertifikat Setup"
    echo "============================================"
    echo -e "${NC}"
}

validate_domain() {
    local domain="$1"
    
    # Prüfe ob Domain mindestens einen Punkt enthält
    if [[ ! "$domain" =~ \. ]]; then
        return 1
    fi
    
    # Prüfe auf gültige Zeichen (a-z, 0-9, -, .)
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        return 1
    fi
    
    # Prüfe dass Domain nicht mit - oder . beginnt/endet
    if [[ "$domain" =~ ^[-.]|[-.]$ ]]; then
        return 1
    fi
    
    return 0
}

validate_subdomain() {
    local subdomain="$1"
    
    # Prüfe auf gültige Zeichen für Subdomain (a-z, 0-9, -)
    if [[ ! "$subdomain" =~ ^[a-zA-Z0-9-]+$ ]]; then
        return 1
    fi
    
    # Prüfe dass Subdomain nicht mit - beginnt/endet
    if [[ "$subdomain" =~ ^-|-$ ]]; then
        return 1
    fi
    
    return 0
}

test_domain_reachability() {
    local domain="$1"
    
    print_info "Teste DNS-Auflösung für $domain..."
    
    if nslookup "$domain" >/dev/null 2>&1; then
        print_success "DNS-Auflösung für $domain erfolgreich"
        return 0
    else
        print_warning "DNS-Auflösung für $domain fehlgeschlagen"
        return 1
    fi
}

setup_domains() {
    print_info "=== DOMAIN-KONFIGURATION ==="
    
    while true; do
        echo ""
        echo "Gib die Hauptdomain ein, für die das Zertifikat erstellt werden soll."
        echo "Beispiel: meinedomain.de"
        read -p "Hauptdomain eingeben: " MAIN_DOMAIN
        
        if validate_domain "$MAIN_DOMAIN"; then
            print_success "Hauptdomain '$MAIN_DOMAIN' ist gültig"
            break
        else
            print_error "Ungültige Hauptdomain '$MAIN_DOMAIN'. Bitte versuche es erneut."
            echo "Eine gültige Domain muss:"
            echo "  - Mindestens einen Punkt enthalten (z.B. .de, .com)"
            echo "  - Nur Buchstaben, Zahlen, Bindestriche und Punkte enthalten"
            echo "  - Nicht mit Bindestrich oder Punkt beginnen/enden"
        fi
    done
    
    echo ""
    echo "Gib zusätzliche SUBDOMAINS ein (nur die Bezeichnung vor der Hauptdomain)."
    echo "Diese werden automatisch mit der Hauptdomain '$MAIN_DOMAIN' kombiniert."
    echo "Verwende Kommas, um mehrere Subdomains zu trennen."
    echo "Beispiele:"
    echo "  www,api          → www.$MAIN_DOMAIN, api.$MAIN_DOMAIN"
    echo "  www              → www.$MAIN_DOMAIN"
    echo "  any1,any2,admin  → any1.$MAIN_DOMAIN, any2.$MAIN_DOMAIN, admin.$MAIN_DOMAIN"
    echo "Lasse das Feld leer, wenn keine Subdomains benötigt werden."
    read -p "Subdomains eingeben: " SUBDOMAINS_INPUT
    
    # Domains in ein Array einfügen
    DOMAINS=("$MAIN_DOMAIN")
    INVALID_SUBDOMAINS=()
    
    if [ ! -z "$SUBDOMAINS_INPUT" ]; then
        IFS=',' read -r -a SUBDOMAINS <<< "$SUBDOMAINS_INPUT"
        for subdomain in "${SUBDOMAINS[@]}"; do
            # Whitespace entfernen
            subdomain=$(echo "$subdomain" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            if [ ! -z "$subdomain" ]; then
                if validate_subdomain "$subdomain"; then
                    # Vollständige Domain aus Subdomain + Hauptdomain erstellen
                    full_domain="$subdomain.$MAIN_DOMAIN"
                    DOMAINS+=("$full_domain")
                    print_success "Subdomain '$subdomain' → '$full_domain' hinzugefügt"
                else
                    INVALID_SUBDOMAINS+=("$subdomain")
                    print_error "Ungültige Subdomain '$subdomain' - wird übersprungen"
                fi
            fi
        done
    fi
    
    if [ ${#INVALID_SUBDOMAINS[@]} -gt 0 ]; then
        echo ""
        print_warning "Folgende Subdomains wurden übersprungen (ungültig):"
        for invalid_subdomain in "${INVALID_SUBDOMAINS[@]}"; do
            echo "  ❌ $invalid_subdomain"
        done
        echo ""
        print_info "Ungültige Subdomains dürfen nur enthalten:"
        echo "  - Buchstaben (a-z, A-Z)"
        echo "  - Zahlen (0-9)"
        echo "  - Bindestriche (-), aber nicht am Anfang oder Ende"
        echo ""
        read -p "Trotzdem fortfahren? (j/N): " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[jJ]$ ]]; then
            print_info "Setup abgebrochen."
            exit 0
        fi
    fi
    
    # E-Mail-Adresse für Certbot abfragen
    while true; do
        read -p "Gib deine E-Mail-Adresse für Certbot ein: " CERTBOT_EMAIL
        
        # Einfache E-Mail-Validierung
        if [[ "$CERTBOT_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            print_error "Ungültige E-Mail-Adresse. Bitte versuche es erneut."
        fi
    done
    
    echo ""
    print_success "Zertifikat wird für folgende Domain(s) erstellt:"
    for domain in "${DOMAINS[@]}"; do
        echo "  ✅ $domain"
    done
    
    echo ""
    print_info "Teste DNS-Auflösung für alle Domains..."
    UNREACHABLE_DOMAINS=()
    for domain in "${DOMAINS[@]}"; do
        if ! test_domain_reachability "$domain"; then
            UNREACHABLE_DOMAINS+=("$domain")
        fi
    done
    
    if [ ${#UNREACHABLE_DOMAINS[@]} -gt 0 ]; then
        echo ""
        print_warning "Folgende Domains konnten nicht aufgelöst werden:"
        for unreachable_domain in "${UNREACHABLE_DOMAINS[@]}"; do
            echo "  ⚠️  $unreachable_domain"
        done
        echo ""
        print_warning "Let's Encrypt kann nur Zertifikate für erreichbare Domains erstellen."
        print_info "Stelle sicher, dass die DNS-Einträge korrekt sind und auf diesen Server zeigen."
        echo ""
        read -p "Trotzdem fortfahren? (j/N): " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[jJ]$ ]]; then
            print_info "Setup abgebrochen. Konfiguriere zuerst die DNS-Einträge."
            exit 0
        fi
    fi
}

setup_nginx() {
    print_info "=== NGINX INSTALLATION ==="
    
    apt-get update
    apt-get install -y nginx dnsutils  # dnsutils für nslookup
    
    systemctl start nginx
    systemctl enable nginx
    
    ufw allow 'Nginx Full'
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    print_success "Nginx installiert und konfiguriert"
}

setup_certbot() {
    print_info "=== CERTBOT INSTALLATION ==="
    
    apt-get install -y certbot python3-certbot-nginx
    
    print_success "Certbot installiert"
}

create_nginx_config() {
    print_info "=== NGINX-KONFIGURATION ==="
    
    local SERVER_NAMES_STRING="${DOMAINS[*]}"
    local CONFIG_PATH="/etc/nginx/sites-available/default-ssl-proxy"
    local SYMLINK_PATH="/etc/nginx/sites-enabled/default-ssl-proxy"
    
    # Default-Site deaktivieren
    rm -f /etc/nginx/sites-enabled/default
    
    print_info "Erstelle Nginx-Konfiguration für ${SERVER_NAMES_STRING}..."
    
    cat > "$CONFIG_PATH" << EOF
server {
    listen 80;
    server_name $SERVER_NAMES_STRING;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $SERVER_NAMES_STRING;
    
    # Die SSL-Konfiguration wird von Certbot automatisch hinzugefügt
    
    # Security Headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubdomains; preload" always;
    
    # Proxy-Pass auf Port 3001 (oder einen anderen gewünschten Dienst)
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
        client_max_body_size 200M;
    }
}
EOF
    
    ln -sf "$CONFIG_PATH" "$SYMLINK_PATH"
    
    nginx -t
    systemctl reload nginx
    
    print_success "Nginx-Konfiguration erstellt und aktiviert."
}

create_letsencrypt_cert() {
    print_info "=== LET'S ENCRYPT ZERTIFIKATE ==="
    
    local DOMAIN_ARGS=""
    for domain in "${DOMAINS[@]}"; do
        DOMAIN_ARGS+=" -d $domain"
    done
    
    print_info "Erstelle Zertifikat mit Certbot..."
    print_info "Domains: $DOMAIN_ARGS"
    
    if certbot --nginx $DOMAIN_ARGS --non-interactive --agree-tos --email $CERTBOT_EMAIL; then
        print_success "Let's Encrypt Zertifikat für alle Domains erstellt."
        
        certbot renew --dry-run
        print_info "Auto-Renewal erfolgreich getestet."
    else
        print_error "Zertifikaterstellung fehlgeschlagen!"
        print_info "Mögliche Ursachen:"
        echo "  - DNS-Einträge zeigen nicht auf diesen Server"
        echo "  - Domains sind nicht erreichbar"
        echo "  - Firewall blockiert Port 80/443"
        echo "  - Rate-Limit von Let's Encrypt erreicht"
        exit 1
    fi
}

main() {
    print_header
    
    if [[ $EUID -ne 0 ]]; then
        print_error "Dieses Skript muss als root ausgeführt werden!"
        print_info "Verwende: sudo $0"
        exit 1
    fi
    
    setup_nginx
    setup_certbot
    
    setup_domains
    
    create_nginx_config
    
    print_info "Warte 30 Sekunden auf DNS-Propagation..."
    sleep 30
    
    create_letsencrypt_cert
    
    print_success "SSL-Setup abgeschlossen!"
    echo ""
    echo "🎉 Installation erfolgreich!"
    echo "================================"
    echo ""
    echo "✅ Sichere URLs:"
    for DOMAIN in "${DOMAINS[@]}"; do
        echo "   🔒 https://$DOMAIN"
    done
    
    echo ""
    echo "🔧 Nützliche Befehle:"
    echo "   nginx -t                    # Nginx-Config testen"
    echo "   systemctl reload nginx      # Nginx neu laden"
    echo "   certbot renew              # Zertifikate erneuern"
    echo "   certbot certificates       # Zertifikate anzeigen"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi