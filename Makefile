# Makefile for OTEL Cloud Spanner Receiver Development
# Works with existing docker-compose.yml structure

.PHONY: help setup start stop restart clean logs status build update test validate dash dev quick-setup

# Configuration
COMPOSE_CMD := $(shell command -v podman-compose 2> /dev/null || command -v docker-compose 2> /dev/null || echo "docker compose")
EXAMPLE_DIR := ./OtelCloudSpannerReceiverExample
OTEL_DIR := ./opentelemetry-collector-contrib
SETUP_SCRIPT := ./setup.sh

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
RED := \033[0;31m
NC := \033[0m

# Default target
help:
	@echo -e "$(BLUE)OTEL Cloud Spanner Receiver - Make Commands$(NC)"
	@echo ""
	@echo "Quick Start:"
	@echo "  make setup              - Complete automated setup"
	@echo "  make quick-setup        - Setup with existing repos"
	@echo ""
	@echo "Service Management:"
	@echo "  make start              - Start all services"
	@echo "  make stop               - Stop all services"
	@echo "  make restart            - Restart all services"
	@echo "  make status             - Check service status"
	@echo "  make logs               - View all logs"
	@echo "  make logs-collector     - View collector logs only"
	@echo ""
	@echo "Development:"
	@echo "  make dev                - Setup in development mode"
	@echo "  make build              - Build OTEL from source"
	@echo "  make update             - Update collector with new build"
	@echo "  make test               - Run integration tests"
	@echo "  make validate           - Validate metrics collection"
	@echo ""
	@echo "Access:"
	@echo "  make dash               - Open Grafana (localhost:3000)"
	@echo "  make prom               - Open Prometheus (localhost:9090)"
	@echo "  make metrics            - Show OTEL metrics"
	@echo ""
	@echo "Utilities:"
	@echo "  make traffic            - Generate test traffic"
	@echo "  make clean              - Clean up everything"
	@echo "  make troubleshoot       - Run diagnostic checks"
	@echo ""
	@echo "Current Configuration:"
	@echo "  COMPOSE_CMD = $(COMPOSE_CMD)"
	@echo "  Project: $(SPANNER_PROJECT_ID)"
	@echo "  Instance: $(SPANNER_INSTANCE_ID)"
	@echo "  Database: $(SPANNER_DATABASE_ID)"

# Complete setup
setup:
	@echo -e "$(GREEN)Running complete OTEL setup...$(NC)"
	@if [[ ! -f "$(SETUP_SCRIPT)" ]]; then \
		echo -e "$(YELLOW)Downloading setup script...$(NC)"; \
		curl -sSL https://raw.githubusercontent.com/your-org/otel-automation/main/setup.sh -o $(SETUP_SCRIPT); \
		chmod +x $(SETUP_SCRIPT); \
	fi
	@$(SETUP_SCRIPT)

# Quick setup (skip repository cloning)
quick-setup:
	@echo -e "$(GREEN)Running quick setup...$(NC)"
	@$(SETUP_SCRIPT) --skip-clone

# Development mode setup
dev:
	@echo -e "$(GREEN)Setting up development environment...$(NC)"
	@$(SETUP_SCRIPT) --dev-mode

# Start services
start:
	@echo -e "$(GREEN)Starting OTEL services...$(NC)"
	@cd $(EXAMPLE_DIR) && $(COMPOSE_CMD) up -d
	@echo -e "$(GREEN)Services started!$(NC)"
	@echo "Waiting for services to be ready..."
	@sleep 5
	@$(MAKE) status

# Stop services
stop:
	@echo -e "$(YELLOW)Stopping OTEL services...$(NC)"
	@cd $(EXAMPLE_DIR) && $(COMPOSE_CMD) down
	@echo -e "$(GREEN)Services stopped$(NC)"

# Restart services
restart:
	@echo -e "$(YELLOW)Restarting services...$(NC)"
	@cd $(EXAMPLE_DIR) && $(COMPOSE_CMD) restart
	@echo -e "$(GREEN)Services restarted$(NC)"

# Check status
status:
	@echo -e "$(BLUE)Service Status:$(NC)"
	@echo ""
	@cd $(EXAMPLE_DIR) && $(COMPOSE_CMD) ps
	@echo ""
	@echo -e "$(BLUE)Health Checks:$(NC)"
	@if curl -s -f http://localhost:9090/-/healthy > /dev/null 2>&1; then \
		echo -e "  Prometheus:     $(GREEN)✓ Healthy$(NC)"; \
	else \
		echo -e "  Prometheus:     $(RED)✗ Not responding$(NC)"; \
	fi
	@if curl -s -f http://localhost:3000/api/health > /dev/null 2>&1; then \
		echo -e "  Grafana:        $(GREEN)✓ Healthy$(NC)"; \
	else \
		echo -e "  Grafana:        $(RED)✗ Not responding$(NC)"; \
	fi
	@if curl -s http://localhost:8889/metrics > /dev/null 2>&1; then \
		echo -e "  OTEL Metrics:   $(GREEN)✓ Available$(NC)"; \
		echo ""; \
		echo -e "$(BLUE)Metrics Summary:$(NC)"; \
		@curl -s http://localhost:8889/metrics | grep -c "googlecloudspanner" | xargs echo "  Cloud Spanner metrics:" || echo "  Cloud Spanner metrics: 0"; \
	else \
		echo -e "  OTEL Metrics:   $(RED)✗ Not available$(NC)"; \
	fi

# View logs
logs:
	@cd $(EXAMPLE_DIR) && $(COMPOSE_CMD) logs -f

logs-collector:
	@cd $(EXAMPLE_DIR) && $(COMPOSE_CMD) logs -f collector

logs-prometheus:
	@cd $(EXAMPLE_DIR) && $(COMPOSE_CMD) logs -f prometheus

logs-grafana:
	@cd $(EXAMPLE_DIR) && $(COMPOSE_CMD) logs -f grafana

# Build OTEL from source
build:
	@echo -e "$(GREEN)Building OTEL collector from source...$(NC)"
	@if [[ ! -d "$(OTEL_DIR)" ]]; then \
		echo -e "$(RED)OTEL contrib directory not found!$(NC)"; \
		echo "Run 'make dev' first to set up development environment"; \
		exit 1; \
	fi
	@cd $(OTEL_DIR) && make docker-otelcontribcol
	@docker tag otelcontribcol:latest otel/opentelemetry-collector-contrib:local
	@echo -e "$(GREEN)Build complete!$(NC)"

# Update running collector
update: build
	@echo -e "$(GREEN)Updating OTEL collector...$(NC)"
	@cd $(EXAMPLE_DIR) && $(COMPOSE_CMD) up -d collector
	@echo -e "$(GREEN)Collector updated!$(NC)"
	@sleep 3
	@$(MAKE) logs-collector

# Generate test traffic
traffic:
	@echo -e "$(GREEN)Generating test traffic...$(NC)"
	@if [[ -f "$(EXAMPLE_DIR)/generate-traffic.sh" ]]; then \
		$(EXAMPLE_DIR)/generate-traffic.sh \
			"$(SPANNER_PROJECT_ID)" \
			"$(SPANNER_INSTANCE_ID)" \
			"$(SPANNER_DATABASE_ID)"; \
	else \
		echo -e "$(RED)Traffic generator not found. Run 'make setup' first.$(NC)"; \
	fi

# Run tests
test:
	@echo -e "$(GREEN)Running integration tests...$(NC)"
	@echo ""
	@echo "1. Checking service health..."
	@$(MAKE) -s status
	@echo ""
	@echo "2. Validating Prometheus targets..."
	@if curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job=="otel") | .health' | grep -q "up"; then \
		echo -e "$(GREEN)✓ Prometheus is scraping OTEL metrics$(NC)"; \
	else \
		echo -e "$(RED)✗ Prometheus not scraping OTEL metrics$(NC)"; \
	fi
	@echo ""
	@echo "3. Checking for Cloud Spanner metrics..."
	@if curl -s http://localhost:8889/metrics | grep -q "googlecloudspanner"; then \
		echo -e "$(GREEN)✓ Cloud Spanner metrics present$(NC)"; \
	else \
		echo -e "$(YELLOW)⚠ No Cloud Spanner metrics yet (may need traffic)$(NC)"; \
	fi

# Validate metrics in detail
validate:
	@echo -e "$(BLUE)Cloud Spanner Metrics Validation:$(NC)"
	@echo ""
	@echo "Available metric types:"
	@curl -s http://localhost:8889/metrics | grep "^googlecloudspanner" | cut -d'{' -f1 | sort | uniq | head -20 || echo "No metrics found"
	@echo ""
	@echo "Sample metrics with labels:"
	@curl -s http://localhost:8889/metrics | grep "^googlecloudspanner" | head -5 || echo "No metrics found"

# Open Grafana
dash:
	@echo -e "$(GREEN)Opening Grafana...$(NC)"
	@echo "URL: http://localhost:3000"
	@echo "Login: admin / admin"
	@if command -v open &> /dev/null; then \
		open http://localhost:3000; \
	elif command -v xdg-open &> /dev/null; then \
		xdg-open http://localhost:3000; \
	else \
		echo -e "$(YELLOW)Please open http://localhost:3000 in your browser$(NC)"; \
	fi

# Open Prometheus
prom:
	@echo -e "$(GREEN)Opening Prometheus...$(NC)"
	@if command -v open &> /dev/null; then \
		open http://localhost:9090; \
	elif command -v xdg-open &> /dev/null; then \
		xdg-open http://localhost:9090; \
	else \
		echo -e "$(YELLOW)Please open http://localhost:9090 in your browser$(NC)"; \
	fi

# Show metrics
metrics:
	@echo -e "$(BLUE)OTEL Collector Metrics:$(NC)"
	@curl -s http://localhost:8889/metrics | grep googlecloudspanner || echo "No Cloud Spanner metrics found"

# Clean up everything
clean:
	@echo -e "$(RED)Cleaning up OTEL setup...$(NC)"
	@read -p "This will remove all containers and volumes. Continue? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd $(EXAMPLE_DIR) 2>/dev/null && $(COMPOSE_CMD) down -v || true; \
		if [[ -f "$(EXAMPLE_DIR)/traffic-generator.pid" ]]; then \
			kill $$(cat "$(EXAMPLE_DIR)/traffic-generator.pid") 2>/dev/null || true; \
			rm -f "$(EXAMPLE_DIR)/traffic-generator.pid"; \
		fi; \
		echo -e "$(GREEN)Cleanup complete$(NC)"; \
	else \
		echo "Cleanup cancelled"; \
	fi

# Troubleshooting
troubleshoot:
	@echo -e "$(BLUE)Running diagnostic checks...$(NC)"
	@echo ""
	@echo "1. Container Runtime:"
	@$(COMPOSE_CMD) version || echo "Compose command not working!"
	@echo ""
	@echo "2. Port Availability:"
	@for port in 9090 3000 8888 8889; do \
		if lsof -i :$port &> /dev/null; then \
			echo -e "   Port $port: $(RED)In use$(NC)"; \
		else \
			echo -e "   Port $port: $(GREEN)Available$(NC)"; \
		fi; \
	done
	@echo ""
	@echo "3. Directory Structure:"
	@if [[ -d "$(EXAMPLE_DIR)" ]]; then \
		echo -e "   Example repo: $(GREEN)Found$(NC)"; \
	else \
		echo -e "   Example repo: $(RED)Not found$(NC) - Run 'make setup'"; \
	fi
	@if [[ -d "$(OTEL_DIR)" ]]; then \
		echo -e "   OTEL repo:    $(GREEN)Found$(NC) (dev mode)"; \
	else \
		echo -e "   OTEL repo:    $(YELLOW)Not found$(NC) (using pre-built images)"; \
	fi
	@echo ""
	@echo "4. Configuration Files:"
	@if [[ -f "$(EXAMPLE_DIR)/collector/config.yml" ]]; then \
		echo -e "   Collector config: $(GREEN)Found$(NC)"; \
		grep -q "project_id:" "$(EXAMPLE_DIR)/collector/config.yml" && \
			echo -e "   Project configured: $(GREEN)Yes$(NC)" || \
			echo -e "   Project configured: $(RED)No$(NC)"; \
	else \
		echo -e "   Collector config: $(RED)Not found$(NC)"; \
	fi
	@echo ""
	@echo "5. Recent Collector Logs:"
	@cd $(EXAMPLE_DIR) 2>/dev/null && $(COMPOSE_CMD) logs --tail=10 collector 2>&1 | sed 's/^/   /' || echo "   No logs available"

# Quick health check for scripts
health:
	@curl -s -f http://localhost:8889/metrics > /dev/null 2>&1 && echo "UP" || echo "DOWN"

# Development workflow example
dev-workflow:
	@echo -e "$(BLUE)Development Workflow Example:$(NC)"
	@echo ""
	@echo "1. Set up development environment:"
	@echo "   $$ make dev"
	@echo ""
	@echo "2. Make changes to OTEL receiver code in:"
	@echo "   $(OTEL_DIR)/receiver/googlecloudspannerreceiver/"
	@echo ""
	@echo "3. Build and update:"
	@echo "   $$ make update"
	@echo ""
	@echo "4. Generate test traffic:"
	@echo "   $$ make traffic"
	@echo ""
	@echo "5. Check metrics:"
	@echo "   $$ make metrics"
	@echo "   $$ make dash"
	@echo ""

.SILENT: health