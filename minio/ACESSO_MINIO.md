# Como Acessar o MinIO Console

## ✅ MinIO Instalado com Sucesso

O **MinIO** (S3-compatible storage) está disponível em:

**Console**: https://minio-console.home.arpa/
**S3 API**: https://minio-s3.home.arpa/

## 🔐 Credenciais de Acesso

Para acessar o console web:
- **Usuário**: `admin`
- **Senha**: `password123`

## 📋 Informações da Instalação

| Item | Valor |
|------|-------|
| **Console Web** | https://minio-console.home.arpa/ |
| **S3 API Endpoint** | https://minio-s3.home.arpa/ |
| **Ingress IP** | 192.168.1.51 |
| **Namespace** | minio |
| **StatefulSet** | minio |
| **Réplicas** | 1 (modo single node) |
| **TLS** | ✅ Sim (cert-manager local-ca) |
| **Persistência** | ✅ 100Gi |

## 🌐 Configuração DNS

### Se já configurou no roteador:
✅ Você já apontou `*.home.arpa` para `192.168.1.51` no roteador
✅ Pode acessar diretamente:
   - https://minio-console.home.arpa/
   - https://minio-s3.home.arpa/

### Se ainda não configurou localmente:

**Linux/Mac**:
```bash
echo "192.168.1.51 minio-console.home.arpa" | sudo tee -a /etc/hosts
echo "192.168.1.51 minio-s3.home.arpa" | sudo tee -a /etc/hosts
```

**Windows** (como Administrador):
```powershell
Add-Content C:\Windows\System32\drivers\etc\hosts "192.168.1.51 minio-console.home.arpa"
Add-Content C:\Windows\System32\drivers\etc\hosts "192.168.1.51 minio-s3.home.arpa"
```

## 🧪 Testar Acesso

### Método 1: Browser (Console)
1. Abra o navegador
2. Acesse: https://minio-console.home.arpa/
3. Aceite o certificado autoassinado (é esperado)
4. Login: `admin` / `password123`

### Método 2: MinIO Client (mc)

**Instalar mc**:
```bash
# Linux
curl https://dl.min.io/client/mc/release/linux-amd64/mc -o mc
chmod +x mc
sudo mv mc /usr/local/bin/

# macOS
brew install minio/stable/mc

# Windows
# Baixe de https://dl.min.io/client/mc/release/windows-amd64/mc.exe
```

**Configurar alias**:
```bash
# Adicionar servidor MinIO
mc alias set myminio https://minio-s3.home.arpa admin password123 --insecure

# Testar conexão
mc admin info myminio --insecure
```

### Método 3: AWS CLI (S3-compatible)

**Instalar AWS CLI**:
```bash
# Linux
sudo apt install awscli

# macOS
brew install awscli
```

**Configurar**:
```bash
# Criar arquivo de configuração
cat > ~/.aws/config <<EOF
[default]
region = us-east-1
output = json
EOF

cat > ~/.aws/credentials <<EOF
[default]
aws_access_key_id = admin
aws_secret_access_key = password123
EOF
```

**Usar**:
```bash
# Listar buckets
aws --endpoint-url https://minio-s3.home.arpa s3 ls --no-verify-ssl

# Criar bucket
aws --endpoint-url https://minio-s3.home.arpa s3 mb s3://mybucket --no-verify-ssl

# Upload arquivo
aws --endpoint-url https://minio-s3.home.arpa s3 cp file.txt s3://mybucket/ --no-verify-ssl

# Download arquivo
aws --endpoint-url https://minio-s3.home.arpa s3 cp s3://mybucket/file.txt . --no-verify-ssl
```

## 🎯 O que você pode fazer no MinIO Console

✅ **Gerenciar buckets** (criar, deletar, configurar)
✅ **Upload e download** de arquivos
✅ **Organizar objetos** em pastas
✅ **Configurar políticas** de acesso
✅ **Gerenciar usuários** e chaves de acesso
✅ **Configurar versionamento** de objetos
✅ **Configurar replicação** (em clusters)
✅ **Configurar lifecycle** rules
✅ **Ver estatísticas** de uso
✅ **Monitorar logs** e eventos
✅ **Configurar notificações** (webhooks, Kafka, etc)

## 📊 Recursos da Interface

### Buckets
- Criar e deletar buckets
- Configurar políticas de acesso (public/private)
- Configurar retenção de objetos
- Habilitar versionamento
- Configurar encriptação

### Object Browser
- Navegar pelos objetos
- Upload/download de arquivos
- Criar pastas
- Preview de arquivos
- Compartilhar links temporários

### Identity
- Gerenciar usuários
- Criar service accounts
- Gerenciar grupos
- Configurar políticas (policies)

### Monitoring
- Métricas de uso
- Logs de auditoria
- Gráficos de performance

### Configuration
- Settings gerais
- Notificações
- Site replication
- Tiering

## 🔌 Integração com Aplicações

### URLs de Conexão

