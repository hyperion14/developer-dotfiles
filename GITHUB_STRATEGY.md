# GitHub Repository Strategy

**Date**: 2025-10-29
**Purpose**: Establish version control strategy for home directory and BHK RAG System

---

## 🎯 Strategy Overview

### Recommended Approach: **2 Separate Repositories**

1. **`bhk-rag-system`** - Main application repository (Public/Private)
2. **`developer-dotfiles`** - Personal configuration repository (Private)

**Rationale**:
- ✅ Separation of concerns (application vs environment)
- ✅ Cleaner application repository without personal configs
- ✅ Easy to share application code
- ✅ Personal configs remain private
- ✅ Different update frequencies

---

## 📦 Repository 1: bhk-rag-system

### Purpose
Main BHK RAG System application - legal document processing pipeline with hybrid RAG

### Location
`~/projects/bhk-rag-system/`

### Visibility
**Recommended**: Private (contains business logic)
**Alternative**: Public (if open-sourcing)

### What to Include
```
✅ Application code
  ├── src/                    # Source code
  ├── flask_pipeline/         # Flask application
  ├── tests/                  # Unit & integration tests
  ├── docker/                 # Docker configurations
  ├── scripts/                # Application scripts
  └── docs/                   # Documentation

✅ Configuration templates
  ├── .env.example
  ├── config/*.example
  └── pyproject.toml

✅ Infrastructure as Code
  ├── docker-compose.yml
  ├── Dockerfile
  └── requirements.txt

✅ Documentation
  ├── README.md
  ├── INSTALL.md
  └── API_DOCS.md
```

### What to Exclude (via .gitignore)
```
❌ Secrets & credentials
  ├── .env
  ├── *.key
  ├── *.pem
  └── config/secrets/

❌ Data & logs
  ├── data/raw/*
  ├── data/processed/*
  ├── logs/*
  └── *.log

❌ Generated files
  ├── __pycache__/
  ├── *.pyc
  ├── .pytest_cache/
  └── flask_pipeline_backup_*/

❌ Docker volumes
  ├── neo4j/data/
  ├── neo4j/logs/
  └── qdrant/storage/
```

### Current Status
- Git initialized: ✅ (on branch master)
- Remote configured: ❌ (none)
- Untracked files:
  - claude_code_instr/
  - docker/
  - flask_pipeline/
  - flask_pipeline_backup_*
  - poetry.lock
  - pyproject.toml

---

## 📦 Repository 2: developer-dotfiles

### Purpose
Personal development environment configuration and utilities

### Location
`~/` (home directory)

### Visibility
**Recommended**: Private (contains personal configurations)

### What to Include
```
✅ Configuration files
  ├── .bashrc
  ├── .gitconfig
  └── .ssh/config

✅ Scripts collection
  └── scripts/
      ├── setup/
      ├── infrastructure/
      ├── integration/
      └── utils/

✅ Documentation
  ├── README.md
  ├── SETUP.md
  └── docs/

✅ Project management
  ├── CLEANUP_STRATEGY.md
  └── GITHUB_STRATEGY.md
```

### What to Exclude (via .gitignore)
```
❌ Projects (have their own repos)
  └── projects/*

❌ Secrets & keys
  ├── .credentials/*
  ├── .ssh/*.pem
  ├── .ssh/*_rsa
  └── .ssh/*_ed25519*

❌ Sensitive files
  ├── .bash_history
  ├── .viminfo
  └── .lesshst

❌ Cache & temporary
  ├── .cache/
  ├── .npm/
  ├── .nvm/
  └── .local/

❌ IDE & tool configs
  ├── .claude/
  ├── .claude.json*
  ├── .vscode-*/
  └── .docker/

❌ Backups
  └── backups/*

❌ Data & logs
  ├── data/*
  └── logs/*
```

### Current Status
- Git initialized: ✅ (on branch master)
- Remote configured: ❌ (none)
- Many tracked files that should be ignored

---

## 🚀 Implementation Plan

### Phase 1: Prepare Repositories

#### A. BHK RAG System
```bash
cd ~/projects/bhk-rag-system

# 1. Update .gitignore
# 2. Add untracked files
git add claude_code_instr/ docker/ flask_pipeline/ poetry.lock pyproject.toml

# 3. Remove backup from tracking
echo "flask_pipeline_backup_*/" >> .gitignore

# 4. Create initial commit
git commit -m "Initial commit: BHK RAG System with Flask pipeline

- Flask application with source detection
- Docker compose setup (PostgreSQL, Neo4j, Qdrant)
- 9 specialized extractors for legal documents
- Complete test suite
- Production-ready containerization"

# 5. Create GitHub repository (see below)
```

#### B. Developer Dotfiles
```bash
cd ~

# 1. Clean up git tracking
git rm --cached ionos-legal-rag -rf
git rm --cached S3_Zugriff complete-ssl.sh fresh_start_v2.sh
# ... (remove all moved/deleted files)

# 2. Update .gitignore (comprehensive version)

# 3. Add organized structure
git add scripts/ docs/ CLEANUP_STRATEGY.md GITHUB_STRATEGY.md

# 4. Create commit
git commit -m "Organize home directory structure

- Scripts organized into categories
- Documentation consolidated
- Projects moved to dedicated directories
- Credentials secured"
```

