2. **Run Setup**
   ```bash
   export SPANNER_PROJECT_ID="our-prod-project"
   export SPANNER_INSTANCE_ID="monitoring-instance"
   export SPANNER_DATABASE_ID="metrics-db"
   
   curl -sSL https://raw.githubusercontent.com/our-org/otel-spanner-automation/main/quick-start.sh | bash
