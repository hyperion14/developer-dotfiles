# Home Directory Cleanup Strategy
**Date**: 2025-10-29
**Goal**: Organize scattered projects and scripts into a clean, maintainable structure

---

## 📊 Current Situation Analysis

### Active Projects (Keep & Organize)
1. **bhk-rag-system/** - Main project (15 dirs, active development)
2. **flask_pipeline/** - Standalone Flask app (to be merged)
3. **ionos-legal-rag/** - Related project (9 dirs)

### Backups (Archive)
1. **bhk-rag-system_backup_20251029_154040/** - Recent backup (can archive)

### Loose Scripts (Consolidate)
1. **merge_flask.sh** - Flask merge script (execute then delete)
2. **rag_setup.sh** - RAG setup script
3. **install_node.sh** - Node installation
4. **fresh_start_v2.sh** - System setup (48KB)
5. **complete-ssl.sh** - SSL setup
6. **ssl_setup.sh** - SSL setup (duplicate?)
7. **nginx-fix.sh** - Nginx configuration
8. **integrate_ollama.sh** - Ollama integration
9. **install-anythingllm.sh** - AnythingLLM installer
10. **setup-second-instance.sh** - Instance setup
11. **troubleshoot.sh** - Troubleshooting utilities

### Loose Files (Organize)
1. **Claude Code Implementation: Flask.md** - Documentation
2. **S3_Zugriff** - S3 access credentials
3. **.env.example** - Environment template

### System Directories (Leave)
- .cache, .config, .docker, .dotnet, .npm, .nvm, .ssh, .vscode-*
- .git, .claude/, snap/

### Root-owned Directories (Check)
- data/ (root:root)
- logs/ (root:root)

---

## 🎯 Cleanup Strategy

### Phase 1: Merge Flask Pipeline
**Priority**: HIGH
**Action**: Execute merge_flask.sh to consolidate flask_pipeline into bhk-rag-system

```bash
cd /home/developer
./merge_flask.sh
# After successful merge and testing:
rm -rf flask_pipeline/
rm merge_flask.sh
```

### Phase 2: Create Organization Structure
```
/home/developer/
├── projects/                    # Active development
│   ├── bhk-rag-system/         # Main project (move here)
│   └── ionos-legal-rag/        # Related project (move here)
├── scripts/                     # Utility scripts
│   ├── setup/                  # One-time setup scripts
│   │   ├── install_node.sh
│   │   ├── fresh_start_v2.sh
│   │   └── install-anythingllm.sh
│   ├── infrastructure/         # Infrastructure scripts
│   │   ├── ssl_setup.sh
│   │   ├── complete-ssl.sh
│   │   ├── nginx-fix.sh
│   │   └── setup-second-instance.sh
│   ├── integration/            # Integration scripts
│   │   ├── integrate_ollama.sh
│   │   └── rag_setup.sh
│   └── utils/                  # Utilities
│       └── troubleshoot.sh
├── docs/                       # Documentation
│   └── Claude Code Implementation: Flask.md
├── backups/                    # Project backups
│   └── bhk-rag-system_backup_20251029_154040/
├── .credentials/               # Sensitive files
│   ├── S3_Zugriff
│   └── .env.example
└── [system dirs remain unchanged]
```

### Phase 3: Fix Permissions
```bash
# Fix root-owned directories
sudo chown -R developer:developer /home/developer/data
sudo chown -R developer:developer /home/developer/logs
```

### Phase 4: Archive Old Backups
```bash
# Compress and move old backups
tar -czf backups/bhk-rag-system_backup_20251029.tar.gz bhk-rag-system_backup_20251029_154040/
rm -rf bhk-rag-system_backup_20251029_154040/
```

---

## 📋 Execution Checklist

### Immediate Actions
- [ ] Execute merge_flask.sh
- [ ] Test merged bhk-rag-system/flask_pipeline
- [ ] Delete standalone flask_pipeline/
- [ ] Create new directory structure (projects/, scripts/, docs/, backups/, .credentials/)
- [ ] Move bhk-rag-system to projects/
- [ ] Move ionos-legal-rag to projects/

### Script Organization
- [ ] Create scripts/setup/ and move setup scripts
- [ ] Create scripts/infrastructure/ and move infrastructure scripts
- [ ] Create scripts/integration/ and move integration scripts
- [ ] Create scripts/utils/ and move troubleshoot.sh
- [ ] Review and delete duplicate scripts (ssl_setup vs complete-ssl)

### Documentation & Credentials
- [ ] Move documentation to docs/
- [ ] Create .credentials/ directory (chmod 700)
- [ ] Move S3_Zugriff and .env.example to .credentials/

### Backups
- [ ] Create backups/ directory
- [ ] Compress old backup
- [ ] Move compressed backup to backups/

### Cleanup
- [ ] Fix data/ and logs/ permissions
- [ ] Delete merge_flask.sh after successful merge
- [ ] Remove .gitignore and .git from home (if not needed)
- [ ] Clean up duplicate/obsolete files

---

## 🚀 Quick Execution Script

```bash
#!/bin/bash
# Quick cleanup execution

# Phase 1: Merge flask pipeline
./merge_flask.sh && rm -rf flask_pipeline/ && rm merge_flask.sh

# Phase 2: Create structure
mkdir -p projects scripts/{setup,infrastructure,integration,utils} docs backups .credentials
chmod 700 .credentials

# Phase 3: Move projects
mv bhk-rag-system projects/
mv ionos-legal-rag projects/

# Phase 4: Organize scripts
mv install_node.sh fresh_start_v2.sh install-anythingllm.sh scripts/setup/
mv ssl_setup.sh complete-ssl.sh nginx-fix.sh setup-second-instance.sh scripts/infrastructure/
mv integrate_ollama.sh rag_setup.sh scripts/integration/
mv troubleshoot.sh scripts/utils/

# Phase 5: Move docs and credentials
mv "Claude Code Implementation: Flask.md" docs/
mv S3_Zugriff .env.example .credentials/

# Phase 6: Archive backups
tar -czf backups/bhk-rag-system_backup_20251029.tar.gz bhk-rag-system_backup_20251029_154040/
rm -rf bhk-rag-system_backup_20251029_154040/

# Phase 7: Fix permissions
sudo chown -R developer:developer data/ logs/

echo "✓ Cleanup complete!"
```

---

## 📝 Post-Cleanup Verification

After cleanup, your home directory should look like:
```
/home/developer/
├── projects/                    (2 dirs: bhk-rag-system, ionos-legal-rag)
├── scripts/                     (4 subdirs with organized scripts)
├── docs/                        (documentation files)
├── backups/                     (compressed backups)
├── .credentials/                (sensitive files, chmod 700)
├── data/                        (shared data, proper permissions)
├── logs/                        (shared logs, proper permissions)
└── [system directories: .cache, .config, .ssh, etc.]
```

**Expected Result**:
- ~27 loose files reduced to ~5 organized directories
- Clear separation between projects, scripts, docs
- No root-owned files in user home
- Proper permissions on sensitive directories
