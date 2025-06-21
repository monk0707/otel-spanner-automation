#!/bin/bash
# setup.sh - Automated setup for OTEL Cloud Spanner Receiver
# Handles all configuration files and placeholders automatically

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_VERSION="3.0.0"

# Repository URLs
EXAMPLE_REPO="https://github.com/cloudspannerecosystem/OtelCloudSpannerReceiverExample.git"
OTEL_CONTRIB_REPO="https://github.com/open-telemetry/opentelemetry-collector-contrib.git"

# Default paths
WORK_DIR="${OTEL_WORK_DIR:-$(pwd)}"
EXAMPLE_DIR="${WORK_DIR}/OtelCloudSpannerReceiverExample"
OTEL_CONTRIB_DIR="${WORK_DIR}/opentelemetry-collector-contrib"

# Configuration defaults
DEFAULT_COMPOSE_CMD=""
USE_PODMAN="${USE_PODMAN:-true}"
DEV_MODE="${DEV_MODE:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Automated setup for OTEL Cloud Spanner Receiver with docker-compose.

OPTIONS:
    -h, --help                      Show this help message
    -p, --project PROJECT           GCP Project ID
    -i, --instance INSTANCE         Cloud Spanner Instance ID
    -d, --database DATABASE         Cloud Spanner Database ID
    -k, --service-account-key PATH  Path to service account key JSON
    -e, --service-account-email EMAIL  Service account email (for Cloud Monitoring)
    --dev-mode                      Enable development mode (builds local OTEL)
    --use-docker                    Use Docker instead of Podman
    --skip-clone                    Skip cloning repositories
    --skip-build                    Skip building OTEL (dev mode only)
    --cleanup                       Clean up all resources

EXAMPLES:
    # Basic setup with prompts
    $0

    # Full setup with all parameters
    $0 -p my-project -i my-instance -d my-db -k /path/to/key.json

    # Development mode
    $0 --dev-mode

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -p|--project)
                SPANNER_PROJECT_ID="$2"
                shift 2
                ;;
            -i|--instance)
                SPANNER_INSTANCE_ID="$2"
                shift 2
                ;;
            -d|--database)
                SPANNER_DATABASE_ID="$2"
                shift 2
                ;;
            -k|--service-account-key)
                SERVICE_ACCOUNT_KEY_PATH="$2"
                shift 2
                ;;
            -e|--service-account-email)
                SERVICE_ACCOUNT_EMAIL="$2"
                shift 2
                ;;
            --dev-mode)
                DEV_MODE=true
                shift
                ;;
            --use-docker)
                USE_PODMAN=false
                shift
                ;;
            --skip-clone)
                SKIP_CLONE=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --cleanup)
                cleanup_all
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Detect and setup container runtime
setup_container_runtime() {
    log "Setting up container runtime..."
    
    if [[ "$USE_PODMAN" == "true" ]] && command -v podman &> /dev/null; then
        if command -v podman-compose &> /dev/null; then
            DEFAULT_COMPOSE_CMD="podman-compose"
            log_success "Using podman-compose"
        else
            log_warn "podman-compose not found. Installing..."
            install_podman_compose
        fi
    elif command -v docker &> /dev/null; then
        if docker compose version &> /dev/null 2>&1; then
            DEFAULT_COMPOSE_CMD="docker compose"
            log_success "Using docker compose"
        elif command -v docker-compose &> /dev/null; then
            DEFAULT_COMPOSE_CMD="docker-compose"
            log_success "Using docker-compose"
        else
            log_error "No docker-compose command found"
            exit 1
        fi
    else
        log_error "Neither Podman nor Docker found. Please install one."
        exit 1
    fi
    
    export COMPOSE_CMD="${COMPOSE_CMD:-$DEFAULT_COMPOSE_CMD}"
}

