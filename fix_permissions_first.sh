#!/bin/bash

###############################################################################
# FIX PERMISSIONS SCRIPT
# Fixes root-owned directories in home before migration
###############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           FIX HOME DIRECTORY PERMISSIONS                   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}This script will fix root-owned directories in your home.${NC}"
echo ""
echo "The following directories are currently owned by root:"
echo ""

ls -la /home/developer/ | grep "^d.*root.*root" | awk '{print "  - " $9}'

echo ""
echo -e "${CYAN}These will be changed to developer:developer${NC}"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

echo ""
echo -e "${GREEN}▶ Fixing ownership...${NC}"
echo -e "${YELLOW}(You will be prompted for your sudo password)${NC}"
echo ""

# Fix data directory
if [ -d /home/developer/data ]; then
    sudo chown -R developer:developer /home/developer/data
    echo -e "${GREEN}✓ Fixed: /home/developer/data${NC}"
fi

# Fix logs directory
if [ -d /home/developer/logs ]; then
    sudo chown -R developer:developer /home/developer/logs
    echo -e "${GREEN}✓ Fixed: /home/developer/logs${NC}"
fi

# Fix projects data/logs if they exist
if [ -d /home/developer/projects/data ]; then
    sudo chown -R developer:developer /home/developer/projects/data
    echo -e "${GREEN}✓ Fixed: /home/developer/projects/data${NC}"
fi

if [ -d /home/developer/projects/logs ]; then
    sudo chown -R developer:developer /home/developer/projects/logs
    echo -e "${GREEN}✓ Fixed: /home/developer/projects/logs${NC}"
fi

echo ""
echo -e "${GREEN}✓ Ownership fixed!${NC}"
echo ""
echo "Verification:"
ls -la /home/developer/ | grep -E "^d.*(data|logs)"
echo ""
echo -e "${CYAN}Now you can run the migration script:${NC}"
echo "  ./migrate_server_structure.sh"
echo ""