---

### Phase 2: Create GitHub Repositories

#### Option A: Using GitHub Web Interface

1. **Go to GitHub.com**
   - Navigate to https://github.com/new

2. **Create bhk-rag-system repository**
   ```
   Repository name: bhk-rag-system
   Description: Hybrid RAG System for legal document processing
   Visibility: Private (or Public if open-sourcing)
   ☐ Add README (already exists)
   ☐ Add .gitignore (already exists)
   ☐ Add license (optional: MIT, Apache 2.0)
   ```

3. **Create developer-dotfiles repository**
   ```
   Repository name: developer-dotfiles
   Description: Personal development environment configuration
   Visibility: Private
   ☐ Add README (will create manually)
   ☐ Add .gitignore (will create manually)
   ```

#### Option B: Using Git Command Line

```bash
# Install GitHub CLI first (if not installed)
curl -fsSL https://cli.github.com/packages/githubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# Authenticate
gh auth login

# Create repositories
cd ~/projects/bhk-rag-system
gh repo create bhk-rag-system --private --source=. --remote=origin --push

cd ~
gh repo create developer-dotfiles --private --source=. --remote=origin --push
```

---

### Phase 3: Link Local Repositories to GitHub

#### For bhk-rag-system
```bash
cd ~/projects/bhk-rag-system

# Add remote
git remote add origin git@github.com:YOUR_USERNAME/bhk-rag-system.git

# Verify
git remote -v

# Push initial commit
git branch -M main  # Rename master to main (optional)
git push -u origin main
```

#### For developer-dotfiles
```bash
cd ~

# Add remote
git remote add origin git@github.com:YOUR_USERNAME/developer-dotfiles.git

# Verify
git remote -v

# Push initial commit
git branch -M main
git push -u origin main
```

---

## 📋 .gitignore Files

### For bhk-rag-system
Already exists at `~/projects/bhk-rag-system/.gitignore`

**Additions needed**:
```bash
cd ~/projects/bhk-rag-system

cat >> .gitignore << 'EOF'

# Flask pipeline backups
flask_pipeline_backup_*/

# Claude Code
.claude/
.claude.json

# Development docs (optional)
claude_code_instr/

EOF
```

### For home directory (developer-dotfiles)
Create comprehensive version:

```bash
cd ~
cat > .gitignore << 'EOF'
# Projects (have their own repos)
projects/

# Secrets & SSH Keys
.credentials/
.ssh/*.pem
.ssh/*_rsa
.ssh/*_rsa.pub
.ssh/*_ed25519
.ssh/*_ed25519.pub
.ssh/known_hosts
.ssh/known_hosts.old
.env
.env.*
!.env.example

# History & Sessions
.bash_history
.viminfo
.lesshst
.wget-hsts

# Cache & Temporary
.cache/
.npm/
.nvm/
.local/
.dotnet/
.docker/

# IDE & Development Tools
.vscode-server/
.vscode-remote-containers/
.claude/
.claude.json
.claude.json.backup
.config/

# Backups & Archives
backups/
*.tar.gz
*.zip
*_backup_*/

# Data & Logs
data/
logs/
*.log

# System Files
.DS_Store
Thumbs.db
.sudo_as_admin_successful

# Snap
snap/

# Git (keep only local config)
.git/
.gitconfig

EOF
```

---

## 🔐 Security Checklist

Before pushing to GitHub, verify:

- [ ] No `.env` files in repository
- [ ] No SSH private keys
- [ ] No API keys or tokens
- [ ] No passwords or credentials
- [ ] No sensitive customer data
- [ ] No database dumps
- [ ] `.gitignore` properly configured
- [ ] Secrets in `.credentials/` (excluded)
- [ ] `S3_Zugriff` excluded from repo

---

## 📚 Repository Structure

### bhk-rag-system Repository
```
bhk-rag-system/
├── README.md                       # Project overview
├── INSTALL.md                      # Installation guide
├── pyproject.toml                  # Python dependencies
├── poetry.lock                     # Locked dependencies
├── .gitignore                      # Git exclusions
├── .env.example                    # Environment template
├── docker/
│   ├── docker-compose.yml          # Services orchestration
│   ├── neo4j/                      # Neo4j config
│   └── qdrant/                     # Qdrant config
├── flask_pipeline/
│   ├── Dockerfile                  # Flask container
│   ├── app.py                      # Application entry
│   ├── requirements.txt            # Python deps
│   ├── api/                        # API routes
│   ├── config/                     # Configuration
│   ├── models/                     # Database models
│   └── flask_pipeline/             # Core package
│       ├── pipeline/               # Processing pipeline
│       │   ├── source_detector.py  # Source detection
│       │   └── extractors/         # 9 extractors
│       ├── models/                 # Data models
│       └── tests/                  # Unit tests
├── src/                            # Additional source
│   ├── api/
│   ├── ingestion/
│   └── retrieval/
├── tests/                          # Integration tests
├── scripts/                        # Utility scripts
└── docs/                           # Documentation
```

