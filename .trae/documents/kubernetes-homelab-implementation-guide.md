# Kubernetes Homelab - Implementation Guide

## 🚀 Quick Start Implementation

This guide provides step-by-step instructions to implement the revised Kubernetes homelab architecture with enhanced security, monitoring, and operational capabilities.

## 1. Prerequisites and Environment Setup

### 1.1 System Requirements
```bash
# Verify MicroK8s installation
microk8s status --wait-ready

# Enable required addons
microk8s enable dns
microk8s enable ingress
microk8s enable cert-manager
microk8s enable storage
microk8s enable metrics-server

# Verify all addons are active
microk8s status
```

### 1.2 Development Tools Setup
```bash
# Install required CLI tools
sudo snap install kubectl --classic
sudo snap install helm --classic
sudo snap install yq

# Install Velero for backups
wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.0/velero-v1.12.0-linux-amd64.tar.gz
tar -xvf velero-v1.12.0-linux-amd64.tar.gz
sudo mv velero-v1.12.0-linux-amd64/velero /usr/local/bin/

# Install Sealed Secrets
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar -xvf kubeseal-0.24.0-linux-amd64.tar.gz
sudo mv kubeseal /usr/local/bin/
```

## 2. Security Foundation Implementation

### 2.1 Network Policies Setup

Create the file `security/network-policies/default-deny.yaml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

Create the file `security/network-policies/allow-dns.yaml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

Create the file `security/network-policies/allow-ingress.yaml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress
```

Apply network policies:
```bash
# Create security namespace
kubectl create namespace security

# Apply network policies to all namespaces
for ns in default monitoring minio coder redis; do
  kubectl apply -f security/network-policies/default-deny.yaml -n $ns
  kubectl apply -f security/network-policies/allow-dns.yaml -n $ns
done
```

### 2.2 Pod Security Standards

Create the file `security/pod-security/namespace-labels.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 2.3 Secret Management with Sealed Secrets

Install Sealed Secrets controller:
```bash
# Install Sealed Secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Create sealed secrets for Grafana
echo -n 'your-secure-admin-password' > grafana-admin-password.txt
kubectl create secret generic grafana-admin-secret \
  --from-file=GF_SECURITY_ADMIN_PASSWORD=grafana-admin-password.txt \
  --dry-run=client -o yaml > grafana-admin-secret.yaml

# Seal the secret
kubeseal --format yaml < grafana-admin-secret.yaml > grafana-admin-sealed.yaml
```

Create the file `security/secrets/grafana-admin-sealed.yaml`:
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: grafana-admin-secret
  namespace: monitoring
spec:
  encryptedData:
    GF_SECURITY_ADMIN_PASSWORD: AgByImtV... # Sealed secret value
  template:
    metadata:
      name: grafana-admin-secret
      namespace: monitoring
    type: Opaque
```

## 3. Infrastructure Components Implementation

### 3.1 Enhanced Certificate Management

Create the file `infrastructure/cert-manager/cluster-issuers.yaml`:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@homelab.local
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@homelab.local
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-root
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: local-root-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: local-root-ca
  secretName: local-root-ca
  issuerRef:
    name: selfsigned-root
    kind: ClusterIssuer
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: local-ca
spec:
  ca:
    secretName: local-root-ca
```

Apply certificate issuers:
```bash
kubectl apply -f infrastructure/cert-manager/cluster-issuers.yaml
```

### 3.2 Storage Class Configuration

Create the file `infrastructure/storage/storage-classes.yaml`:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path-fast
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
parameters:
  nodeSelector: "kubernetes.io/hostname"
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path-retain
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path-backup
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: false
```

## 4. Monitoring Stack Implementation

### 4.1 Prometheus with High Availability

