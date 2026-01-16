# AtBench AI Services - Deployment Guide

Deploy AtBench AI services on a Linux VPS using Docker with source code mounting.

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
│   ├── .env                    # ← App's own config
│   └── ...
│
├── atbench-ai-interviews/      # Interview service source code
│   ├── app.py
│   ├── requirements.txt
│   ├── .env                    # ← App's own config
│   └── ...
│
└── atbench-ai-docker/          # Docker configuration (this repo)
    ├── docker-compose.source.yml
    ├── nginx/
    │   └── nginx.conf
    ├── ssl/
    │   ├── fullchain.pem
    │   └── privkey.pem
    └── scripts/
        ├── deploy.sh
        └── deploy-remote.sh
```

> **Note:** No `.env` file needed in `atbench-ai-docker/`. Each app reads its own `.env` file.

---

## Prerequisites

### On VPS

1. **Docker & Docker Compose**
   ```bash
   curl -fsSL https://get.docker.com | sh
   docker --version
   docker compose version
   ```

2. **Git**
   ```bash
   apt update && apt install -y git
   ```

3. **Ollama** (installed directly on VPS, not in Docker)
   ```bash
   curl -fsSL https://ollama.com/install.sh | sh
   systemctl enable ollama
   systemctl start ollama

   # Verify
   curl http://localhost:11434/api/tags
   ```

4. **SSL Certificates**
   ```bash
   apt install -y certbot
   certbot certonly --standalone -d ai.atbench.com

   mkdir -p /root/atbench-ai-docker/ssl
   cp /etc/letsencrypt/live/ai.atbench.com/fullchain.pem /root/atbench-ai-docker/ssl/
   cp /etc/letsencrypt/live/ai.atbench.com/privkey.pem /root/atbench-ai-docker/ssl/
   ```

---

## Initial Setup

### 1. Clone Repositories

```bash
ssh root@<VPS_IP>
cd /root

git clone https://github.com/your-org/atbench-ai.git
git clone https://github.com/your-org/atbench-ai-interviews.git
git clone https://github.com/your-org/atbench-ai-docker.git
```

### 2. Configure Each App's `.env`

Each app has its own `.env` file. **Important:** Use Docker hostnames, not `localhost`.

**atbench-ai/.env:**
```env
# Qdrant (use Docker service name)
QDRANT_HOST=http://qdrant:6333
QDRANT_API_KEY=

# Redis (use Docker service name)
REDIS_HOST=redis
REDIS_PORT=6379

# Ollama (use host.docker.internal to reach VPS host)
OLLAMA_HOST=http://host.docker.internal:11434
OLLAMA_MODEL=llama3.2

# API Keys
OPENAI_API_KEY=sk-xxxx
GOOGLE_API_KEY=xxxx

# AWS S3
AWS_ACCESS_KEY_ID=xxxx
AWS_SECRET_ACCESS_KEY=xxxx
AWS_REGION=us-east-1
S3_BUCKET_NAME=your-bucket
```

**atbench-ai-interviews/.env:**
```env
# Qdrant
QDRANT_HOST=http://qdrant:6333

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# Ollama
OLLAMA_HOST=http://host.docker.internal:11434
OLLAMA_MODEL=llama3.2

# API Keys
OPENAI_API_KEY=sk-xxxx
GOOGLE_API_KEY=xxxx

# AWS S3
AWS_ACCESS_KEY_ID=xxxx
AWS_SECRET_ACCESS_KEY=xxxx
```

### 3. Docker Hostname Reference

| Service | Localhost (wrong) | Docker hostname (correct) |
|---------|-------------------|---------------------------|
| Qdrant | `localhost:6333` | `qdrant:6333` |
| Redis | `localhost:6379` | `redis:6379` |
| Ollama | `localhost:11434` | `host.docker.internal:11434` |

### 4. Setup SSL

```bash
mkdir -p /root/atbench-ai-docker/ssl
cp /path/to/fullchain.pem /root/atbench-ai-docker/ssl/
cp /path/to/privkey.pem /root/atbench-ai-docker/ssl/
```

### 5. Deploy

```bash
cd /root/atbench-ai-docker
./scripts/deploy.sh
```

---

## Deployment Methods

### Method 1: Deploy from VPS

```bash
ssh root@<VPS_IP>
cd /root/atbench-ai-docker
./scripts/deploy.sh
```

### Method 2: Deploy Remotely

First, configure your VPS details in `scripts/deploy-remote.sh`:
```bash
VPS_IP="YOUR_VPS_IP"
```

Then run:
```bash
# Using environment variable
export VPS_IP=192.168.1.100
./scripts/deploy-remote.sh

