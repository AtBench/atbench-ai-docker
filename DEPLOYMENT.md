# AtBench AI Services - Deployment Guide

This guide covers deploying AtBench AI services on a Linux VPS using Docker.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Linux VPS (ai.atbench.com)                                             │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Docker Network                                                  │   │
│  │                                                                  │   │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │   │
│  │  │   Nginx     │    │ atbench-ai  │    │ atbench-ai-interviews│  │   │
│  │  │  (80/443)   │───▶│   (:5001)   │    │       (:5002)        │  │   │
│  │  └─────────────┘    └─────────────┘    └─────────────────────┘  │   │
│  │         │                  │                     │               │   │
│  │         │           ┌──────┴─────────────────────┘               │   │
│  │         │           ▼                                            │   │
│  │         │    ┌─────────────┐    ┌─────────────┐                  │   │
│  │         │    │   Qdrant    │    │    Redis    │                  │   │
│  │         │    │ (:6333/6334)│    │   (:6379)   │                  │   │
│  │         │    └─────────────┘    └─────────────┘                  │   │
│  └─────────┼────────────────────────────────────────────────────────┘   │
│            │                                                            │
│            ▼                                                            │
│  ┌─────────────────┐                                                    │
│  │     Ollama      │  (Installed directly on VPS, not in Docker)        │
│  │    (:11434)     │                                                    │
│  └─────────────────┘                                                    │
└─────────────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
/root/
├── atbench-ai/                 # AI service source code
│   ├── app.py
│   ├── requirements.txt
│   └── ...
│
├── atbench-ai-interviews/      # Interview service source code
│   ├── app.py
│   ├── requirements.txt
│   └── ...
│
└── atbench-ai-docker/          # Docker configuration (this repo)
    ├── docker-compose.source.yml
    ├── nginx/
    │   └── nginx.conf
    ├── ssl/
    │   ├── fullchain.pem
    │   └── privkey.pem
    ├── .env
    └── scripts/
        ├── deploy.sh
        └── deploy-remote.sh
```

## Prerequisites

### On VPS

1. **Docker & Docker Compose**
   ```bash
   # Install Docker
   curl -fsSL https://get.docker.com | sh

   # Verify installation
   docker --version
   docker compose version
   ```

2. **Git**
   ```bash
   apt update && apt install -y git
   ```

3. **Ollama** (installed directly on VPS)
   ```bash
   curl -fsSL https://ollama.com/install.sh | sh

   # Start Ollama service
   systemctl enable ollama
   systemctl start ollama

   # Verify
   curl http://localhost:11434/api/tags
   ```

4. **SSL Certificates**
   ```bash
   # Using Let's Encrypt (certbot)
   apt install -y certbot
   certbot certonly --standalone -d ai.atbench.com

   # Copy certificates
   mkdir -p /root/atbench-ai-docker/ssl
   cp /etc/letsencrypt/live/ai.atbench.com/fullchain.pem /root/atbench-ai-docker/ssl/
   cp /etc/letsencrypt/live/ai.atbench.com/privkey.pem /root/atbench-ai-docker/ssl/
   ```

### On Local Machine

1. **SSH Key** configured for VPS access
2. **Git** for version control

---

## Initial Setup (First Time)

### 1. Clone Repositories on VPS

```bash
ssh root@<VPS_IP>

cd /root

# Clone all three repositories
git clone https://github.com/your-org/atbench-ai.git
git clone https://github.com/your-org/atbench-ai-interviews.git
git clone https://github.com/your-org/atbench-ai-docker.git
```

### 2. Configure Environment

```bash
cd /root/atbench-ai-docker

# Copy example env file
cp .env.example .env

# Edit with your configuration
nano .env
```

Required environment variables:
```env
# API Keys
OPENAI_API_KEY=sk-xxxx
GOOGLE_API_KEY=xxxx
GROQ_API_KEY=xxxx

# AWS S3 (for file storage)
AWS_ACCESS_KEY_ID=xxxx
AWS_SECRET_ACCESS_KEY=xxxx
AWS_REGION=us-east-1
S3_BUCKET_NAME=your-bucket

# Qdrant
QDRANT_API_KEY=your-qdrant-key

# Ollama (running on host)
OLLAMA_HOST=http://host.docker.internal:11434
OLLAMA_MODEL=llama3.2

# Redis
REDIS_PASSWORD=your-redis-password

# Security
SECRET_KEY=your-secret-key
```

### 3. Setup SSL Certificates

```bash
mkdir -p /root/atbench-ai-docker/ssl

# Copy your SSL certificates
cp /path/to/fullchain.pem /root/atbench-ai-docker/ssl/
cp /path/to/privkey.pem /root/atbench-ai-docker/ssl/
```

### 4. Run Initial Deployment

```bash
cd /root/atbench-ai-docker
./scripts/deploy.sh
```

---

## Deployment Methods

### Method 1: Deploy from VPS (SSH into server)

```bash
ssh root@<VPS_IP>
cd /root/atbench-ai-docker
./scripts/deploy.sh
```

**What it does:**
1. Pulls latest code from all 3 repositories
2. Loads environment variables from `.env`
3. Stops existing containers
4. Starts containers using `docker-compose.source.yml`
5. Waits for health checks

### Method 2: Deploy Remotely (from local machine)

```bash
# Using default SSH key
./scripts/deploy-remote.sh

# Using custom SSH key
./scripts/deploy-remote.sh ~/.ssh/your-key
```

**What it does:**
1. SSHs into VPS
2. Pulls latest code from all repositories
3. Runs `deploy.sh` on the server

---

## Configuration

### Deploy Script Configuration

Edit `scripts/deploy-remote.sh` to update VPS details:

```bash
# VPS Configuration
VPS_IP="<YOUR_VPS_IP>"
VPS_USER="root"
VPS_BASE_DIR="/root"

