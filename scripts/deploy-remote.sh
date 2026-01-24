#!/bin/bash
# =============================================================================
# deploy-remote.sh - Deploy AtBench AI to VPS from local machine (Source Build)
# =============================================================================
# SSH into VPS, pull latest changes from all repos, and run deployment
#
# Directory Structure on VPS:
#   /root/
#   ├── atbench-ai/              (source repo with .env)
#   ├── atbench-ai-interviews/   (source repo with .env)
#   └── atbench-ai-docker/       (docker configs)
#
# Usage:
#   ./scripts/deploy-remote.sh <VPS_IP> [SSH_KEY_PATH]
#
# Examples:
#   ./scripts/deploy-remote.sh 192.168.1.100                      # Default SSH key
#   ./scripts/deploy-remote.sh 192.168.1.100 ~/.ssh/my-key        # Custom key
#
# Environment variables (optional):
#   VPS_USER     - SSH user (default: root)
#   VPS_BASE_DIR - Base directory on VPS (default: /root)
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
VPS_IP="$1"
SSH_KEY="${2:-$HOME/.ssh/id_rsa}"

# VPS Configuration (can be overridden via environment variables)
VPS_USER="${VPS_USER:-root}"
VPS_BASE_DIR="${VPS_BASE_DIR:-/root/AI-ATBENCH-APPS/}"

# Show usage if no VPS_IP provided
if [ -z "$VPS_IP" ]; then
    echo -e "${RED}Error: VPS_IP is required${NC}"
    echo ""
    echo "Usage: $0 <VPS_IP> [SSH_KEY_PATH]"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.100                       # Default SSH key (~/.ssh/id_rsa)"
    echo "  $0 192.168.1.100 ~/.ssh/my-key         # Custom SSH key"
    echo ""
    echo "Optional environment variables:"
    echo "  VPS_USER=root                          # SSH user"
    echo "  VPS_BASE_DIR=/root                     # Base directory on VPS"
    exit 1
fi

# Validate SSH key file exists
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}Error: SSH key file not found: $SSH_KEY${NC}"
    echo ""
    echo "Usage: $0 <VPS_IP> [SSH_KEY_PATH]"
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