**S3 API Endpoint**:
```
https://minio-s3.home.arpa
```

**Credenciais**:
- Access Key: `admin`
- Secret Key: `password123`

### Exemplos de Código

#### Python (boto3)
```python
import boto3
from botocore.client import Config

# Configurar cliente S3
s3 = boto3.client(
    's3',
    endpoint_url='https://minio-s3.home.arpa',
    aws_access_key_id='admin',
    aws_secret_access_key='password123',
    config=Config(signature_version='s3v4'),
    verify=False  # Aceitar certificado autoassinado
)

# Listar buckets
response = s3.list_buckets()
print('Buckets:', [bucket['Name'] for bucket in response['Buckets']])

# Criar bucket
s3.create_bucket(Bucket='mybucket')

# Upload arquivo
s3.upload_file('local_file.txt', 'mybucket', 'remote_file.txt')

# Download arquivo
s3.download_file('mybucket', 'remote_file.txt', 'downloaded_file.txt')

# Listar objetos
response = s3.list_objects_v2(Bucket='mybucket')
for obj in response.get('Contents', []):
    print(f"  {obj['Key']} ({obj['Size']} bytes)")
```

#### Python (minio client)
```python
from minio import Minio
from minio.error import S3Error

# Criar cliente MinIO
client = Minio(
    'minio-s3.home.arpa',
    access_key='admin',
    secret_key='password123',
    secure=True,  # HTTPS
    cert_check=False  # Aceitar certificado autoassinado
)

# Criar bucket
try:
    if not client.bucket_exists('mybucket'):
        client.make_bucket('mybucket')
    print('Bucket criado ou já existe')
except S3Error as err:
    print(f'Erro: {err}')

# Upload arquivo
client.fput_object('mybucket', 'remote_file.txt', 'local_file.txt')
print('Arquivo enviado')

# Download arquivo
client.fget_object('mybucket', 'remote_file.txt', 'downloaded_file.txt')
print('Arquivo baixado')

# Listar objetos
objects = client.list_objects('mybucket')
for obj in objects:
    print(f"  {obj.object_name} ({obj.size} bytes)")
```

#### Node.js (Minio SDK)
```javascript
const Minio = require('minio');

// Criar cliente
const minioClient = new Minio.Client({
    endPoint: 'minio-s3.home.arpa',
    port: 443,
    useSSL: true,
    accessKey: 'admin',
    secretKey: 'password123'
});

// Listar buckets
minioClient.listBuckets((err, buckets) => {
    if (err) return console.log(err);
    console.log('Buckets:', buckets);
});

// Upload arquivo
const file = 'local_file.txt';
minioClient.fPutObject('mybucket', 'remote_file.txt', file, (err, etag) => {
    if (err) return console.log(err);
    console.log('Upload bem-sucedido, etag:', etag);
});

// Download arquivo
minioClient.fGetObject('mybucket', 'remote_file.txt', 'downloaded_file.txt', (err) => {
    if (err) return console.log(err);
    console.log('Download bem-sucedido');
});
```

#### Java (MinIO SDK)
```java
import io.minio.MinioClient;
import io.minio.UploadObjectArgs;
import io.minio.DownloadObjectArgs;

public class MinioExample {
    public static void main(String[] args) {
        // Criar cliente
        MinioClient minioClient = MinioClient.builder()
            .endpoint("https://minio-s3.home.arpa")
            .credentials("admin", "password123")
            .build();

        try {
            // Upload arquivo
            minioClient.uploadObject(
                UploadObjectArgs.builder()
                    .bucket("mybucket")
                    .object("remote_file.txt")
                    .filename("local_file.txt")
                    .build()
            );
            System.out.println("Upload bem-sucedido");

            // Download arquivo
            minioClient.downloadObject(
                DownloadObjectArgs.builder()
                    .bucket("mybucket")
                    .object("remote_file.txt")
                    .filename("downloaded_file.txt")
                    .build()
            );
            System.out.println("Download bem-sucedido");
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

#### Go
```go
package main

import (
    "context"
    "log"
    "github.com/minio/minio-go/v7"
    "github.com/minio/minio-go/v7/pkg/credentials"
)

func main() {
    // Criar cliente
    minioClient, err := minio.New("minio-s3.home.arpa", &minio.Options{
        Creds:  credentials.NewStaticV4("admin", "password123", ""),
        Secure: true,
    })
    if err != nil {
        log.Fatalln(err)
    }

    // Upload arquivo
    _, err = minioClient.FPutObject(context.Background(),
        "mybucket", "remote_file.txt", "local_file.txt",
        minio.PutObjectOptions{})
    if err != nil {
        log.Fatalln(err)
    }
    log.Println("Upload bem-sucedido")

    // Download arquivo
    err = minioClient.FGetObject(context.Background(),
        "mybucket", "remote_file.txt", "downloaded_file.txt",
        minio.GetObjectOptions{})
    if err != nil {
        log.Fatalln(err)
    }
    log.Println("Download bem-sucedido")
}
```

## 🔧 Status do Serviço

Verificar se o MinIO está rodando:

```bash
# Como usuário k8s1
kubectl get pods -n minio
kubectl get svc -n minio
kubectl get ingress -n minio
kubectl get pvc -n minio
```

Ver logs:
```bash
kubectl logs -n minio minio-0 -f
```

Entrar no pod (troubleshooting):
```bash
kubectl exec -it -n minio minio-0 -- sh