# Install podman-compose
install_podman_compose() {
    if command -v pip3 &> /dev/null; then
        pip3 install --user podman-compose
        export PATH="$HOME/.local/bin:$PATH"
    elif command -v pip &> /dev/null; then
        pip install --user podman-compose
        export PATH="$HOME/.local/bin:$PATH"
    else
        log_error "pip not found. Please install podman-compose manually"
        exit 1
    fi
}

# Clone or update repositories
setup_repositories() {
    if [[ "${SKIP_CLONE:-false}" == "true" ]]; then
        log "Skipping repository clone"
        return
    fi
    
    log "Setting up repositories..."
    
    # Clone example repository
    if [[ -d "$EXAMPLE_DIR" ]]; then
        log "Updating example repository..."
        cd "$EXAMPLE_DIR"
        git pull origin main || log_warn "Could not update repository"
    else
        log "Cloning example repository..."
        git clone "$EXAMPLE_REPO" "$EXAMPLE_DIR"
    fi
    
    # Clone OTEL contrib if in dev mode
    if [[ "$DEV_MODE" == "true" ]]; then
        if [[ -d "$OTEL_CONTRIB_DIR" ]]; then
            log "Updating OTEL contrib repository..."
            cd "$OTEL_CONTRIB_DIR"
            git pull origin main || log_warn "Could not update repository"
        else
            log "Cloning OTEL contrib repository..."
            git clone "$OTEL_CONTRIB_REPO" "$OTEL_CONTRIB_DIR"
        fi
    fi
    
    cd "$EXAMPLE_DIR"
}

# Collect configuration interactively
collect_configuration() {
    log "Collecting configuration..."
    
    # Project ID
    if [[ -z "${SPANNER_PROJECT_ID:-}" ]]; then
        read -p "Enter GCP Project ID: " SPANNER_PROJECT_ID
    fi
    
    # Instance ID
    if [[ -z "${SPANNER_INSTANCE_ID:-}" ]]; then
        read -p "Enter Cloud Spanner Instance ID: " SPANNER_INSTANCE_ID
    fi
    
    # Database ID
    if [[ -z "${SPANNER_DATABASE_ID:-}" ]]; then
        read -p "Enter Cloud Spanner Database ID: " SPANNER_DATABASE_ID
    fi
    
    # Service Account Key
    if [[ -z "${SERVICE_ACCOUNT_KEY_PATH:-}" ]]; then
        echo ""
        echo "Service Account Key options:"
        echo "1. Use existing key file"
        echo "2. Use Application Default Credentials (ADC)"
        echo "3. Create new service account key"
        read -p "Choose option [1-3]: " key_option
        
        case $key_option in
            1)
                read -p "Enter path to service account key JSON: " SERVICE_ACCOUNT_KEY_PATH
                if [[ ! -f "$SERVICE_ACCOUNT_KEY_PATH" ]]; then
                    log_error "File not found: $SERVICE_ACCOUNT_KEY_PATH"
                    exit 1
                fi
                ;;
            2)
                SERVICE_ACCOUNT_KEY_PATH="ADC"
                ;;
            3)
                create_service_account_key
                ;;
        esac
    fi
    
    # Extract service account email from key file if not provided
    if [[ -z "${SERVICE_ACCOUNT_EMAIL:-}" ]] && [[ "$SERVICE_ACCOUNT_KEY_PATH" != "ADC" ]]; then
        if [[ -f "$SERVICE_ACCOUNT_KEY_PATH" ]]; then
            SERVICE_ACCOUNT_EMAIL=$(jq -r '.client_email // empty' "$SERVICE_ACCOUNT_KEY_PATH" 2>/dev/null || true)
            if [[ -n "$SERVICE_ACCOUNT_EMAIL" ]]; then
                log "Detected service account email: $SERVICE_ACCOUNT_EMAIL"
            fi
        fi
    fi
    
    # If still no email and using Cloud Monitoring datasource
    if [[ -z "${SERVICE_ACCOUNT_EMAIL:-}" ]]; then
        echo ""
        read -p "Enter service account email (for Cloud Monitoring, or press Enter to skip): " SERVICE_ACCOUNT_EMAIL
    fi
    
    # Validate required inputs
    if [[ -z "$SPANNER_PROJECT_ID" ]] || [[ -z "$SPANNER_INSTANCE_ID" ]] || [[ -z "$SPANNER_DATABASE_ID" ]]; then
        log_error "Missing required configuration"
        exit 1
    fi
}

