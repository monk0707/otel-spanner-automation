# Detailed Setup Guide

## Prerequisites
- Podman or Docker installed
- Git and curl
- GCP Project with Cloud Spanner instance

## Installation Methods

### Method 1: One-Line Install
```bash
curl -sSL https://raw.githubusercontent.com/YOUR-ORG/otel-spanner-automation/main/quick-start.sh | \
  SPANNER_PROJECT_ID="your-project" \
  SPANNER_INSTANCE_ID="your-instance" \
  SPANNER_DATABASE_ID="your-database" \
  bash