Create the file `applications/monitoring/prometheus-ha.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
      external_labels:
        cluster: 'homelab'
        replica: 'prometheus-1'
    
    # Alertmanager configuration
    alerting:
      alertmanagers:
      - static_configs:
        - targets:
          - alertmanager:9093
    
    # Load rules once and periodically evaluate them
    rule_files:
      - "alert-rules.yml"
      - "recording-rules.yml"
    
    # Scrape configurations
    scrape_configs:
      # Kubernetes API server
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
        - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
          action: keep
          regex: default;kubernetes;https
      
      # Kubernetes nodes
      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
        - role: node
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
      
      # Kubernetes pods
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
        - role: pod
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
          target_label: __address__
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_pod_name]
          action: replace
          target_label: kubernetes_pod_name
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: prometheus
  namespace: monitoring
spec:
  serviceName: prometheus
  replicas: 2
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      securityContext:
        runAsUser: 65534
        runAsNonRoot: true
        fsGroup: 65534
      containers:
      - name: prometheus
        image: prom/prometheus:v2.45.0
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus/'
          - '--storage.tsdb.retention.time=30d'
          - '--storage.tsdb.retention.size=50GB'
          - '--web.enable-lifecycle'
          - '--web.enable-admin-api'
          - '--web.console.libraries=/etc/prometheus/console_libraries'
          - '--web.console.templates=/etc/prometheus/consoles'
          - '--storage.tsdb.wal-compression'
        ports:
        - containerPort: 9090
          name: web
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
          limits:
            cpu: 2000m
            memory: 8Gi
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: storage
          mountPath: /prometheus
        livenessProbe:
          httpGet:
            path: /-/healthy
            port: 9090
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /-/ready
            port: 9090
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: config
        configMap:
          name: prometheus-config
  volumeClaimTemplates:
  - metadata:
      name: storage
    spec:
      storageClassName: local-path-fast
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 50Gi
```

### 4.2 Grafana with Persistent Storage

Create the file `applications/monitoring/grafana-deployment.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      url: http://prometheus:9090
      isDefault: true
      jsonData:
        timeInterval: "15s"
    - name: Loki
      type: loki
      access: proxy
      url: http://loki:3100
      jsonData:
        maxLines: 1000
    - name: Mimir
      type: prometheus
      access: proxy
      url: http://mimir:9009/prometheus
      jsonData:
        timeInterval: "15s"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      securityContext:
        runAsUser: 472
        runAsGroup: 472
        fsGroup: 472
      containers:
      - name: grafana
        image: grafana/grafana:10.0.0
        ports:
        - containerPort: 3000
          name: grafana
        env:
        - name: GF_SECURITY_ADMIN_USER
          value: admin
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-admin-secret
              key: GF_SECURITY_ADMIN_PASSWORD
        - name: GF_INSTALL_PLUGINS
          value: grafana-piechart-panel,grafana-worldmap-panel
        resources:
          requests:
            cpu: 250m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 2Gi
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
        - name: grafana-datasources
          mountPath: /etc/grafana/provisioning/datasources
        livenessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 5
      volumes:
      - name: grafana-storage
        persistentVolumeClaim:
          claimName: grafana-storage
      - name: grafana-datasources
        configMap:
          name: grafana-datasources
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-storage
  namespace: monitoring
spec:
  storageClassName: local-path-retain
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

## 5. Backup and Disaster Recovery Implementation

### 5.1 Velero Backup Setup

Create the file `scripts/backup/install-velero.sh`:
```bash
#!/bin/bash
set -e

# Configuration
VELERO_NAMESPACE=velero
MINIO_BUCKET=velero-backups
MINIO_ENDPOINT=http://minio.minio.svc.cluster.local:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin

# Create MinIO bucket for backups
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: minio-setup
  namespace: minio
spec:
  containers:
  - name: mc
    image: minio/mc:latest
    command: ["/bin/sh", "-c"]
    args:
    - |
      mc alias set minio http://minio.minio.svc.cluster.local:9000 ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY}
      mc mb minio/${MINIO_BUCKET} || true
      mc policy set download minio/${MINIO_BUCKET}
    env:
    - name: MINIO_ACCESS_KEY
      value: "${MINIO_ACCESS_KEY}"
    - name: MINIO_SECRET_KEY
      value: "${MINIO_SECRET_KEY}"
  restartPolicy: Never
EOF

# Wait for MinIO setup to complete
kubectl wait --for=condition=complete job/minio-setup -n minio --timeout=60s

# Create Velero namespace
kubectl create namespace ${VELERO_NAMESPACE} || true

# Create credentials file
cat > velero-credentials <<EOF
[default]
aws_access_key_id=${MINIO_ACCESS_KEY}
aws_secret_access_key=${MINIO_SECRET_KEY}
EOF

