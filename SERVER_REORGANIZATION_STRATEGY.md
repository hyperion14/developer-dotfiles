# Server Reorganization Strategy

**Date**: 2025-11-10
**Goal**: Systematically organize all development projects and services on the server

---

## 📊 Current Situation Analysis

### Server-wide Overview
- **Total Disk**: 466GB (15% used, 69GB)
- **Available**: 397GB

### Current Problems
1. ❌ Projects scattered across `/home/developer/projects/` and `/opt/`
2. ❌ AnythingLLM projects in `/opt/` (should be in user space)
3. ❌ Mixed ownership (root and developer) in `/opt/anythingllm/`
4. ❌ Data directories owned by root in `~/projects/`
5. ❌ No clear separation between production and development services
6. ❌ Docker compose files scattered in different locations

### Current Directory Structure

#### `/home/developer/` (Organized - from recent cleanup)
```
/home/developer/
├── projects/
│   ├── bhk-rag-system/          ✓ Good location
│   ├── ionos-legal-rag/         ✓ Good location
│   ├── data/                    ⚠ Root-owned
│   └── logs/                    ⚠ Root-owned
├── scripts/                      ✓ Organized
├── docs/                         ✓ Organized
├── backups/                      ✓ Organized
└── .credentials/                 ✓ Secured
```

#### `/opt/` (Messy - needs cleanup)
```
/opt/
├── anythingllm/                 ❌ Should be in ~/projects/
│   ├── docker-compose.yml
│   ├── anythingllm_data/
│   ├── ollama_data/
│   ├── data/
│   ├── backups/
│   └── .env
├── anythingllm-sohn/            ❌ Should be in ~/projects/
│   ├── docker-compose.yml
│   ├── data/
│   ├── backups/
│   └── .env
├── acronis/                     ✓ System backup (keep)
├── Acronis/                     ✓ System backup (keep)
└── containerd/                  ✓ System (keep)
```

### Running Services
```
✓ anythingllm         (port 3001) - Up 4 weeks
✓ anythingllm-sohn    (port 3002) - Up 4 weeks
✓ ollama              (port 11434) - Up 4 weeks
⚠ ollama-sohn         (port 11435) - Up 2 weeks (unhealthy)
✓ bhk-postgres        (port 5432) - Up 11 days
✓ bhk-neo4j           (port 7474, 7687) - Up 11 days
✓ bhk-qdrant          (port 6333-6334) - Up 11 days
○ bhk-flask-pipeline  - Exited
```

---

## 🎯 Proposed New Structure

### Philosophy
1. **Developer workspace**: All dev projects in `~/projects/`
2. **System services**: Only system-level tools in `/opt/`
3. **Clear ownership**: Developer owns all dev projects
4. **Service separation**: Production vs Development vs Personal
5. **Data centralization**: Shared data in `~/data/`, project data in project dirs

---

## 📁 New Directory Structure

### `/home/developer/` - Developer Workspace