# Create service account key
create_service_account_key() {
    log "Creating service account key..."
    
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI not found. Please install Google Cloud SDK"
        exit 1
    fi
    
    SA_NAME="otel-spanner-reader"
    SA_EMAIL="${SA_NAME}@${SPANNER_PROJECT_ID}.iam.gserviceaccount.com"
    KEY_FILE="${EXAMPLE_DIR}/collector/service-account-key.json"
    
    # Create service account
    gcloud iam service-accounts create "$SA_NAME" \
        --display-name="OTEL Spanner Reader" \
        --project="$SPANNER_PROJECT_ID" 2>/dev/null || true
    
    # Grant permissions
    log "Granting required permissions..."
    gcloud projects add-iam-policy-binding "$SPANNER_PROJECT_ID" \
        --member="serviceAccount:${SA_EMAIL}" \
        --role="roles/spanner.databaseReader" \
        --quiet
    
    gcloud projects add-iam-policy-binding "$SPANNER_PROJECT_ID" \
        --member="serviceAccount:${SA_EMAIL}" \
        --role="roles/monitoring.metricWriter" \
        --quiet
    
    gcloud projects add-iam-policy-binding "$SPANNER_PROJECT_ID" \
        --member="serviceAccount:${SA_EMAIL}" \
        --role="roles/monitoring.viewer" \
        --quiet
    
    # Create key
    mkdir -p "$(dirname "$KEY_FILE")"
    gcloud iam service-accounts keys create "$KEY_FILE" \
        --iam-account="$SA_EMAIL" \
        --project="$SPANNER_PROJECT_ID"
    
    SERVICE_ACCOUNT_KEY_PATH="$KEY_FILE"
    SERVICE_ACCOUNT_EMAIL="$SA_EMAIL"
    log_success "Service account key created: $KEY_FILE"
}

# Update configuration files
update_configurations() {
    log "Updating configuration files..."
    
    cd "$EXAMPLE_DIR"
    
    # Backup existing configs
    backup_configs
    
    # Determine service account key filename
    if [[ "$SERVICE_ACCOUNT_KEY_PATH" != "ADC" ]]; then
        # Copy service account key to collector directory
        SERVICE_ACCOUNT_KEY_FILENAME="service-account-key.json"
        cp "$SERVICE_ACCOUNT_KEY_PATH" "${EXAMPLE_DIR}/collector/${SERVICE_ACCOUNT_KEY_FILENAME}"
    fi
    
    # Update all configuration files
    update_collector_config
    update_docker_compose
    update_prometheus_config
    update_grafana_datasources
    fix_grafana_dashboards
    create_env_file
    
    log_success "All configurations updated"
}

# Backup existing configurations
backup_configs() {
    local backup_dir="${EXAMPLE_DIR}/backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    cp -r collector "$backup_dir/" 2>/dev/null || true
    cp docker-compose.yml "$backup_dir/" 2>/dev/null || true
    cp -r prometheus "$backup_dir/" 2>/dev/null || true
    cp -r grafana "$backup_dir/" 2>/dev/null || true
    
    log "Configurations backed up to: $backup_dir"
}