### developer-dotfiles Repository
```
developer-dotfiles/
├── README.md                       # Setup guide
├── .gitignore                      # Git exclusions
├── .bashrc                         # Bash config
├── scripts/
│   ├── setup/                      # Setup scripts
│   │   ├── install_node.sh
│   │   └── fresh_start_v2.sh
│   ├── infrastructure/             # Infrastructure
│   │   ├── ssl_setup.sh
│   │   └── nginx-fix.sh
│   ├── integration/                # Integrations
│   │   └── rag_setup.sh
│   └── utils/                      # Utilities
│       └── troubleshoot.sh
├── docs/
│   └── Claude Code Implementation: Flask.md
├── CLEANUP_STRATEGY.md
└── GITHUB_STRATEGY.md
```

---

## 🔄 Workflow After Setup

### Daily Development (bhk-rag-system)
```bash
cd ~/projects/bhk-rag-system

# Pull latest changes
git pull

# Create feature branch
git checkout -b feature/new-feature

# Make changes, test, commit
git add .
git commit -m "Add new feature"

# Push to GitHub
git push origin feature/new-feature

# Create pull request on GitHub
# Merge after review
```

### Environment Updates (developer-dotfiles)
```bash
cd ~

# Update scripts or configs
vim scripts/setup/new_script.sh

# Commit changes
git add scripts/
git commit -m "Add new setup script"

# Push to GitHub
git push
```

---

## 🎯 Next Steps

1. **Install GitHub CLI** (optional but recommended)
   ```bash
   curl -fsSL https://cli.github.com/packages/githubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
   sudo apt update && sudo apt install gh
   gh auth login
   ```

2. **Update .gitignore files** (see sections above)

3. **Clean git status** (remove deleted/moved files from tracking)

4. **Create GitHub repositories** (via web or CLI)

5. **Push initial commits**

6. **Add README files** with proper documentation

7. **Set up branch protection** (for main branch)

8. **Configure GitHub Actions** (optional: CI/CD)

---

## 📝 README Templates

### bhk-rag-system/README.md
```markdown
# BHK RAG System

Hybrid RAG (Retrieval-Augmented Generation) system for processing and analyzing legal documents.

## Features

- 🔍 **Source Detection**: Automatic identification of document sources (Beck, Juris, IBR, etc.)
- 📄 **Document Processing**: 9 specialized extractors for different document types
- 🐳 **Containerized**: Full Docker setup with PostgreSQL, Neo4j, and Qdrant
- 🧪 **Tested**: Comprehensive test suite
- 🚀 **Production Ready**: Gunicorn with 4 workers

## Quick Start

```bash
# Clone repository
git clone git@github.com:YOUR_USERNAME/bhk-rag-system.git
cd bhk-rag-system

# Setup environment
cp .env.example .env
# Edit .env with your API keys

# Start services
cd docker
docker-compose up -d

# Access API
curl http://localhost:5001/health
```

## Documentation

- [Installation Guide](INSTALL.md)
- [API Documentation](docs/API.md)
- [Development Guide](docs/DEVELOPMENT.md)

## License

[Choose: MIT, Apache 2.0, or Proprietary]
```

### developer-dotfiles/README.md
```markdown
# Developer Dotfiles

Personal development environment configuration and utility scripts.

## Structure

- `scripts/` - Organized utility scripts
- `docs/` - Documentation and guides
- Configuration files for bash, git, etc.

## Setup

```bash
# Clone to home directory
git clone git@github.com:YOUR_USERNAME/developer-dotfiles.git ~/dotfiles
cd ~/dotfiles

# Link configurations (optional)
ln -s ~/dotfiles/.bashrc ~/.bashrc

# Make scripts executable
chmod +x scripts/**/*.sh
```

## Scripts

- **Setup**: System and tool installation
- **Infrastructure**: SSL, Nginx, server setup
- **Integration**: RAG system, Ollama integration
- **Utils**: Troubleshooting and maintenance

## Private Repository

This repository contains personal configurations and should remain private.
```

---

## ⚠️ Important Notes

1. **Never commit secrets**: Always check for API keys, passwords, or tokens before committing
2. **Use .env files**: Keep sensitive configuration in `.env` (excluded from git)
3. **Branch protection**: Enable on main branch to prevent direct pushes
4. **Regular backups**: GitHub is not a backup solution, maintain separate backups
5. **Documentation**: Keep README files updated with latest changes

---

## 🆘 Troubleshooting

### Issue: "remote: Repository not found"
**Solution**: Check repository name and permissions, ensure SSH key is added to GitHub

### Issue: "Permission denied (publickey)"
**Solution**: Add SSH key to GitHub account
```bash
cat ~/.ssh/github_id_ed25519.pub
# Copy and add to GitHub Settings > SSH Keys
```

### Issue: Large files error
**Solution**: Use Git LFS for files >100MB
```bash
git lfs install
git lfs track "*.pdf"
git add .gitattributes
```

---

**Strategy created**: 2025-10-29
**Status**: Ready for implementation
**Estimated time**: 30-60 minutes