```
/home/developer/
│
├── projects/                           # All development projects
│   ├── production/                     # Production services
│   │   ├── bhk-rag-system/            # Main RAG system
│   │   │   ├── docker/
│   │   │   │   └── docker-compose.yml
│   │   │   ├── flask_pipeline/
│   │   │   ├── src/
│   │   │   ├── data/                  # Project-specific data
│   │   │   ├── logs/                  # Project-specific logs
│   │   │   └── .env
│   │   │
│   │   └── anythingllm/               # Main AnythingLLM (moved from /opt)
│   │       ├── docker-compose.yml
│   │       ├── anythingllm_data/
│   │       ├── ollama_data/
│   │       ├── backups/
│   │       └── .env
│   │
│   ├── development/                    # Development projects
│   │   ├── ionos-legal-rag/           # Moved from projects/
│   │   │   ├── app/
│   │   │   ├── config/
│   │   │   ├── docker-compose.yml
│   │   │   └── .env
│   │   │
│   │   └── anythingllm-sohn/          # Development instance (moved from /opt)
│   │       ├── docker-compose.yml
│   │       ├── data/
│   │       ├── backups/
│   │       └── .env
│   │
│   └── archived/                       # Old/inactive projects
│       └── (move old projects here)
│
├── services/                           # Standalone services (not Docker)
│   ├── nginx/                         # If running nginx outside Docker
│   ├── systemd/                       # Custom systemd services
│   └── cron/                          # Cron jobs
│
├── data/                               # Shared data (owned by developer)
│   ├── shared/                        # Data shared between projects
│   ├── uploads/                       # Common upload area
│   ├── processing/                    # Common processing area
│   └── exports/                       # Common export area
│
├── logs/                               # Centralized logs (owned by developer)
│   ├── nginx/
│   ├── bhk-rag-system/
│   ├── anythingllm/
│   └── system/
│
├── backups/                            # All backups
│   ├── databases/                     # Database backups
│   │   ├── postgres/
│   │   ├── neo4j/
│   │   └── qdrant/
│   ├── projects/                      # Project backups
│   │   ├── bhk-rag-system/
│   │   └── anythingllm/
│   └── configs/                       # Configuration backups
│
├── scripts/                            # Organized scripts (already done)
│   ├── setup/
│   ├── infrastructure/
│   ├── integration/
│   ├── utils/
│   └── deployment/                    # Add deployment scripts
│
├── docs/                               # Documentation (already done)
│   ├── infrastructure/
│   ├── projects/
│   └── runbooks/
│
├── .credentials/                       # Secrets (already secured)
│   ├── .env.example
│   ├── S3_Zugriff
│   └── api-keys/
│
└── .config/                            # User configurations
    ├── git/
    ├── docker/
    └── systemd/
```

### `/opt/` - System Services Only

```
/opt/
├── acronis/              # ✓ Keep (system backup)
├── Acronis/              # ✓ Keep (system backup)
└── containerd/           # ✓ Keep (Docker system)
```

**Remove from /opt:**
- ❌ `anythingllm/` → Move to `~/projects/production/anythingllm/`
- ❌ `anythingllm-sohn/` → Move to `~/projects/development/anythingllm-sohn/`

---

## 🔄 Migration Plan

### Phase 1: Preparation (Backup Everything)

```bash
# Create backup of current state
sudo tar -czf ~/backups/pre-reorganization-backup-$(date +%Y%m%d).tar.gz \
  /opt/anythingllm /opt/anythingllm-sohn ~/projects/

# Create new directory structure
mkdir -p ~/projects/{production,development,archived}
mkdir -p ~/services/{nginx,systemd,cron}
mkdir -p ~/data/{shared,uploads,processing,exports}
mkdir -p ~/logs/{nginx,bhk-rag-system,anythingllm,system}
mkdir -p ~/backups/{databases/{postgres,neo4j,qdrant},projects,configs}
mkdir -p ~/scripts/deployment
mkdir -p ~/docs/{infrastructure,projects,runbooks}
mkdir -p ~/.credentials/api-keys
```

### Phase 2: Move Projects

#### 2a. Move AnythingLLM (Main)
```bash
# Stop services
cd /opt/anythingllm
docker-compose down

# Move to new location
sudo mv /opt/anythingllm ~/projects/production/
sudo chown -R developer:developer ~/projects/production/anythingllm

# Update docker-compose.yml paths (if needed)
cd ~/projects/production/anythingllm
# Review and update volume paths in docker-compose.yml

# Restart services
docker-compose up -d

# Verify services
docker ps | grep anythingllm
curl http://localhost:3001  # Test
```

#### 2b. Move AnythingLLM-Sohn (Development)
```bash
# Stop services
cd /opt/anythingllm-sohn
docker-compose down

# Move to new location
sudo mv /opt/anythingllm-sohn ~/projects/development/
sudo chown -R developer:developer ~/projects/development/anythingllm-sohn

# Update docker-compose.yml paths
cd ~/projects/development/anythingllm-sohn

# Restart services
docker-compose up -d

# Verify
docker ps | grep anythingllm-sohn
curl http://localhost:3002
```

