#!/bin/bash
# =============================================================================
# ATBench AI - Source Build Setup Script
# =============================================================================
# Sets up AI services from cloned source repositories
# Uses docker-compose.source.yml (builds from source, not Docker Hub images)
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
# =============================================================================

set -e

DEPLOY_DIR="${DEPLOY_DIR:-/opt/ai-atbench-servers}"
ATBENCH_AI_REPO="${ATBENCH_AI_REPO:-https://github.com/your-org/atbench-ai.git}"
ATBENCH_INTERVIEWS_REPO="${ATBENCH_INTERVIEWS_REPO:-https://github.com/your-org/atbench-ai-interviews.git}"

echo "=========================================="
echo "ATBench AI - Source Build Setup"
echo "=========================================="

# Create deployment directory
echo "[1/6] Creating deployment directory: $DEPLOY_DIR"
sudo mkdir -p "$DEPLOY_DIR"
sudo chown $USER:$USER "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# Clone repositories
echo "[2/6] Cloning atbench-ai repository..."
if [ -d "atbench-ai" ]; then
    echo "  -> atbench-ai exists, pulling latest..."
    cd atbench-ai && git pull && cd ..
else
    git clone "$ATBENCH_AI_REPO" atbench-ai
fi

echo "[3/6] Cloning atbench-ai-interviews repository..."
if [ -d "atbench-ai-interviews" ]; then
    echo "  -> atbench-ai-interviews exists, pulling latest..."
    cd atbench-ai-interviews && git pull && cd ..
else
    git clone "$ATBENCH_INTERVIEWS_REPO" atbench-ai-interviews
fi

# Create run-atbench-ai folder if not exists
echo "[4/6] Setting up run-atbench-ai folder..."
mkdir -p run-atbench-ai/nginx
mkdir -p run-atbench-ai/ssl

# Copy files from this script's folder if running from source
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/docker-compose.source.yml" ]; then
    cp "$SCRIPT_DIR/docker-compose.source.yml" run-atbench-ai/
    cp "$SCRIPT_DIR/nginx/nginx.conf" run-atbench-ai/nginx/
    cp "$SCRIPT_DIR/.env.source.template" run-atbench-ai/
fi

# Create .env if not exists
if [ ! -f "run-atbench-ai/.env" ]; then
    if [ -f "run-atbench-ai/.env.source.template" ]; then
        cp run-atbench-ai/.env.source.template run-atbench-ai/.env
        echo "  -> Created .env file - PLEASE EDIT with your API keys!"
    fi
fi

# Check Docker
echo "[5/6] Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed. Please install Docker first."
    echo "  curl -fsSL https://get.docker.com | sh"
    exit 1
fi

# Add PyJWT to interview requirements if missing
echo "[6/6] Checking interview service requirements..."
if [ -f "atbench-ai-interviews/requirements.txt" ]; then
    if ! grep -q "PyJWT" atbench-ai-interviews/requirements.txt; then
        echo "PyJWT>=2.10.0" >> atbench-ai-interviews/requirements.txt
        echo "  -> Added PyJWT to interview requirements"
    fi
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Directory structure:"
echo "  $DEPLOY_DIR/"
echo "  ├── atbench-ai/                (source repo)"
echo "  ├── atbench-ai-interviews/     (source repo)"
echo "  └── run-atbench-ai/"
echo "      ├── docker-compose.source.yml  (builds from source)"
echo "      ├── docker-compose.yaml        (uses Docker Hub images)"
echo "      ├── .env"
echo "      ├── nginx/"
echo "      └── ssl/"
echo ""
echo "=========================================="
echo "NEXT STEPS"
echo "=========================================="
echo ""
echo "1. Edit your .env file:"
echo "   nano $DEPLOY_DIR/run-atbench-ai/.env"
echo ""
echo "2. Add SSL certificates:"
echo "   certbot certonly --standalone -d ai.atbench.com"
echo "   cp /etc/letsencrypt/live/ai.atbench.com/fullchain.pem $DEPLOY_DIR/run-atbench-ai/ssl/"
echo "   cp /etc/letsencrypt/live/ai.atbench.com/privkey.pem $DEPLOY_DIR/run-atbench-ai/ssl/"
echo ""
echo "3. Start services (from source):"
echo "   cd $DEPLOY_DIR/run-atbench-ai"
echo "   docker compose -f docker-compose.source.yml up -d"
echo ""
echo "   OR use Docker Hub images:"
echo "   docker compose -f docker-compose.yaml up -d"
echo ""
echo "4. Check status:"
echo "   docker compose ps"
echo "   docker compose logs -f"
echo ""
echo "=========================================="
echo "URLs (after SSL setup)"
echo "=========================================="
echo ""
echo "  https://ai.atbench.com/              -> Main App"
echo "  https://ai.atbench.com/interviews    -> Interview List"
echo "  https://ai.atbench.com/ai-interview  -> AI Interview"
echo "  https://ai.atbench.com/qdrant/       -> Qdrant Dashboard"
echo ""