# Update collector configuration
update_collector_config() {
    local config_file="${EXAMPLE_DIR}/collector/config.yml"
    
    log "Updating collector configuration..."
    
    cat > "$config_file" << EOF
receivers:
  googlecloudspanner:
    collection_interval: 60s
    top_metrics_query_max_rows: 100
    # backfill_enabled: true
    projects:
      - project_id: "${SPANNER_PROJECT_ID}"
EOF

    if [[ "$SERVICE_ACCOUNT_KEY_PATH" != "ADC" ]]; then
        echo "        service_account_key: \"${SERVICE_ACCOUNT_KEY_FILENAME}\"" >> "$config_file"
    fi
    
    cat >> "$config_file" << EOF
        instances:
          - instance_id: "${SPANNER_INSTANCE_ID}"
            databases:
              - "${SPANNER_DATABASE_ID}"

exporters:
  prometheus:
    add_metric_suffixes: false # For collector version > 0.84.0
    send_timestamps: true
    endpoint: "0.0.0.0:8889"
  logging:
    loglevel: debug
  # googlecloud:
  #   retry_on_failure:
  #     enabled: false

processors:
  batch:
    send_batch_size: 200

service:
  pipelines:
    metrics:
      receivers: [googlecloudspanner]
      processors: [batch]
      exporters: [logging, prometheus]
EOF
}

# Update docker-compose.yml
update_docker_compose() {
    local compose_file="${EXAMPLE_DIR}/docker-compose.yml"
    
    log "Updating docker-compose.yml..."
    
    # Determine collector image
    local collector_image="otel/opentelemetry-collector-contrib:0.42.0"
    if [[ "$DEV_MODE" == "true" ]]; then
        collector_image="otel/opentelemetry-collector-contrib:local"
    fi
    
    cat > "$compose_file" << EOF
version: "3.9"
services:
  prometheus:
    command: ["--storage.tsdb.min-block-duration=30m", "--query.lookback-delta=1m", "--config.file=/etc/prometheus/prometheus.yml", "--enable-feature=remote-write-receiver"]
    image: prom/prometheus:v2.30.3
    ports:
      - "9090:9090"
    volumes:
      - prometheus-storage:/prometheus
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:8.3.1
    depends_on:
      - "collector"
    ports:
      - "3000:3000"
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./grafana/provisioning/:/etc/grafana/provisioning/
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin

  collector:
    image: ${collector_image}
    depends_on:
      - "prometheus"
EOF

    if [[ "$SERVICE_ACCOUNT_KEY_PATH" != "ADC" ]]; then
        cat >> "$compose_file" << EOF
    environment:
      - GOOGLE_APPLICATION_CREDENTIALS=/${SERVICE_ACCOUNT_KEY_FILENAME}
EOF
    fi
    
    cat >> "$compose_file" << EOF
    ports:
      - "8889:8889"
      - "8888:8888"
    volumes:
      - ./collector/config.yml:/config.yml
EOF

    if [[ "$SERVICE_ACCOUNT_KEY_PATH" != "ADC" ]]; then
        cat >> "$compose_file" << EOF
      - ./collector/${SERVICE_ACCOUNT_KEY_FILENAME}:/${SERVICE_ACCOUNT_KEY_FILENAME}
EOF
    fi
    
    cat >> "$compose_file" << EOF
    command: ["--config=/config.yml"]

volumes:
  prometheus-storage:
  grafana-storage:
EOF
}

# Update Prometheus configuration
update_prometheus_config() {
    local prom_file="${EXAMPLE_DIR}/prometheus/prometheus.yml"
    
    log "Updating Prometheus configuration..."
    
    # The existing prometheus.yml doesn't have placeholders, but ensure it exists
    if [[ ! -f "$prom_file" ]]; then
        mkdir -p "$(dirname "$prom_file")"
        cat > "$prom_file" << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "otel"
    honor_timestamps: true
    static_configs:
      - targets: ["collector:8888", "collector:8889"]
EOF
    fi
}

