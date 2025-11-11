# RabbitMQ Kubernetes Deployment

A comprehensive, production-ready RabbitMQ deployment for Kubernetes homelab environments with high availability, monitoring, backup, and security features.

## 🚀 Quick Start

```bash
# Clone or navigate to the rabbitmq directory
cd /home/k8s1/k8s/rabbitmq

# Install RabbitMQ cluster
./install-rabbitmq.sh install

# Test the installation
./test-rabbitmq.sh all

# Access management UI
kubectl port-forward -n rabbitmq svc/rabbitmq 15672:15672
# Open browser: http://localhost:15672
# Default credentials: admin / rabbitmq123
```

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Monitoring & Alerting](#monitoring--alerting)
- [Backup & Recovery](#backup--recovery)
- [High Availability](#high-availability)
- [Performance Tuning](#performance-tuning)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)
- [Environment-Specific Deployments](#environment-specific-deployments)

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │  RabbitMQ   │  │  RabbitMQ   │  │  RabbitMQ   │            │
│  │  Node 0     │  │  Node 1     │  │  Node 2     │            │
│  │             │  │             │  │             │            │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │            │
│  │ │  Mnesia │ │  │ │  Mnesia │ │  │ │  Mnesia │ │            │
│  │ │  Queue  │ │  │ │  Queue  │ │  │ │  Queue  │ │            │
│  │ │  Data   │ │  │ │  Data   │ │  │ │  Data   │ │            │
│  │ └────┬────┘ │  │ └────┬────┘ │  │ └────┬────┘ │            │
│  │      │      │  │      │      │  │      │      │            │
│  │ ┌────┴────┐ │  │ ┌────┴────┐ │  │ ┌────┴────┐ │            │
│  │ │  Disk   │ │  │ │  Disk   │ │  │ │  Disk   │ │            │
│ │ │Storage  │ │  │ │Storage  │ │  │ │Storage  │ │            │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │            │
│  └─────┬───────┘  └─────┬───────┘  └─────┬───────┘            │
│        │                │                │                    │
│        └────────────────┴────────────────┘                    │
│                         │                                      │
│        ┌────────────────┴────────────────┐                    │
│        │        Cluster Formation          │                    │
│        │     (pause_minority policy)     │                    │
│        └────────────────┬────────────────┘                    │
│                         │                                      │
│  ┌─────────────┐  ┌─────┴─────┐  ┌─────────────┐            │
│  │   Ingress   │  │  Service  │  │   Service   │            │
│  │  (Management│  │  (AMQP)   │  │  (Prometheus)│            │
│  │   UI)       │  │  5672/1   │  │   15692/1   │            │
│  │  443/80     │  │           │  │             │            │
│  └─────────────┘  └───────────┘  └─────────────┘            │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐         │
│  │              Monitoring & Alerting                  │         │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────┐│         │
│  │  │ Prometheus   │  │ Grafana      │  │ Alert-   ││         │
│  │  │ Service      │  │ Dashboards   │  │ manager  ││         │
│  │  │ Monitor      │  │              │  │          ││         │
│  │  └──────────────┘  └──────────────┘  └──────────┘│         │
│  └─────────────────────────────────────────────────────┘         │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐         │
│  │              Backup & Recovery                      │         │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────┐│         │
│  │  │ CronJob      │  │ PVC Storage  │  │ Scripts  ││         │
│  │  │ Backup       │  │              │  │          ││         │
│  │  │ Automation   │  │              │  │          ││         │
│  │  └──────────────┘  └──────────────┘  └──────────┘│         │
│  └─────────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────┘
```

## ✨ Features

### Core Features
- **High Availability**: 3-node cluster with automatic failover
- **Persistent Storage**: Persistent volumes with data retention
- **TLS/SSL**: Secure communication with certificate management
- **Monitoring**: Prometheus metrics and Grafana dashboards
- **Alerting**: Comprehensive alert rules for critical conditions
- **Backup & Recovery**: Automated backup with restore capabilities
- **Security**: Network policies, RBAC, and authentication
- **Performance Tuning**: Multiple performance profiles
- **Scalability**: Horizontal and vertical pod autoscaling

### Advanced Features
- **Federation**: Cross-cluster message routing
- **Shovel**: Reliable message transfer between brokers
- **Disaster Recovery**: Multi-site replication support
- **Custom Resource Definitions**: Declarative cluster management
- **Environment-Specific Configs**: Dev, staging, production profiles
- **Network Policies**: Fine-grained network security
- **Pod Disruption Budgets**: High availability during maintenance

## 📋 Prerequisites

### Required Software
- **Kubernetes**: 1.20+ (tested with 1.25+)
- **kubectl**: Latest version
- **Helm**: 3.0+ (optional, for advanced deployments)

### Required Kubernetes Components
- **cert-manager**: For TLS certificate management
- **ingress-nginx**: For external access
- **Prometheus Operator**: For monitoring and alerting
- **Storage Class**: For persistent volumes

### System Requirements
- **CPU**: 2+ cores per RabbitMQ node
- **Memory**: 4GB+ per RabbitMQ node
- **Storage**: 10GB+ per node (SSD recommended)
- **Network**: Low-latency network between nodes

### Pre-installation Check
```bash
# Run prerequisite check
./install-rabbitmq.sh check-prerequisites
```

## 🚀 Installation

### Quick Installation
```bash
# Install everything with default settings
./install-rabbitmq.sh install

# Install with custom namespace
./install-rabbitmq.sh install -n my-rabbitmq

# Install with specific storage class
./install-rabbitmq.sh install -s fast-ssd
```

### Step-by-Step Installation

#### 1. Create Namespace and RBAC
```bash
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-rbac.yaml
```

#### 2. Configure Secrets and TLS
```bash
# Create basic auth secret
kubectl apply -f 32-basic-auth-secret.yaml

# Create TLS certificates (requires cert-manager)
kubectl apply -f 20-tls-certificate.yaml
```

#### 3. Deploy Configuration
```bash
# Apply main configuration
kubectl apply -f 10-configmap.yaml
kubectl apply -f 11-plugins-configmap.yaml
kubectl apply -f 53-performance-tuning.yaml
kubectl apply -f 56-environment-config.yaml
```

#### 4. Deploy RabbitMQ Cluster
```bash
# Apply StatefulSet and services
kubectl apply -f 30-statefulset.yaml
kubectl apply -f 31-services.yaml
```

#### 5. Configure External Access
```bash
# TCP services for NodePort
kubectl apply -f 33-tcp-services-configmap.yaml

# Ingress for management UI
kubectl apply -f 34-ingress.yaml
```

#### 6. Set Up Monitoring
```bash
# Prometheus monitoring
kubectl apply -f 60-monitoring.yaml
kubectl apply -f 61-prometheus-rules.yaml
```

#### 7. Configure High Availability
```bash
# Network policies
kubectl apply -f 40-network-policy.yaml

# Pod disruption budgets
kubectl apply -f 41-pod-disruption-budget.yaml

# Autoscaling
kubectl apply -f 42-horizontal-pod-autoscaler.yaml
kubectl apply -f 43-vertical-pod-autoscaler.yaml
```

#### 8. Set Up Backup
```bash
# Backup automation
kubectl apply -f 55-backup-automation.yaml

# Persistent volumes (if using local storage)
kubectl apply -f 54-persistent-volumes.yaml
```

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RABBITMQ_DEFAULT_USER` | `admin` | Default admin username |
| `RABBITMQ_DEFAULT_PASS` | `rabbitmq123` | Default admin password |
| `RABBITMQ_ERLANG_COOKIE` | Generated | Cluster formation cookie |
| `RABBITMQ_VM_MEMORY_HIGH_WATERMARK` | `0.6` | Memory threshold |
| `RABBITMQ_DISK_FREE_LIMIT` | `1GB` | Disk space threshold |

### Configuration Files

#### Main Configuration (`10-configmap.yaml`)
```yaml
# Core RabbitMQ settings
cluster_formation.peer_discovery_backend = rabbit_peer_discovery_k8s
cluster_formation.k8s.host = kubernetes.default.svc.cluster.local
cluster_formation.k8s.address_type = hostname
```

#### Performance Tuning (`53-performance-tuning.yaml`)
- **High Throughput**: Optimized for message throughput
- **Low Latency**: Optimized for minimal latency
- **Balanced**: Default balanced configuration

#### Environment-Specific (`56-environment-config.yaml`)
- **Development**: Single node, minimal resources
- **Staging**: 2 nodes, moderate resources
- **Production**: 3+ nodes, high resources

### Custom Configuration

#### Adding Custom Plugins
```bash
# Edit plugins configuration
kubectl edit configmap rabbitmq-plugins -n rabbitmq

# Restart cluster
kubectl rollout restart statefulset/rabbitmq -n rabbitmq
```

#### Performance Profiles
```bash
# Apply high-throughput profile
kubectl patch configmap rabbitmq-config -n rabbitmq \
  --patch-file configs/high-throughput.yaml

# Apply low-latency profile
kubectl patch configmap rabbitmq-config -n rabbitmq \
  --patch-file configs/low-latency.yaml
```

## 📊 Monitoring & Alerting

### Prometheus Metrics

#### Key Metrics
- `rabbitmq_queue_messages`: Queue message count
- `rabbitmq_queue_memory`: Queue memory usage
- `rabbitmq_connections`: Active connections
- `rabbitmq_channels`: Open channels
- `rabbitmq_consumers`: Active consumers
- `rabbitmq_cluster_nodes`: Cluster node status

#### Metric Endpoints
- **HTTP**: `http://rabbitmq:15692/metrics`
- **HTTPS**: `https://rabbitmq:15691/metrics`

### Alert Rules

#### Critical Alerts
- **RabbitMQDown**: Cluster is unreachable
- **ClusterPartition**: Network partition detected
- **LowDiskSpace**: Disk space below threshold
- **NodeNotRunning**: Node is not running

#### Warning Alerts
- **HighMemoryUsage**: Memory usage above 80%
- **HighConnections**: Connection count above threshold
- **QueueBacklog**: Queue messages above threshold
- **ConsumerUtilization**: Low consumer utilization

### Grafana Dashboards

#### Import Dashboards
```bash
# Download official RabbitMQ dashboard
wget https://grafana.com/api/dashboards/11334/revisions/1/download -O rabbitmq-dashboard.json

# Import via Grafana UI or API
```

#### Custom Dashboards
- **Cluster Overview**: Node health, queues, connections
- **Performance Metrics**: Throughput, latency, resource usage
- **Alert Summary**: Active alerts and notifications

## 💾 Backup & Recovery

### Automated Backups

#### Configuration
```bash
# Edit backup schedule
kubectl edit cronjob rabbitmq-backup-cronjob -n rabbitmq

# Default schedule: Daily at 2 AM
# Retention: 7 days (configurable)
```

#### Backup Contents
- **Definitions**: Users, vhosts, exchanges, queues, bindings
- **Policies**: Queue policies and parameters
- **Metadata**: Cluster information and status
- **Configuration**: RabbitMQ configuration files

### Manual Backup
```bash
# Trigger manual backup
kubectl create job --from=cronjob/rabbitmq-backup-cronjob rabbitmq-backup-manual -n rabbitmq

# Check backup status
kubectl logs -n rabbitmq -l job-name=rabbitmq-backup-manual
```

### Recovery Process

#### Full Recovery
```bash
# Use backup script
./backup-rabbitmq.sh restore <backup-file>

# Manual restore via API
curl -u admin:rabbitmq123 -X POST \
  http://rabbitmq:15672/api/definitions \
  -H "Content-Type: application/json" \
  -d @definitions.json
```

#### Selective Recovery
```bash
# Restore only users
curl -u admin:rabbitmq123 -X POST \
  http://rabbitmq:15672/api/users \
  -H "Content-Type: application/json" \
  -d @users.json

# Restore only queues
curl -u admin:rabbitmq123 -X POST \
  http://rabbitmq:15672/api/queues \
  -H "Content-Type: application/json" \
  -d @queues.json
```

## 🔄 High Availability

### Cluster Formation
- **Discovery**: Kubernetes-based peer discovery
- **Quorum**: Majority-based consensus (pause_minority)
- **Recovery**: Automatic node recovery and rejoining

### Pod Disruption Budgets
```yaml
# Ensures minimum availability during updates
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: rabbitmq-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: rabbitmq
```

### Network Policies
- **Ingress Control**: Restricted access to specific ports
- **Egress Control**: Limited outbound connectivity
- **Namespace Isolation**: Cross-namespace communication rules

### Auto-scaling

#### Horizontal Pod Autoscaler
```yaml
# Scales based on CPU, memory, and queue metrics
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: rabbitmq-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: rabbitmq
  minReplicas: 3
  maxReplicas: 7
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

#### Vertical Pod Autoscaler
```yaml
# Automatically adjusts resource requests/limits
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: rabbitmq-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: rabbitmq
  updatePolicy:
    updateMode: "Auto"
```

## 🚀 Performance Tuning

### Performance Profiles

#### High Throughput Profile
```bash
# Apply high-throughput configuration
kubectl apply -f configs/high-throughput.yaml

# Key settings:
# - Increased TCP buffers
# - Optimized message store
# - Higher memory thresholds
# - Parallel connection handling
```

#### Low Latency Profile
```bash
# Apply low-latency configuration
kubectl apply -f configs/low-latency.yaml

# Key settings:
# - Reduced TCP buffers
# - Faster heartbeats
# - Lower memory thresholds
# - Disabled background GC
```

#### Balanced Profile (Default)
```bash
# Apply balanced configuration (recommended)
kubectl apply -f configs/balanced.yaml

# Key settings:
# - Moderate TCP buffers
# - Standard heartbeats
# - Balanced memory management
# - Enabled background GC
```

### Queue Optimization

#### Queue Types
- **Classic Queues**: Standard queues with persistence
- **Quorum Queues**: Replicated queues for HA
- **Stream Queues**: High-throughput append-only logs

#### Best Practices
```bash
# Use quorum queues for HA
rabbitmqctl set_policy ha-queues "^ha\." '{"queue-type":"quorum"}' --priority 1

# Set appropriate queue masters
rabbitmqctl set_policy queue-masters ".*" '{"queue-master-locator":"min-masters"}' --priority 1
```

### Connection Management

#### Connection Pooling
- **Limit Connections**: Set appropriate connection limits
- **Use Connection Pooling**: Implement client-side pooling
- **Monitor Connections**: Track connection metrics

#### Client Configuration
```python
# Python client example
import pika

connection_params = pika.ConnectionParameters(
    host='rabbitmq.rabbitmq.svc.cluster.local',
    port=5672,
    credentials=pika.PlainCredentials('admin', 'rabbitmq123'),
    heartbeat=60,
    blocked_connection_timeout=300,
    connection_attempts=3,
    retry_delay=2
)
```

## 🔒 Security

### Authentication & Authorization

#### Default Security
- **Username**: `admin` (configurable)
- **Password**: Generated secret (change immediately)
- **TLS/SSL**: Enabled with cert-manager

#### Custom Users
```bash
# Create new user
rabbitmqctl add_user myuser mypassword

# Set permissions
rabbitmqctl set_permissions -p / myuser ".*" ".*" ".*"

# Set user tags
rabbitmqctl set_user_tags myuser monitoring
```

#### LDAP Integration
```yaml
# Configure LDAP authentication
ldap.servers.1 = ldap.example.com
ldap.dn_lookup_bind.user_dn = cn=admin,dc=example,dc=com
ldap.dn_lookup_bind.password = password
ldap.user_dn_pattern = cn=${username},ou=users,dc=example,dc=com
```

### Network Security

#### Network Policies
```yaml
# Restrict access to RabbitMQ ports
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: rabbitmq-network-policy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: rabbitmq
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 15692  # Prometheus metrics
```

#### TLS Configuration
```bash
# Enable TLS for AMQP
rabbitmqctl enable_plugin rabbitmq_auth_mechanism_ssl

# Configure TLS listeners
listeners.ssl.default = 5671
ssl_options.cacertfile = /etc/rabbitmq/ca_certificate.pem
ssl_options.certfile = /etc/rabbitmq/server_certificate.pem
ssl_options.keyfile = /etc/rabbitmq/server_key.pem
```

### Secret Management

#### Kubernetes Secrets
```bash
# Create secret for basic auth
kubectl create secret generic rabbitmq-basic-auth \
  --from-literal=username=admin \
  --from-literal=password=securepassword \
  -n rabbitmq

# Create TLS secret
kubectl create secret tls rabbitmq-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n rabbitmq
```

#### External Secret Management
- **HashiCorp Vault**: Integration with Vault
- **AWS Secrets Manager**: Cloud secret management
- **Azure Key Vault**: Microsoft cloud secrets

## 🔧 Troubleshooting

### Common Issues

#### Pod Startup Issues
```bash
# Check pod logs
kubectl logs -n rabbitmq rabbitmq-0

# Check pod events
kubectl describe pod -n rabbitmq rabbitmq-0

# Check PVC status
kubectl get pvc -n rabbitmq
```

#### Cluster Formation Issues
```bash
# Check cluster status
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl cluster_status

# Check node communication
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl ping

# Reset node if needed
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl reset
```

#### Performance Issues
```bash
# Check memory usage
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl status

# Check queue status
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl list_queues name messages memory

# Check connections
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl list_connections
```

### Diagnostic Tools

#### Built-in Diagnostics
```bash
# Run comprehensive diagnostics
./troubleshoot-rabbitmq.sh all

# Check specific areas
./troubleshoot-rabbitmq.sh cluster
./troubleshoot-rabbitmq.sh network
./troubleshoot-rabbitmq.sh storage
./troubleshoot-rabbitmq.sh performance
```

#### Manual Diagnostics
```bash
# Check node health
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmq-diagnostics node_health_check

# Check alarms
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmq-diagnostics alarms

# Check environment
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmq-diagnostics environment
```

### Log Analysis

#### Log Locations
```bash
# Container logs
kubectl logs -n rabbitmq rabbitmq-0

# RabbitMQ logs inside container
kubectl exec -n rabbitmq rabbitmq-0 -- tail -f /var/log/rabbitmq/rabbit@*.log

# SASL logs
kubectl exec -n rabbitmq rabbitmq-0 -- tail -f /var/log/rabbitmq/rabbit@*-sasl.log
```

#### Log Configuration
```yaml
# Configure log levels
log.console.level = warning
log.file.level = warning
log.exchange.level = warning
```

## 🛠️ Maintenance

### Upgrades

#### Rolling Upgrades
```bash
# Upgrade with zero downtime
kubectl patch statefulset rabbitmq -n rabbitmq \
  --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "rabbitmq:3.13-management"}]'

# Monitor upgrade progress
kubectl rollout status statefulset/rabbitmq -n rabbitmq
```

#### Version Compatibility
- **Major Versions**: Test in staging first
- **Minor Versions**: Generally safe for rolling upgrades
- **Plugins**: Ensure plugin compatibility

### Capacity Planning

#### Resource Monitoring
```bash
# Monitor resource usage
kubectl top pods -n rabbitmq

# Check PVC usage
kubectl get pvc -n rabbitmq

# Monitor queue growth
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl list_queues name messages message_bytes
```

#### Scaling Guidelines
- **CPU**: Scale based on connection count and message rate
- **Memory**: Scale based on queue size and message retention
- **Storage**: Plan for message persistence and retention policies

### Cleanup

#### Remove RabbitMQ
```bash
# Complete cleanup
./install-rabbitmq.sh cleanup

# Remove specific components
kubectl delete -f 30-statefulset.yaml
kubectl delete -f 31-services.yaml
kubectl delete namespace rabbitmq
```

## 🌍 Environment-Specific Deployments

### Development Environment
```bash
# Deploy development configuration
kubectl apply -f configs/dev-cluster.yaml

# Features:
# - Single node
# - Minimal resources
# - Debug logging enabled
# - Basic monitoring
```

### Staging Environment
```bash
# Deploy staging configuration
kubectl apply -f configs/staging-cluster.yaml

# Features:
# - 2-node cluster
# - Moderate resources
# - Full monitoring
# - Backup enabled
```

### Production Environment
```bash
# Deploy production configuration
kubectl apply -f configs/prod-cluster.yaml

# Features:
# - 3+ node cluster
# - High resources
# - Full HA configuration
# - Advanced monitoring
# - Automated backup
# - Network policies
```

### Custom Environment
```bash
# Create custom configuration
cp configs/prod-cluster.yaml configs/custom-cluster.yaml

# Edit as needed
vim configs/custom-cluster.yaml

# Deploy custom configuration
kubectl apply -f configs/custom-cluster.yaml
```

## 📚 Additional Resources

### Documentation
- [RabbitMQ Official Documentation](https://www.rabbitmq.com/documentation.html)
- [Kubernetes Operator Documentation](https://www.rabbitmq.com/kubernetes/operator/operator-overview.html)
- [Prometheus Monitoring Guide](https://www.rabbitmq.com/prometheus.html)

### Community
- [RabbitMQ Community](https://github.com/rabbitmq/rabbitmq-server)
- [Kubernetes Slack #rabbitmq](https://kubernetes.slack.com/channels/rabbitmq)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/rabbitmq)

### Tools
- [rabbitmqctl](https://www.rabbitmq.com/rabbitmqctl.8.html): Command-line tool
- [rabbitmq-diagnostics](https://www.rabbitmq.com/rabbitmq-diagnostics.8.html): Diagnostics tool
- [PerfTest](https://github.com/rabbitmq/rabbitmq-perf-test): Performance testing tool

## 🤝 Contributing

### Contributing Guidelines
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Testing
```bash
# Run all tests
./test-rabbitmq.sh all

# Run specific tests
./test-rabbitmq.sh cluster
./test-rabbitmq.sh performance
./test-rabbitmq.sh ha
```

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

### Getting Help
- **Issues**: Create an issue in the repository
- **Discussions**: Use GitHub Discussions
- **Documentation**: Check the troubleshooting section

### Commercial Support
- **RabbitMQ Commercial**: https://www.rabbitmq.com/services.html
- **VMware Support**: https://tanzu.vmware.com/rabbitmq

---

**Note**: This deployment is designed for Kubernetes homelab environments. For production use, ensure you review and customize all security settings, resource limits, and monitoring configurations according to your specific requirements.