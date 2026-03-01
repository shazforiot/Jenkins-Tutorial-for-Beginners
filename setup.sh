#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Jenkins Quick-Start Setup Script
# ─────────────────────────────────────────────────────────────────────────────
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Jenkins CI/CD — Quick Start Setup        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# ── STEP 1: Check prerequisites ─────────────────────────────────────────────
echo -e "${YELLOW}[1/5] Checking prerequisites...${NC}"

if ! command -v docker &>/dev/null; then
    echo -e "${RED}✗ Docker is not installed.${NC}"
    echo "  Please install Docker Desktop from https://docker.com/get-started"
    exit 1
fi

if ! docker compose version &>/dev/null; then
    echo -e "${RED}✗ Docker Compose v2 is not available.${NC}"
    echo "  Please update Docker Desktop to the latest version."
    exit 1
fi

echo -e "${GREEN}✓ Docker $(docker --version | awk '{print $3}' | tr -d ',')${NC}"
echo -e "${GREEN}✓ Docker Compose $(docker compose version --short)${NC}"

# ── STEP 2: Check port availability ──────────────────────────────────────────
echo ""
echo -e "${YELLOW}[2/5] Checking ports 8080 and 50000...${NC}"

check_port() {
    local port=$1
    if lsof -i ":${port}" &>/dev/null 2>&1 || netstat -an 2>/dev/null | grep -q ":${port} "; then
        echo -e "${RED}✗ Port ${port} is already in use!${NC}"
        echo "  Stop the process using port ${port} and re-run this script."
        exit 1
    fi
}

check_port 8080  || true   # gracefully continue if lsof not available
check_port 50000 || true
echo -e "${GREEN}✓ Ports 8080 and 50000 are available${NC}"

# ── STEP 3: Start Jenkins ────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[3/5] Starting Jenkins...${NC}"

# Ensure docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}✗ docker-compose.yml not found in current directory.${NC}"
    echo "  Run this script from the demo/ folder."
    exit 1
fi

docker compose up -d

echo -e "${GREEN}✓ Jenkins container started${NC}"

# ── STEP 4: Wait for Jenkins to be ready ─────────────────────────────────────
echo ""
echo -e "${YELLOW}[4/5] Waiting for Jenkins to initialize (up to 90s)...${NC}"
echo -e "${BLUE}  (Watch full logs with: docker compose logs -f jenkins)${NC}"

TRIES=0
MAX_TRIES=30
until curl -sf http://localhost:8080/login &>/dev/null; do
    TRIES=$((TRIES + 1))
    if [ $TRIES -ge $MAX_TRIES ]; then
        echo -e "${RED}✗ Jenkins did not start within 90 seconds.${NC}"
        echo "  Check logs: docker compose logs jenkins"
        exit 1
    fi
    echo -n "."
    sleep 3
done

echo ""
echo -e "${GREEN}✓ Jenkins is up and responding!${NC}"

# ── STEP 5: Get admin password ────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[5/5] Retrieving initial admin password...${NC}"

PASSWORD=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "NOT_FOUND")

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🎉 Jenkins is ready!                     ║${NC}"
echo -e "${BLUE}╠════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║   URL:      http://localhost:8080           ║${NC}"
echo -e "${BLUE}║                                             ║${NC}"
echo -e "${BLUE}║   Admin Password:                           ║${NC}"
echo -e "${GREEN}║   ${PASSWORD}   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Open http://localhost:8080 in your browser"
echo "  2. Paste the password above"
echo "  3. Click 'Install Suggested Plugins'"
echo "  4. Create your admin user"
echo "  5. Create a Pipeline job and point it to your repo"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo "  docker compose logs -f jenkins     Watch live logs"
echo "  docker compose stop                Stop Jenkins"
echo "  docker compose start               Restart Jenkins"
echo "  docker compose down -v             Remove everything (data deleted!)"
echo ""
