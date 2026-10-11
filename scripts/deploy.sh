#!/bin/bash

# Lex-Tech AI Agents - Quick Deployment Script
# This script automates the deployment process

set -e  # Exit on error

echo "🚀 Lex-Tech AI Agents Deployment Script"
echo "===================================="

# Configuration
BACKEND_PORT=8001
FRONTEND_PORT=5174
APP_DIR="$HOME/AI-Agents"
BACKUP_DIR="$HOME/AI-Agents-backup"
BRANCH="${1:-dev}"  # Default to dev branch

# Load NVM
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
elif [ -s "/root/.nvm/nvm.sh" ]; then
    export NVM_DIR="/root/.nvm"
    . "$NVM_DIR/nvm.sh"
fi

# Ensure node is available
if command -v nvm >/dev/null; then
    nvm install 22
    nvm use 22
    nvm alias default 22
    echo "Using Node.js version: $(node -v)"
    echo "Using npm version: $(npm -v)"
else
    echo "⚠ NVM command not found"
    # Try adding common paths just in case
    export PATH=$PATH:/root/.nvm/versions/node/$(ls /root/.nvm/versions/node/ | head -1)/bin
fi

echo ""
echo "📋 Configuration:"
echo "   Branch: $BRANCH"
echo "   App Dir: $APP_DIR"
echo "   Backend Port: $BACKEND_PORT"
echo "   Frontend Port: $FRONTEND_PORT"
echo ""

# Step 1: Create backup
echo "📦 Step 1: Creating backup..."
if [ -d "$APP_DIR" ]; then
    rm -rf "$BACKUP_DIR"
    cp -r "$APP_DIR" "$BACKUP_DIR"
    echo "✓ Backup created at $BACKUP_DIR"
else
    echo "⚠ No existing deployment to backup"
fi

# Step 2: Stop running services
echo ""
echo "⏹ Step 2: Stopping services..."

# Stop backend
BACKEND_PID=$(lsof -ti:$BACKEND_PORT || true)
if [ ! -z "$BACKEND_PID" ]; then
    kill -9 $BACKEND_PID || true
    echo "✓ Backend stopped (PID: $BACKEND_PID)"
else
    echo "⚠ No backend process found"
fi

# Stop anything on frontend port (covers orphaned vite/node processes)
FRONTEND_PID=$(lsof -ti:$FRONTEND_PORT || true)
if [ ! -z "$FRONTEND_PID" ]; then
    kill -9 $FRONTEND_PID || true
    echo "✓ Freed frontend port $FRONTEND_PORT (PID: $FRONTEND_PID)"
else
    echo "⚠ No process found on frontend port $FRONTEND_PORT"
fi

# We use 'pm2 kill' to ensure the pm2 daemon (which might be running on an old node version) is stopped
pm2 delete frontend 2>/dev/null || true
pm2 kill || true
echo "✓ Frontend stopped and PM2 daemon killed"
echo "✓ Frontend stopped"

sleep 3

# Step 3: Deploy new code
echo ""
echo "📥 Step 3: Deploying new code..."
cd "$HOME"

# Remove old directory
if [ -d "$APP_DIR" ]; then
    rm -rf "$APP_DIR"
fi

# Clone repository
git clone -b "$BRANCH" https://github.com/Lex-Tech-2026/AI-Agents.git "$APP_DIR"
cd "$APP_DIR"
echo "✓ Code cloned from branch: $BRANCH"

# Step 4: Install backend dependencies
echo ""
echo "📚 Step 4: Installing backend dependencies..."
poetry lock --no-update
poetry install --no-interaction
echo "✓ Backend dependencies installed"

# Step 5: Run database migrations
echo ""
echo "🗄 Step 5: Running database migrations..."
poetry run python scripts/migrate_db.py
echo "✓ Database migrations completed"

# Step 6: Start backend
echo ""
echo "🟢 Step 6: Starting backend..."
nohup poetry run python run.py > output.log 2>&1 &
sleep 10

# Verify backend is running
if lsof -ti:$BACKEND_PORT > /dev/null; then
    echo "✓ Backend started successfully"
    
    # Test health endpoint
    if curl -f http://localhost:$BACKEND_PORT/health > /dev/null 2>&1; then
        echo "✓ Backend health check passed"
    else
        echo "⚠ Backend health check failed (but process is running)"
    fi
else
    echo "❌ ERROR: Backend failed to start"
    echo "Check logs: tail -50 output.log"
    exit 1
fi

# Step 7: Install frontend dependencies
echo ""
echo "📚 Step 7: Installing frontend dependencies..."
cd "$APP_DIR/Front-End"
# Remove node_modules and package-lock to ensure clean install with pinned versions
rm -rf node_modules package-lock.json
npm install 2>&1 | tail -20
# DO NOT run npm audit fix --force - it upgrades vite to v7 which requires Node 20+
# Install pm2 globally
npm install -g pm2 || true
echo "✓ Frontend dependencies installed"

# Step 8: Start frontend
echo ""
echo "🟢 Step 8: Starting frontend..."
# Direct path to the current node executable
NODE_PATH=$(which node)
NPM_PATH=$(which npm)
PM2_PATH=$(which pm2 || true)
echo "   Using Node at: $NODE_PATH"
echo "   Using NPM at: $NPM_PATH"
echo "   Using PM2 at: $PM2_PATH"

echo "   Node version: $(node -v)"
if [ ! -z "$PM2_PATH" ]; then
    echo "   PM2 version: $($PM2_PATH -v)"
fi

# Start using the specific interpreter to force the correct node version
pm2 delete frontend 2>/dev/null || true
pm2 start node_modules/vite/bin/vite.js --name frontend --interpreter "$NODE_PATH" -- --host 0.0.0.0 --port 5174
pm2 save || true
sleep 5

# Verify frontend is running
if pm2 list | grep -q "frontend.*online"; then
    echo "✓ Frontend started successfully"
else
    echo "❌ ERROR: Frontend failed to start"
    echo "Check logs: pm2 logs frontend"
    exit 1
fi

# Final verification
echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "📊 Status:"
pm2 list
echo ""
lsof -i:$BACKEND_PORT -i:$FRONTEND_PORT
echo ""
echo "🔗 URLs:"
echo "   Backend Health: http://localhost:$BACKEND_PORT/health"
echo "   Backend API: http://localhost:$BACKEND_PORT/api/v1"
echo "   Frontend: http://localhost:$FRONTEND_PORT"
echo ""
echo "📝 Logs:"
echo "   Backend: tail -f $APP_DIR/output.log"
echo "   Frontend: pm2 logs frontend"
echo ""
echo "🎉 Deployment successful! System is ready."