# Update Grafana datasources
update_grafana_datasources() {
    log "Updating Grafana datasources..."
    
    # Update Cloud Monitoring datasource if service account email is provided
    if [[ -n "${SERVICE_ACCOUNT_EMAIL:-}" ]] && [[ "$SERVICE_ACCOUNT_KEY_PATH" != "ADC" ]]; then
        local cm_datasource="${EXAMPLE_DIR}/grafana/provisioning/datasources/cloud-monitoring-datasource.yml"
        
        # Extract private key from service account JSON
        local private_key=$(jq -r '.private_key // empty' "$SERVICE_ACCOUNT_KEY_PATH" 2>/dev/null || true)
        
        if [[ -n "$private_key" ]]; then
            log "Updating Cloud Monitoring datasource..."
            
            cat > "$cm_datasource" << EOF
apiVersion: 1

datasources:
  - name: Google Cloud Monitoring
    type: stackdriver
    access: proxy
    jsonData:
      tokenUri: https://oauth2.googleapis.com/token
      clientEmail: ${SERVICE_ACCOUNT_EMAIL}
      authenticationType: jwt
      defaultProject: ${SPANNER_PROJECT_ID}
    secureJsonData:
      privateKey: |
$(echo "$private_key" | sed 's/^/        /')
EOF
        fi
    fi
    
    # Ensure Prometheus datasource exists and is correct
    local prom_datasource="${EXAMPLE_DIR}/grafana/provisioning/datasources/prometheus-datasource.yml"
    cat > "$prom_datasource" << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    # Access mode - proxy (server in the UI) or direct (browser in the UI).
    access: proxy
    url: http://prometheus:9090
EOF
}

# Fix Grafana dashboard configurations
fix_grafana_dashboards() {
    log "Checking Grafana dashboards..."
    
    local dashboards_dir="${EXAMPLE_DIR}/grafana/provisioning/dashboards"
    
    # Ensure dashboards.yml exists
    local dashboards_yml="${dashboards_dir}/dashboards.yml"
    if [[ ! -f "$dashboards_yml" ]]; then
        mkdir -p "$dashboards_dir"
        cat > "$dashboards_yml" << 'EOF'
apiVersion: 1

providers:
  - name: dashboards
    type: file
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
      foldersFromFilesStructure: true
EOF
    fi
    
    # Fix any dashboard JSON files with incorrect datasource UIDs
    find "$dashboards_dir" -name "*.json" -type f 2>/dev/null | while read -r dashboard; do
        # Fix common datasource reference issues
        sed -i.bak 's/"datasource": "Prometheus"/"datasource": {"type": "prometheus", "uid": "${DS_PROMETHEUS}"}/g' "$dashboard" 2>/dev/null || true
        rm -f "${dashboard}.bak"
    done
}

# Create .env file
create_env_file() {
    cat > "${EXAMPLE_DIR}/.env" << EOF
# Generated by OTEL setup script on $(date)
SPANNER_PROJECT_ID=${SPANNER_PROJECT_ID}
SPANNER_INSTANCE_ID=${SPANNER_INSTANCE_ID}
SPANNER_DATABASE_ID=${SPANNER_DATABASE_ID}
COMPOSE_PROJECT_NAME=otel-spanner

# Container runtime
COMPOSE_CMD=${COMPOSE_CMD}

# Development mode
DEV_MODE=${DEV_MODE}
EOF

    # Add to .gitignore
    if [[ -f "${EXAMPLE_DIR}/.gitignore" ]]; then
        grep -q "^.env$" "${EXAMPLE_DIR}/.gitignore" || echo ".env" >> "${EXAMPLE_DIR}/.gitignore"
        grep -q "^backups/$" "${EXAMPLE_DIR}/.gitignore" || echo "backups/" >> "${EXAMPLE_DIR}/.gitignore"
        grep -q "^service-account-key.json$" "${EXAMPLE_DIR}/.gitignore" || echo "collector/service-account-key.json" >> "${EXAMPLE_DIR}/.gitignore"
    else
        cat > "${EXAMPLE_DIR}/.gitignore" << EOF
.env
backups/
collector/service-account-key.json
*.log
*.pid
EOF
    fi
}

