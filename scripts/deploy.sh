#!/bin/bash
# =============================================================================
# deploy.sh - Deploy AtBench AI Services (Source Build)
# =============================================================================
# Pull latest code and run AtBench AI services from source
#
# Directory Structure (required):
#   /root/
#   ├── atbench-ai/              (source repo)
#   ├── atbench-ai-interviews/   (source repo)
#   └── atbench-ai-docker/       (this repo - docker configs)
#
# Usage:
#   ./scripts/deploy.sh
#
# This script:
#   1. Pulls latest code from all three repos
#   2. Stops existing containers
#   3. Starts services using docker-compose.source.yml
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PARENT_DIR="$(dirname "$PROJECT_ROOT")"

# Sibling directories
AI_REPO="$PARENT_DIR/atbench-ai"
INTERVIEW_REPO="$PARENT_DIR/atbench-ai-interviews"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  AtBench AI Deployment Script (Source Build)${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "${YELLOW}Docker Config:${NC} $PROJECT_ROOT"
echo -e "${YELLOW}AI Source:${NC} $AI_REPO"
echo -e "${YELLOW}Interview Source:${NC} $INTERVIEW_REPO"
echo ""

cd "$PROJECT_ROOT"

# -----------------------------------------------------------------------------
# Check for required directories and files
# -----------------------------------------------------------------------------
echo -e "${BLUE}[1/5] Checking required files and directories...${NC}"

MISSING=()

if [ ! -d "$AI_REPO" ]; then
    MISSING+=("atbench-ai (sibling directory)")
fi

if [ ! -d "$INTERVIEW_REPO" ]; then
    MISSING+=("atbench-ai-interviews (sibling directory)")
fi

if [ ! -f "docker-compose.source.yml" ]; then
    MISSING+=("docker-compose.source.yml")
fi

if [ ! -f "nginx/nginx.conf" ]; then
    MISSING+=("nginx/nginx.conf")
fi

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        echo -e "${YELLOW}.env not found, copying from .env.example...${NC}"
        cp .env.example .env
        echo -e "${RED}Please edit .env with your configuration before continuing${NC}"
        exit 1
    else
        MISSING+=(".env")
    fi
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    echo -e "${RED}Missing required files/directories:${NC}"
    for item in "${MISSING[@]}"; do
        echo -e "  - ${YELLOW}$item${NC}"
    done
    exit 1
fi

echo -e "${GREEN}✓ All required files and directories present${NC}"
echo ""

# -----------------------------------------------------------------------------
# Pull latest code from all repos
# -----------------------------------------------------------------------------
echo -e "${BLUE}[2/5] Pulling latest code from repositories...${NC}"

echo -e "${YELLOW}Pulling atbench-ai-docker...${NC}"
git pull || echo -e "${YELLOW}Warning: Could not pull atbench-ai-docker${NC}"

echo -e "${YELLOW}Pulling atbench-ai...${NC}"
cd "$AI_REPO"
git pull || echo -e "${YELLOW}Warning: Could not pull atbench-ai${NC}"

echo -e "${YELLOW}Pulling atbench-ai-interviews...${NC}"
cd "$INTERVIEW_REPO"
git pull || echo -e "${YELLOW}Warning: Could not pull atbench-ai-interviews${NC}"

cd "$PROJECT_ROOT"
echo -e "${GREEN}✓ Code pulled${NC}"
echo ""

# -----------------------------------------------------------------------------
# Load environment variables
# -----------------------------------------------------------------------------
echo -e "${BLUE}[3/5] Loading environment variables...${NC}"

# Export all variables from .env file
while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ $key =~ ^#.*$ ]] && continue
    [[ -z $key ]] && continue
    # Remove leading/trailing whitespace and quotes
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    # Export the variable
    export "$key=$value"
done < .env

echo -e "${GREEN}✓ Environment loaded${NC}"
echo ""

# -----------------------------------------------------------------------------
# Stop existing containers
# -----------------------------------------------------------------------------
echo -e "${BLUE}[4/5] Stopping existing containers...${NC}"
docker compose -f docker-compose.source.yml --env-file .env down --remove-orphans || true
echo -e "${GREEN}✓ Containers stopped${NC}"
echo ""

# -----------------------------------------------------------------------------
# Start containers
# -----------------------------------------------------------------------------
echo -e "${BLUE}[5/5] Starting containers...${NC}"
docker compose -f docker-compose.source.yml --env-file .env up -d
echo -e "${GREEN}✓ Containers started${NC}"
echo ""

# -----------------------------------------------------------------------------
# Health check
# -----------------------------------------------------------------------------
echo -e "${BLUE}Waiting for services to be healthy...${NC}"
echo -e "${YELLOW}Note: First startup takes longer (installing dependencies)${NC}"
sleep 15

# Check AI service health
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -sf http://localhost:5001/health > /dev/null 2>&1 || \
       docker exec atbench-ai curl -sf http://localhost:5001/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ AI service is healthy${NC}"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo "Waiting for AI service... ($ATTEMPT/$MAX_ATTEMPTS)"
    sleep 10
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo -e "${YELLOW}Warning: AI service health check timed out (may still be installing dependencies)${NC}"
fi

# Check Interview service health
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -sf http://localhost:5002/health > /dev/null 2>&1 || \
       docker exec atbench-ai-interviews curl -sf http://localhost:5002/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Interview service is healthy${NC}"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo "Waiting for Interview service... ($ATTEMPT/$MAX_ATTEMPTS)"
    sleep 10
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo -e "${YELLOW}Warning: Interview service health check timed out (may still be installing dependencies)${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Services running:"
docker compose -f docker-compose.source.yml --env-file .env ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo -e "${BLUE}Quick commands:${NC}"
echo -e "  View logs:           docker compose -f docker-compose.source.yml logs -f"
echo -e "  View AI logs:        docker logs -f atbench-ai"
echo -e "  View Interview logs: docker logs -f atbench-ai-interviews"
echo -e "  Stop all:            docker compose -f docker-compose.source.yml down"
echo -e "  Restart:             docker compose -f docker-compose.source.yml restart"
echo ""
