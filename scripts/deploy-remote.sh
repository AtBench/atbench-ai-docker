#!/bin/bash
# =============================================================================
# deploy-remote.sh - Deploy AtBench AI to VPS from local machine (Source Build)
# =============================================================================
# SSH into VPS, pull latest changes from all repos, and run deployment
#
# Directory Structure on VPS:
#   /root/
#   ├── atbench-ai/              (source repo)
#   ├── atbench-ai-interviews/   (source repo)
#   └── atbench-ai-docker/       (docker configs)
#
# Usage:
#   ./scripts/deploy-remote.sh [SSH_KEY_PATH]
#
# Examples:
#   ./scripts/deploy-remote.sh                    # Use default key
#   ./scripts/deploy-remote.sh ~/.ssh/id_rsa     # Use custom key
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# VPS Configuration (UPDATE THESE VALUES)
VPS_IP="${VPS_IP:-YOUR_VPS_IP}"          # e.g., 192.168.1.100
VPS_USER="${VPS_USER:-root}"
VPS_BASE_DIR="${VPS_BASE_DIR:-/root}"

# Default SSH key path (UPDATE THIS)
DEFAULT_SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"

# Parse arguments
SSH_KEY="${1:-$DEFAULT_SSH_KEY}"

# Check if VPS_IP is configured
if [ "$VPS_IP" = "YOUR_VPS_IP" ]; then
    echo -e "${RED}Error: VPS_IP not configured${NC}"
    echo ""
    echo "Please set VPS_IP in one of the following ways:"
    echo "  1. Edit this script and update VPS_IP variable"
    echo "  2. Set environment variable: export VPS_IP=192.168.1.100"
    echo ""
    exit 1
fi

# Validate SSH key file exists
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}Error: SSH key file not found: $SSH_KEY${NC}"
    echo ""
    echo "Usage: $0 [SSH_KEY_PATH]"
    echo ""
    echo "Examples:"
    echo "  $0                        # Use default key (~/.ssh/id_rsa)"
    echo "  $0 ~/.ssh/my-key         # Use custom key"
    echo ""
    echo "Or set environment variable: export SSH_KEY=~/.ssh/my-key"
    exit 1
fi

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  AtBench AI Remote Deployment (Source Build)${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "${YELLOW}VPS:${NC} $VPS_USER@$VPS_IP"
echo -e "${YELLOW}SSH Key:${NC} $SSH_KEY"
echo -e "${YELLOW}Base Directory:${NC} $VPS_BASE_DIR"
echo ""

# SSH commands to execute on VPS
REMOTE_COMMANDS="
echo '=== Pulling atbench-ai ===' && \
cd $VPS_BASE_DIR/atbench-ai && git pull && \
echo '' && \
echo '=== Pulling atbench-ai-interviews ===' && \
cd $VPS_BASE_DIR/atbench-ai-interviews && git pull && \
echo '' && \
echo '=== Pulling atbench-ai-docker ===' && \
cd $VPS_BASE_DIR/atbench-ai-docker && git pull && \
echo '' && \
echo '=== Running deployment ===' && \
./scripts/deploy.sh
"

echo -e "${BLUE}[1/1] Connecting to VPS and deploying...${NC}"
echo ""

# Execute remote commands via SSH with key authentication
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$VPS_USER@$VPS_IP" "$REMOTE_COMMANDS"

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Remote Deployment Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