# Build OTEL collector (dev mode)
build_otel_collector() {
    if [[ "$DEV_MODE" != "true" ]] || [[ "${SKIP_BUILD:-false}" == "true" ]]; then
        return
    fi
    
    log "Building OTEL collector from source..."
    
    cd "$OTEL_CONTRIB_DIR"
    
    # Build the collector
    make docker-otelcontribcol
    
    # Tag for use in docker-compose
    docker tag otelcontribcol:latest otel/opentelemetry-collector-contrib:local
    
    log_success "OTEL collector built and tagged as otel/opentelemetry-collector-contrib:local"
}

# Start services
start_services() {
    log "Starting services..."
    
    cd "$EXAMPLE_DIR"
    
    # Start with docker-compose
    $COMPOSE_CMD up -d
    
    # Wait for services to be ready
    log "Waiting for services to start..."
    sleep 10
    
    # Check health
    check_services_health
}

# Check services health
check_services_health() {
    log "Checking services health..."
    
    local all_healthy=true
    
    # Check Prometheus
    if curl -s -f "http://localhost:9090/-/healthy" > /dev/null 2>&1; then
        log_success "Prometheus is healthy"
    else
        log_error "Prometheus health check failed"
        all_healthy=false
    fi
    
    # Check Grafana
    if curl -s -f "http://localhost:3000/api/health" > /dev/null 2>&1; then
        log_success "Grafana is healthy"
    else
        log_error "Grafana health check failed"
        all_healthy=false
    fi
    
    # Check OTEL Collector metrics endpoint
    if curl -s "http://localhost:8889/metrics" > /dev/null 2>&1; then
        log_success "OTEL Collector metrics endpoint is accessible"
    else
        log_warn "OTEL Collector metrics endpoint not responding"
    fi
    
    if [[ "$all_healthy" == "false" ]]; then
        log_error "Some services failed health checks. Check logs with:"
        log_error "$COMPOSE_CMD logs"
        return 1
    fi
    
    return 0
}

# Generate test traffic script
create_traffic_generator() {
    log "Creating traffic generator script..."
    
    cat > "${EXAMPLE_DIR}/generate-traffic.sh" << 'EOF'
#!/bin/bash
# Generate test traffic for Cloud Spanner

PROJECT_ID="$1"
INSTANCE_ID="$2"
DATABASE_ID="$3"
DURATION="${4:-300}"

if [[ -z "$PROJECT_ID" || -z "$INSTANCE_ID" || -z "$DATABASE_ID" ]]; then
    echo "Usage: $0 PROJECT_ID INSTANCE_ID DATABASE_ID [DURATION_SECONDS]"
    exit 1
fi

echo "Generating traffic for $DURATION seconds..."
echo "Project: $PROJECT_ID, Instance: $INSTANCE_ID, Database: $DATABASE_ID"

# Check if gcloud is available
if ! command -v gcloud &> /dev/null; then
    echo "gcloud CLI not found. Please install Google Cloud SDK."
    exit 1
fi

# Create test table
echo "Creating test table..."
gcloud spanner databases ddl update "$DATABASE_ID" \
    --instance="$INSTANCE_ID" \
    --project="$PROJECT_ID" \
    --ddl="CREATE TABLE IF NOT EXISTS test_metrics (
        id STRING(36) NOT NULL,
        data STRING(1024),
        value FLOAT64,
        created_at TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp=true)
    ) PRIMARY KEY (id)" 2>/dev/null || true

# Generate traffic
end_time=$(($(date +%s) + DURATION))
counter=0

while [[ $(date +%s) -lt $end_time ]]; do
    # Insert operation
    gcloud spanner rows insert \
        --database="$DATABASE_ID" \
        --instance="$INSTANCE_ID" \
        --project="$PROJECT_ID" \
        --table=test_metrics \
        --data="id='$(uuidgen || echo $RANDOM$RANDOM)',data='Test data $counter',value=$((RANDOM % 100)),created_at=PENDING_COMMIT_TIMESTAMP()" 2>/dev/null || true
    
    # Read operations
    gcloud spanner databases execute-sql "$DATABASE_ID" \
        --instance="$INSTANCE_ID" \
        --project="$PROJECT_ID" \
        --sql="SELECT COUNT(*) as count FROM test_metrics WHERE created_at > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)" &>/dev/null || true
    
    # Update operation
    if ((counter % 5 == 0)); then
        gcloud spanner databases execute-sql "$DATABASE_ID" \
            --instance="$INSTANCE_ID" \
            --project="$PROJECT_ID" \
            --sql="UPDATE test_metrics SET value = value * 1.1 WHERE created_at > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 5 MINUTE)" &>/dev/null || true
    fi
    
    ((counter++))
    
    # Show progress
    if ((counter % 10 == 0)); then
        echo "Generated $counter operations..."
    fi
    
    sleep 1
