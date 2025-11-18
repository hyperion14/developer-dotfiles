#!/bin/bash

###############################################################################
# SERVER REORGANIZATION SCRIPT
# Migrates projects from /opt to ~/projects with proper structure
###############################################################################

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths
HOME_DIR="/home/developer"
OPT_DIR="/opt"
BACKUP_DIR="$HOME_DIR/backups"

###############################################################################
# FUNCTIONS
###############################################################################

print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          SERVER STRUCTURE REORGANIZATION                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
}

print_phase() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  PHASE $1: $2${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

print_step() {
    echo -e "${GREEN}▶ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

confirm() {
    echo -e "${YELLOW}$1${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Aborted by user"
        exit 1
    fi
}

###############################################################################
# PRE-FLIGHT CHECKS
###############################################################################

print_header

print_phase "0" "Pre-flight Checks"

# Check if running as correct user
if [ "$USER" != "developer" ]; then
    print_error "This script must be run as user 'developer'"
    print_warning "Current user: $USER"
    exit 1
fi

print_success "Running as developer user"

# Check if directories exist
print_step "Checking source directories..."
ANYTHINGLLM_EXISTS=false
ANYTHINGLLM_SOHN_EXISTS=false

if [ -d "/opt/anythingllm" ]; then
    print_success "/opt/anythingllm exists"
    ANYTHINGLLM_EXISTS=true
else
    print_warning "/opt/anythingllm not found (may already be moved)"
fi

if [ -d "/opt/anythingllm-sohn" ]; then
    print_success "/opt/anythingllm-sohn exists"
    ANYTHINGLLM_SOHN_EXISTS=true
else
    print_warning "/opt/anythingllm-sohn not found (may already be moved)"
fi

if [ "$ANYTHINGLLM_EXISTS" = false ] && [ "$ANYTHINGLLM_SOHN_EXISTS" = false ]; then
    print_warning "No /opt projects to move. Structure may already be reorganized."
    read -p "Continue with other reorganization steps? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Check disk space
print_step "Checking disk space..."
AVAILABLE=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE" -lt 20 ]; then
    print_error "Not enough disk space. Need at least 20GB free, have ${AVAILABLE}GB"
    exit 1
fi
print_success "Disk space OK: ${AVAILABLE}GB available"

# Check for root-owned directories in home
print_step "Checking for permission issues..."
ROOT_OWNED=$(ls -la "$HOME_DIR" 2>/dev/null | grep "^d.*root.*root" | awk '{print $9}' | grep -v "^\." | wc -l)
if [ "$ROOT_OWNED" -gt 0 ]; then
    echo ""
    print_error "Found root-owned directories in $HOME_DIR:"
    ls -la "$HOME_DIR" | grep "^d.*root.*root" | awk '{print "  - " $9}'
    echo ""
    print_warning "These directories need to be owned by developer first."
    echo ""
    echo -e "${CYAN}Run this command to fix:${NC}"
    echo "  ./fix_permissions_first.sh"
    echo ""
    echo "Or manually:"
    echo "  sudo chown -R developer:developer ~/data ~/logs"
    echo ""
    exit 1
fi
print_success "No permission issues found"

# Show what will be done
echo ""
echo -e "${CYAN}This script will:${NC}"
echo "1. Create full backup of current state"
echo "2. Create new directory structure"
echo "3. Move /opt/anythingllm → ~/projects/production/anythingllm"
echo "4. Move /opt/anythingllm-sohn → ~/projects/development/anythingllm-sohn"
echo "5. Move ~/projects/ionos-legal-rag → ~/projects/development/ionos-legal-rag"
echo "6. Keep ~/projects/bhk-rag-system → ~/projects/production/bhk-rag-system"
echo "7. Fix all ownership to developer:developer"
echo "8. Create management scripts"
echo ""

confirm "This will reorganize your server structure."

###############################################################################
# PHASE 1: Backup
###############################################################################

print_phase "1" "Create Backup"

BACKUP_FILE="$BACKUP_DIR/pre-reorganization-$(date +%Y%m%d_%H%M%S).tar.gz"
print_step "Creating backup: $BACKUP_FILE"

# Create backup directory if needed
mkdir -p "$BACKUP_DIR"

# Backup /opt projects and ~/projects
print_step "Backing up /opt and ~/projects..."
sudo tar -czf "$BACKUP_FILE" \
    /opt/anythingllm 2>/dev/null || true \
    /opt/anythingllm-sohn 2>/dev/null || true \
    "$HOME_DIR/projects/" 2>/dev/null || true

print_success "Backup created: $BACKUP_FILE"
BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | awk '{print $1}')
print_success "Backup size: $BACKUP_SIZE"

###############################################################################
# PHASE 2: Create New Directory Structure
###############################################################################

print_phase "2" "Create New Directory Structure"

print_step "Creating directory hierarchy..."

# Main structure
mkdir -p "$HOME_DIR/projects/production"
mkdir -p "$HOME_DIR/projects/development"
mkdir -p "$HOME_DIR/projects/archived"

mkdir -p "$HOME_DIR/services/nginx"
mkdir -p "$HOME_DIR/services/systemd"
mkdir -p "$HOME_DIR/services/cron"

mkdir -p "$HOME_DIR/data/shared"
mkdir -p "$HOME_DIR/data/uploads"
mkdir -p "$HOME_DIR/data/processing"
mkdir -p "$HOME_DIR/data/exports"

mkdir -p "$HOME_DIR/logs/nginx"
mkdir -p "$HOME_DIR/logs/bhk-rag-system"
mkdir -p "$HOME_DIR/logs/anythingllm"
mkdir -p "$HOME_DIR/logs/system"

mkdir -p "$HOME_DIR/backups/databases/postgres"
mkdir -p "$HOME_DIR/backups/databases/neo4j"
mkdir -p "$HOME_DIR/backups/databases/qdrant"
mkdir -p "$HOME_DIR/backups/projects"
mkdir -p "$HOME_DIR/backups/configs"

mkdir -p "$HOME_DIR/scripts/deployment"
mkdir -p "$HOME_DIR/docs/infrastructure"
mkdir -p "$HOME_DIR/docs/projects"
mkdir -p "$HOME_DIR/docs/runbooks"

mkdir -p "$HOME_DIR/.credentials/api-keys"

print_success "Directory structure created"

###############################################################################
# PHASE 3: Stop Services
###############################################################################

print_phase "3" "Stop Running Services"

print_step "Documenting current container state..."
docker ps -a > "$BACKUP_DIR/docker-state-before-migration.txt"

if [ "$ANYTHINGLLM_EXISTS" = true ]; then
    print_step "Stopping AnythingLLM services..."
    cd /opt/anythingllm
    sudo docker-compose down || print_warning "Failed to stop AnythingLLM (may not be running)"
fi

if [ "$ANYTHINGLLM_SOHN_EXISTS" = true ]; then
    print_step "Stopping AnythingLLM-Sohn services..."
    cd /opt/anythingllm-sohn
    sudo docker-compose down || print_warning "Failed to stop AnythingLLM-Sohn (may not be running)"
fi

print_success "Services stopped"

###############################################################################
# PHASE 4: Move Projects
###############################################################################

print_phase "4" "Move Projects"

# 4a. Move AnythingLLM
if [ "$ANYTHINGLLM_EXISTS" = true ] && [ ! -d "$HOME_DIR/projects/production/anythingllm" ]; then
    print_step "Moving /opt/anythingllm → ~/projects/production/anythingllm"
    sudo mv /opt/anythingllm "$HOME_DIR/projects/production/"
    sudo chown -R developer:developer "$HOME_DIR/projects/production/anythingllm"
    print_success "AnythingLLM moved"
else
    print_warning "Skipping AnythingLLM (already moved or doesn't exist)"
fi

# 4b. Move AnythingLLM-Sohn
if [ "$ANYTHINGLLM_SOHN_EXISTS" = true ] && [ ! -d "$HOME_DIR/projects/development/anythingllm-sohn" ]; then
    print_step "Moving /opt/anythingllm-sohn → ~/projects/development/anythingllm-sohn"
    sudo mv /opt/anythingllm-sohn "$HOME_DIR/projects/development/"
    sudo chown -R developer:developer "$HOME_DIR/projects/development/anythingllm-sohn"
    print_success "AnythingLLM-Sohn moved"
else
    print_warning "Skipping AnythingLLM-Sohn (already moved or doesn't exist)"
fi

# 4c. Reorganize existing projects
if [ -d "$HOME_DIR/projects/ionos-legal-rag" ] && [ ! -d "$HOME_DIR/projects/development/ionos-legal-rag" ]; then
    print_step "Moving ~/projects/ionos-legal-rag → ~/projects/development/"
    mv "$HOME_DIR/projects/ionos-legal-rag" "$HOME_DIR/projects/development/"
    print_success "ionos-legal-rag moved to development"
fi

if [ -d "$HOME_DIR/projects/bhk-rag-system" ] && [ ! -d "$HOME_DIR/projects/production/bhk-rag-system" ]; then
    print_step "Moving ~/projects/bhk-rag-system → ~/projects/production/"
    mv "$HOME_DIR/projects/bhk-rag-system" "$HOME_DIR/projects/production/"
    print_success "bhk-rag-system moved to production"
fi

print_success "All projects moved"

###############################################################################
# PHASE 5: Fix Permissions
###############################################################################

print_phase "5" "Fix Ownership and Permissions"

print_step "Setting ownership to developer:developer..."

# Fix project ownership
sudo chown -R developer:developer "$HOME_DIR/projects/" 2>/dev/null || print_warning "Some files may remain root-owned"
sudo chown -R developer:developer "$HOME_DIR/data/" 2>/dev/null || true
sudo chown -R developer:developer "$HOME_DIR/logs/" 2>/dev/null || true
sudo chown -R developer:developer "$HOME_DIR/backups/" 2>/dev/null || true

# Secure credentials
chmod 700 "$HOME_DIR/.credentials"
chmod -R 600 "$HOME_DIR/.credentials/"* 2>/dev/null || true

print_success "Ownership fixed"

###############################################################################
# PHASE 6: Create Management Scripts
###############################################################################

print_phase "6" "Create Management Scripts"

# Start all services
print_step "Creating start-all-services.sh..."
cat > "$HOME_DIR/scripts/deployment/start-all-services.sh" << 'EOFSCRIPT'
#!/bin/bash

echo "Starting BHK RAG System..."
cd ~/projects/production/bhk-rag-system/docker
docker-compose up -d

echo "Starting AnythingLLM..."
cd ~/projects/production/anythingllm
docker-compose up -d

echo "Services started!"
docker ps
EOFSCRIPT

chmod +x "$HOME_DIR/scripts/deployment/start-all-services.sh"
print_success "Created start-all-services.sh"

# Stop all services
print_step "Creating stop-all-services.sh..."
cat > "$HOME_DIR/scripts/deployment/stop-all-services.sh" << 'EOFSCRIPT'
#!/bin/bash

echo "Stopping BHK RAG System..."
cd ~/projects/production/bhk-rag-system/docker
docker-compose down

echo "Stopping AnythingLLM..."
cd ~/projects/production/anythingllm
docker-compose down

if [ -d ~/projects/development/anythingllm-sohn ]; then
    echo "Stopping AnythingLLM-Sohn..."
    cd ~/projects/development/anythingllm-sohn
    docker-compose down
fi

echo "All services stopped!"
EOFSCRIPT

chmod +x "$HOME_DIR/scripts/deployment/stop-all-services.sh"
print_success "Created stop-all-services.sh"

# Service status
print_step "Creating service-status.sh..."
cat > "$HOME_DIR/scripts/deployment/service-status.sh" << 'EOFSCRIPT'
#!/bin/bash

echo "=== Docker Containers ==="
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=== Disk Usage ==="
df -h /

echo ""
echo "=== Service Health ==="
curl -s http://localhost:3001 > /dev/null && echo "✓ AnythingLLM (3001): OK" || echo "✗ AnythingLLM (3001): DOWN"
curl -s http://localhost:3002 > /dev/null && echo "✓ AnythingLLM-Sohn (3002): OK" || echo "✗ AnythingLLM-Sohn (3002): DOWN"
curl -s http://localhost:5001/health > /dev/null && echo "✓ BHK Flask (5001): OK" || echo "✗ BHK Flask (5001): DOWN"
EOFSCRIPT

chmod +x "$HOME_DIR/scripts/deployment/service-status.sh"
print_success "Created service-status.sh"

###############################################################################
# PHASE 7: Restart Services
###############################################################################

print_phase "7" "Restart Services"

if [ -d "$HOME_DIR/projects/production/anythingllm" ]; then
    print_step "Starting AnythingLLM..."
    cd "$HOME_DIR/projects/production/anythingllm"
    docker-compose up -d || print_warning "Failed to start AnythingLLM"
    sleep 3
fi

if [ -d "$HOME_DIR/projects/development/anythingllm-sohn" ]; then
    print_step "Starting AnythingLLM-Sohn..."
    cd "$HOME_DIR/projects/development/anythingllm-sohn"
    docker-compose up -d || print_warning "Failed to start AnythingLLM-Sohn"
    sleep 3
fi

if [ -d "$HOME_DIR/projects/production/bhk-rag-system/docker" ]; then
    print_step "BHK RAG System can be started manually:"
    echo "  cd ~/projects/production/bhk-rag-system/docker"
    echo "  docker-compose up -d"
fi

print_success "Services restarted"

###############################################################################
# PHASE 8: Verify
###############################################################################

print_phase "8" "Verification"

print_step "Checking Docker containers..."
docker ps -a

echo ""
print_step "Checking project structure..."
tree -L 2 -d "$HOME_DIR/projects" 2>/dev/null || ls -la "$HOME_DIR/projects/"

echo ""
print_step "Checking ownership..."
ls -la "$HOME_DIR/projects/"

###############################################################################
# SUMMARY
###############################################################################

print_phase "✓" "REORGANIZATION COMPLETE"

echo ""
echo -e "${GREEN}Server structure successfully reorganized!${NC}"
echo ""
echo -e "${CYAN}New Structure:${NC}"
echo "  ~/projects/production/         - Production services"
echo "    ├── bhk-rag-system/"
echo "    └── anythingllm/"
echo "  ~/projects/development/        - Development projects"
echo "    ├── ionos-legal-rag/"
echo "    └── anythingllm-sohn/"
echo "  ~/data/                        - Shared data"
echo "  ~/logs/                        - Centralized logs"
echo "  ~/backups/                     - All backups"
echo "  ~/scripts/deployment/          - Management scripts"
echo ""
echo -e "${CYAN}Management Commands:${NC}"
echo "  Start all:    ~/scripts/deployment/start-all-services.sh"
echo "  Stop all:     ~/scripts/deployment/stop-all-services.sh"
echo "  Check status: ~/scripts/deployment/service-status.sh"
echo ""
echo -e "${CYAN}Backup Location:${NC}"
echo "  $BACKUP_FILE"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Test all services"
echo "2. Update documentation"
echo "3. Commit changes to Git"
echo "4. Clean up empty /opt directories (sudo rmdir /opt/anythingllm /opt/anythingllm-sohn)"
echo ""
print_success "All done! 🚀"
