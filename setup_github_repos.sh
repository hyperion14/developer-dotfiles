#!/bin/bash

###############################################################################
# GITHUB REPOSITORIES SETUP SCRIPT
# Sets up two repositories: bhk-rag-system and developer-dotfiles
###############################################################################

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

###############################################################################
# CONFIGURATION
###############################################################################

# GitHub username (CHANGE THIS!)
GITHUB_USERNAME="${GITHUB_USERNAME:-YOUR_USERNAME}"

# Repository names
BHK_REPO="bhk-rag-system"
DOTFILES_REPO="developer-dotfiles"

# Paths
BHK_PATH="/home/developer/projects/bhk-rag-system"
HOME_PATH="/home/developer"

###############################################################################
# FUNCTIONS
###############################################################################

print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           GITHUB REPOSITORIES SETUP                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
}

print_phase() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
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

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed"
        return 1
    fi
    return 0
}

###############################################################################
# PRE-FLIGHT CHECKS
###############################################################################

print_header

print_phase "PRE-FLIGHT CHECKS"

# Check if git is installed
print_step "Checking git installation..."
if check_command git; then
    print_success "Git is installed"
else
    print_error "Git is not installed. Please install git first."
    exit 1
fi

# Check GitHub username
if [ "$GITHUB_USERNAME" = "YOUR_USERNAME" ]; then
    print_warning "GitHub username not set!"
    echo ""
    read -p "Enter your GitHub username: " GITHUB_USERNAME
    if [ -z "$GITHUB_USERNAME" ]; then
        print_error "GitHub username is required"
        exit 1
    fi
fi

print_success "GitHub username: $GITHUB_USERNAME"

# Check SSH key
print_step "Checking SSH key for GitHub..."
if [ -f ~/.ssh/github_id_ed25519 ]; then
    print_success "SSH key found: ~/.ssh/github_id_ed25519"
    echo ""
    echo -e "${CYAN}Make sure this public key is added to your GitHub account:${NC}"
    echo -e "${YELLOW}https://github.com/settings/keys${NC}"
    echo ""
    cat ~/.ssh/github_id_ed25519.pub
    echo ""
    confirm "Is this SSH key added to your GitHub account?"
else
    print_warning "GitHub SSH key not found"
    confirm "Do you want to create a new SSH key for GitHub?"

    ssh-keygen -t ed25519 -C "github@$GITHUB_USERNAME" -f ~/.ssh/github_id_ed25519 -N ""
    print_success "SSH key created"
    echo ""
    echo -e "${CYAN}Add this public key to your GitHub account:${NC}"
    echo -e "${YELLOW}https://github.com/settings/keys${NC}"
    echo ""
    cat ~/.ssh/github_id_ed25519.pub
    echo ""
    read -p "Press Enter after adding the key to GitHub..."
fi

# Check if directories exist
print_step "Checking directories..."
if [ ! -d "$BHK_PATH" ]; then
    print_error "bhk-rag-system directory not found: $BHK_PATH"
    exit 1
fi
print_success "Directories exist"

###############################################################################
# PHASE 1: Setup bhk-rag-system Repository
###############################################################################

print_phase "PHASE 1: Setup bhk-rag-system Repository"

cd "$BHK_PATH"

# Check git status
print_step "Checking git status..."
if [ ! -d .git ]; then
    print_warning "Not a git repository. Initializing..."
    git init
    git branch -M main
fi

# Check for untracked files
print_step "Adding untracked files..."
git add claude_code_instr/ 2>/dev/null || true
git add docker/ 2>/dev/null || true
git add flask_pipeline/ 2>/dev/null || true
git add poetry.lock pyproject.toml 2>/dev/null || true
print_success "Files staged"

# Show what will be committed
echo ""
echo -e "${CYAN}Files to be committed:${NC}"
git status --short

# Create initial commit
confirm "Create initial commit for bhk-rag-system?"

print_step "Creating initial commit..."
git commit -m "Initial commit: BHK RAG System with Flask pipeline

- Flask application with source detection
- Docker compose setup (PostgreSQL, Neo4j, Qdrant)
- 9 specialized extractors for legal documents
- Complete test suite
- Production-ready containerization

🤖 Generated with Claude Code" || print_warning "Nothing to commit (maybe already committed)"

print_success "Repository prepared"

# Add remote
print_step "Adding GitHub remote..."
REMOTE_URL="git@github.com:${GITHUB_USERNAME}/${BHK_REPO}.git"

if git remote | grep -q "^origin$"; then
    print_warning "Remote 'origin' already exists"
    git remote set-url origin "$REMOTE_URL"
    print_success "Updated remote URL"
else
    git remote add origin "$REMOTE_URL"
    print_success "Added remote: $REMOTE_URL"
fi

print_success "bhk-rag-system repository ready!"

###############################################################################
# PHASE 2: Setup developer-dotfiles Repository
###############################################################################

print_phase "PHASE 2: Setup developer-dotfiles Repository"

cd "$HOME_PATH"

# Clean up git tracking of moved/deleted files
print_step "Cleaning up moved/deleted files..."

# Remove deleted files from git index
git rm -r --cached ionos-legal-rag 2>/dev/null || true
git rm --cached S3_Zugriff 2>/dev/null || true
git rm --cached *-ssl.sh *-fix.sh *-instance.sh 2>/dev/null || true
git rm --cached fresh_start_v2.sh install-anythingllm.sh 2>/dev/null || true
git rm --cached integrate_ollama.sh troubleshoot.sh 2>/dev/null || true

