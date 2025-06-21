# OTEL Cloud Spanner Receiver - Team Setup

## Quick Start (5 minutes)

1. **Install Docker or Podman**
   - Mac: `brew install podman`
   - Linux: `sudo apt install podman`

2. **Run Setup**
   ```bash
   export SPANNER_PROJECT_ID="our-prod-project"
   export SPANNER_INSTANCE_ID="monitoring-instance"
   export SPANNER_DATABASE_ID="metrics-db"
   
   curl -sSL https://raw.githubusercontent.com/our-org/otel-spanner-automation/main/quick-start.sh | bash
