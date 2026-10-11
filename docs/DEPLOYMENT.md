# Deployment Guide - Lex-Tech AI Agents

## Prerequisites

- Server with Ubuntu 20.04+ or similar
- PostgreSQL 13+
- Node.js 18+
- Python 3.11+
- Poetry installed
- PM2 installed globally
- Git access to repository

## Manual Deployment Steps

### 1. Server Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install PostgreSQL
sudo apt install postgresql postgresql-contrib -y

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install nodejs -y

# Install Python 3.11
sudo apt install python3.11 python3.11-venv python3-pip -y

# Install Poetry
curl -sSL https://install.python-poetry.org | python3 -

# Install PM2
sudo npm install -g pm2

# Setup firewall
sudo ufw allow 8001/tcp  # Backend
sudo ufw allow 5174/tcp  # Frontend (dev)
sudo ufw allow 22/tcp    # SSH
sudo ufw enable
```

### 2. Database Setup

```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE Lex-Tech_agents;
CREATE USER Lex-Tech_user WITH ENCRYPTED PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE Lex-Tech_agents TO Lex-Tech_user;
\q
```

### 3. Clone Repository

```bash
cd /root
git clone -b dev https://ghp_YOUR_TOKEN@github.com/Lex-Tech-2026/AI-Agents.git
cd AI-Agents
```

### 4. Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit with your settings
nano .env
```

Required settings:
```env
# Database
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=Lex-Tech_agents
POSTGRES_USER=Lex-Tech_user
POSTGRES_PASSWORD=your_secure_password

# AWS S3 (Required)
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_REGION=us-east-1
AWS_S3_BUCKET=your-bucket

# OpenAI (Required)
OPENAI_API_KEY=your_openai_key

# Email (Optional but recommended)
EMAIL_ENABLED=true
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
EMAIL_FROM=noreply@yourdomain.com
FRONTEND_URL=http://your-server-ip:5174

# Security
SECRET_KEY=generate-random-secret-here
JWT_ALGORITHM=HS256
```

### 5. Backend Setup

```bash
# Install dependencies
poetry lock --no-update
poetry install

# Run database migrations
poetry run python scripts/migrate_db.py

# Create admin user
poetry run python create_admin.py
```

### 6. Start Backend

```bash
# Start in background
nohup poetry run python run.py > output.log 2>&1 &

# Verify it's running
curl http://localhost:8001/health

# Check logs
tail -f output.log
```

### 7. Frontend Setup

```bash
cd Front-End

# Install dependencies
npm install --force

# Fix vulnerabilities
npm audit fix --force

# Start with PM2
pm2 start npm --name frontend -- run dev

# Save PM2 configuration
pm2 save

# Setup PM2 to start on boot
pm2 startup
# Run the command it outputs
```

### 8. Verify Deployment

```bash
# Check backend
curl http://localhost:8001/health

# Check frontend
curl http://localhost:5174

# Check PM2 processes
pm2 list

# Check backend logs
tail -f /root/AI-Agents/output.log

# Check frontend logs
pm2 logs frontend
```

## GitHub Actions Deployment

### Setup

1. **Add SSH Key to Server**:
```bash
# On your local machine, generate key if needed
ssh-keygen -t rsa -b 4096 -C "deploy@Lex-Tech"

# Copy public key to server
ssh-copy-id root@your-server-ip

# Add private key to GitHub Secrets as SSH_PRIVATE_KEY
```

2. **Configure GitHub Secrets**:
   - Go to Repository → Settings → Secrets and variables → Actions
   - Add `SSH_PRIVATE_KEY`: Your private SSH key

3. **Update Workflow** (if needed):
   - Edit `.github/workflows/deploy.yml`
   - Update `DEPLOY_HOST` to your server IP
   - Update ports if using different ones

### Trigger Deployment

```bash
# Push to dev branch to trigger deployment
git push origin dev

# Or trigger manually from GitHub Actions tab
```

### Monitor Deployment

- Go to GitHub Actions tab
- Click on latest workflow run
- Watch deployment steps in real-time
- Check for any errors in logs

## Maintenance

### Update Application

```bash
cd /root/AI-Agents

# Stop services
pm2 stop frontend
kill -9 $(lsof -ti:8001)

# Pull latest changes
git pull origin dev

# Update backend
poetry install
poetry run python scripts/migrate_db.py

# Update frontend
cd Front-End
npm install --force

# Restart services
cd /root/AI-Agents
nohup poetry run python run.py > output.log 2>&1 &
cd Front-End
pm2 restart frontend
```

### Backup Database

```bash
# Create backup
sudo -u postgres pg_dump Lex-Tech_agents > backup_$(date +%Y%m%d).sql

# Restore from backup
sudo -u postgres psql Lex-Tech_agents < backup_20260123.sql
```

### Monitor Services

```bash
# Check running processes
pm2 list
lsof -i:8001  # Backend
lsof -i:5174  # Frontend

# Check logs
tail -f /root/AI-Agents/output.log
pm2 logs frontend

# Check system resources
htop
df -h
free -m
```

### Common Issues

**Backend won't start**:
```bash
# Check database connection
poetry run python -c "from src.services.databases.postgresql.database import engine; import asyncio; asyncio.run(engine.connect())"

# Check environment variables
poetry run python -c "from src.core.settings.config import settings; print(settings.database_url)"

# Check logs
tail -50 output.log
```

**Frontend won't start**:
```bash
# Check Node version
node --version  # Should be 18+

# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install --force

# Check PM2 logs
pm2 logs frontend --lines 100
```

**Database migrations fail**:
```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Check connection
psql -h localhost -U Lex-Tech_user -d Lex-Tech_agents

# Run migration with verbose output
poetry run python scripts/migrate_db.py
```

## Security Checklist

- [ ] Change default database password
- [ ] Generate secure SECRET_KEY
- [ ] Enable firewall (ufw)
- [ ] Setup SSL/TLS certificates
- [ ] Configure CORS for production domains
- [ ] Enable rate limiting
- [ ] Setup backup automation
- [ ] Configure monitoring/alerting
- [ ] Review and restrict file permissions
- [ ] Enable audit logging

## Performance Tuning

### PostgreSQL

```bash
# Edit PostgreSQL config
sudo nano /etc/postgresql/13/main/postgresql.conf

# Recommended settings
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 2621kB
min_wal_size = 1GB
max_wal_size = 4GB

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### Backend

- Increase `API_WORKERS` in .env for more concurrency
- Enable Redis caching with `REDIS_ENABLED=true`
- Configure CDN for static assets
- Setup load balancer for multiple instances

### Frontend

- Build production version: `npm run build`
- Serve with nginx for better performance
- Enable gzip compression
- Configure CDN

## Monitoring

### Setup Prometheus + Grafana

```bash
# Install Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.40.0/prometheus-2.40.0.linux-amd64.tar.gz
tar -xzf prometheus-2.40.0.linux-amd64.tar.gz
cd prometheus-2.40.0.linux-amd64
./prometheus --config.file=prometheus.yml &

# Install Grafana
sudo apt-get install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
sudo apt-get update
sudo apt-get install grafana
sudo systemctl start grafana-server
```

### Application Metrics

Backend exposes metrics at `/metrics` endpoint:
```bash
curl http://localhost:8001/metrics
```

## Support

For issues:
1. Check logs first
2. Review error messages
3. Consult documentation
4. Contact support team

---

Last updated: January 2026