# Default SSH key path
DEFAULT_SSH_KEY="$HOME/.ssh/your-ssh-key"
```

### Nginx Configuration

The nginx configuration (`nginx/nginx.conf`) handles:

| Route | Service | Port |
|-------|---------|------|
| `/` | atbench-ai | 5001 |
| `/interview-api/*` | atbench-ai-interviews | 5002 |
| `/ai-interview` | atbench-ai-interviews | 5002 |
| `/ollama/*` | Ollama (host) | 11434 |
| `/qdrant/*` | Qdrant | 6333 |
| `/dashboard/*` | Qdrant Dashboard | 6333 |

---

## Service URLs

After deployment, services are available at:

| Service | URL |
|---------|-----|
| Main AI App | `https://ai.atbench.com/` |
| AI Health | `https://ai.atbench.com/health` |
| Interview Service | `https://ai.atbench.com/interview-api/` |
| Interview Health | `https://ai.atbench.com/interview-health` |
| Ollama API | `https://ai.atbench.com/ollama/api/tags` |
| Qdrant Dashboard | `https://ai.atbench.com/dashboard/` |

---

## Common Commands

### View Logs

```bash
# All services
docker compose -f docker-compose.source.yml logs -f

# Specific service
docker logs -f atbench-ai
docker logs -f atbench-ai-interviews
docker logs -f atbench-nginx
docker logs -f atbench-qdrant
docker logs -f atbench-redis
```

### Restart Services

```bash
# Restart all
docker compose -f docker-compose.source.yml restart

# Restart specific service
docker compose -f docker-compose.source.yml restart atbench-ai
```

### Stop Services

```bash
docker compose -f docker-compose.source.yml down
```

### Check Service Status

```bash
docker compose -f docker-compose.source.yml ps
```

### Shell into Container

```bash
docker exec -it atbench-ai bash
docker exec -it atbench-ai-interviews bash
```

---

## Troubleshooting

### Services Not Starting

1. **Check logs:**
   ```bash
   docker logs atbench-ai
   docker logs atbench-ai-interviews
   ```

2. **Verify source directories exist:**
   ```bash
   ls -la /root/atbench-ai/
   ls -la /root/atbench-ai-interviews/
   ```

3. **Check .env file:**
   ```bash
   cat /root/atbench-ai-docker/.env
   ```

### Ollama Connection Issues

1. **Verify Ollama is running on host:**
   ```bash
   systemctl status ollama
   curl http://localhost:11434/api/tags
   ```

2. **Check nginx can reach host:**
   ```bash
   docker exec atbench-nginx ping host.docker.internal
   ```

### SSL Certificate Issues

1. **Verify certificates exist:**
   ```bash
   ls -la /root/atbench-ai-docker/ssl/
   ```

2. **Check certificate validity:**
   ```bash
   openssl x509 -in /root/atbench-ai-docker/ssl/fullchain.pem -text -noout | grep -A2 "Validity"
   ```

### Health Check Failures

First startup takes longer due to pip dependency installation. Wait 5-10 minutes and check:

```bash
# Check if dependencies are still installing
docker logs -f atbench-ai

# Manual health check
curl http://localhost:5001/health
curl http://localhost:5002/health
```

---

## SSL Certificate Renewal

```bash
# Renew certificate
certbot renew

# Copy renewed certificates
cp /etc/letsencrypt/live/ai.atbench.com/fullchain.pem /root/atbench-ai-docker/ssl/
cp /etc/letsencrypt/live/ai.atbench.com/privkey.pem /root/atbench-ai-docker/ssl/

# Restart nginx
docker compose -f docker-compose.source.yml restart nginx
```

### Auto-renewal Cron Job

```bash
# Add to crontab
crontab -e

# Add this line (runs at 2am on the 1st of each month)
0 2 1 * * certbot renew --quiet && cp /etc/letsencrypt/live/ai.atbench.com/*.pem /root/atbench-ai-docker/ssl/ && cd /root/atbench-ai-docker && docker compose -f docker-compose.source.yml restart nginx
```

---

## Updating Services

To deploy new code changes:

```bash
# From local machine
./scripts/deploy-remote.sh

# Or from VPS
cd /root/atbench-ai-docker
./scripts/deploy.sh
```

The deploy script automatically:
1. Pulls latest code from all repositories
2. Restarts containers with new code
3. Source code is mounted as volumes, so changes take effect immediately

---

## Backup

### Backup Volumes

```bash
# Create backup directory
mkdir -p /root/backups

# Backup Qdrant data
docker run --rm -v atbench-ai-docker_qdrant-storage:/data -v /root/backups:/backup alpine tar czf /backup/qdrant-backup-$(date +%Y%m%d).tar.gz -C /data .

# Backup Redis data
docker run --rm -v atbench-ai-docker_redis-data:/data -v /root/backups:/backup alpine tar czf /backup/redis-backup-$(date +%Y%m%d).tar.gz -C /data .
```

### Restore Volumes

```bash
# Restore Qdrant
docker run --rm -v atbench-ai-docker_qdrant-storage:/data -v /root/backups:/backup alpine tar xzf /backup/qdrant-backup-YYYYMMDD.tar.gz -C /data

# Restore Redis
docker run --rm -v atbench-ai-docker_redis-data:/data -v /root/backups:/backup alpine tar xzf /backup/redis-backup-YYYYMMDD.tar.gz -C /data
```
