# Kubernetes Foundation Setup

This skill sets up foundational Kubernetes infrastructure including cluster validation and base service installation.

## Purpose

Automates the setup of essential Kubernetes components and validates cluster readiness for application deployment.

## Components

### Scripts

- **check-cluster.sh**: Validates Kubernetes cluster health and readiness
- **install-base.sh**: Installs base infrastructure components

### Helm Charts

- **nginx/**: Nginx ingress controller configuration

## Prerequisites

- `kubectl` configured with cluster access
- `helm` v3+ installed
- Appropriate RBAC permissions

## Usage

1. **Check Cluster Health**:
   ```bash
   ./scripts/check-cluster.sh
   ```

2. **Install Base Infrastructure**:
   ```bash
   ./scripts/install-base.sh
   ```

## What Gets Installed

- Nginx Ingress Controller
- Base networking components
- Monitoring namespace preparation
- Common ConfigMaps and Secrets structure

## Validation

The check-cluster script validates:
- Cluster connectivity
- Node readiness
- Core DNS functionality
- Storage class availability
- RBAC configuration