done

echo "Traffic generation completed. Generated $counter operations."
EOF

    chmod +x "${EXAMPLE_DIR}/generate-traffic.sh"
}

# Create helper scripts
create_helper_scripts() {
    log "Creating helper scripts..."
    
    # Create status check script
    cat > "${EXAMPLE_DIR}/check-status.sh" << 'EOF'
#!/bin/bash
# Quick status check for OTEL setup

echo "=== OTEL Cloud Spanner Receiver Status ==="
echo ""

# Service health checks
echo "Service Health:"
if curl -s -f http://localhost:9090/-/healthy > /dev/null 2>&1; then
    echo "  ✓ Prometheus:    Healthy"
else
    echo "  ✗ Prometheus:    Not responding"
fi

if curl -s -f http://localhost:3000/api/health > /dev/null 2>&1; then
    echo "  ✓ Grafana:       Healthy"
else
    echo "  ✗ Grafana:       Not responding"
fi

if curl -s http://localhost:8889/metrics > /dev/null 2>&1; then
    echo "  ✓ OTEL Metrics:  Available"
else
    echo "  ✗ OTEL Metrics:  Not available"
fi

echo ""
echo "Metrics Summary:"
if curl -s http://localhost:8889/metrics 2>/dev/null | grep -q "googlecloudspanner"; then
    count=$(curl -s http://localhost:8889/metrics | grep -c "googlecloudspanner" || echo "0")
    echo "  Cloud Spanner metrics found: $count"
    echo ""
    echo "  Sample metrics:"
    curl -s http://localhost:8889/metrics | grep "googlecloudspanner" | head -5
else
    echo "  No Cloud Spanner metrics found yet"
    echo "  (This is normal if just started - run generate-traffic.sh)"
fi
EOF
    chmod +x "${EXAMPLE_DIR}/check-status.sh"
    
    # Create quick restart script
    cat > "${EXAMPLE_DIR}/restart-services.sh" << EOF
#!/bin/bash
# Quick restart of all services

cd "\$(dirname "\$0")"
echo "Restarting OTEL services..."
${COMPOSE_CMD} restart
echo "Services restarted. Check status with: ./check-status.sh"
EOF
    chmod +x "${EXAMPLE_DIR}/restart-services.sh"
    
    # Create logs viewer script
    cat > "${EXAMPLE_DIR}/view-logs.sh" << EOF
#!/bin/bash
# View logs for OTEL services

cd "\$(dirname "\$0")"
echo "Choose service to view logs:"
echo "1. All services"
echo "2. Collector only"
echo "3. Prometheus only"
echo "4. Grafana only"
read -p "Choice [1-4]: " choice

case \$choice in
    1) ${COMPOSE_CMD} logs -f ;;
    2) ${COMPOSE_CMD} logs -f collector ;;
    3) ${COMPOSE_CMD} logs -f prometheus ;;
    4) ${COMPOSE_CMD} logs -f grafana ;;
    *) echo "Invalid choice" ;;
esac
EOF
    chmod +x "${EXAMPLE_DIR}/view-logs.sh"
    
    # Create update script for dev mode
    if [[ "$DEV_MODE" == "true" ]]; then
        cat > "${EXAMPLE_DIR}/update-otel.sh" << EOF
#!/bin/bash
# Quick script to rebuild and update OTEL collector

set -e

