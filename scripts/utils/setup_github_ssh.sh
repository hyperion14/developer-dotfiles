#!/bin/bash

###############################################################################
# GITHUB SSH KEY SETUP SCRIPT
# Ensures SSH key is properly configured for GitHub access
###############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           GITHUB SSH KEY SETUP                             ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if key exists
if [ ! -f ~/.ssh/github_id_ed25519.pub ]; then
    echo -e "${RED}✗ GitHub SSH key not found!${NC}"
    echo ""
    echo "Would you like to create a new key? (y/N)"
    read -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}▶ Creating new SSH key...${NC}"
        ssh-keygen -t ed25519 -C "justus.kampp@gmail.com" -f ~/.ssh/github_id_ed25519 -N ""
        echo -e "${GREEN}✓ Key created${NC}"
    else
        exit 1
    fi
fi

# Start SSH agent and add key
echo -e "${GREEN}▶ Starting SSH agent...${NC}"
eval "$(ssh-agent -s)"

echo ""
echo -e "${YELLOW}Adding SSH key to agent...${NC}"
echo -e "${YELLOW}(You may need to enter your passphrase)${NC}"
echo ""

if ssh-add ~/.ssh/github_id_ed25519; then
    echo -e "${GREEN}✓ Key added to SSH agent${NC}"
else
    echo -e "${RED}✗ Failed to add key to agent${NC}"
    echo "If you don't remember the passphrase, you can create a new key."
    exit 1
fi

# Show public key
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Add this PUBLIC KEY to your GitHub account:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
cat ~/.ssh/github_id_ed25519.pub
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Instructions:${NC}"
echo "1. Go to: ${CYAN}https://github.com/settings/keys${NC}"
echo "2. Click '${GREEN}New SSH key${NC}'"
echo "3. Title: '${GREEN}Developer Server - BHK RAG${NC}'"
echo "4. Key type: '${GREEN}Authentication Key${NC}'"
echo "5. Paste the key shown above"
echo "6. Click '${GREEN}Add SSH key${NC}'"
echo ""
read -p "Press Enter after adding the key to GitHub..."

# Test connection
echo ""
echo -e "${GREEN}▶ Testing GitHub connection...${NC}"
echo ""

if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo ""
    echo -e "${GREEN}✓ SUCCESS! GitHub SSH is working!${NC}"
    echo ""
    echo -e "${CYAN}You can now run:${NC}"
    echo "  ./setup_github_repos.sh"
    echo ""
    exit 0
else
    echo ""
    echo -e "${YELLOW}⚠ Connection test details:${NC}"
    ssh -T git@github.com 2>&1
    echo ""
    echo -e "${RED}✗ GitHub connection failed${NC}"
    echo ""
    echo "Possible issues:"
    echo "- Key not added to GitHub account yet"
    echo "- Wrong key added to GitHub"
    echo "- Network/firewall blocking SSH"
    echo ""
    echo "Try the test manually:"
    echo "  ssh -T git@github.com"
    echo ""
    exit 1
fi
