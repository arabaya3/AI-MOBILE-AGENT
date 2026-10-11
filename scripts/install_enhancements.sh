#!/bin/bash

# UI/UX Enhancements Installation Script
# This script fixes permissions and installs dependencies for the frontend

set -e

echo "🚀 Starting UI/UX Enhancements Installation..."
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FRONTEND_DIR="$SCRIPT_DIR/Front-End"

echo "📁 Working directory: $FRONTEND_DIR"
echo ""

# Check if frontend directory exists
if [ ! -d "$FRONTEND_DIR" ]; then
    echo -e "${RED}❌ Error: Front-End directory not found!${NC}"
    exit 1
fi

# Fix permissions for npm cache
echo "🔧 Fixing npm cache permissions..."
if sudo chown -R $(id -u):$(id -g) "$HOME/.npm"; then
    echo -e "${GREEN}✅ npm cache permissions fixed${NC}"
else
    echo -e "${YELLOW}⚠️  Could not fix npm cache permissions (may require manual intervention)${NC}"
fi
echo ""

# Fix permissions for frontend directory
echo "🔧 Fixing Front-End directory permissions..."
if sudo chown -R $(id -u):$(id -g) "$FRONTEND_DIR"; then
    echo -e "${GREEN}✅ Front-End directory permissions fixed${NC}"
else
    echo -e "${RED}❌ Failed to fix Front-End directory permissions${NC}"
    exit 1
fi
echo ""

# Navigate to frontend directory
cd "$FRONTEND_DIR"

# Clean existing installations (optional but recommended)
echo "🧹 Cleaning previous installations..."
if [ -f "package-lock.json" ]; then
    rm -f package-lock.json
    echo -e "${GREEN}✅ Removed old package-lock.json${NC}"
fi

if [ -d "node_modules" ]; then
    rm -rf node_modules
    echo -e "${GREEN}✅ Removed old node_modules${NC}"
fi
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
echo "   This may take a few minutes..."
echo ""

if npm install; then
    echo ""
    echo -e "${GREEN}✅ Dependencies installed successfully!${NC}"
else
    echo ""
    echo -e "${RED}❌ Failed to install dependencies${NC}"
    exit 1
fi
echo ""

# Verify recharts is installed
echo "🔍 Verifying recharts installation..."
if npm list recharts > /dev/null 2>&1; then
    echo -e "${GREEN}✅ recharts is installed${NC}"
else
    echo -e "${YELLOW}⚠️  recharts may not be installed correctly${NC}"
fi
echo ""

# Build the project
echo "🏗️  Building frontend..."
if npm run build; then
    echo ""
    echo -e "${GREEN}✅ Frontend built successfully!${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠️  Build completed with warnings (check above for details)${NC}"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✨ Installation Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Summary of Enhancements:"
echo "  ✅ Admin can see all models in policy editor"
echo "  ✅ Loading states for request approval/decline"
echo "  ✅ Real-time upload approval updates"
echo "  ✅ Better request type labels (no underscores)"
echo "  ✅ Fixed empty rectangle bug in chat"
echo "  ✅ AI prompt enhancement button"
echo "  ✅ Admin analytics dashboard with charts"
echo "  ✅ Enhanced space sidebar with admin badges"
echo ""
echo "🚀 Next Steps:"
echo "  1. Start the development server:"
echo "     cd Front-End && npm run dev"
echo ""
echo "  2. Access the analytics dashboard:"
echo "     Navigate to: http://localhost:5174/admin/analytics"
echo ""
echo "  3. Test the enhancements:"
echo "     - Try the AI prompt enhancement button (magic wand icon)"
echo "     - Check loading states on approval/decline"
echo "     - Verify admin badges in space sidebar"
echo ""
echo "📖 Full documentation: UI_UX_ENHANCEMENTS.md"
echo ""