print_success "Cleaned up tracking"

# Add organized structure
print_step "Adding organized structure..."
git add .gitignore 2>/dev/null || true
git add .bashrc 2>/dev/null || true
git add scripts/ 2>/dev/null || true
git add docs/ 2>/dev/null || true
git add CLEANUP_STRATEGY.md GITHUB_STRATEGY.md 2>/dev/null || true

print_success "Files staged"

# Show what will be committed
echo ""
echo -e "${CYAN}Files to be committed:${NC}"
git status --short | head -20
echo ""

# Create commit
confirm "Create commit for developer-dotfiles?"

print_step "Creating commit..."
git commit -m "Organize home directory structure

- Scripts organized into categories (setup, infrastructure, integration, utils)
- Documentation consolidated in docs/
- Projects moved to dedicated directories
- Credentials secured in .credentials/
- Comprehensive .gitignore for privacy

🤖 Generated with Claude Code" || print_warning "Nothing to commit (maybe already committed)"

print_success "Repository prepared"

# Add remote
print_step "Adding GitHub remote..."
REMOTE_URL="git@github.com:${GITHUB_USERNAME}/${DOTFILES_REPO}.git"

if git remote | grep -q "^origin$"; then
    print_warning "Remote 'origin' already exists"
    git remote set-url origin "$REMOTE_URL"
    print_success "Updated remote URL"
else
    git remote add origin "$REMOTE_URL"
    print_success "Added remote: $REMOTE_URL"
fi

print_success "developer-dotfiles repository ready!"

###############################################################################
# PHASE 3: Create GitHub Repositories
###############################################################################

print_phase "PHASE 3: Create GitHub Repositories"

echo ""
echo -e "${CYAN}Now you need to create the repositories on GitHub:${NC}"
echo ""
echo -e "${YELLOW}1. Go to: https://github.com/new${NC}"
echo ""
echo -e "${GREEN}2. Create first repository:${NC}"
echo "   Repository name: ${BHK_REPO}"
echo "   Description: Hybrid RAG System for legal document processing"
echo "   Visibility: Private (or Public if open-sourcing)"
echo "   ☐ Do NOT initialize with README"
echo "   ☐ Do NOT add .gitignore"
echo "   ☐ Do NOT add license (we'll add later if needed)"
echo ""
echo -e "${GREEN}3. Create second repository:${NC}"
echo "   Repository name: ${DOTFILES_REPO}"
echo "   Description: Personal development environment configuration"
echo "   Visibility: Private"
echo "   ☐ Do NOT initialize with README"
echo "   ☐ Do NOT add .gitignore"
echo ""

confirm "Have you created both repositories on GitHub?"

###############################################################################
# PHASE 4: Push to GitHub
###############################################################################

print_phase "PHASE 4: Push to GitHub"

# Push bhk-rag-system
print_step "Pushing bhk-rag-system..."
cd "$BHK_PATH"

# Ensure we're on main branch
git branch -M main

# Push to GitHub
if git push -u origin main 2>&1 | tee /tmp/git_push_bhk.log; then
    print_success "bhk-rag-system pushed to GitHub!"
else
    print_error "Failed to push bhk-rag-system"
    echo "Check the error above. Common issues:"
    echo "- Repository doesn't exist on GitHub"
    echo "- SSH key not added to GitHub account"
    echo "- Wrong repository URL"
    exit 1
fi

# Push developer-dotfiles
print_step "Pushing developer-dotfiles..."
cd "$HOME_PATH"

# Ensure we're on main branch
git branch -M main

# Push to GitHub
if git push -u origin main 2>&1 | tee /tmp/git_push_dotfiles.log; then
    print_success "developer-dotfiles pushed to GitHub!"
else
    print_error "Failed to push developer-dotfiles"
    echo "Check the error above. Common issues:"
    echo "- Repository doesn't exist on GitHub"
    echo "- SSH key not added to GitHub account"
    echo "- Wrong repository URL"
    exit 1
fi

###############################################################################
# SUMMARY
###############################################################################

print_phase "✓ SETUP COMPLETE"

echo ""
echo -e "${GREEN}Your repositories are now on GitHub!${NC}"
echo ""
echo -e "${CYAN}Repository URLs:${NC}"
echo "  📦 bhk-rag-system:    https://github.com/${GITHUB_USERNAME}/${BHK_REPO}"
echo "  🏠 developer-dotfiles: https://github.com/${GITHUB_USERNAME}/${DOTFILES_REPO}"
echo ""
echo -e "${CYAN}Local paths:${NC}"
echo "  📁 bhk-rag-system:    $BHK_PATH"
echo "  📁 developer-dotfiles: $HOME_PATH"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Add README.md to both repositories"
echo "2. Configure branch protection on main branches"
echo "3. Add collaborators if needed"
echo "4. Set up GitHub Actions for CI/CD (optional)"
echo ""
echo -e "${GREEN}Daily workflow:${NC}"
echo "  # Pull latest changes"
echo "  git pull"
echo ""
echo "  # Make changes, then commit"
echo "  git add ."
echo "  git commit -m \"Description of changes\""
echo ""
echo "  # Push to GitHub"
echo "  git push"
echo ""
print_success "All done! 🚀"
