# MinIO - Object Storage (K3s Homelab)

Armazenamento de objetos compatível com S3 para K3s.

## 🚀 Visão Rápida

- **Namespace**: `minio`
- **StatefulSet**: `minio` com 1 réplica
- **Console**: https://minio-console.home.arpa/
- **S3 API**: https://minio-s3.home.arpa/
- **Credenciais**: `admin` / `Admin@123`
- **Armazenamento**: 100Gi

## 📦 Componentes Instalados

### Services
- `minio-service` (ClusterIP): Portas 9000, 9001
- `minio-headless` (Headless): Para clustering
- `minio-console` (ClusterIP): Console UI (9001)

### Ingress
- `minio-console-ingress`: https://minio-console.home.arpa/
- `minio-s3-ingress`: https://minio-s3.home.arpa/

### Volumes
- **Data**: 100Gi (armazenamento de objetos)

### Segurança
- TLS habilitado (cert-manager com local-ca)
- Credenciais: admin/Admin@123

## 🛠️ Instalação

```bash
cd /home/k8s1/k8s/minio

# Método 1: Usar script de instalação
./install-minio-k3s.sh

# Método 2: Manual
kubectl apply -f 00-namespace.yaml
kubectl apply -f 03-rbac.yaml
kubectl apply -f 01-secret.yaml
kubectl apply -f 23-minio-console-certificate.yaml
kubectl apply -f 24-minio-s3-certificate.yaml
kubectl apply -f 11-headless-svc.yaml
kubectl apply -f 12-client-svc.yaml
kubectl apply -f 20-minio-console-svc.yaml
kubectl apply -f 20-statefulset.yaml
kubectl apply -f 21-minio-console-ingress.yaml
kubectl apply -f 22-minio-s3-ingress.yaml
```

## 🔌 Acesso

### Console Web
- **URL**: https://minio-console.home.arpa/
- **Usuário**: `admin`
- **Senha**: `Admin@123`

### S3 API Endpoints

**Dentro do cluster Kubernetes**:
```
http://minio-service.minio.svc.cluster.local:9000
```

**De fora do cluster** (via Ingress):
```
https://minio-s3.home.arpa
```

## 💻 Exemplos de Uso

### AWS CLI (s3cmd)
```bash
# Configurar AWS CLI
aws configure set aws_access_key_id admin
aws configure set aws_secret_access_key Admin@123
aws configure set default.region us-east-1

# Criar bucket
aws --endpoint-url https://minio-s3.home.arpa s3 mb s3://my-bucket

# Listar buckets
aws --endpoint-url https://minio-s3.home.arpa s3 ls

# Upload arquivo
aws --endpoint-url https://minio-s3.home.arpa s3 cp file.txt s3://my-bucket/

# Download arquivo
aws --endpoint-url https://minio-s3.home.arpa s3 cp s3://my-bucket/file.txt .
```

### Python (boto3)
```python
import boto3
from botocore.client import Config

# Configurar cliente
s3 = boto3.client(
    's3',
    endpoint_url='https://minio-s3.home.arpa',
    aws_access_key_id='admin',
    aws_secret_access_key='Admin@123',
    config=Config(signature_version='s3v4'),
    verify=False  # Para certificados self-signed
)

# Criar bucket
s3.create_bucket(Bucket='my-bucket')

# Listar buckets
response = s3.list_buckets()
for bucket in response['Buckets']:
    print(bucket['Name'])

# Upload arquivo
s3.upload_file('file.txt', 'my-bucket', 'file.txt')

# Download arquivo
s3.download_file('my-bucket', 'file.txt', 'downloaded.txt')
```

### Node.js (AWS SDK)
```javascript
const AWS = require('aws-sdk');

// Configurar cliente
const s3 = new AWS.S3({
    endpoint: 'https://minio-s3.home.arpa',
    accessKeyId: 'admin',
    secretAccessKey: 'Admin@123',
    s3ForcePathStyle: true,
    signatureVersion: 'v4',
    sslEnabled: true
});

// Criar bucket
s3.createBucket({ Bucket: 'my-bucket' }, (err, data) => {
    if (err) console.error(err);
    else console.log('Bucket criado:', data);
});

// Listar buckets
s3.listBuckets((err, data) => {
    if (err) console.error(err);
    else console.log('Buckets:', data.Buckets);
});
```

### MinIO Client (mc)
```bash
# Instalar mc
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Configurar alias
mc alias set myminio https://minio-s3.home.arpa admin Admin@123

# Listar buckets
mc ls myminio

# Criar bucket
mc mb myminio/my-bucket

# Upload arquivo
mc cp file.txt myminio/my-bucket/

# Download arquivo
mc cp myminio/my-bucket/file.txt .

# Mirror diretório
mc mirror /local/dir myminio/my-bucket/
```