# Or with custom SSH key
./scripts/deploy-remote.sh ~/.ssh/my-key
```

**What deploy.sh does:**
1. Checks all required files exist
2. Pulls latest code from all 3 repos
3. Stops existing containers
4. Starts services with `docker-compose.source.yml`
5. Waits for health checks

---

## Nginx Routes

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

| Service | URL |
|---------|-----|
| Main AI App | `https://ai.atbench.com/` |
| Health Check | `https://ai.atbench.com/health` |
| Interview API | `https://ai.atbench.com/interview-api/` |
| Interview Health | `https://ai.atbench.com/interview-health` |
| Ollama API | `https://ai.atbench.com/ollama/api/tags` |
| Qdrant Dashboard | `https://ai.atbench.com/dashboard/` |

---

## Common Commands

### Logs
```bash
# All services
docker compose -f docker-compose.source.yml logs -f

# Specific service
docker logs -f atbench-ai
docker logs -f atbench-ai-interviews
docker logs -f atbench-nginx
```

### Restart
```bash
# All services
docker compose -f docker-compose.source.yml restart

# Single service
docker compose -f docker-compose.source.yml restart atbench-ai
```

### Stop
```bash
docker compose -f docker-compose.source.yml down
```

### Status
```bash
docker compose -f docker-compose.source.yml ps
```

### Shell Access
```bash
docker exec -it atbench-ai bash
docker exec -it atbench-ai-interviews bash
```

---

## Troubleshooting

### Services Not Starting

```bash
# Check logs
docker logs atbench-ai
docker logs atbench-ai-interviews

# Verify source directories
ls -la /root/atbench-ai/
ls -la /root/atbench-ai-interviews/

# Check .env files exist
cat /root/atbench-ai/.env
cat /root/atbench-ai-interviews/.env
```

### Ollama Connection Issues

```bash
# Check Ollama on host
systemctl status ollama
curl http://localhost:11434/api/tags

# Test from container
docker exec atbench-nginx ping host.docker.internal
```

### Health Check Failures

First startup is slow (pip installs). Wait 5-10 minutes:
```bash
# Watch installation progress
docker logs -f atbench-ai

# Manual health check
curl http://localhost:5001/health
curl http://localhost:5002/health
```

### Wrong Hostnames in .env

If you see connection errors, verify `.env` uses Docker hostnames:
```bash
# Wrong
QDRANT_HOST=http://localhost:6333

# Correct
QDRANT_HOST=http://qdrant:6333
```

---

## SSL Certificate Renewal

```bash
certbot renew
cp /etc/letsencrypt/live/ai.atbench.com/fullchain.pem /root/atbench-ai-docker/ssl/
cp /etc/letsencrypt/live/ai.atbench.com/privkey.pem /root/atbench-ai-docker/ssl/
docker compose -f docker-compose.source.yml restart nginx
```

### Auto-renewal Cron
```bash
crontab -e

# Add (runs 1st of each month at 2am)
0 2 1 * * certbot renew --quiet && cp /etc/letsencrypt/live/ai.atbench.com/*.pem /root/atbench-ai-docker/ssl/ && cd /root/atbench-ai-docker && docker compose -f docker-compose.source.yml restart nginx
```

---

## Backup & Restore

### Backup Volumes
```bash
mkdir -p /root/backups

# Qdrant
docker run --rm -v atbench-ai-docker_qdrant-storage:/data -v /root/backups:/backup alpine \
  tar czf /backup/qdrant-$(date +%Y%m%d).tar.gz -C /data .

# Redis
docker run --rm -v atbench-ai-docker_redis-data:/data -v /root/backups:/backup alpine \
  tar czf /backup/redis-$(date +%Y%m%d).tar.gz -C /data .
```

### Restore Volumes
```bash
# Qdrant
docker run --rm -v atbench-ai-docker_qdrant-storage:/data -v /root/backups:/backup alpine \
  tar xzf /backup/qdrant-YYYYMMDD.tar.gz -C /data

# Redis
docker run --rm -v atbench-ai-docker_redis-data:/data -v /root/backups:/backup alpine \
  tar xzf /backup/redis-YYYYMMDD.tar.gz -C /data
```

---

## Quick Reference

```bash
# Deploy
./scripts/deploy.sh

# Remote deploy
export VPS_IP=x.x.x.x && ./scripts/deploy-remote.sh

# Logs
docker compose -f docker-compose.source.yml logs -f

# Restart
docker compose -f docker-compose.source.yml restart

# Stop
docker compose -f docker-compose.source.yml down
```