# Install Velero
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket ${MINIO_BUCKET} \
  --secret-file ./velero-credentials \
  --use-volume-snapshots=false \
  --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=${MINIO_ENDPOINT} \
  --namespace ${VELERO_NAMESPACE}

# Create daily backup schedule
velero create schedule daily-backup \
  --schedule="0 2 * * *" \
  --include-namespaces monitoring,production \
  --ttl 720h \
  --namespace ${VELERO_NAMESPACE}

echo "Velero backup setup completed!"
```

Make the script executable:
```bash
chmod +x scripts/backup/install-velero.sh
```

### 5.2 Database Backup Implementation

Create the file `applications/monitoring/postgres-backup.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-backup-script
  namespace: monitoring
data:
  backup.sh: |
    #!/bin/bash
    set -e
    
    # Configuration
    POSTGRES_HOST=${POSTGRES_HOST:-postgres.database.svc.cluster.local}
    POSTGRES_PORT=${POSTGRES_PORT:-5432}
    POSTGRES_DB=${POSTGRES_DB:-grafana}
    POSTGRES_USER=${POSTGRES_USER:-postgres}
    BACKUP_DIR=${BACKUP_DIR:-/backup}
    RETENTION_DAYS=${RETENTION_DAYS:-7}
    
    # Create backup filename with timestamp
    BACKUP_FILE="${BACKUP_DIR}/backup-$(date +%Y%m%d_%H%M%S).sql.gz"
    
    # Create backup
    pg_dump -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER} -d ${POSTGRES_DB} | gzip > ${BACKUP_FILE}
    
    # Verify backup
    if [ -f "${BACKUP_FILE}" ]; then
      echo "Backup created successfully: ${BACKUP_FILE}"
      ls -lh ${BACKUP_FILE}
    else
      echo "Backup failed!"
      exit 1
    fi
    
    # Cleanup old backups
    find ${BACKUP_DIR} -name "backup-*.sql.gz" -mtime +${RETENTION_DAYS} -delete
    echo "Old backups cleaned up (older than ${RETENTION_DAYS} days)"
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: monitoring
spec:
  schedule: "0 3 * * *"  # Daily at 3 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: postgres-backup
            image: postgres:15-alpine
            command: ["/bin/bash", "/scripts/backup.sh"]
            env:
            - name: POSTGRES_HOST
              value: "postgres.database.svc.cluster.local"
            - name: POSTGRES_DB
              value: "grafana"
            - name: POSTGRES_USER
              value: "postgres"
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: password
            - name: BACKUP_DIR
              value: "/backup"
            - name: RETENTION_DAYS
              value: "7"
            volumeMounts:
            - name: backup-script
              mountPath: /scripts
            - name: backup-storage
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: backup-script
            configMap:
              name: postgres-backup-script
              defaultMode: 0755
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-storage
```

## 6. GitOps Implementation with ArgoCD

### 6.1 ArgoCD ApplicationSet Configuration

Create the file `applications/argocd/applicationset.yaml`:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: homelab-apps
  namespace: argocd
spec:
  generators:
  - git:
      repoURL: https://github.com/yourusername/k8s-homelab
      revision: HEAD
      directories:
      - path: applications/monitoring
      - path: applications/minio
      - path: applications/coder
      - path: applications/redis
  template:
    metadata:
      name: '{{path.basename}}'
      finalizers:
      - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      source:
        repoURL: https://github.com/yourusername/k8s-homelab
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
          allowEmpty: false
        syncOptions:
        - CreateNamespace=true
        retry:
          limit: 5
          backoff:
            duration: 5s
            factor: 2
            maxDuration: 3m
```

### 6.2 ArgoCD Project Configuration

Create the file `applications/argocd/projects.yaml`:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: homelab
  namespace: argocd