# Dentro do pod, usar mc
mc admin info local
mc admin trace local
```

Reiniciar (se necessário):
```bash
kubectl rollout restart statefulset/minio -n minio
```

## 📊 Monitoramento

### Prometheus Metrics
MinIO expõe métricas Prometheus:

```bash
# Dentro do cluster
curl http://minio-service.minio.svc.cluster.local:9000/minio/v2/metrics/cluster
```

### Grafana Dashboard
Você pode importar dashboards MinIO no Grafana:
- Dashboard ID: 13502 (MinIO Dashboard)

## 💾 Backup e Recovery

### Backup de Dados
```bash
# Usando mc mirror (sync)
mc mirror myminio/mybucket /backup/mybucket --insecure

# Usando mc cp (copy)
mc cp --recursive myminio/mybucket /backup/mybucket --insecure
```

### Restore de Dados
```bash
# Restaurar de backup
mc mirror /backup/mybucket myminio/mybucket --insecure
```

### Snapshot de PVC
```bash
# Os dados estão no PVC
kubectl get pvc -n minio

# Você pode usar ferramentas de backup do Kubernetes
# como Velero para backup/restore de PVCs
```

## 🚨 Troubleshooting

### Erro: "Página não encontrada" (404)
**Causa**: DNS não configurado
**Solução**: Configure o /etc/hosts ou DNS do roteador

### Erro: "Connection refused"
**Verificar**:
```bash
# Status do pod
kubectl get pods -n minio

# Logs
kubectl logs -n minio minio-0 --tail=50

# Port forward (teste direto)
kubectl port-forward -n minio minio-0 9001:9001
# Depois acesse: http://localhost:9001
```

### Login não funciona
**Verificar credenciais**:
```bash
kubectl get secret minio-creds -n minio -o jsonpath='{.data.rootUser}' | base64 -d
kubectl get secret minio-creds -n minio -o jsonpath='{.data.rootPassword}' | base64 -d
```

### Erro "Bucket does not exist"
**Causa**: Bucket não foi criado
**Solução**: Crie o bucket via Console ou mc:
```bash
mc mb myminio/mybucket --insecure
```

### Disco cheio
**Verificar espaço**:
```bash
kubectl exec -n minio minio-0 -- df -h /data

# Verificar PVC
kubectl get pvc -n minio
kubectl describe pvc data-minio-0 -n minio
```

## 🔒 Segurança

### Criar Service Accounts

Via Console:
1. Acesse Identity → Service Accounts
2. Clique em "Create Service Account"
3. Defina políticas de acesso
4. Salve as credenciais (Access Key e Secret Key)

Via mc CLI:
```bash
# Criar service account
mc admin user svcacct add myminio admin --insecure

# Listar service accounts
mc admin user svcacct list myminio admin --insecure

# Deletar service account
mc admin user svcacct rm myminio <access-key> --insecure
```

### Políticas de Acesso

Criar política customizada:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::mybucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::mybucket"
      ]
    }
  ]
}
```

Aplicar via mc:
```bash
mc admin policy create myminio mypolicy /path/to/policy.json --insecure
mc admin policy attach myminio mypolicy --user myuser --insecure
```

### Encriptação

Habilitar encriptação de bucket:
```bash
# Via mc
mc encrypt set sse-s3 myminio/mybucket --insecure
```

## 📱 Acesso de Outros Dispositivos

### Mesmo Computador
✅ Console: https://minio-console.home.arpa/
✅ S3 API: https://minio-s3.home.arpa/

### Outro Computador na Mesma Rede
✅ Com DNS do roteador configurado, acesse diretamente os URLs acima

### Aplicações no Kubernetes
```
# S3 API interno
http://minio-service.minio.svc.cluster.local:9000
```

## 📚 Referências

- **MinIO Official**: https://min.io/
- **MinIO Client (mc)**: https://min.io/docs/minio/linux/reference/minio-mc.html
- **S3 API Compatibility**: https://min.io/docs/minio/linux/integrations/aws-cli-with-minio.html
- **SDKs**: https://min.io/docs/minio/linux/developers/minio-drivers.html

## 🎉 Resumo

✅ MinIO instalado com sucesso
✅ Console: https://minio-console.home.arpa/
✅ S3 API: https://minio-s3.home.arpa/
✅ Login: admin / password123
✅ TLS configurado com cert-manager
✅ Persistência: 100Gi
✅ Compatível com S3 API

**Aproveite seu object storage!** 📦
