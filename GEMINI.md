# Gemini Project Context: Kubernetes Homelab on MicroK8s

## Project Overview

This repository contains a comprehensive set of Kubernetes manifests and scripts for bootstrapping and managing a feature-rich homelab environment running on MicroK8s. It follows Infrastructure-as-Code (IaC) principles to provide a reproducible setup for development, monitoring, and core infrastructure services.

The project is structured into modular components, each responsible for a specific piece of functionality. The primary technologies used are Kubernetes (via MicroK8s), YAML for declarative configurations, and shell scripts for automation.

### Key Components:

*   **Core Infrastructure:**
    *   **`microk8s-setup`**: Scripts to install and configure the base MicroK8s cluster.
    *   **`certs`**: Manages TLS infrastructure using `cert-manager` to provide a local Certificate Authority (`local-ca`) for issuing self-signed certificates across the cluster.
    *   **`dashboard`**: Deploys the official Kubernetes Dashboard for web-based cluster management.
    *   **`minio`**: Sets up a Minio object storage service, accessible via S3-compatible APIs.

*   **Development & Operations:**
    *   **`argocd`**: Implements a GitOps workflow using ArgoCD for continuous delivery of applications defined in this repository.
    *   **`coder`**: Deploys Coder to provide secure, remote development workspaces for developers.

*   **Monitoring Stack (`monitoring`):**
    *   **Prometheus**: For metrics collection and alerting.
    *   **Grafana**: For visualizing metrics and logs in rich dashboards.
    *   **Loki**: For log aggregation.
    *   **Mimir**: For long-term metrics storage.
    *   **Tempo**: For distributed tracing.
    *   **Pyroscope**: For continuous profiling.

*   **In-Memory Data Store (`redis` & `redis-helm`):**
    *   Provides two alternative methods for deploying a Redis master-replica cluster:
        1.  **`redis`**: A manual, highly-customized setup using StatefulSets, custom scripts for replication, and an HAProxy sidecar for secure external access.
        2.  **`redis-helm`**: A simpler setup using the official Bitnami Redis Helm chart, pre-configured to match the architecture of the manual setup.

## Building and Running

This project is not "built" in a traditional sense. Instead, its components are "applied" to a running Kubernetes cluster.

### Prerequisites:

1.  A running MicroK8s cluster.
2.  The `kubectl` CLI configured to point to the cluster.
3.  Essential MicroK8s addons enabled, such as `dns`, `ingress`, `cert-manager`, and `storage`.

### General Workflow:

1.  **Cluster Setup**: Use the scripts in `microk8s-setup/` to prepare the base cluster.
2.  **Apply Manifests**: Navigate into a component directory (e.g., `monitoring/`) and apply the YAML files using `kubectl apply -f <filename>.yaml`. The `README.md` in each directory specifies the correct order and any prerequisite steps.
3.  **Use Scripts**: Many components include helper scripts (e.g., `install-redis.sh`, `90-status.sh`) to automate installation, check status, or perform cleanup. These should be made executable (`chmod +x *.sh`) before use.

**Example: Deploying the Monitoring Stack**

```bash
# 1. Create the namespace
kubectl apply -f monitoring/00-namespace.yaml

# 2. Create secrets and configurations
kubectl apply -f monitoring/01-grafana-admin-secret.yaml
kubectl apply -f monitoring/02-grafana-config-datasource.yaml

# 3. Deploy Prometheus, Grafana, and other components in order
kubectl apply -f monitoring/10-prometheus-rbac.yaml
kubectl apply -f monitoring/12-prometheus-statefulset.yaml
# ... and so on for all files in the directory.
```

## Development Conventions

*   **Modularity**: Each distinct service or application is contained within its own top-level directory.
*   **Number Prefixing**: YAML files within component directories are prefixed with numbers (e.g., `00-`, `10-`, `20-`) to indicate the recommended application order.
*   **Documentation**: Each module has a detailed `README.md` that serves as the primary documentation for that component.
*   **Hostnames**: Services are exposed via Ingress using the local domain suffix `.home.arpa` (e.g., `grafana.home.arpa`). This requires manual entries in the client machine's `hosts` file.
*   **Automation Scripts**: Repetitive or complex tasks are encapsulated in shell scripts. These scripts often include checks, waits, and detailed logging to ensure reliability.
*   **Security**: TLS is a primary concern, with `cert-manager` being a core dependency. Secrets are generally managed via standard Kubernetes `Secret` objects, with templates or instructions for customization.