spec:
  description: Homelab Kubernetes Applications
  sourceRepos:
  - 'https://github.com/yourusername/k8s-homelab'
  - 'https://charts.helm.sh/stable'
  - 'https://prometheus-community.github.io/helm-charts'
  destinations:
  - namespace: 'monitoring'
    server: https://kubernetes.default.svc
  - namespace: 'minio'
    server: https://kubernetes.default.svc
  - namespace: 'coder'
    server: https://kubernetes.default.svc
  - namespace: 'redis'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: ''
    kind: 'Namespace'
  - group: 'rbac.authorization.k8s.io'
    kind: 'ClusterRole'
  - group: 'rbac.authorization.k8s.io'
    kind: 'ClusterRoleBinding'
  namespaceResourceWhitelist:
  - group: 'apps'
    kind: 'Deployment'
  - group: 'apps'
    kind: 'StatefulSet'
  - group: 'apps'
    kind: 'DaemonSet'
  - group: ''
    kind: 'Service'
  - group: ''
    kind: 'ConfigMap'
  - group: ''
    kind: 'Secret'
  - group: ''
    kind: 'PersistentVolumeClaim'
  - group: 'networking.k8s.io'
    kind: 'Ingress'
  - group: 'networking.k8s.io'
    kind: 'NetworkPolicy'
  - group: 'batch'
    kind: 'CronJob'
  - group: 'autoscaling'
    kind: 'HorizontalPodAutoscaler'
  roles:
  - name: admin
    policies:
    - p, proj:homelab:admin, applications, *, homelab/*, allow
    - p, proj:homelab:admin, repositories, *, *, allow
    groups:
    - homelab-admins
```

## 7. Validation and Testing

### 7.1 Deployment Validation Script

Create the file `scripts/tests/validate-deployment.sh`:
```bash
#!/bin/bash
set -e

echo "🔍 Starting deployment validation..."

# Check cluster health
echo "📊 Checking cluster health..."
kubectl get nodes
kubectl get componentstatuses

# Validate namespaces
echo "🏠 Validating namespaces..."
for ns in monitoring minio coder redis security; do
  if kubectl get namespace $ns > /dev/null 2>&1; then
    echo "✅ Namespace $ns exists"
  else
    echo "❌ Namespace $ns missing"
    exit 1
  fi
done

# Check certificate issuers
echo "🔐 Checking certificate issuers..."
kubectl get clusterissuers -o wide

# Validate network policies
echo "🌐 Validating network policies..."
for ns in monitoring minio coder redis; do
  if kubectl get networkpolicies -n $ns | grep -q default-deny; then
    echo "✅ Network policies active in $ns"
  else
    echo "⚠️  Network policies missing in $ns"
  fi
done

# Check monitoring stack
echo "📈 Checking monitoring stack..."
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# Validate storage
echo "💾 Validating storage..."
kubectl get storageclass
kubectl get pvc -A

# Check ingress
echo "🚪 Checking ingress..."
kubectl get ingress -A

# Validate certificates
echo "📜 Validating certificates..."
kubectl get certificates -A

# Test DNS resolution
echo "🔍 Testing DNS resolution..."
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Check resource quotas
echo "📋 Checking resource quotas..."
kubectl describe resourcequotas -A

# Validate backups
echo "💿 Validating backup configuration..."
if kubectl get schedules -n velero | grep -q daily-backup; then
  echo "✅ Backup schedule configured"
else
  echo "⚠️  Backup schedule missing"
fi

echo "✅ Deployment validation completed!"
```

Make the script executable:
```bash
chmod +x scripts/tests/validate-deployment.sh
```

### 7.2 Performance Testing

Create the file `scripts/tests/performance-test.sh`:
```bash
#!/bin/bash
set -e

echo "🚀 Starting performance tests..."

# Install hey (HTTP load generator)
if ! command -v hey &> /dev/null; then
  wget https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64
  chmod +x hey_linux_amd64
  sudo mv hey_linux_amd64 /usr/local/bin/hey
fi

# Test Grafana performance
echo "📊 Testing Grafana performance..."
GRAFANA_URL="https://dashboard.home.arpa"
hey -n 100 -c 10 -m GET "$GRAFANA_URL/api/health"

# Test Prometheus performance
echo "📈 Testing Prometheus performance..."
PROMETHEUS_URL="https://prometheus.home.arpa"
hey -n 100 -c 10 -m GET "$PROMETHEUS_URL/-/healthy"

# Test MinIO performance
echo "💾 Testing MinIO performance..."
MINIO_URL="https://minio.home.arpa/minio/health/live"
hey -n 50 -c 5 -m GET "$MINIO_URL"

# Resource usage check
echo "🔍 Checking resource usage..."
kubectl top nodes
kubectl top pods -A --sort-by=cpu

# Storage usage
echo "💿 Checking storage usage..."
kubectl get pvc -A -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,SIZE:.status.capacity.storage,USED:.status.used

echo "✅ Performance testing completed!"
```

## 8. Maintenance and Operations

### 8.1 Automated Maintenance Script

Create the file `scripts/maintenance/daily-maintenance.sh`:
```bash
#!/bin/bash
set -e

# Configuration
LOG_FILE="/var/log/homelab-maintenance.log"
ALERT_EMAIL="admin@homelab.local"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting daily maintenance..."

# Clean up old container images
log "🧹 Cleaning up old container images..."
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | while read node; do
    log "Cleaning images on node: $node"
    kubectl debug node/$node -it --image=busybox --rm -- /bin/sh -c "crictl images | grep '<none>' | awk '{print \$3}' | xargs -r crictl rmi"
done

# Check for failed pods and restart them
log "🔍 Checking for failed pods..."
FAILED_PODS=$(kubectl get pods -A --field-selector=status.phase=Failed -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}')
if [ -n "$FAILED_PODS" ]; then
    log "Found failed pods, attempting restart..."
    echo "$FAILED_PODS" | while read namespace pod; do
        kubectl delete pod -n "$namespace" "$pod" --grace-period=0 --force
        log "Restarted failed pod: $namespace/$pod"
    done
fi

# Check certificate expiration
log "📜 Checking certificate expiration..."
kubectl get certificates -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.status.notAfter}{"\n"}{end}' | while read namespace cert expiry; do
    if [ -n "$expiry" ]; then
        expiry_epoch=$(date -d "$expiry" +%s)
        current_epoch=$(date +%s)
        days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        if [ $days_until_expiry -lt 30 ]; then
            log "WARNING: Certificate $namespace/$cert expires in $days_until_expiry days!"
            echo "Certificate $namespace/$cert expires in $days_until_expiry days" | mail -s "Certificate Expiry Warning" "$ALERT_EMAIL"
        fi
    fi
done

# Update system packages on nodes
log "📦 Updating system packages..."
kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | while read node; do
    log "Updating packages on node: $node"
    kubectl debug node/$node -it --image=alpine --rm -- /bin/sh -c "apk update && apk upgrade"
done

# Backup etcd (if external)
log "💾 Backing up etcd..."
if kubectl get pods -n kube-system | grep -q etcd; then
    ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')
    kubectl exec -n kube-system "$ETCD_POD" -- etcdctl snapshot save /tmp/etcd-backup-$(date +%Y%m%d).db
    log "Etcd backup completed"
fi

# Check disk usage
log "💿 Checking disk usage..."
kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | while read node; do
    usage=$(kubectl debug node/$node -it --image=busybox --rm -- /bin/sh -c "df -h / | tail -1 | awk '{print \$5}'" 2>/dev/null | tr -d '%')
    if [ -n "$usage" ] && [ "$usage" -gt 80 ]; then
        log "WARNING: Disk usage on node $node is ${usage}%"
        echo "Disk usage on node $node is ${usage}%" | mail -s "Disk Usage Warning" "$ALERT_EMAIL"
    fi
done

# Rotate logs
log "📋 Rotating logs..."
find /var/log -name "*.log" -type f -size +100M -exec logrotate -f {} \;

log "Daily maintenance completed!"
```

### 8.2 Monitoring Health Checks

Create the file `scripts/monitoring/health-checks.sh`:
```bash
#!/bin/bash
set -e

# Configuration
GRAFANA_URL="https://dashboard.home.arpa"
PROMETHEUS_URL="https://prometheus.home.arpa"
ALERTMANAGER_URL="https://alertmanager.home.arpa"

# Function to check HTTP endpoint
check_endpoint() {
    local url=$1
    local name=$2
    local timeout=10
    
    if curl -s --max-time $timeout "$url" > /dev/null; then
        echo "✅ $name is healthy"
        return 0
    else
        echo "❌ $name is unhealthy"
        return 1
    fi
}

# Function to check service endpoints
check_service() {
    local namespace=$1
    local service=$2
    local port=$3
    
    if kubectl get endpoints -n "$namespace" "$service" | grep -q "$port"; then
        echo "✅ Service $namespace/$service:$port is available"
        return 0
    else
        echo "❌ Service $namespace/$service:$port is unavailable"
        return 1
    fi
}

echo "🔍 Running health checks..."

# Check external endpoints
check_endpoint "$GRAFANA_URL/api/health" "Grafana"
check_endpoint "$PROMETHEUS_URL/-/healthy" "Prometheus"
check_endpoint "$ALERTMANAGER_URL/-/healthy" "Alertmanager"

# Check internal services
check_service "monitoring" "prometheus" "9090"
check_service "monitoring" "grafana" "3000"
check_service "monitoring" "alertmanager" "9093"
check_service "minio" "minio" "9000"
check_service "minio" "minio-console" "9090"
check_service "redis" "redis-master" "6379"

# Check certificate status
echo "📜 Checking certificate status..."
kubectl get certificates -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{": "}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | while read cert status; do
    if [ "$status" = "True" ]; then
        echo "✅ Certificate $cert is ready"
    else
        echo "❌ Certificate $cert is not ready"
    fi
done

# Check for critical alerts
echo "🚨 Checking for critical alerts..."
CRITICAL_ALERTS=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=ALERTS{severity=\"critical\"}" | jq -r '.data.result[].metric.alertname')
if [ -n "$CRITICAL_ALERTS" ]; then
    echo "❌ Critical alerts detected:"
    echo "$CRITICAL_ALERTS"
else
    echo "✅ No critical alerts"
fi

# Check pod restart counts
echo "🔄 Checking pod restart counts..."
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{": "}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | while read pod restarts; do
    if [ "$restarts" -gt 5 ]; then
        echo "⚠️  Pod $pod has $restarts restarts"
    fi
done

echo "✅ Health checks completed!"
```

## 9. Troubleshooting Guide

### 9.1 Common Issues and Solutions

Create the file `docs/troubleshooting/common-issues.md`:
```markdown
# Common Issues and Solutions

## Certificate Issues

### Problem: Certificate not ready
```bash
# Check certificate status
kubectl describe certificate -n <namespace> <certificate-name>

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Force certificate renewal
kubectl delete certificate -n <namespace> <certificate-name>
```

### Problem: TLS handshake error
```bash
# Check ingress configuration
kubectl describe ingress -n <namespace> <ingress-name>

# Verify certificate is valid
openssl s_client -connect <hostname>:443 -servername <hostname>
```

## Storage Issues

### Problem: PersistentVolumeClaim pending
```bash
# Check PVC events
kubectl describe pvc -n <namespace> <pvc-name>

# Check storage class
kubectl get storageclass

# Check available storage
kubectl get pv
```

### Problem: Disk pressure on nodes
```bash
# Check node conditions
kubectl describe node <node-name>

# Clean up unused images
kubectl debug node/<node-name> -it --image=busybox -- crictl images | grep '<none>'

# Check disk usage
kubectl debug node/<node-name> -it --image=busybox -- df -h
```

## Network Issues

### Problem: Pod cannot reach service
```bash
# Check network policies
kubectl get networkpolicies -n <namespace>

# Test connectivity from pod
kubectl exec -it <pod-name> -n <namespace> -- ping <service-name>

# Check DNS resolution
kubectl exec -it <pod-name> -n <namespace> -- nslookup <service-name>
```

### Problem: Ingress not working
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress configuration
kubectl describe ingress -n <namespace> <ingress-name>

# Test ingress endpoint
curl -I http://<ingress-ip> -H "Host: <hostname>"
```

## Monitoring Issues

### Problem: Prometheus not scraping targets
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090/targets

# Check service discovery
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090/service-discovery
```

### Problem: Grafana not showing data
```bash
# Check Grafana logs
kubectl logs -n monitoring deployment/grafana

# Check data source connectivity
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Visit http://localhost:3000 and check data sources
```

## Backup Issues

### Problem: Velero backup failing
```bash
# Check Velero logs
kubectl logs -n velero deployment/velero

# Check backup status
velero backup describe <backup-name> --details

# Test backup storage
kubectl exec -n velero deployment/velero -- velero backup-location get
```
```

### 9.2 Diagnostic Script

Create the file `scripts/diagnostics/full-diagnostic.sh`:
```bash
#!/bin/bash
set -e

# Configuration
DIAGNOSTIC_DIR="/tmp/homelab-diagnostic-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$DIAGNOSTIC_DIR"

echo "🔍 Running full system diagnostic..."
echo "📁 Saving results to: $DIAGNOSTIC_DIR"

# Cluster information
echo "📋 Collecting cluster information..."
kubectl cluster-info dump > "$DIAGNOSTIC_DIR/cluster-info.txt"
kubectl get nodes -o wide > "$DIAGNOSTIC_DIR/nodes.txt"
kubectl get namespaces > "$DIAGNOSTIC_DIR/namespaces.txt"

# System pods status
echo "🔄 Checking system pods..."
kubectl get pods -A > "$DIAGNOSTIC_DIR/all-pods.txt"
kubectl get pods -n kube-system > "$DIAGNOSTIC_DIR/system-pods.txt"

# Events
echo "📅 Collecting events..."
kubectl get events -A --sort-by='.lastTimestamp' > "$DIAGNOSTIC_DIR/events.txt"

# Logs from critical components
echo "📝 Collecting logs from critical components..."
kubectl logs -n kube-system -l component=kube-apiserver > "$DIAGNOSTIC_DIR/kube-apiserver-logs.txt" 2>&1 || true
kubectl logs -n kube-system -l component=kube-controller-manager > "$DIAGNOSTIC_DIR/kube-controller-manager-logs.txt" 2>&1 || true
kubectl logs -n kube-system -l component=kube-scheduler > "$DIAGNOSTIC_DIR/kube-scheduler-logs.txt" 2>&1 || true
kubectl logs -n kube-system -l component=etcd > "$DIAGNOSTIC_DIR/etcd-logs.txt" 2>&1 || true

# Network connectivity tests
echo "🌐 Testing network connectivity..."
kubectl run -it --rm diagnostic-pod --image=busybox --restart=Never -- nslookup kubernetes.default > "$DIAGNOSTIC_DIR/dns-test.txt" 2>&1 || true

# Storage status
echo "💾 Checking storage status..."
kubectl get pv > "$DIAGNOSTIC_DIR/persistent-volumes.txt"
kubectl get pvc -A > "$DIAGNOSTIC_DIR/persistent-volume-claims.txt"

# Certificate status
echo "📜 Checking certificate status..."
kubectl get certificates -A > "$DIAGNOSTIC_DIR/certificates.txt"
kubectl get clusterissuers > "$DIAGNOSTIC_DIR/cluster-issuers.txt"

# Resource usage
echo "📊 Checking resource usage..."
kubectl top nodes > "$DIAGNOSTIC_DIR/node-resource-usage.txt" 2>&1 || true
kubectl top pods -A > "$DIAGNOSTIC_DIR/pod-resource-usage.txt" 2>&1 || true

# Create archive
echo "📦 Creating diagnostic archive..."
cd /tmp
tar -czf "$DIAGNOSTIC_DIR.tar.gz" "$(basename "$DIAGNOSTIC_DIR")"

echo "✅ Diagnostic completed!"
echo "📁 Archive created: $DIAGNOSTIC_DIR.tar.gz"
echo "📧 Please send this archive to support team if needed"
```

Make the script executable:
```bash
chmod +x scripts/diagnostics/full-diagnostic.sh
```

## 10. Summary and Next Steps

This implementation guide provides a comprehensive approach to setting up a production-ready Kubernetes homelab with:

### ✅ Completed Features
- **Security Hardening**: Network policies, pod security standards, secret management
- **High Availability**: Multi-replica deployments, health checks, resource limits
- **Backup Strategy**: Velero integration, automated database backups
- **Monitoring**: Complete observability stack with alerting
- **GitOps**: ArgoCD automation with ApplicationSets
- **Documentation**: Comprehensive troubleshooting guides

### 🔄 Next Steps
1. **Customize configurations** for your specific environment
2. **Set up CI/CD pipeline** for automated deployments
3. **Implement cost optimization** strategies
4. **Add compliance monitoring** and reporting
5. **Set up disaster recovery** procedures
6. **Train team members** on the new architecture

### 📚 Additional Resources
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/)
- [MicroK8s Documentation](https://microk8s.io/docs)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/)
- [Prometheus Monitoring Guide](https://prometheus.io/docs/)

This implementation transforms your basic Kubernetes setup into an enterprise-grade platform suitable for production workloads while maintaining the simplicity needed for a homelab environment.