#!/bin/bash
# quick-start.sh - One-line installer for OTEL Cloud Spanner Receiver
# Usage: curl -sSL https://your-domain.com/quick-start.sh | bash

set -euo pipefail

# Configuration
AUTOMATION_REPO="https://github.com/your-org/otel-spanner-automation"
INSTALL_DIR="${HOME}/otel-spanner-setup"
REQUIRED_TOOLS=(git curl)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Banner
show_banner() {
    cat << 'EOF'
   ___  _____ _____ _       ____                                  
  / _ \|_   _| ____| |     / ___| _ __   __ _ _ __  _ __   ___ _ __ 
 | | | | | | |  _| | |     \___ \| '_ \ / _` | '_ \| '_ \ / _ \ '__|
 | |_| | | | | |___| |___   ___) | |_) | (_| | | | | | | |  __/ |   
  \___/  |_| |_____|_____| |____/| .__/ \__,_|_| |_|_| |_|\___|_|   
                                 |_|                                 
          Automated Setup for Cloud Spanner Receiver
          
EOF
}

# Logging
log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Check if running from curl pipe
is_piped() {
    [[ ! -t 0 ]]
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing=()
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing[*]}"
    fi
    
    # Check for container runtime
    if command -v podman &> /dev/null; then
        log "Found Podman (recommended)"
        if ! command -v podman-compose &> /dev/null; then
            log "Installing podman-compose..."
            if command -v pip3 &> /dev/null; then
                pip3 install --user podman-compose || warn "Failed to install podman-compose"
            elif command -v pip &> /dev/null; then
                pip install --user podman-compose || warn "Failed to install podman-compose"
            fi
            export PATH="$HOME/.local/bin:$PATH"
        fi
    elif command -v docker &> /dev/null; then
        log "Found Docker"
        if ! docker compose version &> /dev/null 2>&1 && ! command -v docker-compose &> /dev/null; then
            error "docker-compose not found. Please install Docker Compose."
        fi
    else
        error "Neither Podman nor Docker found. Please install one:\n  Podman: https://podman.io/getting-started/installation\n  Docker: https://docs.docker.com/get-docker/"
    fi
    
    success "Prerequisites check passed"
}

# Interactive configuration
configure_interactively() {
    echo ""
    echo -e "${BLUE}=== Configuration Setup ===${NC}"
    echo ""
    
    # Check for environment variables first
    if [[ -n "${SPANNER_PROJECT_ID:-}" ]] && \
       [[ -n "${SPANNER_INSTANCE_ID:-}" ]] && \
       [[ -n "${SPANNER_DATABASE_ID:-}" ]]; then
        log "Using environment variables for configuration"
        echo "  Project:  $SPANNER_PROJECT_ID"
        echo "  Instance: $SPANNER_INSTANCE_ID"
        echo "  Database: $SPANNER_DATABASE_ID"
        return
    fi
    
    # Interactive prompts
    echo "Please provide your Cloud Spanner configuration:"
    echo ""
    read -p "GCP Project ID: " SPANNER_PROJECT_ID
    read -p "Cloud Spanner Instance ID: " SPANNER_INSTANCE_ID
    read -p "Cloud Spanner Database ID: " SPANNER_DATABASE_ID
    
    export SPANNER_PROJECT_ID SPANNER_INSTANCE_ID SPANNER_DATABASE_ID
}

