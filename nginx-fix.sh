#!/bin/bash

# Manueller Fix für Nginx-Konfiguration
# Korrekte Subdomains: anythingllm.eunomialegal.de und jasper.eunomialegal.de

set -e

echo "=== NGINX REPARATUR für eunomialegal.de ==="

# Nginx stoppen
sudo systemctl stop nginx

# Alte, fehlerhafte Configs entfernen
sudo rm -f /etc/nginx/sites-enabled/anythingllm*
sudo rm -f /etc/nginx/sites-available/anythingllm*

# Korrekte Nginx-Config für anythingllm.eunomialegal.de
sudo tee /etc/nginx/sites-available/anythingllm-main << 'EOF'
# AnythingLLM Hauptinstanz - anythingllm.eunomialegal.de
server {
    listen 80;
    server_name anythingllm.eunomialegal.de;
    
    # Erstmal nur HTTP (SSL kommt später)
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
        client_max_body_size 100M;
    }
    
    location /health {
        access_log off;
        return 200 "healthy - anythingllm main\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Korrekte Nginx-Config für jasper.eunomialegal.de (falls Sohn-Instanz existiert)
if [ -d "/opt/anythingllm-sohn" ]; then
    sudo tee /etc/nginx/sites-available/jasper << 'EOF'
# AnythingLLM Jasper-Instanz - jasper.eunomialegal.de
server {
    listen 80;
    server_name jasper.eunomialegal.de;
    
    # Erstmal nur HTTP (SSL kommt später)
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
        client_max_body_size 100M;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
    
    location /health {
        access_log off;
        return 200 "healthy - jasper instance\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    sudo ln -sf /etc/nginx/sites-available/jasper /etc/nginx/sites-enabled/
    echo "✅ Jasper-Config erstellt"
fi

# Sites aktivieren
sudo ln -sf /etc/nginx/sites-available/anythingllm-main /etc/nginx/sites-enabled/

# Default Site entfernen falls vorhanden
sudo rm -f /etc/nginx/sites-enabled/default

# Nginx Config testen
echo "Teste Nginx-Konfiguration..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "✅ Nginx-Config ist valide"
    
    # Nginx starten
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    echo ""
    echo "🎉 Nginx erfolgreich repariert!"
    echo ""
    echo "📍 DNS-Records prüfen bei Strato:"
    echo "   A-Record: anythingllm → 217.160.216.231" 
    echo "   A-Record: jasper → 217.160.216.231"
    echo ""
    echo "🧪 HTTP-Test (ohne SSL):"
    echo "   http://anythingllm.eunomialegal.de"
    if [ -d "/opt/anythingllm-sohn" ]; then
        echo "   http://jasper.eunomialegal.de"
    fi
    echo ""
    echo "⏭️  Nächster Schritt: SSL-Zertifikate hinzufügen"
    echo "   sudo certbot --nginx -d anythingllm.eunomialegal.de"
    if [ -d "/opt/anythingllm-sohn" ]; then
        echo "   sudo certbot --nginx -d jasper.eunomialegal.de"
    fi
    
else
    echo "❌ Nginx-Config hat Fehler!"
    sudo nginx -t
fi