echo "Building OTEL collector..."
cd "${OTEL_CONTRIB_DIR}"
make docker-otelcontribcol

echo "Tagging image..."
docker tag otelcontribcol:latest otel/opentelemetry-collector-contrib:local

echo "Updating running container..."
cd "${EXAMPLE_DIR}"
${COMPOSE_CMD} up -d collector

echo "Done! Check logs with: ${COMPOSE_CMD} logs -f collector"
EOF
        chmod +x "${EXAMPLE_DIR}/update-otel.sh"
    fi
}

# Cleanup function
cleanup_all() {
    log "Cleaning up OTEL setup..."
    
    cd "$EXAMPLE_DIR" 2>/dev/null || true
    
    # Stop and remove containers
    if [[ -n "${COMPOSE_CMD:-}" ]]; then
        log "Stopping services..."
        $COMPOSE_CMD down -v
    fi
    
    log_success "Cleanup completed"
}

# Show completion message
show_completion_message() {
    cat << EOF

${GREEN}================================================${NC}
${GREEN}OTEL Cloud Spanner Receiver Setup Complete! 🎉${NC}
${GREEN}================================================${NC}

${BLUE}Configuration Summary:${NC}
  • Project:       ${SPANNER_PROJECT_ID}
  • Instance:      ${SPANNER_INSTANCE_ID}
  • Database:      ${SPANNER_DATABASE_ID}
  • Runtime:       ${COMPOSE_CMD}

${BLUE}Access Points:${NC}
  • Prometheus:    ${GREEN}http://localhost:9090${NC}
  • Grafana:       ${GREEN}http://localhost:3000${NC}
    Username: admin
    Password: admin
  • OTEL Metrics:  ${GREEN}http://localhost:8889/metrics${NC}

${BLUE}Quick Commands:${NC}
  • Check status:    ${YELLOW}./check-status.sh${NC}
  • View logs:       ${YELLOW}./view-logs.sh${NC}
  • Restart:         ${YELLOW}./restart-services.sh${NC}
  • Generate traffic: ${YELLOW}./generate-traffic.sh ${SPANNER_PROJECT_ID} ${SPANNER_INSTANCE_ID} ${SPANNER_DATABASE_ID}${NC}

${BLUE}Directory:${NC}
  ${YELLOW}cd ${EXAMPLE_DIR}${NC}

EOF

    if [[ "$DEV_MODE" == "true" ]]; then
        cat << EOF
${BLUE}Development Mode:${NC}
  • OTEL Source:     ${YELLOW}${OTEL_CONTRIB_DIR}${NC}
  • Quick rebuild:   ${YELLOW}./update-otel.sh${NC}

EOF
    fi

    cat << EOF
${BLUE}Next Steps:${NC}
  1. Generate test traffic to see metrics
  2. Import Cloud Spanner dashboards in Grafana
  3. Configure alerts as needed

${BLUE}Troubleshooting:${NC}
  • No metrics? Run: ${YELLOW}./generate-traffic.sh${NC}
  • View logs:       ${YELLOW}${COMPOSE_CMD} logs collector${NC}
  • Check README:    ${YELLOW}${EXAMPLE_DIR}/README.md${NC}

EOF
}

# Main execution
main() {
    log "OTEL Cloud Spanner Receiver Setup v${SCRIPT_VERSION}"
    echo ""
    
    # Parse arguments
    parse_args "$@"
    
    # Setup container runtime
    setup_container_runtime
    
    # Clone/update repositories
    setup_repositories
    
    # Collect configuration
    collect_configuration
    
    # Update configurations
    update_configurations
    
    # Build OTEL if in dev mode
    build_otel_collector
    
    # Start services
    start_services
    
    # Create helper scripts
    create_traffic_generator
    create_helper_scripts
    
    # Show completion message
    show_completion_message
    
    log_success "Setup completed successfully!"
}

# Handle errors
trap 'log_error "Setup failed. Check logs for details."; exit 1' ERR

# Run main function
main "$@"