# Download and run setup
run_setup() {
    log "Creating installation directory..."
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Download setup files
    log "Downloading automation scripts..."
    
    # Clone or download the automation repository
    if [[ -d "otel-spanner-automation" ]]; then
        log "Updating existing automation scripts..."
        cd otel-spanner-automation
        git pull origin main || warn "Could not update, using existing version"
        cd ..
    else
        # Try git clone first
        if git clone "$AUTOMATION_REPO" otel-spanner-automation 2>/dev/null; then
            log "Downloaded automation repository"
        else
            # Fallback to direct download of setup script
            log "Downloading setup script directly..."
            mkdir -p otel-spanner-automation
            cd otel-spanner-automation
            
            if command -v curl &> /dev/null; then
                curl -sSL "${AUTOMATION_REPO}/raw/main/setup.sh" -o setup.sh || \
                    curl -sSL "https://raw.githubusercontent.com/your-org/otel-spanner-automation/main/setup.sh" -o setup.sh
            elif command -v wget &> /dev/null; then
                wget -q "${AUTOMATION_REPO}/raw/main/setup.sh" -O setup.sh || \
                    wget -q "https://raw.githubusercontent.com/your-org/otel-spanner-automation/main/setup.sh" -O setup.sh
            fi
            
            if [[ ! -f setup.sh ]]; then
                error "Failed to download setup script"
            fi
            
            # Download Makefile too
            curl -sSL "${AUTOMATION_REPO}/raw/main/Makefile" -o Makefile 2>/dev/null || true
            cd ..
        fi
    fi
    
    cd otel-spanner-automation
    chmod +x setup.sh
    
    # Determine if we should use dev mode
    local dev_flag=""
    if [[ "${DEV_MODE:-false}" == "true" ]]; then
        dev_flag="--dev-mode"
        log "Development mode enabled"
    fi
    
    # Run main setup
    log "Running OTEL setup..."
    ./setup.sh \
        --project "$SPANNER_PROJECT_ID" \
        --instance "$SPANNER_INSTANCE_ID" \
        --database "$SPANNER_DATABASE_ID" \
        $dev_flag
}

# Show next steps
show_next_steps() {
    echo ""
    success "Quick setup completed!"
    echo ""
    echo -e "${BLUE}What just happened:${NC}"
    echo "  ✓ Downloaded OTEL Cloud Spanner Receiver example"
    echo "  ✓ Configured all services automatically"
    echo "  ✓ Started Prometheus, Grafana, and OTEL Collector"
    echo "  ✓ Created helper scripts for management"
    echo ""
    echo -e "${BLUE}Quick Commands:${NC}"
    echo "  cd $INSTALL_DIR/OtelCloudSpannerReceiverExample"
    echo "  ./check-status.sh      # Check service health"
    echo "  ./generate-traffic.sh  # Generate test metrics"
    echo "  ./view-logs.sh         # View service logs"
    echo ""
    echo -e "${BLUE}Access Points:${NC}"
    echo "  Grafana:    http://localhost:3000 (admin/admin)"
    echo "  Prometheus: http://localhost:9090"
    echo "  Metrics:    http://localhost:8889/metrics"
    echo ""
    echo -e "${YELLOW}Note:${NC} If you don't see metrics immediately, run the traffic generator!"
}

# Main execution when run interactively
main_interactive() {
    clear
    show_banner
    check_prerequisites
    configure_interactively
    run_setup
    show_next_steps
}

# Main execution when piped from curl
main_piped() {
    # When piped, show instructions instead of running
    cat << 'USAGE_EOF'

============================================================
OTEL Cloud Spanner Receiver - One-Line Installer
============================================================

To run this installer, you have several options:

OPTION 1: Set environment variables and pipe to bash
-------------------------------------------------
export SPANNER_PROJECT_ID="your-project"
export SPANNER_INSTANCE_ID="your-instance"
export SPANNER_DATABASE_ID="your-database"

curl -sSL https://your-domain.com/quick-start.sh | bash


OPTION 2: Download and run interactively
----------------------------------------
curl -sSL https://your-domain.com/quick-start.sh -o quick-start.sh
chmod +x quick-start.sh
./quick-start.sh


OPTION 3: One-line with inline configuration
--------------------------------------------
curl -sSL https://your-domain.com/quick-start.sh | \
  SPANNER_PROJECT_ID="your-project" \
  SPANNER_INSTANCE_ID="your-instance" \
  SPANNER_DATABASE_ID="your-database" \
  bash


OPTION 4: Development mode installation
---------------------------------------
curl -sSL https://your-domain.com/quick-start.sh | \
  DEV_MODE=true \
  SPANNER_PROJECT_ID="your-project" \
  SPANNER_INSTANCE_ID="your-instance" \
  SPANNER_DATABASE_ID="your-database" \
  bash


For more information, visit:
https://github.com/your-org/otel-spanner-automation

USAGE_EOF
}

# Detect if we're being piped or run directly
if is_piped; then
    # Check if environment variables are set
    if [[ -n "${SPANNER_PROJECT_ID:-}" ]] && \
       [[ -n "${SPANNER_INSTANCE_ID:-}" ]] && \
       [[ -n "${SPANNER_DATABASE_ID:-}" ]]; then
        # Run the installation
        show_banner
        check_prerequisites
        run_setup
        show_next_steps
    else
        # Show usage instructions
        main_piped
    fi
else
    # Running interactively
    main_interactive
fi