#### 2c. Reorganize Existing Projects
```bash
# Move ionos-legal-rag to development
mv ~/projects/ionos-legal-rag ~/projects/development/

# Keep bhk-rag-system in production
mv ~/projects/bhk-rag-system ~/projects/production/

# Fix ownership of data and logs
sudo chown -R developer:developer ~/projects/data ~/projects/logs
```

### Phase 3: Fix Permissions

```bash
# Ensure developer owns everything in home
sudo chown -R developer:developer ~/projects/
sudo chown -R developer:developer ~/data/
sudo chown -R developer:developer ~/logs/
sudo chown -R developer:developer ~/backups/

# Secure credentials
chmod 700 ~/.credentials
chmod 600 ~/.credentials/*
```

### Phase 4: Update Configurations

#### Update Docker Compose Files
For each moved project, check and update:
- Volume paths (absolute → relative or correct absolute)
- Network names (if shared)
- Port conflicts

#### Update Environment Variables
```bash
# Create master environment tracker
cat > ~/docs/infrastructure/environment-variables.md << 'EOF'
# Environment Variables by Project

## bhk-rag-system
- POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB
- NEO4J_URI, NEO4J_USER
- QDRANT_HOST, QDRANT_PORT
- MISTRAL_API_KEY
- IONOS_S3_ACCESS_KEY, IONOS_S3_SECRET_KEY

## anythingllm (production)
- Port: 3001
- Data: ~/projects/production/anythingllm/anythingllm_data

## anythingllm-sohn (development)
- Port: 3002
- Data: ~/projects/development/anythingllm-sohn/data
EOF
```

### Phase 5: Create Management Scripts

#### Start All Services
```bash
cat > ~/scripts/deployment/start-all-services.sh << 'EOF'
#!/bin/bash
# Start all production services

echo "Starting BHK RAG System..."
cd ~/projects/production/bhk-rag-system/docker
docker-compose up -d

echo "Starting AnythingLLM..."
cd ~/projects/production/anythingllm
docker-compose up -d

echo "Services started!"
docker ps
EOF

chmod +x ~/scripts/deployment/start-all-services.sh
```

#### Stop All Services
```bash
cat > ~/scripts/deployment/stop-all-services.sh << 'EOF'
#!/bin/bash
# Stop all services

echo "Stopping BHK RAG System..."
cd ~/projects/production/bhk-rag-system/docker
docker-compose down

echo "Stopping AnythingLLM..."
cd ~/projects/production/anythingllm
docker-compose down

echo "Stopping Development services..."
cd ~/projects/development/anythingllm-sohn
docker-compose down

echo "All services stopped!"
EOF

chmod +x ~/scripts/deployment/stop-all-services.sh
```

#### Service Status
```bash
cat > ~/scripts/deployment/service-status.sh << 'EOF'
#!/bin/bash
# Check status of all services

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
EOF

chmod +x ~/scripts/deployment/service-status.sh
```

### Phase 6: Documentation

Create project documentation in each directory:

```bash
# bhk-rag-system
cat > ~/projects/production/bhk-rag-system/README.md << 'EOF'
# BHK RAG System

Production hybrid RAG system for legal document processing.

## Location
`~/projects/production/bhk-rag-system/`

## Services
- PostgreSQL: 5432
- Neo4j: 7474, 7687
- Qdrant: 6333-6334
- Flask API: 5001

## Quick Start
```bash
cd ~/projects/production/bhk-rag-system/docker
docker-compose up -d
```

## Data
- Uploads: `data/uploads/`
- Processing: `data/processing/`
- Logs: `logs/`
EOF

# anythingllm
cat > ~/projects/production/anythingllm/README.md << 'EOF'
# AnythingLLM (Production)

Main AnythingLLM instance with Ollama integration.

## Location
`~/projects/production/anythingllm/`

## Services
- AnythingLLM: 3001
- Ollama: 11434

## Quick Start
```bash
cd ~/projects/production/anythingllm
docker-compose up -d
```

## Data
- AnythingLLM data: `anythingllm_data/`
- Ollama models: `ollama_data/`
- Backups: `backups/`
EOF
```