## 🔧 Operações Comuns

### Verificar Status
```bash
# Status dos pods
kubectl get pods -n minio

# Status dos services
kubectl get svc -n minio

# Status dos ingress
kubectl get ingress -n minio

# Logs
kubectl logs -n minio minio-0 -f
```

### Gerenciar Buckets (via Console)
1. Acesse https://minio-console.home.arpa/
2. Login com admin/Admin@123
3. Vá para "Buckets"
4. Clique em "Create Bucket"
5. Configure políticas de acesso

### Alterar Credenciais
```bash
# Editar secret
kubectl edit secret minio-creds -n minio

# Ou recriar
kubectl delete secret minio-creds -n minio
kubectl create secret generic minio-creds \
  --from-literal=rootUser=newuser \
  --from-literal=rootPassword=newpassword \
  -n minio

# Reiniciar pod
kubectl delete pod minio-0 -n minio
```

## 📊 Monitoramento

### Métricas Prometheus
MinIO expõe métricas no endpoint:
```bash
# Dentro do cluster
curl http://minio-service.minio.svc.cluster.local:9000/minio/v2/metrics/cluster

# Via ingress
curl -k https://minio-s3.home.arpa/minio/v2/metrics/cluster
```

### Health Check
```bash
# Liveness
curl -k https://minio-s3.home.arpa/minio/health/live

# Readiness
curl -k https://minio-s3.home.arpa/minio/health/ready
```

## 💾 Backup e Recovery

### Backup via mc
```bash
# Mirror bucket para backup
mc mirror myminio/my-bucket /backup/my-bucket

# Mirror com versionamento
mc mirror --preserve myminio/my-bucket /backup/my-bucket
```

### Restore via mc
```bash
# Restaurar de backup
mc mirror /backup/my-bucket myminio/my-bucket
```

## 🚨 Troubleshooting

### Pod não inicia
```bash
# Ver logs
kubectl logs -n minio minio-0

# Descrever pod
kubectl describe pod -n minio minio-0

# Verificar PVC
kubectl get pvc -n minio
```

### Login não funciona
```bash
# Verificar credenciais
kubectl get secret minio-creds -n minio -o jsonpath='{.data.rootUser}' | base64 -d
kubectl get secret minio-creds -n minio -o jsonpath='{.data.rootPassword}' | base64 -d
```

### Erro de certificado
```bash
# Verificar certificados
kubectl get certificate -n minio

# Ver detalhes
kubectl describe certificate minio-console-tls -n minio
kubectl describe certificate minio-s3-tls -n minio
```

### Reiniciar
```bash
# Reiniciar pod
kubectl delete pod minio-0 -n minio

# Ou rollout restart
kubectl rollout restart statefulset/minio -n minio
```

## 🔒 Segurança

### Políticas de Bucket
```bash
# Via mc - Bucket público para leitura
mc policy set download myminio/my-bucket

# Bucket público para leitura/escrita
mc policy set public myminio/my-bucket

# Bucket privado
mc policy set private myminio/my-bucket

# Política customizada via Console
# Acesse Console → Buckets → [seu bucket] → Access → Manage
```

### Criar Usuários Adicionais
Via Console Web:
1. Acesse https://minio-console.home.arpa/
2. Vá para "Identity" → "Users"
3. Clique em "Create User"
4. Defina Access Key e Secret Key
5. Atribua políticas

## 🧹 Remoção

```bash
# Remover tudo
kubectl delete -f 22-minio-s3-ingress.yaml
kubectl delete -f 21-minio-console-ingress.yaml
kubectl delete -f 20-statefulset.yaml
kubectl delete -f 20-minio-console-svc.yaml
kubectl delete -f 12-client-svc.yaml
kubectl delete -f 11-headless-svc.yaml
kubectl delete -f 24-minio-s3-certificate.yaml
kubectl delete -f 23-minio-console-certificate.yaml
kubectl delete -f 01-secret.yaml
kubectl delete -f 03-rbac.yaml
kubectl delete -f 00-namespace.yaml

# Ou deletar o namespace inteiro (cuidado: apaga os dados!)
kubectl delete namespace minio
```

## 📚 Referências

- [MinIO Docs](https://min.io/docs/minio/kubernetes/upstream/)
- [MinIO Client (mc)](https://min.io/docs/minio/linux/reference/minio-mc.html)
- [S3 API Compatibility](https://min.io/docs/minio/linux/developers/s3-compatible-api.html)
- [Python SDK (boto3)](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)

## 📄 Licença

MIT
