#!/bin/bash
set -e

echo "=== Instalando e Configurando Velero ==="

# Verificar se o namespace existe
echo "Verificando namespace velero..."
if ! kubectl get namespace velero &> /dev/null; then
    echo "Criando namespace velero..."
    kubectl apply -f infrastructure/backup/velero-namespace-rbac.yaml
    sleep 5
fi

# Verificar se o MinIO está instalado (para armazenamento de backups)
echo ""
echo "Verificando MinIO..."
if ! kubectl get namespace minio-system &> /dev/null; then
    echo "MinIO não encontrado. Instalando MinIO para armazenamento de backups..."
    
    # Criar namespace do MinIO
    kubectl create namespace minio-system
    
    # Instalar MinIO
    kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-storage
  namespace: minio-system
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: local-hostpath
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: minio-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: minio/minio:latest
        args:
        - server
        - /storage
        - --console-address
        - ":9001"
        env:
        - name: MINIO_ROOT_USER
          value: minioadmin
        - name: MINIO_ROOT_PASSWORD
          value: minioadmin
        ports:
        - containerPort: 9000
          name: s3
        - containerPort: 9001
          name: console
        volumeMounts:
        - name: storage
          mountPath: /storage
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: minio-storage
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: minio-system
spec:
  selector:
    app: minio
  ports:
  - name: s3
    port: 9000
    targetPort: 9000
  - name: console
    port: 9001
    targetPort: 9001
  type: ClusterIP
EOF
    
    echo "Aguardando MinIO ficar pronto..."
    kubectl wait --for=condition=available --timeout=300s deployment/minio -n minio-system
    
    echo "Criando bucket no MinIO..."
    # Criar bucket usando MinIO client
    kubectl run minio-client --image=minio/mc:latest --rm -i --restart=Never -- \
        sh -c "
        mc alias set local http://minio.minio-system.svc.cluster.local:9000 minioadmin minioadmin &&
        mc mb local/velero-backups || true
        " || echo "Bucket pode já existir"
fi

# Instalar Velero CLI se não estiver instalado
echo ""
echo "Verificando Velero CLI..."
if ! command -v velero &> /dev/null; then
    echo "Velero CLI não encontrado. Instalando..."
    VELERO_VERSION="v1.12.0"
    
    # Detectar arquitetura
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="arm" ;;
        *) echo "Arquitetura não suportada: $ARCH"; exit 1 ;;
    esac
    
    wget "https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/velero-${VELERO_VERSION}-linux-${ARCH}.tar.gz"
    tar -xvf "velero-${VELERO_VERSION}-linux-${ARCH}.tar.gz"
    sudo mv velero-${VELERO_VERSION}-linux-${ARCH}/velero /usr/local/bin/
    sudo chmod +x /usr/local/bin/velero
    rm -rf "velero-${VELERO_VERSION}-linux-${ARCH}" "velero-${VELERO_VERSION}-linux-${ARCH}.tar.gz"
fi

# Aplicar configuração do Velero
echo ""
echo "Aplicando configuração do Velero..."
kubectl apply -f infrastructure/backup/velero-deployment.yaml

# Aguardar Velero ficar pronto
echo ""
echo "Aguardando Velero ficar pronto..."
kubectl wait --for=condition=available --timeout=300s deployment/velero -n velero

# Configurar localizações de backup
echo ""
echo "Configurando localizações de backup..."
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: default
  namespace: velero
spec:
  provider: aws
  objectStorage:
    bucket: velero-backups
    prefix: kubernetes-backups
  config:
    region: minio
    s3ForcePathStyle: "true"
    s3Url: http://minio.minio-system.svc.cluster.local:9000
    publicUrl: http://minio.minio-system.svc.cluster.local:9000
EOF

# Criar localização de snapshot de volume
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: VolumeSnapshotLocation
metadata:
  name: default
  namespace: velero
spec:
  provider: aws
  config:
    region: minio
EOF

echo ""
echo "=== Velero instalado com sucesso! ==="
echo ""
echo "Para verificar o status:"
echo "kubectl get all -n velero"
echo ""
echo "Para criar um backup manual:"
echo "velero backup create manual-backup-$(date +%Y%m%d-%H%M%S) --include-namespaces default,monitoring"
echo ""
echo "Para listar backups:"
echo "velero backup get"
echo ""
echo "Para acessar o console do MinIO:"
echo "kubectl port-forward -n minio-system service/minio 9001:9001"
echo "Acesse: http://localhost:9001 (usuário: minioadmin, senha: minioadmin)"