---

## 📋 Migration Checklist

### Pre-Migration
- [ ] Create full backup of `/opt/anythingllm` and `/opt/anythingllm-sohn`
- [ ] Create backup of current `~/projects/`
- [ ] Document current Docker container states
- [ ] Document current port assignments
- [ ] Check disk space (need ~10GB free for moves)

### Migration
- [ ] Create new directory structure
- [ ] Stop all Docker containers
- [ ] Move anythingllm from /opt to ~/projects/production/
- [ ] Move anythingllm-sohn from /opt to ~/projects/development/
- [ ] Move ionos-legal-rag to ~/projects/development/
- [ ] Keep bhk-rag-system in ~/projects/production/
- [ ] Fix all file ownership (developer:developer)
- [ ] Update docker-compose.yml paths
- [ ] Update .env files if needed

### Post-Migration
- [ ] Start services one by one
- [ ] Verify each service works
- [ ] Check logs for errors
- [ ] Test all endpoints
- [ ] Update documentation
- [ ] Create management scripts
- [ ] Clean up empty /opt directories
- [ ] Update GitHub repositories

### Verification
- [ ] All containers running: `docker ps`
- [ ] AnythingLLM accessible: http://localhost:3001
- [ ] AnythingLLM-Sohn accessible: http://localhost:3002
- [ ] BHK RAG System health: http://localhost:5001/health
- [ ] No permission errors in logs
- [ ] All data accessible
- [ ] Backups working

---

## 🚀 Benefits of New Structure

### Organization
✅ **Clear hierarchy**: production vs development vs archived
✅ **Logical grouping**: Similar projects together
✅ **Easy to find**: Everything in expected locations

### Maintenance
✅ **Easier backups**: All projects in `~/projects/`
✅ **Simpler updates**: Clear project separation
✅ **Better monitoring**: Centralized logs

### Security
✅ **Proper ownership**: All dev files owned by developer
✅ **No sudo needed**: For daily development work
✅ **Credentials isolated**: In secured `.credentials/`

### Scalability
✅ **Add new projects**: Just put in production/development/
✅ **Archive old projects**: Move to archived/
✅ **Share between projects**: Use `~/data/shared/`

---

## 📊 Expected Results

### Before
```
Projects:      Scattered (~/projects + /opt)
Ownership:     Mixed (root + developer)
Organization:  Flat structure
Maintenance:   Difficult (multiple locations)
```

### After
```
Projects:      Centralized (~/projects/{production,development})
Ownership:     Consistent (developer:developer)
Organization:  Hierarchical (production/dev/archived)
Maintenance:   Easy (single location, management scripts)
```

---

## ⚠️ Important Notes

1. **Backup First**: Always backup before moving production services
2. **Stop Services**: Always stop Docker containers before moving
3. **Test Incrementally**: Move and test one service at a time
4. **Keep /opt Clean**: Only system-level tools in /opt
5. **Document Changes**: Update all documentation after moves
6. **Update Git**: Commit new structure to repositories

---

## 🆘 Rollback Plan

If something goes wrong:

```bash
# Stop new services
~/scripts/deployment/stop-all-services.sh

# Restore from backup
cd ~
tar -xzf backups/pre-reorganization-backup-$(date +%Y%m%d).tar.gz -C /

# Move back to /opt
sudo mv ~/projects/production/anythingllm /opt/
sudo mv ~/projects/development/anythingllm-sohn /opt/

# Restart original services
cd /opt/anythingllm && docker-compose up -d
cd /opt/anythingllm-sohn && docker-compose up -d
```

---

**Ready to reorganize?** Run the automated migration script next!
